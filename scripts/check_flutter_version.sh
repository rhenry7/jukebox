#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/.flutter-version"

if [ ! -f "$VERSION_FILE" ]; then
  echo "❌ Missing Flutter version pin file: $VERSION_FILE"
  exit 1
fi

EXPECTED_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"

if [ -z "$EXPECTED_VERSION" ]; then
  echo "❌ .flutter-version is empty."
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "❌ Flutter is not installed or not on PATH."
  echo "   Expected Flutter version: $EXPECTED_VERSION"
  exit 1
fi

VERSION_JSON="$(flutter --version --machine 2>/dev/null || true)"
CURRENT_VERSION="$(printf '%s\n' "$VERSION_JSON" | sed -n 's/.*"frameworkVersion":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"

if [ -z "$CURRENT_VERSION" ]; then
  echo "❌ Unable to determine the active Flutter version."
  echo "   Expected Flutter version: $EXPECTED_VERSION"
  echo "   Try running: flutter --version"
  exit 1
fi

if [ "$CURRENT_VERSION" != "$EXPECTED_VERSION" ]; then
  echo "❌ Flutter version mismatch."
  echo "   Expected: $EXPECTED_VERSION"
  echo "   Current : $CURRENT_VERSION"
  if command -v fvm >/dev/null 2>&1; then
    echo "   Fix: run 'fvm use $EXPECTED_VERSION' and use 'fvm flutter ...'"
  else
    echo "   Fix: switch your active Flutter SDK to $EXPECTED_VERSION"
  fi
  exit 1
fi

echo "✅ Flutter version pinned correctly: $CURRENT_VERSION"
