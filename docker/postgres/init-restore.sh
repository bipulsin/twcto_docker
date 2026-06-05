#!/bin/bash
set -euo pipefail

DUMP="/docker-entrypoint-initdb.d/trademanthan.dump.gz"

if [ ! -f "$DUMP" ]; then
    echo "No seed dump found at $DUMP — starting with empty ${POSTGRES_DB} database."
    exit 0
fi

echo "Restoring TradeWithCTO database from ${DUMP} (this may take several minutes)..."
gunzip -c "$DUMP" | pg_restore \
    --no-owner \
    --no-privileges \
    --role="${POSTGRES_USER}" \
    --dbname="${POSTGRES_DB}" \
    --verbose

echo "Database restore complete."
