# Family Calendar

Flutter + Node family wall calendar. Phones manage Google accounts; the wall kiosk displays a read-only merged grid.

| Flavor | Package | APK output | Distribution |
|--------|---------|------------|--------------|
| **mobile** | `com.smircich.familycalendar` | `app-mobile-release.apk` / iOS IPA | Firebase App Distribution (phones) |
| **kiosk** | `com.smircich.familycalendar.kiosk` | `app-kiosk-release.apk` | OTA from server (or ADB for first install) |

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

Both Android flavors use **`android/key.properties`** (via `setup-android-signing.sh`). The **same Windows debug keystore** must sign every mobile and kiosk release — otherwise Firebase installs uninstall/reinstall and kiosk OTA fails with “App not installed”.

**iOS does not use this keystore** — phones are signed in Xcode with your Apple Developer certificate (`build-ios.sh` on a Mac).

One-time setup:

```bash
# From Windows (PC that signed prior Android builds):
app\scripts\upload-android-keystore.bat

# On bering-dev:
app/scripts/setup-android-signing.sh --import ~/.config/family-calendar/windows-debug.keystore
```

`build-mobile.sh` and `build-kiosk.sh` **auto-import** that keystore if `key.properties` is missing, or **exit with an error**. After each build, and before Firebase/OTA upload, scripts print **`Verified signing certificate matches key.properties`** — do not distribute if that line is missing.

Legacy script names `upload-kiosk-keystore.bat` and `setup-kiosk-signing.sh` still work (they call the Android versions).

### Publish a kiosk release (OTA)

1. **Bump version** in `app/pubspec.yaml` (e.g. `1.0.1+19`).
2. **Build** with signing configured: `app/scripts/build-kiosk.sh`
3. **Copy APK** to bering-dev (no sudo — directory is owned by `andy`):

```bash
scp app/build/app/outputs/flutter-apk/app-kiosk-release.apk \
  bering-dev:/var/www/family-calendar/releases/app-kiosk-release.apk
```

Or on bering-dev directly after building:

```bash
cp app/build/app/outputs/flutter-apk/app-kiosk-release.apk \
  /var/www/family-calendar/releases/app-kiosk-release.apk
```

4. **Update `.env`** in `/home/andy/calendar/.env` (must match `pubspec.yaml`):

```env
KIOSK_LATEST_VERSION=1.0.1
KIOSK_LATEST_BUILD=19
KIOSK_APK_URL=https://smircich.ddns.net/releases/app-kiosk-release.apk
KIOSK_RELEASE_NOTES=Short note shown on the wall admin screen
```

5. **Restart Node:**

```bash
cd ~/calendar/server && npm run build && pm2 restart family-calendar
```

6. **On the wall tablet:** tap **“Family Calendar” in the title bar 7 times** → **Check for updates** → **Download and install** → tap **Install** on the Android prompt.

The installer briefly exits kiosk lock mode so the system prompt can appear. If prompted once, enable **Install unknown apps** for Family Calendar in Settings, then retry.

If install fails with **“App not installed”**, the APK signing key does not match the installed app — see **Signing** above.

Update check API: `GET /api/v1/kiosk/update?build=N` (returns `204` if already current).

**First install** on a new tablet still requires USB/ADB once (`kiosk-setup.bat`); OTA handles updates after that.

## Prerequisites

- Flutter SDK (with Android toolchain)
- **Windows:** run `.bat` scripts from `app/scripts/` (safe from any directory)
- **Firebase (mobile):** Node.js + `npx firebase-tools login` (or `npm install -g firebase-tools`)
- **iOS (phones):** Mac with Xcode, Apple Distribution cert, Ad Hoc devices registered
- **Kiosk (wall):** `adb` in PATH, USB debugging on tablet
- **`.env`** at repo root with at least:

