#!/usr/bin/env bash
# Builds a debug APK and saves it as the next number in apks/ (1.apk, 2.apk, ...).
# Serve them with: scripts/serve-apks.sh
#
#   scripts/publish-apk.sh            # points at the production relay (wss://hamjam.anisharaz.com.np)
#   HAMJAM_LAN=1 scripts/publish-apk.sh   # points at a relay on this machine's LAN IP, port 8080
#   SERVER_URL=ws://host:port scripts/publish-apk.sh   # any other relay
#   RELEASE=1 scripts/publish-apk.sh  # small release build (arm64, wss:// only) instead of a debug build
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/development/flutter/bin:$PATH"

if [ -n "${SERVER_URL:-}" ]; then
  URL="$SERVER_URL"
elif [ -n "${HAMJAM_LAN:-}" ]; then
  URL="ws://$(ip -4 route get 1.1.1.1 | grep -oP 'src \K\S+'):8080"
else
  URL="wss://hamjam.anisharaz.com.np"
fi

if [ -n "${RELEASE:-}" ]; then
  (cd app && flutter build apk --release --target-platform android-arm64 --dart-define=SERVER_URL="$URL")
  APK=app/build/app/outputs/flutter-apk/app-release.apk
else
  (cd app && flutter build apk --debug --dart-define=SERVER_URL="$URL")
  APK=app/build/app/outputs/flutter-apk/app-debug.apk
fi
mkdir -p apks
n=$(( $(ls apks | grep -oE '^[0-9]+' | sort -n | tail -1 || echo 0) + 1 ))
cp "$APK" "apks/$n.apk"
echo "Saved apks/$n.apk (server $URL)"
