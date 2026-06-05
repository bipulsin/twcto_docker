#!/usr/bin/env bash
# Export production PostgreSQL + NSE instruments into the Docker build context.
# Run on the EC2 host (or any host with pg_dump access to production DB).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB_DIR="${ROOT}/db"
DATA_DIR="${ROOT}/data/instruments"
DUMP_PATH="${DB_DIR}/trademanthan.dump.gz"

mkdir -p "${DB_DIR}" "${DATA_DIR}"

echo "==> Exporting PostgreSQL database (custom format, gzip)..."
sudo -u postgres pg_dump -Fc trademanthan | gzip -c > "${DUMP_PATH}.tmp"
mv "${DUMP_PATH}.tmp" "${DUMP_PATH}"
ls -lh "${DUMP_PATH}"

INSTR_SRC="${INSTRUMENTS_SRC:-/home/ubuntu/trademanthan/data/instruments/nse_instruments.json}"
if [ -f "${INSTR_SRC}" ]; then
    echo "==> Copying NSE instruments JSON..."
    cp "${INSTR_SRC}" "${DATA_DIR}/nse_instruments.json"
    ls -lh "${DATA_DIR}/nse_instruments.json"
else
    echo "WARN: ${INSTR_SRC} not found — app image build will fail until this file exists." >&2
    exit 1
fi

echo "==> Build context ready under ${ROOT}"
