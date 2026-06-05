#!/bin/sh
set -eu

wait_for_postgres() {
    host="${POSTGRES_HOST:-postgres}"
    port="${POSTGRES_PORT:-5432}"
    user="${POSTGRES_USER:-trademanthan}"
    db="${POSTGRES_DB:-trademanthan}"

    echo "Waiting for PostgreSQL at ${host}:${port}..."
    for i in $(seq 1 90); do
        if python - <<'PY'
import os, sys
import psycopg2
host = os.environ.get("POSTGRES_HOST", "postgres")
port = int(os.environ.get("POSTGRES_PORT", "5432"))
user = os.environ.get("POSTGRES_USER", "trademanthan")
password = os.environ.get("POSTGRES_PASSWORD", "trademanthan123")
db = os.environ.get("POSTGRES_DB", "trademanthan")
try:
    psycopg2.connect(host=host, port=port, user=user, password=password, dbname=db, connect_timeout=3)
except Exception:
    sys.exit(1)
PY
        then
            echo "PostgreSQL is ready."
            return 0
        fi
        sleep 2
    done
    echo "PostgreSQL did not become ready in time." >&2
    exit 1
}

if [ -n "${DATABASE_URL:-}" ]; then
    wait_for_postgres
fi

exec "$@"
