#!/usr/bin/env bash
# Shared helpers for reading calendar/.env (do not source .env directly).

read_env() {
  local key="$1"
  if [[ ! -f "$ENV_FILE" ]]; then
    return 0
  fi
  grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//" || true
}

load_firebase_env() {
  IOS_APP_ID="$(read_env IOS_APP_ID)"
  ANDROID_APP_ID="$(read_env ANDROID_APP_ID)"
}

load_kiosk_deploy_env() {
  KIOSK_DEPLOY_HOST="$(read_env KIOSK_DEPLOY_HOST)"
  if [[ -z "$KIOSK_DEPLOY_HOST" ]]; then
    KIOSK_DEPLOY_HOST=bering-dev
  fi
  KIOSK_DEPLOY_PATH="$(read_env KIOSK_DEPLOY_PATH)"
  if [[ -z "$KIOSK_DEPLOY_PATH" ]]; then
    KIOSK_DEPLOY_PATH=/var/www/family-calendar/releases/app-kiosk-release.apk
  fi
}
