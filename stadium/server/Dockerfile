# The SpeedFest Stadium master + official servers (server.js), for the owner's Raspberry Pi (arm64)
# or any docker host. Built from stadium/ (the server reads the game's track list and zones):
#   cd stadium/server && docker compose up -d --build
FROM node:22-alpine
WORKDIR /app/server
COPY server/package.json server/package-lock.json ./
RUN npm ci --omit=dev
COPY server/server.js ./
COPY server/lib ./lib
COPY server/config.example.json ./config.json
COPY tracks /app/tracks
COPY data /app/data
# the Stadium block catalogue: uploaded community tracks are checked against it (lib/content.js)
COPY blocks/data/block_catalogue.json /app/blocks/data/block_catalogue.json
RUN mkdir -p /data && chown node:node /data
ENV DATA_DIR=/data PORT=8090 CONFIG=/app/server/config.json NODE_ENV=production
VOLUME /data
EXPOSE 8090
USER node
CMD ["node", "server.js"]
