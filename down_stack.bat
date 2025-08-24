@echo off
echo [TEARDOWN] Stopping containers, keeping volumes…
docker compose down
REM To also delete volumes (danger: deletes DB data), use:
REM docker compose down -v
