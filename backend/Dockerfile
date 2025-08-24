# --- build ---
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev --no-audit --no-fund

# --- runtime ---
FROM node:20-alpine
ENV NODE_ENV=production
WORKDIR /app
RUN addgroup -S app && adduser -S app -G app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
USER app
EXPOSE 4000
CMD ["node", "server.js"]
