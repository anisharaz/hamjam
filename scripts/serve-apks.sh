#!/usr/bin/env bash
# Serves apks/ on :8000 so phones on the same network can download builds.
cd "$(dirname "$0")/../apks" && exec python3 -m http.server 8000
