#!/usr/bin/env bash
# Source from build scripts on Linux dev hosts (e.g. bering-dev).
# Installed by setup-dev-android.sh into ~/develop/jdk-17 and ~/Android/Sdk.

export JAVA_HOME="${JAVA_HOME:-$HOME/develop/jdk-17}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$HOME/.gradle}"

# Serialize Android builds and stop stale Gradle daemons between flavors.
ANDROID_BUILD_LOCK="${ANDROID_BUILD_LOCK:-${TMPDIR:-/tmp}/family-calendar-android-build.lock}"
ANDROID_BUILD_TIMEOUT_SEC="${ANDROID_BUILD_TIMEOUT_SEC:-900}"

if [[ -d "$JAVA_HOME/bin" ]]; then
  export PATH="$JAVA_HOME/bin:$PATH"
fi
if [[ -d "$ANDROID_HOME/platform-tools" ]]; then
  export PATH="$ANDROID_HOME/platform-tools:$PATH"
fi
if [[ -d "$ANDROID_HOME/cmdline-tools/latest/bin" ]]; then
  export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
fi
if [[ -d "$ANDROID_HOME/build-tools" ]]; then
  latest_build_tools="$(find "$ANDROID_HOME/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1)"
  if [[ -n "$latest_build_tools" ]]; then
    export PATH="$latest_build_tools:$PATH"
  fi
fi

android_acquire_build_lock() {
  exec 9>"$ANDROID_BUILD_LOCK"
  if ! flock -w 300 9; then
    echo "ERROR: Another Android build is running (lock: $ANDROID_BUILD_LOCK)"
    exit 1
  fi
}

android_stop_gradle_daemons() {
  local app_dir="${1:-}"
  local gradlew="$app_dir/android/gradlew"
  if [[ -x "$gradlew" ]]; then
    echo "Stopping Gradle daemons..."
    (cd "$app_dir/android" && ./gradlew --stop >/dev/null 2>&1) || true
  fi
}

android_run_flutter_build() {
  local label="$1"
  shift
  echo "Starting $label (timeout: ${ANDROID_BUILD_TIMEOUT_SEC}s)..."
  if ! timeout --foreground "$ANDROID_BUILD_TIMEOUT_SEC" flutter "$@"; then
    local status=$?
    if [[ $status -eq 124 ]]; then
      echo "ERROR: $label timed out after ${ANDROID_BUILD_TIMEOUT_SEC}s"
      echo "Try: rm -f $ANDROID_BUILD_LOCK && app/scripts/build-kiosk.sh"
    fi
    android_stop_gradle_daemons "$(pwd)"
    exit "$status"
  fi
}

android_verify_apk_signing() {
  local apk_path="$1"
  local key_props="$2"
  if [[ ! -f "$key_props" ]]; then
    return 0
  fi

  local store_file alias store_pass
  store_file="$(sed -n 's/^storeFile=//p' "$key_props" | head -1)"
  alias="$(sed -n 's/^keyAlias=//p' "$key_props" | head -1)"
  store_pass="$(sed -n 's/^storePassword=//p' "$key_props" | head -1)"
  if [[ -z "$store_file" || -z "$alias" || -z "$store_pass" || ! -f "$store_file" ]]; then
    echo "WARNING: Could not verify APK signing (missing key.properties fields or keystore)."
    return 0
  fi

  local apksigner expected actual
  apksigner="$(find "$ANDROID_HOME/build-tools" -name apksigner 2>/dev/null | sort -V | tail -1)"
  if [[ -z "$apksigner" ]]; then
    echo "WARNING: apksigner not found — skipping signing verification."
    return 0
  fi

  expected="$(keytool -list -v -keystore "$store_file" -storepass "$store_pass" -alias "$alias" 2>/dev/null \
    | sed -n 's/^[[:space:]]*SHA256: //p' | head -1 | tr -d ':')"
  actual="$("$apksigner" verify --print-certs "$apk_path" 2>/dev/null \
    | sed -n 's/^Signer #1 certificate SHA-256 digest: //p' | head -1)"
  if [[ -z "$expected" || -z "$actual" ]]; then
    echo "WARNING: Could not read APK or keystore certificate fingerprints."
    return 0
  fi

  if [[ "${expected,,}" != "${actual,,}" ]]; then
    echo "ERROR: APK signing key does not match $store_file"
    echo "       Keystore SHA-256: ${expected^^}"
    echo "       APK SHA-256:      ${actual^^}"
    echo "       Check android/app/build.gradle.kts release signingConfig."
    exit 1
  fi
  echo "Verified signing certificate matches key.properties"
}
