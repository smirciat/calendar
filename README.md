# Family Calendar

Flutter + Node family wall calendar. Phones manage Google accounts; the wall kiosk displays a read-only merged grid.

| Flavor | Package | APK output | Distribution |
|--------|---------|------------|--------------|
| **mobile** | `com.smircich.familycalendar` | `app-mobile-release.apk` | Firebase App Distribution (phones) |
| **kiosk** | `com.smircich.familycalendar.kiosk` | `app-kiosk-release.apk` | ADB sideload (wall tablet) |

Version is set in `app/pubspec.yaml` (`version: 1.0.0+2` → name `1.0.0`, build number `2`).

See `AGENTS.md` for architecture and server setup.

## Prerequisites

- Flutter SDK (with Android toolchain)
- **Windows:** run `.bat` scripts from `app/scripts/` (safe from any directory)
- **Firebase (mobile):** `npm install -g firebase-tools` then `firebase login`
- **Kiosk (wall):** `adb` in PATH, USB debugging on tablet
- **`.env`** at repo root with at least:

```env
ANDROID_APP_ID=1:YOUR_PROJECT:android:YOUR_APP_HASH
FIREBASE_TESTERS_GROUP=family
```

Copy from `.env-sample`. Create the `family` tester group in Firebase Console → App Distribution before distributing.

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

Reads `ANDROID_APP_ID` and `FIREBASE_TESTERS_GROUP` from `.env`. Refuses kiosk APKs.

### Build + upload

```cmd
app\scripts\mobile-release.bat "Release notes here"
```

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

Bump build number in `app/pubspec.yaml` before each distro upload (e.g. `1.0.0+3`).

## Script reference

| Script | Purpose |
|--------|---------|
| `app/scripts/build-mobile.bat` | Build phone APK |
| `app/scripts/distribute-mobile.bat` | Upload phone APK to Firebase |
| `app/scripts/mobile-release.bat` | Build + upload phone APK |
| `app/scripts/build-kiosk.bat` | Build wall APK |
| `app/scripts/kiosk-setup.bat` | ADB install + HOME launcher setup (Windows) |
| `app/scripts/kiosk-setup.sh` | Same for Linux/macOS |
| `app/scripts/_verify-apk-package.bat` | Internal: package check (used by build/distribute) |

Optional PowerShell equivalents: `app/scripts/*.ps1` (same behavior; `.bat` is preferred on Windows).

## Common mistakes

- **Wrong APK on Firebase:** use `build-mobile.bat`, not `build-kiosk.bat`
- **Stale APK:** rebuild mobile after building kiosk; distribute script warns if kiosk APK is newer
- **Firebase group error:** create tester group in Firebase Console first (default name: `family`)
- **Kiosk pairing lost:** new package install = fresh app; generate a new pairing code on a phone
