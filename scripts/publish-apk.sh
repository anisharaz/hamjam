#!/usr/bin/env bash
# Builds a debug APK (server URL defaults to this machine's LAN IP) and saves it
# as the next number in apks/ (1.apk, 2.apk, ...). Serve with: scripts/serve-apks.sh
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/development/flutter/bin:$PATH"
IP="${HAMJAM_HOST:-$(ip -4 route get 1.1.1.1 | grep -oP 'src \K\S+')}"
(cd app && flutter build apk --debug --dart-define=SERVER_URL="ws://$IP:8080")
mkdir -p apks
n=$(( $(ls apks | grep -oE '^[0-9]+' | sort -n | tail -1 || echo 0) + 1 ))
cp app/build/app/outputs/flutter-apk/app-debug.apk "apks/$n.apk"
echo "Saved apks/$n.apk (server ws://$IP:8080)"
