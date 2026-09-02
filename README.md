# Family Calendar

Flutter + Node family wall calendar. Phones manage Google accounts; the wall kiosk displays a read-only merged grid.

| Flavor | Package | APK output | Distribution |
|--------|---------|------------|--------------|
| **mobile** | `com.smircich.familycalendar` | `app-mobile-release.apk` / iOS IPA | Firebase App Distribution (phones) |
| **kiosk** | `com.smircich.familycalendar.kiosk` | `app-kiosk-release.apk` | OTA from server (or ADB for first install) |

**Build hosts:** **Android APKs** (mobile + kiosk) are built on **bering-dev** (Linux). **iOS IPAs** are built on a **Mac** with Xcode. Windows `.bat` scripts remain for **USB sideload** of the kiosk (`kiosk-setup.bat`) only — not for release builds.

Version is set in `app/pubspec.yaml` (`version: 1.0.1+17` → name `1.0.1`, build number `17`). Bump the name for user-visible releases (`1.0.2`, …) and the number after `+` every build.

See `AGENTS.md` for architecture and server setup.

## Server (bering-dev) — nginx, PM2, kiosk OTA

Public URL: `https://smircich.ddns.net` (nginx on **443** → Node on `127.0.0.1:3847`).

| What | Where |
|------|--------|
| nginx site config | `/etc/nginx/sites-available/default` (editable by `andy`; **reload needs sudo**) |
| Node app + `.env` | `/home/andy/calendar/` (PM2: `family-calendar`) |
| Event sort rules | `server/event-display-rules.json` (reloads on save; no app rebuild) |
| Kiosk APK on disk | `/var/www/family-calendar/releases/app-kiosk-release.apk` |
| Kiosk APK URL | `https://smircich.ddns.net/releases/app-kiosk-release.apk` |

### nginx reload (after editing default)

```bash
sudo nginx -t && sudo systemctl reload nginx
```

The `443` server block for `smircich.ddns.net` includes:

- `location /api/` → `http://127.0.0.1:3847`
- `location /releases/` → static APK from `/var/www/family-calendar/releases/`

Reference snippet: `server/deploy/nginx-family-calendar.conf.example`

### Event sort order (doctor / work shifts at top)

Edit **`server/event-display-rules.json`** on bering-dev. The server assigns each event a `display_priority` (0 = top). Changes apply on the next calendar poll (~60s); **no Flutter rebuild**.

```json
{
  "doctor": {
    "title_keywords": ["abby", "bobby", "shockwave"],
    "title_contains": ["doctor", " appointment", "appt"],
    "title_starts_with": ["dr ", "dr.", "appointment"]
  },
  "work_shift": {
    "ics_calendars": true,
    "title_keywords": [],
    "title_contains": ["shift", "work", "on call", "on-call"]
  }
}
```

- **`title_keywords`** — substring match anywhere in the title (add new doctor names here)
- **`title_contains`** / **`title_starts_with`** — additional patterns
- **`ics_calendars`** — treat all ICS/work-shift feed events as work shifts (priority 1)

Optional override path: `EVENT_DISPLAY_RULES_PATH` in `.env`.

### Android signing (mobile + kiosk)

Both Android flavors use **`android/key.properties`** on **bering-dev** (via `setup-android-signing.sh`). Every release must use the **same signing key** — otherwise Firebase installs uninstall/reinstall and kiosk OTA fails with “App not installed”.

**iOS does not use this keystore** — phones are signed in Xcode with your Apple Developer certificate (`build-ios.sh` on a Mac).

One-time setup:

```bash
# From Windows (one-time): upload the keystore that signed tablets already in the field
app\scripts\upload-android-keystore.bat

# On bering-dev (canonical Android build host):
app/scripts/setup-android-signing.sh --import ~/.config/family-calendar/windows-debug.keystore
```

`build-mobile.sh` and `build-kiosk.sh` **auto-import** that keystore if `key.properties` is missing, or **exit with an error**. After each build, and before Firebase/OTA upload, scripts print **`Verified signing certificate matches key.properties`** — do not distribute if that line is missing.

Legacy script names `upload-kiosk-keystore.bat` and `setup-kiosk-signing.sh` still work (they call the Android versions).

### Publish a kiosk release (OTA)

All steps on **bering-dev** after `git pull`:

1. **Bump version** in `app/pubspec.yaml` (e.g. `1.0.1+19`).
2. **Build and deploy:**

```bash
app/scripts/build-kiosk.sh
app/scripts/distribute-kiosk.sh    # copies to /var/www/family-calendar/releases/
```

