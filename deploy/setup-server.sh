#!/usr/bin/env bash
# Bootstrap a fresh Ubuntu/Debian server for STANS production deployment.
# Usage: sudo bash deploy/setup-server.sh
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash deploy/setup-server.sh"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "==> Updating packages"
apt-get update -y
apt-get upgrade -y

echo "==> Installing Docker"
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
fi

. /etc/os-release
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker

echo "==> Installing Nginx and Certbot"
apt-get install -y nginx certbot python3-certbot-nginx
mkdir -p /var/www/certbot

echo "==> Configuring UFW firewall (22, 80, 443 only)"
apt-get install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
ufw status verbose

echo "==> Done."
echo "Next steps:"
echo "  1. Copy nginx/host-ssl.conf.example to /etc/nginx/sites-available/stans"
echo "  2. Replace YOUR_DOMAIN, enable the site, reload nginx"
echo "  3. Run: certbot --nginx -d YOUR_DOMAIN"
echo "  4. Pull and run the STANS image:"
echo "       docker run -d --name stans-app --restart=always -p 127.0.0.1:8080:80 IMAGE"
