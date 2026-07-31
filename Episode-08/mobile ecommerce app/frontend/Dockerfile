# ============================================
# Frontend: React (Create React App)
# Stage 1: Build static files
# Stage 2: Serve with nginx
# ============================================
FROM node:18-alpine AS builder
WORKDIR /app
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile
COPY . .
ENV REACT_APP_BASE_ENDPOINT=http://localhost:4000
RUN yarn build

FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
