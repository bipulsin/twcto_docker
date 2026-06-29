# TradeWithCTO application image (FastAPI + all algos)
# Builds from the public trademanthan Git repository.

ARG TRADEMANTHAN_REPO=https://github.com/bipulsin/trademanthan.git
ARG TRADEMANTHAN_REF=main
# Cache-bust: trademanthan commit SHA (see FRONTEND_SRC_REV in Dockerfile.nginx).
ARG APP_SRC_REV=${TRADEMANTHAN_REF}

FROM python:3.12-slim-bookworm AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    APP_HOME=/app \
    PYTHONPATH=/app

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        git \
        libpq-dev \
        pkg-config \
        rsync \
    && rm -rf /var/lib/apt/lists/*

WORKDIR ${APP_HOME}

FROM base AS app-src

ARG TRADEMANTHAN_REPO
ARG TRADEMANTHAN_REF
ARG APP_SRC_REV

RUN echo "app-src-rev=${APP_SRC_REV}" \
    && git init /tmp/src \
    && cd /tmp/src \
    && git remote add origin "${TRADEMANTHAN_REPO}" \
    && git fetch --depth 1 origin "${TRADEMANTHAN_REF}" \
    && git checkout FETCH_HEAD \
    && cd / \
    && rsync -a \
        --exclude='.git' \
        --exclude='.venv*' \
        --exclude='venv' \
        --exclude='logs' \
        --exclude='__pycache__' \
        --exclude='*.pem' \
        --exclude='.env' \
        --exclude='exports' \
        --exclude='dry_run_outputs' \
        /tmp/src/ ${APP_HOME}/ \
    && rm -rf /tmp/src

# NSE instruments JSON (not in git; copied at build time via build context when present)
COPY data/instruments/nse_instruments.json data/instruments/nse_instruments.json

FROM app-src AS deps

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

RUN pip install --upgrade pip setuptools wheel \
    && sed -i \
        -e 's/pandas-ta==0.3.14b0/pandas-ta>=0.4.71b0/' \
        -e 's/pandas==2.0.3/pandas>=2.3.3/' \
        -e 's/numpy==1.24.3/numpy>=2.2.6/' \
        backend/requirements.txt \
    && pip install -r backend/requirements.txt \
    && pip install torch --index-url https://download.pytorch.org/whl/cpu \
    && pip install -r backend/requirements-ml.txt

FROM python:3.12-slim-bookworm AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_HOME=/app \
    PYTHONPATH=/app \
    PATH="/opt/venv/bin:$PATH" \
    ENVIRONMENT=production

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        libpq5 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR ${APP_HOME}

COPY --from=deps /opt/venv /opt/venv
COPY --from=app-src ${APP_HOME} ${APP_HOME}

RUN mkdir -p logs data/instruments inbox

COPY docker/app/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=15s --start-period=120s --retries=5 \
    CMD curl -fsS http://127.0.0.1:8000/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000", "--timeout-graceful-shutdown", "90"]
