#!/usr/bin/env bash
# One-time setup: JDK 17 + Android SDK for Flutter APK builds on Linux (no root).
# Safe to re-run; skips components that are already installed.
#
# Usage (from anywhere):
#   app/scripts/setup-dev-android.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_android-env.sh
source "$SCRIPT_DIR/_android-env.sh"

CMDLINE_TOOLS_ZIP_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
JDK_URL="https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse?project=jdk"

echo
echo "========================================"
echo " Family Calendar - Dev Android setup"
echo " JDK:     $JAVA_HOME"
echo " SDK:     $ANDROID_HOME"
echo "========================================"
echo

if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: flutter not in PATH."
  exit 1
fi

if [[ ! -x "$JAVA_HOME/bin/java" ]]; then
  echo "Downloading Temurin JDK 17..."
  mkdir -p "$(dirname "$JAVA_HOME")"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT
  curl -fsSL "$JDK_URL" -o "$tmp_dir/jdk.tar.gz"
  tar -xzf "$tmp_dir/jdk.tar.gz" -C "$(dirname "$JAVA_HOME")"
  extracted="$(find "$(dirname "$JAVA_HOME")" -maxdepth 1 -type d -name 'jdk-17*' | sort | tail -1)"
  if [[ -z "$extracted" || ! -d "$extracted" ]]; then
    echo "ERROR: JDK extract failed."
    exit 1
  fi
  rm -rf "$JAVA_HOME"
  mv "$extracted" "$JAVA_HOME"
  echo "OK: $("$JAVA_HOME/bin/java" -version 2>&1 | head -1)"
else
  echo "JDK already installed: $("$JAVA_HOME/bin/java" -version 2>&1 | head -1)"
fi

if [[ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]]; then
  echo "Downloading Android command-line tools..."
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT
  curl -fsSL "$CMDLINE_TOOLS_ZIP_URL" -o "$tmp_dir/cmdline-tools.zip"
  rm -rf "$ANDROID_HOME/cmdline-tools/latest"
  unzip -q "$tmp_dir/cmdline-tools.zip" -d "$tmp_dir/unpack"
  mv "$tmp_dir/unpack/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  echo "OK: cmdline-tools installed"
else
  echo "Android cmdline-tools already installed"
fi

export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

echo
echo "Accepting SDK licenses..."
yes | sdkmanager --licenses >/dev/null || true

echo "Installing SDK packages..."
sdkmanager --install \
  "platform-tools" \
  "platforms;android-36" \
  "platforms;android-35" \
  "build-tools;36.0.0" \
  "ndk;28.2.13676358" \
  "cmake;3.22.1"

flutter config --android-sdk "$ANDROID_HOME" >/dev/null

echo
echo "Running flutter doctor (Android)..."
if ! yes | flutter doctor --android-licenses >/dev/null 2>&1; then
  echo "(flutter android-licenses skipped or already accepted)"
fi
flutter doctor -v | sed -n '/Flutter (Channel/,/Network resources/p'

echo
echo "Done. Build with:"
echo "  app/scripts/build-mobile.sh"
echo "  app/scripts/build-kiosk.sh"
echo
echo "Firebase upload on this host (one-time):"
echo "  npx firebase-tools login"
echo "  # or headless: npx firebase-tools login:ci  → add FIREBASE_TOKEN to .env"
