# Stage 1: Build the React application
FROM node:20-alpine AS builder

WORKDIR /app

# Install dependencies first for better layer caching
COPY package.json package-lock.json ./
RUN npm ci

# Copy source and build production assets
COPY . .
RUN npm run build

# Stage 2: Serve static files with Nginx
FROM nginx:1.27-alpine AS production

# Remove default Nginx config and add SPA-aware config
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf

# Copy built assets from builder stage only (no node_modules / source)
COPY --from=builder /app/dist /usr/share/nginx/html

# Run as non-root where possible; Nginx Alpine already drops privileges per worker
EXPOSE 80

# Health check for orchestrators and --restart policies
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
