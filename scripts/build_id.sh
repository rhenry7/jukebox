#!/usr/bin/env bash
# Prints a unique id for this web build: short commit + UTC time.
#
# Deploys compile it into the app (--dart-define=BUILD_ID=…) and publish it
# as build/web/app_version.json; the app compares the two to notice that a
# newer version is live (lib/services/app_update/).
set -e
commit=$(git rev-parse --short HEAD 2>/dev/null || echo nogit)
echo "${commit}-$(date -u +%Y%m%d%H%M%S)"
