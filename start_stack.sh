#!/usr/bin/env bash
set -euo pipefail

# === Config (align with docker-compose.yml / .env) ===
ADMINER_PORT="${ADMINER_PORT:-8081}"
DB_CONTAINER="${DB_CONTAINER:-mysql_db}"
API_URL="${API_URL:-http://localhost:4000/api/health}"
WEB_URL="${WEB_URL:-http://localhost:3000}"

echo "[INIT] Bootstrapping Docker stack…"
docker compose up -d

echo "[WAIT] Waiting for MySQL to report healthy…"
for i in {1..30}; do
  health="$(docker inspect --format '{{.State.Health.Status}}' "$DB_CONTAINER" 2>/dev/null || echo unknown)"
  if [[ "$health" == "healthy" ]]; then
    echo "[OK] MySQL is healthy."
    break
  fi
  if [[ $i -eq 30 ]]; then
    echo "[ERROR] MySQL did not become healthy in time."
    docker compose ps
    exit 2
  fi
  sleep 2
done

echo "[INFO] Endpoints"
echo "  API     : $API_URL"
echo "  Web     : $WEB_URL"
echo "  Adminer : http://localhost:$ADMINER_PORT"

# Auto-open (best effort)
if command -v xdg-open >/dev/null 2>&1; then xdg-open "http://localhost:$ADMINER_PORT" >/dev/null 2>&1 || true; fi
if command -v open >/dev/null 2>&1; then open "http://localhost:$ADMINER_PORT" >/dev/null 2>&1 || true; fi
