FROM node:22-alpine

ENV NODE_ENV=production PORT=8080
WORKDIR /app

# install production dependencies first so this layer caches
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY index.js ./

USER node
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1

CMD ["node", "index.js"]
