# One image: the website (React, built in stage 1) and the WebSocket relay that serves it.
# Build from the repo root:  docker build -t hamjam .

# ---- stage 1: build the website ----
FROM node:22-alpine AS web
WORKDIR /web
COPY web/package.json web/package-lock.json ./
RUN npm ci
COPY web/ ./
RUN npm run build

# ---- stage 2: relay + static site ----
FROM node:22-alpine
ENV NODE_ENV=production \
    PORT=8080 \
    STATIC_DIR=/app/public \
    DOWNLOADS_DIR=/app/downloads
WORKDIR /app

# production dependencies first so this layer caches
COPY server/package.json server/package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY server/index.js server/static.js ./
COPY --from=web /web/dist ./public

USER node
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1

CMD ["node", "index.js"]
