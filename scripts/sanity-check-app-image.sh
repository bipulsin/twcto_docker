#!/usr/bin/env bash
# Sanity-check a twcto-app image: required source files present + importable.
# Usage:
#   ./scripts/sanity-check-app-image.sh
#   ./scripts/sanity-check-app-image.sh ghcr.io/bipulsin/twcto-app:latest
#   IMAGE=... ./scripts/sanity-check-app-image.sh
set -euo pipefail

IMAGE="${1:-${IMAGE:-ghcr.io/bipulsin/twcto-app:latest}}"

echo "[sanity] checking ${IMAGE}..."
docker run --rm --entrypoint python3 "${IMAGE}" - <<'PY'
from pathlib import Path
import importlib
import sys

required = [
    "backend/main.py",
    "backend/services/kavach_10m.py",
    "backend/services/kavach_engine.py",
    "backend/services/daily_checklist_trade_state.py",
    "backend/services/daily_checklist_chop_gates.py",
    "backend/services/relative_strength_scanner.py",
]
missing = [p for p in required if not Path(p).is_file()]
if missing:
    print("MISSING FILES:", missing, file=sys.stderr)
    sys.exit(1)

# Lightweight imports (no DB). Fail loudly if module path is wrong/empty.
for mod in (
    "backend.services.kavach_10m",
    "backend.services.kavach_engine",
    "backend.services.daily_checklist_chop_gates",
):
    m = importlib.import_module(mod)
    print(f"  import ok: {mod} -> {m.__file__}")

print("app image sanity OK")
PY
