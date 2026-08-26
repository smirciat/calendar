#!/usr/bin/env bash
# Link a Google Calendar account to the family (after revoking at myaccount.google.com/permissions).
# Usage: ./scripts/link-calendar.sh [family-password]
# Or:    FAMILY_PASSWORD=secret ./scripts/link-calendar.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT}/.env"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a && source "$ENV_FILE" && set +a
fi

BASE_URL="${BASE_URL:-https://smircich.ddns.net}"
PASSWORD="${1:-${FAMILY_PASSWORD:-}}"

json_field() {
  local field="$1"
  node -e "
    const fs = require('fs');
    const data = JSON.parse(fs.readFileSync(0, 'utf8'));
    const value = data['$field'];
    if (value === undefined) process.exit(2);
    process.stdout.write(String(value));
  "
}

if [[ -z "$PASSWORD" ]]; then
  read -r -s -p "Family password: " PASSWORD
  echo
fi

echo "Logging in to ${BASE_URL} ..."
LOGIN_JSON=$(curl -sS -X POST "${BASE_URL}/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"${PASSWORD}\"}") || {
  echo "Login request failed." >&2
  exit 1
}

if echo "$LOGIN_JSON" | json_field error >/dev/null 2>&1; then
  ERROR=$(echo "$LOGIN_JSON" | json_field error)
  echo "Login failed: ${ERROR}" >&2
  exit 1
fi

TOKEN=$(echo "$LOGIN_JSON" | json_field token)

echo "Getting Google sign-in URL ..."
OAUTH_JSON=$(curl -sS "${BASE_URL}/api/v1/calendars/oauth/start" \
  -H "Authorization: Bearer ${TOKEN}") || {
  echo "OAuth start request failed." >&2
  exit 1
}

if echo "$OAUTH_JSON" | json_field error >/dev/null 2>&1; then
  ERROR=$(echo "$OAUTH_JSON" | json_field error)
  echo "OAuth start failed: ${ERROR}" >&2
  exit 1
fi

URL=$(echo "$OAUTH_JSON" | json_field url)

echo
echo "=========================================="
echo "  Open this URL and sign in as the person"
echo "  whose calendar you are linking."
echo "=========================================="
echo
echo "$URL"
echo
echo "Grant calendar read access when asked."
echo "Success page: \"Calendar linked\""
echo

if command -v xdg-open >/dev/null 2>&1; then
  read -r -p "Open in browser now? [Y/n] " OPEN
  OPEN=${OPEN:-Y}
  if [[ "$OPEN" =~ ^[Yy] ]]; then
    xdg-open "$URL" >/dev/null 2>&1 || true
  fi
elif command -v open >/dev/null 2>&1; then
  open "$URL"
fi

read -r -p "Press Enter after completing sign-in in the browser..."

echo
echo "Linked calendars:"
curl -sS "${BASE_URL}/api/v1/calendars" \
  -H "Authorization: Bearer ${TOKEN}" | node -e "
const fs = require('fs');
const rows = JSON.parse(fs.readFileSync(0, 'utf8'));
if (!rows.length) {
  console.log('  (none yet)');
  process.exit(0);
}
for (const row of rows) {
  const synced = row.last_synced_at ? 'synced' : 'waiting for sync';
  console.log('  -', row.nickname, '(' + row.google_account_email + ')', '-', synced);
}
"

echo
read -r -p "Link another account? [y/N] " AGAIN
if [[ "$AGAIN" =~ ^[Yy] ]]; then
  exec "$0" "$PASSWORD"
fi

echo "Done. Events sync within about a minute."