3. **Update `.env`** in `/home/andy/calendar/.env` (must match `pubspec.yaml`):

```env
KIOSK_LATEST_VERSION=1.0.1
KIOSK_LATEST_BUILD=19
KIOSK_APK_URL=https://smircich.ddns.net/releases/app-kiosk-release.apk
KIOSK_RELEASE_NOTES=Short note shown on the wall admin screen
```

4. **Restart Node:**

```bash
cd ~/calendar/server && npm run build && pm2 restart family-calendar
```

5. **On the wall tablet:** tap **“Family Calendar” in the title bar 7 times** → **Check for updates** → **Download and install** → tap **Install** on the Android prompt.

The installer briefly exits kiosk lock mode so the system prompt can appear. If prompted once, enable **Install unknown apps** for Family Calendar in Settings, then retry.

If install fails with **“App not installed”**, the APK signing key does not match the installed app — see **Signing** above.

Update check API: `GET /api/v1/kiosk/update?build=N` (returns `204` if already current).

**First install** on a new tablet still requires USB/ADB once from a Windows PC (`kiosk-setup.bat`); OTA handles updates after that.

## Prerequisites

- **Android builds:** bering-dev with Flutter + Android SDK (`app/scripts/setup-dev-android.sh`)
- **Firebase (mobile):** `npx firebase-tools login` on bering-dev (one-time)
- **iOS (phones):** Mac with Xcode, Apple Distribution cert, Ad Hoc devices registered
- **Kiosk first install:** Windows PC with `adb` in PATH, USB debugging on tablet
- **`.env`** at repo root on bering-dev (and on Mac for iOS distribute) with at least:

```env
ANDROID_APP_ID=1:YOUR_PROJECT:android:YOUR_APP_HASH
IOS_APP_ID=1:YOUR_PROJECT:ios:YOUR_APP_HASH
```

Create Firebase tester groups **`family-android`** and **`family-ios`** before distributing. Group names are hard-coded in the distribute scripts.

## Android builds (bering-dev)

**Canonical build host for mobile and kiosk APKs.** iOS builds stay on Mac (below).

### One-time setup

```bash
cd ~/calendar
chmod +x app/scripts/*.sh   # once, after clone
app/scripts/setup-dev-android.sh
app/scripts/setup-android-signing.sh --import ~/.config/family-calendar/windows-debug.keystore
npx firebase-tools login    # once, for mobile Firebase upload
```

Gradle heap is capped at 2 GB in `app/android/gradle.properties` for the VM. Build **mobile and kiosk separately** (not in one shell chain) if memory is tight.

### Every release

```bash
cd ~/calendar && git pull

# Mobile → Firebase
app/scripts/build-mobile.sh
app/scripts/distribute-mobile.sh "Build N: release notes"

# Kiosk → OTA (also bump KIOSK_* in .env — see [Publish a kiosk release](#publish-a-kiosk-release-ota))
app/scripts/build-kiosk.sh
app/scripts/distribute-kiosk.sh
cd ~/calendar/server && pm2 restart family-calendar

# Or mobile + kiosk build/upload in one go (kiosk still needs .env + pm2):
app/scripts/android-release.sh "Build N: release notes"
```

Confirm each build prints **`Verified signing certificate matches key.properties`** before distributing.

### Push mobile build (checklist)

1. Bump `app/pubspec.yaml` (e.g. `1.0.1+23`).
2. Commit and push; on bering-dev: `git pull`.
3. `app/scripts/build-mobile.sh` then `app/scripts/distribute-mobile.sh "…"`.
4. Phones install from Firebase email (should **update in place**, not uninstall/reinstall).

**Kiosk OTA** is separate — bump `KIOSK_LATEST_BUILD` in `.env` only when you deploy a kiosk APK.

**iOS (Mac):** after `git pull`, run `app/scripts/ios-release.sh "same notes"` (same `pubspec` build number).

Headless Firebase (optional): `npx firebase-tools login:ci` → set `FIREBASE_TOKEN` in `.env`.

## Mobile (phones) — macOS / iOS

Scripts in `app/scripts/`. Requires Xcode signing (Runner → Automatically manage signing).

One-time Firebase login (uses `npx` if `firebase` is not global):

```bash
npx firebase-tools login
```

### Build + upload (first time and each release)

```bash
chmod +x app/scripts/*.sh   # once, after clone
app/scripts/ios-release.sh "First iOS family build"
```

### Step by step

```bash
app/scripts/build-ios.sh
app/scripts/distribute-ios.sh "Release notes here"
```

