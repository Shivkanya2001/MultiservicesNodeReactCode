#!/usr/bin/env bash
set -euo pipefail
echo "[TEARDOWN] Stopping containers, keeping volumes…"
docker compose down
# To also delete volumes (danger: deletes DB data), use:
# docker compose down -v
