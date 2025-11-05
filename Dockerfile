# syntax=docker/dockerfile:1
# ----------------------------------------------------
# STAGE 1: Common Base and Dependency Installation
# This stage installs all dependencies (dev and prod) to leverage caching.
# ----------------------------------------------------
FROM node:22.19.0-alpine AS base
WORKDIR /usr/src/app

# Bind mounts are only for dev builds, so this works for prod too.
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=cache,target=/root/.npm \
    npm ci

# Copy the source code for building
COPY . .

# ----------------------------------------------------
# STAGE 2: Development Environment
# This stage is for running the app in dev mode with hot-reloading.
# ----------------------------------------------------
FROM base AS development
ENV NODE_ENV=development
# No special build command needed, just run the start
EXPOSE 3000 4000
CMD ["npm", "start"]

# ----------------------------------------------------
# STAGE 3: Build for Production
# This stage compiles the TypeScript code into JavaScript.
# ----------------------------------------------------
FROM base AS build
ENV NODE_ENV=production
# Run the build script
RUN npm run build

# ----------------------------------------------------
# STAGE 4: Final Production Image
# This stage is as lean as possible, with only prod dependencies and built files.
# ----------------------------------------------------
FROM node:22.19.0-alpine AS production
ENV NODE_ENV=production
WORKDIR /usr/src/app

# Copy only production dependencies from the build stage
COPY --from=build /usr/src/app/package.json /usr/src/app/package-lock.json ./
RUN npm ci --omit=dev

# Copy the built files from the build stage
COPY --from=build /usr/src/app/dist ./dist

EXPOSE 4000
CMD ["node", "dist/app.js"]