FROM node:20-slim AS server

WORKDIR /app/server
COPY server/package*.json ./
RUN npm install --omit=dev
COPY server/ .

FROM node:20-alpine AS runner
WORKDIR /app
COPY --from=server /app/server ./server
RUN mkdir -p /data && chown -R node:node /data
USER node
EXPOSE 10000
ENV NODE_ENV=production
ENV PORT=10000
ENV DATABASE_PATH=/data/echat.db
CMD ["node", "server/index.js"]
