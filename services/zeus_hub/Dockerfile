FROM node:22-alpine AS build
WORKDIR /hub
COPY package*.json tsconfig.json ./
RUN npm ci
COPY src ./src
RUN npm run build && npm prune --omit=dev

FROM node:22-alpine
WORKDIR /hub
ENV NODE_ENV=production
COPY --from=build /hub/node_modules ./node_modules
COPY --from=build /hub/dist ./dist
COPY package.json ./
COPY migrations ./migrations
USER node
EXPOSE 8080
CMD ["node", "dist/src/start.js"]
