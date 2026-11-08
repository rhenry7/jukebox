#!/bin/bash
# Source this (". scripts/use_pinned_flutter.sh") to put the Flutter version in
# .flutter-version first on PATH, when it's installed side by side as
# ~/development/flutter-<version> (this Mac keeps an older Flutter as the
# default for other projects). Does nothing if that copy isn't there.

_pin="$(tr -d '[:space:]' < "$(dirname "${BASH_SOURCE[0]}")/../.flutter-version")"
_sdk="$HOME/development/flutter-$_pin"
if [ -x "$_sdk/bin/flutter" ]; then
  export PATH="$_sdk/bin:$PATH"
fi
unset _pin _sdk
