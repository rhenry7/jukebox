#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

if [ $# -eq 0 ]; then
    echo "Usage: ./scripts/flutter_with_env.sh <flutter-subcommand> [args...]"
    echo "Example: ./scripts/flutter_with_env.sh run -d chrome"
    echo "Shortcut: ./scripts/flutter_with_env.sh ios"
    exit 1
fi

bash ./scripts/check_flutter_version.sh

COMMAND="$1"
shift

ENV_FILE="${FLUTTER_ENV_FILE:-.env}"

resolve_first_ios_device() {
    local device_id
    device_id=$(
        flutter devices 2>/dev/null |
            awk -F '•' '/• ios[[:space:]]*•/ {
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2);
                print $2;
                exit
            }'
    )

    if [ -z "$device_id" ]; then
        echo "❌ No iOS device or simulator found."
        echo "Start a simulator or connect an iPhone, then try again."
        exit 1
    fi

    echo "$device_id"
}

if [ "$COMMAND" = "ios" ]; then
    DEVICE_ID="$(resolve_first_ios_device)"
    echo "📱 Running on iOS device: $DEVICE_ID"
    set -- -d "$DEVICE_ID" "$@"
    COMMAND="run"
fi

case "$COMMAND" in
    run|build|test)
        if [ ! -f "$ENV_FILE" ]; then
            echo "❌ Missing $ENV_FILE"
            echo "Create $ENV_FILE in the project root or pass keys manually with --dart-define."
            exit 1
        fi
        echo "📦 Using compile-time defines from $ENV_FILE"
        exec flutter "$COMMAND" "$@" --dart-define-from-file="$ENV_FILE"
        ;;
    *)
        exec flutter "$COMMAND" "$@"
        ;;
esac