Reads `IOS_APP_ID` from `.env`. Uploads to group **`family-ios`**.

Output: `app/build/ios/ipa/*.ipa` (Ad Hoc, bundle `com.smircich.familycalendar`).

**Before first build:** register App ID **`com.smircich.familycalendar`** + family iPhone UDIDs in Apple Developer; Firebase iOS app must use the same bundle ID.

## Kiosk (wall tablet) — USB sideload (Windows)

**Release builds and OTA deploy happen on bering-dev** ([Android builds](#android-builds-bering-dev), [kiosk OTA](#publish-a-kiosk-release-ota)). Use Windows only for the **first USB install** (or recovery) with a kiosk APK copied from bering-dev or built there.

Tablet on USB, then:

```cmd
app\scripts\kiosk-setup.bat
```

Or manually (APK path may be a copy from bering-dev):

```cmd
adb uninstall com.smircich.familycalendar.kiosk
adb install -r app-kiosk-release.apk
adb shell am start -n com.smircich.familycalendar.kiosk/com.familycalendar.family_calendar.MainActivity
```

After a package-name change, run `kiosk-setup.bat` again to set HOME and re-pair the device.

OTA updates after the first install: [Publish a kiosk release (OTA)](#publish-a-kiosk-release-ota).

## Dev: run in Chrome (mobile UI)

```cmd
cd app
flutter run -d chrome -t lib/main_mobile.dart
```

## Manual Flutter commands (bering-dev)

```bash
cd ~/calendar/app
source ../app/scripts/_android-env.sh

flutter build apk --flavor mobile -t lib/main_mobile.dart --release
flutter build apk --flavor kiosk -t lib/main_kiosk.dart --release
```

Prefer `app/scripts/build-mobile.sh` and `app/scripts/build-kiosk.sh` — they verify package name and signing.

## Script reference

| Script | Purpose |
|--------|---------|
| **bering-dev (Android)** | |
| `app/scripts/setup-dev-android.sh` | One-time JDK + Android SDK |
| `app/scripts/setup-android-signing.sh` | Configure `key.properties` for mobile + kiosk |
| `app/scripts/build-mobile.sh` | Build phone APK |
| `app/scripts/distribute-mobile.sh` | Upload phone APK to Firebase |
| `app/scripts/build-kiosk.sh` | Build wall APK |
| `app/scripts/distribute-kiosk.sh` | Deploy wall APK for OTA |
| `app/scripts/android-release.sh` | Build + distribute mobile + kiosk |
| **Mac (iOS)** | |
| `app/scripts/build-ios.sh` | Build phone IPA |
| `app/scripts/distribute-ios.sh` | Upload phone IPA to Firebase |
| `app/scripts/ios-release.sh` | Build + upload phone IPA |
| **Windows (USB sideload only)** | |
| `app/scripts/upload-android-keystore.bat` | One-time: upload signing key to bering-dev |
| `app/scripts/kiosk-setup.bat` | ADB install + HOME launcher setup |
| **Legacy (avoid for releases)** | `.bat` build/distribute scripts, PowerShell `.ps1` equivalents |

## Common mistakes

- **Building Android on Windows:** release APKs are built on **bering-dev** — Windows is only for USB sideload (`kiosk-setup.bat`) and one-time keystore upload
- **Wrong APK on Firebase:** use `build-mobile.sh`, not `build-kiosk.sh`
- **Gradle hang on bering-dev:** build mobile and kiosk in **separate** shell sessions; `pkill -f GradleDaemon` if stuck
- **Kiosk pairing lost:** new package install = fresh app; generate a new pairing code on a phone
- **Google sign-in 403 / “app has not completed verification”:** the OAuth app is in **Testing** mode. Each family member’s Google email must be added as a **Test user** on the [OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent) in the same Google Cloud project as `GOOGLE_CLIENT_ID`. Set **Privacy policy URL** to `https://smircich.ddns.net/legal/privacy` and **Authorized redirect URI** to `https://smircich.ddns.net/api/v1/calendars/oauth/callback`. Full Google verification is only needed if you publish the app publicly (not required for family-only use).
- **Firebase install uninstalls then reinstalls:** the APK was signed with a **different key** than the installed app (common if `android/key.properties` was missing on bering-dev — Linux uses a different debug keystore than Windows). Run `app/scripts/setup-android-signing.sh --import ~/.config/family-calendar/windows-debug.keystore` before building; build scripts now fail or auto-configure if signing is wrong. Same key is required for **mobile Firebase** and **kiosk OTA**.
