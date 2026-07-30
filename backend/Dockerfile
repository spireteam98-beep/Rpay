FROM node:20-slim
WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

# Cloud Run injects PORT at runtime; config.js already reads it the same way
# Render does (process.env.PORT, default 8080), so no code change needed.
EXPOSE 8080
CMD ["node", "src/server.js"]
