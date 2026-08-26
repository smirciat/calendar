#!/usr/bin/env bash
# Run firebase CLI (global install or npx fallback).

firebase_cmd() {
  if command -v firebase >/dev/null 2>&1; then
    firebase "$@"
  else
    npx --yes firebase-tools "$@"
  fi
}
