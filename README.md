# STANS — Smart Traffic-Aware Navigation System

React/TypeScript navigation app that computes optimal routes with graph algorithms — containerized with Docker, served by Nginx, and deployed via GitHub Actions.

## Quick start (local)

```bash
npm install
npm run dev
```

App runs at `http://localhost:8080`.

| Script | Description |
|--------|-------------|
| `npm run dev` | Vite development server |
| `npm run build` | Production build → `dist/` |
| `npm run preview` | Preview production build |
| `npm run lint` | ESLint |

## Part 2: Containerization

Multi-stage build: Node Alpine compiles the app; Nginx Alpine serves `dist/` on port 80 (SPA-aware routing + `/health`).

```bash
docker build -t stans-app .
docker run -p 8080:80 stans-app
```

Open `http://localhost:8080`. Health: `http://localhost:8080/health`.

Or with Compose:

```bash
docker compose up --build -d
```

## Part 3: CI/CD (GitHub Actions)

Workflow: [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml)

On push to `main` (and PRs for validation only):

1. **Validate** — `npm ci` + `npm run build`
2. **Docker** — build & push to **GitHub Container Registry** (`ghcr.io/<owner>/<repo>:latest`)
3. **Deploy (optional)** — SSH into a server, pull image, restart with `--restart=always`

### Required / optional secrets & variables

| Name | Type | Purpose |
|------|------|---------|
| `GITHUB_TOKEN` | automatic | Push to GHCR |
| `DOCKERHUB_USERNAME` | secret | Docker Hub username (optional) |
| `DOCKERHUB_TOKEN` | secret | Docker Hub access token (optional) |
| `PUSH_DOCKERHUB` | variable | Set to `true` to also push to Docker Hub |
| `ENABLE_SSH_DEPLOY` | variable | Set to `true` to enable remote deploy job |
| `SSH_HOST` | secret | Server hostname/IP |
| `SSH_USER` | secret | SSH username |
| `SSH_PRIVATE_KEY` | secret | Private key for deploy |
| `SSH_PORT` | secret | SSH port (default 22) |
| `GHCR_PULL_TOKEN` | secret | PAT with `read:packages` if server cannot use GITHUB_TOKEN |

**GitHub → Settings → Secrets and variables → Actions**

Package visibility: after the first push, make the GHCR package public (or authenticate the server) under **Packages**.

## Part 4: Production deployment

### 1. Provision a Linux server

Use Ubuntu 22.04+ on AWS, DigitalOcean, Linode, etc. Point a DNS A record at the server IP.

### 2. Bootstrap the host

```bash
# From your machine (after cloning this repo onto the server)
sudo bash deploy/setup-server.sh
```

Installs Docker, Nginx, Certbot, and UFW (ports **22 / 80 / 443** only).

### 3. Run the container

```bash
# Public registry / public package:
export IMAGE=ghcr.io/<owner>/<repo>:latest
bash deploy/run-container.sh

# Or build on the server:
docker compose up --build -d
```

Container listens on `127.0.0.1:8080`; host Nginx handles TLS.

### 4. SSL with Let's Encrypt

1. Edit [`nginx/host-ssl.conf.example`](nginx/host-ssl.conf.example) — replace `YOUR_DOMAIN`.
2. Install on the server:

```bash
sudo cp nginx/host-ssl.conf.example /etc/nginx/sites-available/stans
sudo nano /etc/nginx/sites-available/stans   # set domain
sudo ln -sf /etc/nginx/sites-available/stans /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d YOUR_DOMAIN
```

Certbot renews automatically via systemd timer.

### 5. Firewall checklist

```bash
sudo ufw status
# Should allow: 22/tcp, 80/tcp, 443/tcp only
```

### Architecture

```
Internet → :443 (host Nginx + Let's Encrypt)
              ↓ proxy_pass
         127.0.0.1:8080 (Docker: Nginx Alpine → React SPA)
```

## Project layout (DevOps)

```
Dockerfile                 # Multi-stage Node build + Nginx runtime
docker-compose.yml         # Local/prod container run
.dockerignore
nginx/nginx.conf           # In-container SPA + /health
nginx/host-ssl.conf.example
.github/workflows/deploy.yml
deploy/setup-server.sh
deploy/run-container.sh
```

## Stretch goals (optional)

| Goal | Approach |
|------|----------|
| Health checks | Built into `Dockerfile` / Compose (`/health`) |
| Monitoring | Add Prometheus + cAdvisor + Grafana via Compose |
| Logging | Ship Docker JSON logs to Loki/ELK |
| Load balancing | Multiple replicas behind host Nginx `upstream` or cloud LB |
| IaC | Terraform for droplet/VPC + Ansible for `setup-server.sh` |
| Kubernetes | Deploy Deployment + Service + Ingress instead of single VM |

## License

See [LICENSE](LICENSE).
