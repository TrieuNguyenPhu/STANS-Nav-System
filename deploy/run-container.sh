#!/usr/bin/env bash
# Pull and (re)start the STANS container on a production host.
# Usage:
#   IMAGE=ghcr.io/OWNER/REPO:latest ./deploy/run-container.sh
set -euo pipefail

IMAGE="${IMAGE:-stans-app:latest}"
NAME="${NAME:-stans-app}"
PORT_BINDING="${PORT_BINDING:-127.0.0.1:8080:80}"

docker pull "${IMAGE}" || true

if docker ps -a --format '{{.Names}}' | grep -qx "${NAME}"; then
  docker stop "${NAME}" || true
  docker rm "${NAME}" || true
fi

docker run -d \
  --name "${NAME}" \
  --restart=always \
  -p "${PORT_BINDING}" \
  "${IMAGE}"

echo "Waiting for health..."
for i in $(seq 1 20); do
  if curl -sf "http://127.0.0.1:8080/health" >/dev/null; then
    echo "STANS is healthy at http://127.0.0.1:8080"
    exit 0
  fi
  sleep 1
done

echo "Health check failed" >&2
docker logs "${NAME}" || true
exit 1
