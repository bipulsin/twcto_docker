#!/bin/bash
set -euo pipefail
cd /home/ubuntu/twcto
REBUILD="${REBUILD:-1}"
TRADEMANTHAN_REF="${TRADEMANTHAN_REF:-main}"
export TRADEMANTHAN_REF
git fetch origin main && git reset --hard origin/main
docker compose pull || true
if [[ "$REBUILD" == "1" ]]; then
  docker compose build app nginx
fi
docker compose up -d --force-recreate app nginx
for _ in $(seq 1 40); do
  curl -fsS http://127.0.0.1:8080/scan/health >/dev/null 2>&1 && echo "[deploy] healthy" && exit 0
  sleep 3
done
echo "[deploy] health check timed out" >&2
exit 1
