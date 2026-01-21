FROM node:18-alpine

WORKDIR /app

COPY app/package*.json ./
COPY app/pnpm-lock.yaml ./

RUN npm install -g pnpm

RUN pnpm install

COPY app/ .

EXPOSE 5173

CMD ["pnpm", "run", "dev"]