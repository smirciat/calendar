#!/usr/bin/env bash
# Source from build scripts on Linux dev hosts (e.g. bering-dev).
# Installed by setup-dev-android.sh into ~/develop/jdk-17 and ~/Android/Sdk.

export JAVA_HOME="${JAVA_HOME:-$HOME/develop/jdk-17}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$HOME/.gradle}"

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
