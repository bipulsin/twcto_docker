# TradeWithCTO Docker (`twcto_docker`)

Docker packaging for [tradewithcto.com](https://www.tradewithcto.com) — FastAPI backend, all trading algos, static frontend, PostgreSQL (production seed), and Redis.

## Images (GitHub Container Registry)

| Image | Description |
|-------|-------------|
| `ghcr.io/bipulsin/twcto-app` | FastAPI + schedulers + algos (scan, Vajra, Daily Futures, Iron Condor, arbitrage, etc.) |
| `ghcr.io/bipulsin/twcto-nginx` | Nginx reverse proxy + frontend static assets |
| `ghcr.io/bipulsin/twcto-postgres` | PostgreSQL 16 with production `trademanthan` database seed |

Application source is cloned from [bipulsin/trademanthan](https://github.com/bipulsin/trademanthan) at build time (`TRADEMANTHAN_REF`, default `main`).

## Quick start

```bash
git clone https://github.com/bipulsin/twcto_docker.git
cd twcto_docker
cp .env.example .env
# Edit .env — add Google OAuth, Upstox, OpenAI, etc.

docker compose pull   # use pre-built GHCR images
docker compose up -d

open http://localhost:8080
```

Health checks:

- App: `http://localhost:8080/scan/health` (via nginx → `/scan/health`)
- API root: `http://localhost:8080/` (nginx serves frontend)

## Stack

```
Browser → nginx:80 → app:8000 (uvicorn)
                    ↘ postgres:5432
                    ↘ redis:6379
```

On first start, PostgreSQL restores `db/trademanthan.dump.gz` baked into the `twcto-postgres` image (several minutes for ~1.6 GB DB).

## Build images (with production DB seed)

Seed assets (123 MB DB dump + NSE instruments JSON) are published as a GitHub Release:

- [seed-2026-06-05](https://github.com/bipulsin/twcto_docker/releases/tag/seed-2026-06-05)

CI builds and pushes **multi-arch** (`linux/amd64` + `linux/arm64`) images to GHCR on:

- every push to `twcto_docker` `main`
- `repository_dispatch` event `trademanthan-updated` (from TradeManthan release scripts)

**paperclip-vm** (arm64) deploy: `REBUILD=0 docker compose pull app nginx` (~1 min).

To rebuild manually:

```bash
git clone https://github.com/bipulsin/twcto_docker.git
cd twcto_docker
./scripts/export-production-db.sh   # or download release assets into db/ + data/

export GITHUB_TOKEN=<PAT with write:packages>
docker login ghcr.io -u bipulsin
./scripts/build-and-push.sh latest
```

After the first CI run, make packages **public** under GitHub → Packages → Package settings → Change visibility (if `docker pull` returns 403).

## Configuration

Copy `.env.example` → `.env`. Important variables:

- `SECRET_KEY`, `GOOGLE_*`, `UPSTOX_*` — required for auth and live trading
- `POSTGRES_PASSWORD` — change from default in production
- `HTTP_PORT` — host port mapped to nginx (default `8080`)

`DATABASE_URL` and `REDIS_URL` are set automatically in `docker-compose.yml`.

## Volumes

| Volume | Purpose |
|--------|---------|
| `twcto_pgdata` | PostgreSQL data (persists after first restore) |
| `twcto_logs` | Application logs (`trademanthan.log`, algo logs) |
| `twcto_inbox` | ChartInk webhook inbox files |

## Notes

- **ML stack** (FinBERT): PyTorch CPU + `requirements-ml.txt` are installed in the app image.
- **TLS**: This compose exposes HTTP on port 8080. Put Caddy/Traefik/cloud LB in front for HTTPS.
- **Secrets**: Never commit `.env` or database dumps. Rotate credentials if this image was built from production.

## License

Private — TradeWithCTO / TradeManthan.
