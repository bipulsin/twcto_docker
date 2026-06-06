#!/bin/bash
# Deploy TradeWithCTO on paperclip-vm. GHCR images are multi-arch (arm64 + amd64).
set -euo pipefail
cd /home/ubuntu/twcto

REBUILD="${REBUILD:-0}"
TRADEMANTHAN_REF="${TRADEMANTHAN_REF:-main}"
export TRADEMANTHAN_REF

git fetch origin main && git reset --hard origin/main

if [[ "$REBUILD" == "1" ]]; then
  echo "[deploy] REBUILD=1: local docker compose build app nginx..."
  docker compose build app nginx
else
  echo "[deploy] pulling app + nginx from GHCR (multi-arch)..."
  docker compose pull app nginx
fi

docker compose up -d --force-recreate app nginx

for _ in $(seq 1 40); do
  if curl -fsS http://127.0.0.1:8080/scan/health >/dev/null 2>&1; then
    echo "[deploy] healthy"
    exit 0
  fi
  sleep 3
done
echo "[deploy] health check timed out" >&2
exit 1
