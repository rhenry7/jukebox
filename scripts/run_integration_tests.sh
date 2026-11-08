#!/bin/bash
# End-to-end tests of the main signed-out flows (integration_test/), in
# Chrome, against live data (read-only: nothing signs in or writes).
#
# Needs ChromeDriver matching your Chrome. Set CHROMEDRIVER, or let this
# fetch Google's official build into build/chromedriver:
#   npx @puppeteer/browsers install chromedriver@<your Chrome version>
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/use_pinned_flutter.sh

DRIVER="${CHROMEDRIVER:-$(ls build/chromedriver/chromedriver/*/chromedriver-*/chromedriver 2>/dev/null | head -1)}"
if [ -z "$DRIVER" ]; then
  echo "❌ ChromeDriver not found. See the comment at the top of this script."
  exit 1
fi

# Only the keys the app needs to load public data. Never the demo login:
# these tests run signed out.
DEFINES=()
while IFS='=' read -r key value; do
  case "$key" in
    FIREBASE_OPTIONS_KEY|FIREBASE_APP_ID|SPOTIFY_CLIENT_ID|SPOTIFY_CLIENT_SECRET|CLIENT_ID)
      value="${value%\"}"; value="${value#\"}"
      DEFINES+=("--dart-define=$key=$value") ;;
  esac
done < .env

"$DRIVER" --port=4444 >/dev/null 2>&1 &
DRIVER_PID=$!
trap 'kill $DRIVER_PID 2>/dev/null' EXIT
sleep 1

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart \
  -d web-server --browser-name=chrome \
  "${DEFINES[@]}" "$@"
