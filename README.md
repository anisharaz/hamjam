# HamJam

Listen to music together, remotely. One person (host, Android 10+) shares the
audio playing on their phone; the guest joins with a 6-character code and
listens. The guest's play / pause / previous / next buttons control the host's
player, and both sides can chat (live only, never stored). Either side can ask
to swap roles.

## Layout
- `app/` – Flutter app (Android; native Kotlin for audio capture, AAC streaming, notifications)
- `server/` – WebSocket relay (Node). Rooms live in memory only. Also serves the website and APK downloads.
- `web/` – landing page (React + Vite), built into the same Docker image as the relay
- `Dockerfile` – one image: builds `web/`, then runs the relay with the site baked in
- `deploy/` – Docker Compose + Caddy (automatic HTTPS) for production
- `scripts/` – `publish-apk.sh` (numbered APK builds), `serve-apks.sh` (download server)

## Deploy (hamjam.anisharaz.com.np)
One container serves the website (`/`), APK downloads (`/download/latest.apk`), the health check
(`/healthz`) and the WebSocket relay (the app connects to the same domain).

1. Point a DNS `A` (and `AAAA`) record for `hamjam.anisharaz.com.np` at the server.
2. Open ports 80 and 443 on the server (80 is needed for the certificate challenge).
3. On the server:
   ```sh
   cd deploy
   docker compose up -d --build
   ```
   Caddy fetches the certificate by itself. The folder `apks/` is mounted read-only into the
   container; `/download/latest.apk` always serves the highest-numbered `N.apk` there (or `hamjam.apk`).
   Check: `curl https://hamjam.anisharaz.com.np/healthz`
   should return `{"ok":true,"rooms":0}`, and the home page should show the site.

To ship a new app version: run `scripts/publish-apk.sh` (adds `apks/N.apk`) and copy `apks/` to the
server. No rebuild is needed, the download link picks up the newest file.

Already have your own reverse proxy (nginx, Traefik, Cloudflare Tunnel)? Run only the relay
(`docker compose up -d --build relay`), proxy your domain to `127.0.0.1:8080`, and make sure it
passes WebSocket upgrades and does not close idle connections quickly (the app pings every 20 s).

## Build the app
```sh
scripts/publish-apk.sh                 # production relay (wss://hamjam.anisharaz.com.np)
HAMJAM_LAN=1 scripts/publish-apk.sh    # relay on this machine's LAN IP
scripts/serve-apks.sh                  # then open http://<this-ip>:8000 on a phone
```
The server address can also be changed inside the app (tune icon on the home screen).
Debug builds allow plain `ws://` for LAN testing; a release build only allows `wss://`.

## Dev setup (Arch)
- Flutter: `~/development/flutter` (add `bin` to PATH)
- JDK 17 (`flutter config --jdk-dir /usr/lib/jvm/java-17-openjdk`), Android SDK 36
- Server tests: `cd server && npm test`; app layout tests: `cd app && flutter test`
- Website: `cd web && npm install && npm run dev` (the dev server proxies `/download` to a relay on :8080)
