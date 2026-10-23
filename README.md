# HamJam

Listen to music together, remotely. One person (host, Android 10+) shares the
audio of a single chosen app; the guest joins by code/link and listens, with
play / pause / previous / next controls that act on the host's player.

## Layout
- `app/` – Flutter app (Android first, native Kotlin for audio capture)
- `server/` – signalling server (planned)

## Dev setup (Arch)
- Flutter: `~/development/flutter` (add `bin` to PATH)
- JDK 17 (`flutter config --jdk-dir /usr/lib/jvm/java-17-openjdk`), Android SDK 36

## Milestones
1. [x] Capture spike: pick an app, capture only its audio, show level meter
2. [ ] Signalling server + host→guest audio over WebRTC
3. [ ] Invite code / deep link
4. [ ] Guest controls + now-playing metadata
5. [ ] Polish (reconnect, notification, leave)
