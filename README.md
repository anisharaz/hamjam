# HamJam

Listen to music with someone far away. One phone shares what it is playing, the other joins with a
code and listens. The listener can play, pause and skip, and both people can chat.

It works with any music app. HamJam shares your phone's audio, so Spotify, YouTube Music, a local
player or a podcast app all work the same way.

## How it works

```
 Host phone (Android 10+)                    Relay server                  Listener phone
 ┌────────────────────────┐   AAC audio    ┌──────────────┐   AAC audio   ┌──────────────────┐
 │ any music app          │ ─────────────▶ │  WebSocket   │ ────────────▶ │ decode + play    │
 │  ↓ AudioPlaybackCapture│                │  rooms in    │               │                  │
 │ AAC encode             │ ◀───────────── │  memory only │ ◀──────────── │ play/pause/skip, │
 │ media keys → music app │  control, chat │              │ control, chat │ chat             │
 └────────────────────────┘                └──────────────┘               └──────────────────┘
```

- The host captures all media audio (not calls or notifications) with Android's
  `AudioPlaybackCapture`, encodes it to AAC (128 kbps) and sends it to the relay.
- The relay forwards the audio to the listener. Rooms exist only in memory and disappear when the
  host leaves. Nothing is recorded or stored.
- The listener's buttons travel back through the relay and the host's phone presses the matching
  media key, so the music app on the host's phone responds.
- Latency is roughly a second.

## Features

- Host a jam and share a 6-character code. The listener enters it to join.
- Play, pause, previous and next from either phone.
- Live chat, relayed through the server and never stored. Messages show as notifications when the
  app is in the background.
- Switch roles: either person can ask to swap host and listener, and the other approves. The room
  code and chat carry over.
- Runs in the background with a persistent notification that shows the jam is active.
- A small website with a download link, served by the same container as the relay.

## Repository layout

| Path | What it is |
|---|---|
| `app/` | Flutter app (Android). Native Kotlin handles audio capture, AAC encoding and decoding, the relay connection and notifications. |
| `server/` | Node WebSocket relay. Also serves the website, APK downloads and `/healthz`. |
| `web/` | Landing page (React + Vite). Built into the same Docker image as the relay. |
| `Dockerfile` | One image: builds `web/`, then runs the relay with the site baked in. |
| `deploy/` | Docker Compose and a Caddyfile (automatic HTTPS) for production. |
| `scripts/` | `publish-apk.sh` builds numbered APKs into `apks/`, `serve-apks.sh` serves them on the LAN. |

## Requirements

- **Host:** Android 10 (API 29) or newer. Android only lets apps capture other apps' audio from
  version 10, and only after the user allows a screen-capture prompt (HamJam captures audio, not
  the screen).
- **Listener:** Android 10 or newer.
- Some apps block audio capture (mostly DRM-protected video). Music apps generally work.

## Run it locally

**Relay**

```sh
cd server
npm install
npm start            # listens on :8080
npm test             # relay + static file tests
```

**Website** (optional, in dev mode)

```sh
cd web
npm install
npm run dev          # proxies /download to a relay on :8080
```

**App**

Install [Flutter](https://docs.flutter.dev/get-started/install) with JDK 17 and Android SDK 36, then:

```sh
cd app
flutter pub get
flutter analyze && flutter test
flutter run --dart-define=SERVER_URL=ws://<your-lan-ip>:8080
```

The server address can also be changed inside the app (tune icon on the home screen). Debug builds
allow plain `ws://` for LAN testing. Release builds only allow `wss://`.

**Numbered APKs for testing on phones**

```sh
scripts/publish-apk.sh                   # points at wss://hamjam.anisharaz.com.np
HAMJAM_LAN=1 scripts/publish-apk.sh      # points at this machine's LAN IP, port 8080
scripts/serve-apks.sh                    # then open http://<this-machine>:8000 on a phone
```

## Deploy

One container serves everything on a single domain: the website, `/download/latest.apk`, `/healthz`
and the WebSocket relay.

1. Point a DNS `A` record (and `AAAA` if you have IPv6) for your domain at the server. The domain
   is set in `deploy/Caddyfile` (currently `hamjam.anisharaz.com.np`).
2. Open ports 80 and 443. Port 80 is needed for the certificate challenge.
3. On the server:

   ```sh
   cd deploy
   docker compose up -d --build
   ```

4. Check `https://<domain>/healthz`. It should return `{"ok":true,"rooms":0}`.

Caddy gets and renews the HTTPS certificate. Keep its `caddy_data` volume, or you may hit Let's
Encrypt rate limits.

`apks/` is mounted read-only into the container. `/download/latest.apk` serves the highest-numbered
`N.apk` in it (or `hamjam.apk`). To ship a new version, run `scripts/publish-apk.sh` and copy
`apks/` to the server. No rebuild is needed.

Already have a reverse proxy? Run only the relay with `docker compose up -d --build relay`, proxy
your domain to `127.0.0.1:8080`, and make sure it passes WebSocket upgrades and does not close idle
connections quickly (the app pings every 20 seconds).

## Protocol

The relay speaks JSON text messages plus binary audio frames over one WebSocket.

| Message | Direction | Purpose |
|---|---|---|
| `create` / `created {code}` | host ↔ relay | open a room |
| `join {code}` / `joined` | listener ↔ relay | join a room |
| binary frame | host → listeners | one AAC frame |
| `meta {csd,...}` | host → listeners | codec config, cached for late joiners |
| `playback {playing}` | host → listeners | whether the host's player is playing |
| `control {key}` | listener → host | `playPause`, `next` or `previous` |
| `chat {text}` | both | relayed with the sender's role and a timestamp, rate limited |
| `swap_request`, `swap_response`, `swap_go`, `claim` | both | role swap handshake with a one-time token |

See `server/index.js` for the details and `server/test.js` for examples.

## Known limitations

- Android only.
- The host can't hand a jam over if the new host never allows the screen-capture prompt. The
  request then fails and the jam continues as before.
- Debug APKs are about 170 MB. Release builds for a single architecture are much smaller.
- The server has no accounts or authentication. Anyone with a room code can join that room.
- No license has been chosen yet.
