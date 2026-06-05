#!/usr/bin/env bash
# Build all TradeWithCTO Docker images and push to GitHub Container Registry.
#
# Prerequisites:
#   1. Run scripts/export-production-db.sh (creates db/ + data/instruments/)
#   2. export GITHUB_TOKEN=<PAT with write:packages>
#   3. docker login ghcr.io -u bipulsin
#
# Usage:
#   ./scripts/build-and-push.sh [tag]
#   ./scripts/build-and-push.sh v2026.06.05

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

TAG="${1:-latest}"
REGISTRY="${REGISTRY:-ghcr.io/bipulsin}"
TRADEMANTHAN_REF="${TRADEMANTHAN_REF:-main}"

APP_IMAGE="${REGISTRY}/twcto-app:${TAG}"
NGINX_IMAGE="${REGISTRY}/twcto-nginx:${TAG}"
POSTGRES_IMAGE="${REGISTRY}/twcto-postgres:${TAG}"

if [ ! -f "${ROOT}/db/trademanthan.dump.gz" ]; then
    echo "Missing ${ROOT}/db/trademanthan.dump.gz — run scripts/export-production-db.sh first." >&2
    exit 1
fi

if [ ! -f "${ROOT}/data/instruments/nse_instruments.json" ]; then
    echo "Missing NSE instruments JSON — run scripts/export-production-db.sh first." >&2
    exit 1
fi

if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "GITHUB_TOKEN is not set (PAT with write:packages required for ghcr.io push)." >&2
    exit 1
fi

echo "${GITHUB_TOKEN}" | docker login ghcr.io -u bipulsin --password-stdin

echo "==> Building app image (${APP_IMAGE})..."
docker build \
    -f Dockerfile.app \
    --build-arg "TRADEMANTHAN_REF=${TRADEMANTHAN_REF}" \
    -t "${APP_IMAGE}" \
    .

echo "==> Building nginx image (${NGINX_IMAGE})..."
docker build \
    -f Dockerfile.nginx \
    --build-arg "TRADEMANTHAN_REF=${TRADEMANTHAN_REF}" \
    -t "${NGINX_IMAGE}" \
    .

echo "==> Building postgres image (${POSTGRES_IMAGE})..."
docker build \
    -f Dockerfile.postgres \
    -t "${POSTGRES_IMAGE}" \
    .

if [ "${TAG}" = "latest" ]; then
    docker tag "${APP_IMAGE}" "${REGISTRY}/twcto-app:latest"
    docker tag "${NGINX_IMAGE}" "${REGISTRY}/twcto-nginx:latest"
    docker tag "${POSTGRES_IMAGE}" "${REGISTRY}/twcto-postgres:latest"
fi

echo "==> Pushing images to ${REGISTRY}..."
docker push "${APP_IMAGE}"
docker push "${NGINX_IMAGE}"
docker push "${POSTGRES_IMAGE}"

if [ "${TAG}" != "latest" ]; then
    docker push "${REGISTRY}/twcto-app:latest" 2>/dev/null || true
fi

echo "==> Done."
echo "    ${APP_IMAGE}"
echo "    ${NGINX_IMAGE}"
echo "    ${POSTGRES_IMAGE}"