```env
ANDROID_APP_ID=1:YOUR_PROJECT:android:YOUR_APP_HASH
IOS_APP_ID=1:YOUR_PROJECT:ios:YOUR_APP_HASH
```

Create Firebase tester groups **`family-android`** and **`family-ios`** before distributing. Group names are hard-coded in the distribute scripts.

## Android builds on bering-dev (Linux)

One-time setup (no root — installs JDK + Android SDK under `~/develop` and `~/Android`):

```bash
chmod +x app/scripts/*.sh   # once, after clone
app/scripts/setup-dev-android.sh
```

Then build / release:

```bash
app/scripts/build-mobile.sh
app/scripts/distribute-mobile.sh "Release notes"   # verifies signing before upload
app/scripts/build-kiosk.sh
app/scripts/distribute-kiosk.sh                  # verifies signing before deploy
# or all Android steps:
app/scripts/android-release.sh "Release notes"
```

### Push mobile build (bering-dev checklist)

1. Bump `app/pubspec.yaml` (e.g. `1.0.1+23` — name + build number after `+`).
2. Commit and push; on bering-dev: `git pull`.
3. Build and upload:

```bash
app/scripts/build-mobile.sh
app/scripts/distribute-mobile.sh "Build 23: …"
```

4. Confirm both scripts print **`Verified signing certificate matches key.properties`**.
5. Phones: install from Firebase App Distribution email (should **update in place**, not uninstall/reinstall).

**Kiosk OTA** is separate — only bump `KIOSK_LATEST_BUILD` in `.env` when you build and deploy a kiosk APK. Mobile-only releases do not require kiosk changes.

**iOS (Mac):** after `git pull`, run `app/scripts/ios-release.sh "same notes"` (uses same `pubspec` build number).

Firebase upload on the server (one-time, interactive):

```bash
npx firebase-tools login
# headless CI alternative: npx firebase-tools login:ci  → set FIREBASE_TOKEN in .env
```

**Note:** Gradle heap is capped at 2 GB in `app/android/gradle.properties` so builds fit the dev VM (15 GB RAM). First build downloads NDK/CMake automatically if not pre-installed by the setup script.

## Mobile (phones) — Windows

All scripts live in `app/scripts/`.

### Build only

```cmd
app\scripts\build-mobile.bat
```

Runs:

```cmd
flutter build apk --flavor mobile -t lib/main_mobile.dart --release
```

Output: `app\build\app\outputs\flutter-apk\app-mobile-release.apk`

Verifies package `com.smircich.familycalendar` before finishing.

### Upload to Firebase

```cmd
app\scripts\distribute-mobile.bat "Release notes here"
```

Reads `ANDROID_APP_ID` from `.env`. Uploads to group **`family-android`**. Refuses kiosk APKs.

### Build + upload

```cmd
app\scripts\mobile-release.bat "Release notes here"
```

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

## Kiosk (wall tablet) — Windows

### Build only

```cmd
app\scripts\build-kiosk.bat
```

Runs:

```cmd
flutter build apk --flavor kiosk -t lib/main_kiosk.dart --release
```

Output: `app\build\app\outputs\flutter-apk\app-kiosk-release.apk`

**Do not upload this to Firebase.**

### Copy to server (OTA update)

From `app/scripts/` after `build-kiosk.bat`:

```cmd
distribute-kiosk.bat
```

Or manually:

```bash
scp ../build/app/outputs/flutter-apk/app-kiosk-release.apk \
  bering-dev:/var/www/family-calendar/releases/app-kiosk-release.apk
```

