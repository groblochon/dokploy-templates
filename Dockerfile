FROM node:18-alpine

RUN npm install -g pnpm

WORKDIR /app

# Copy global assets
COPY blueprints ./blueprints
COPY meta.json ./meta.json

# Setup app
WORKDIR /app/app
COPY app/package*.json ./
COPY app/pnpm-lock.yaml ./

RUN pnpm install

COPY app/ .

EXPOSE 5173

CMD ["pnpm", "run", "dev", "--host", "0.0.0.0"]