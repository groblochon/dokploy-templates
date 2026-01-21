FROM node:18-alpine

RUN npm install -g pnpm

# Set working directory to the root of the repository
WORKDIR /usr/src/app

# Copy the entire repository to maintain the relative structure
COPY . .

# Move to the app directory for the build/run
WORKDIR /usr/src/app/app

# Install dependencies
RUN pnpm install

EXPOSE 5173

# Run with host 0.0.0.0 to allow access from outside the container
CMD ["pnpm", "run", "dev", "--host", "0.0.0.0"]