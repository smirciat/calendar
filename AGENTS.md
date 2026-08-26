# Family Calendar — Agent Guide

Replace a wall-mounted kiosk calendar app with a Flutter + Node stack. The wall display is read-only; phones manage Google Calendar connections and family settings.

## Repo layout (target)

```
calendar/
  app/                 # Flutter (kiosk + mobile flavors)
  server/              # Node 24 API
  docs/                # Architecture notes (optional)
  project-description..txt
```

## Product constraints

| Surface | Orientation | Distribution | Auth |
|---------|-------------|--------------|------|
| Wall kiosk | Landscape, 1080×1920 | ADB sideload APK | Device token (setup once) |
| Phones | Portrait | Firebase App Distribution | User login + Google OAuth |

**Wall UX:** 7 columns × 5 rows; current week pinned at top (split-month view); scroll forward/back; idle timeout returns to default week; tap day → detail popup. Read-only.

**Phone UX:** Same grid concept, mobile layout; link Google account(s) to family; nickname + color per calendar (e.g. "Dad", "Mom").

**Server:** `bering-dev` (Oregon), Node 24, PM2, Postgres. Public URL: `https://smircich.ddns.net` (nginx on 443 → `localhost:3847`). Env file: project root `.env` (see `.env-sample`).


## Architecture (decided direction)

```
Phones ──OAuth──► Google Calendar API
  │                      ▲
  │ login + config       │ sync (poll or push)
  ▼                      │
Node API ◄──device token── Wall kiosk
  │
Postgres (families, users, calendar links, cached events, devices)
```

- **Server is source of truth** for merged family events. Kiosk never talks to Google directly.
- **Google OAuth on phones only** — store refresh tokens server-side (encrypted). Support 1–2 accounts per member (work + personal).
- **Event cache** in Postgres with periodic sync; avoids hammering Google and keeps kiosk fast/offline-tolerant.
- **Two Flutter flavors** from one codebase: `kiosk` (landscape, no OAuth UI) and `mobile` (portrait, full settings).

## Implementation phases

1. **Server skeleton** — Express/Fastify, Postgres migrations, password auth + JWT, health check, PM2 config.
2. **Google Calendar integration** — OAuth flow (mobile redirects through server), token storage, sync job, normalized event model.
3. **Family & calendar APIs** — CRUD nicknames/colors, list merged events by date range, device registration.
4. **Flutter mobile** — Login, link Google account, calendar list UI, week grid (portrait).
5. **Flutter kiosk** — Device pairing, landscape grid (7×5), scroll + idle reset, day popup, read-only.
6. **Ops** — Deploy to bering-dev, Firebase App Distribution, kiosk APK build + sideload docs.

## Coding standards

- **Minimize scope** — Smallest correct change; match existing patterns in each package.
- **No secrets in git** — `.env` locally; document required vars in `server/.env.example`.
- **TypeScript** on server; strict mode. **Dart** with `flutter analyze` clean.
- **API versioning** — prefix routes with `/api/v1`.
- **Tests** — Add when behavior is non-obvious or regression-prone; not for trivial CRUD.

## Key files to respect

- `project-description..txt` — product requirements (authoritative for UX).
- `server/` — API, sync, auth.
- `app/` — Flutter UI; flavor-specific entrypoints and layouts.

## Locked decisions

| Topic | Decision |
|-------|----------|
| Sync | Poll Google every **1 minute** (tunable later) |
| Auth | **One shared family password** (Option A) |
| Kiosk pairing | **Pairing code** from mobile admin screen; kiosk enters server URL + code on touchscreen |
| Writes | **Read-only** everywhere; phones only "write" via Google OAuth / calendar permissions |
| Kiosk orientation | **Landscape only** (device mounted landscape; lock in kiosk flavor) |

## Kiosk pairing flow

1. Log in on phone → **Add wall display** → server returns a 6-character code (15 min TTL).
2. On kiosk first boot: enter **server URL** + **pairing code** → receives long-lived device token.
3. Token stored locally; kiosk goes straight to calendar grid on subsequent launches.

## Kiosk as default launcher (survives reboot)

**Fujia wall tablets:** Do **not** `pm disable com.fujia.calendar` — firmware may factory-restore on reboot and **delete sideloaded apps**. Keep Fujia installed; set Family Calendar as default HOME instead.

Setup scripts (copy `app/scripts/` to Windows build PC):

- **`kiosk-setup.bat`** — double-click or run in CMD (no grep, no typos)
- **`kiosk-setup.ps1`** — PowerShell: `powershell -ExecutionPolicy Bypass -File .\kiosk-setup.ps1`

The `add-role-holder` command often fails on Android 10 with a Java exception — that is normal. The script also runs `set-home-activity` and opens **Settings → Home app** for manual selection.

```powershell
# Windows — from calendar\app after building kiosk APK
adb shell pm enable com.fujia.calendar
adb install -r build\app\outputs\flutter-apk\app-kiosk-release.apk
adb shell am start -n com.smircich.familycalendar.kiosk/com.familycalendar.family_calendar.MainActivity
adb shell cmd role add-role-holder android.app.role.HOME com.smircich.familycalendar.kiosk
adb shell cmd package set-home-activity com.smircich.familycalendar.kiosk/com.familycalendar.family_calendar.KioskHome
adb shell dpm set-device-owner com.smircich.familycalendar.kiosk/com.familycalendar.family_calendar.KioskDeviceAdminReceiver
adb reboot
```

Use **full activity class names** (not `.MainActivity` shorthand). Device owner may require no Google account on the wall device.