Then update `KIOSK_*` in `.env` and `pm2 restart family-calendar` — full steps in [Server (bering-dev)](#server-bering-dev--nginx-pm2-kiosk-ota).

### Install + set as HOME launcher

Tablet on USB, then:

```cmd
app\scripts\kiosk-setup.bat
```

Or manually:

```cmd
adb uninstall com.smircich.familycalendar.kiosk
adb install -r app\build\app\outputs\flutter-apk\app-kiosk-release.apk
adb shell am start -n com.smircich.familycalendar.kiosk/com.familycalendar.family_calendar.MainActivity
```

After a package-name change, run `kiosk-setup.bat` again to set HOME and re-pair the device.

OTA updates after the first install are documented in [Server (bering-dev)](#server-bering-dev--nginx-pm2-kiosk-ota) above.

## Kiosk — Linux / macOS

```bash
cd app
flutter build apk --flavor kiosk -t lib/main_kiosk.dart --release
./scripts/kiosk-setup.sh
```

## Dev: run in Chrome (mobile UI)

```cmd
cd app
flutter run -d chrome -t lib/main_mobile.dart
```

## Manual Flutter commands

If you prefer not to use scripts:

```cmd
cd app

REM Mobile
flutter build apk --flavor mobile -t lib/main_mobile.dart --release
firebase appdistribution:distribute build\app\outputs\flutter-apk\app-mobile-release.apk --app "YOUR_ANDROID_APP_ID" --groups "family" --release-notes "Notes"

REM Kiosk
flutter build apk --flavor kiosk -t lib/main_kiosk.dart --release
adb install -r build\app\outputs\flutter-apk\app-kiosk-release.apk
```

Bump version in `app/pubspec.yaml` before each release (e.g. `1.0.2+12` — name for humans, number after `+` for Android/iOS build codes).

## Script reference

| Script | Purpose |
|--------|---------|
| `app/scripts/build-mobile.bat` | Build phone APK (Android) |
| `app/scripts/distribute-mobile.bat` | Upload phone APK to Firebase |
| `app/scripts/mobile-release.bat` | Build + upload phone APK (Android) |
| `app/scripts/build-ios.sh` | Build phone IPA (iOS) |
| `app/scripts/distribute-ios.sh` | Upload phone IPA to Firebase |
| `app/scripts/ios-release.sh` | Build + upload phone IPA (iOS) |
| `app/scripts/build-kiosk.bat` | Build wall APK |
| `app/scripts/distribute-kiosk.bat` | Upload wall APK to bering-dev (OTA) |
| `app/scripts/distribute-kiosk.sh` | Same (Linux/macOS) |
| `app/scripts/kiosk-setup.bat` | ADB install + HOME launcher setup (Windows) |
| `app/scripts/kiosk-setup.sh` | Same for Linux/macOS |
| `app/scripts/_verify-apk-package.bat` | Internal: package check (used by build/distribute) |

Optional PowerShell equivalents: `app/scripts/*.ps1` (same behavior; `.bat` is preferred on Windows).

## Common mistakes

- **Wrong APK on Firebase:** use `build-mobile.bat`, not `build-kiosk.bat`
- **Stale APK:** rebuild mobile after building kiosk; distribute script warns if kiosk APK is newer
- **Firebase group error:** create tester group in Firebase Console first (default name: `family`)
- **Kiosk pairing lost:** new package install = fresh app; generate a new pairing code on a phone
- **Google sign-in 403 / “app has not completed verification”:** the OAuth app is in **Testing** mode. Each family member’s Google email must be added as a **Test user** on the [OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent) in the same Google Cloud project as `GOOGLE_CLIENT_ID`. Set **Privacy policy URL** to `https://smircich.ddns.net/legal/privacy` and **Authorized redirect URI** to `https://smircich.ddns.net/api/v1/calendars/oauth/callback`. Full Google verification is only needed if you publish the app publicly (not required for family-only use).
- **Firebase install uninstalls then reinstalls:** the APK was signed with a **different key** than the installed app (common if `android/key.properties` was missing on bering-dev — Linux uses a different debug keystore than Windows). Run `app/scripts/setup-android-signing.sh --import ~/.config/family-calendar/windows-debug.keystore` before building; build scripts now fail or auto-configure if signing is wrong. Same key is required for **mobile Firebase** and **kiosk OTA**.
