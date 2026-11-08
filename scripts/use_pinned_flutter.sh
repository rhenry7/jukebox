#!/bin/bash
# Source this from the project folder (". scripts/use_pinned_flutter.sh", in
# bash or zsh) to put the Flutter version in .flutter-version first on PATH.
# Flutter versions are managed with FVM (~/fvm/versions/<version>); this is a
# safety net for the scripts in case a shell's PATH has an older Flutter.

_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
if [ -f "$_root/.flutter-version" ]; then
  _sdk="$HOME/fvm/versions/$(tr -d '[:space:]' < "$_root/.flutter-version")"
  if [ -x "$_sdk/bin/flutter" ]; then
    export PATH="$_sdk/bin:$PATH"
  fi
fi
unset _root _sdk
