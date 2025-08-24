@echo off
setlocal ENABLEDELAYEDEXPANSION

REM === Config (align with docker-compose.yml / .env) ===
set ADMINER_PORT=8081
set DB_CONTAINER=mysql_db
set API_URL=http://localhost:4000/api/health
set WEB_URL=http://localhost:3000

echo [INIT] Bootstrapping Docker stack…
docker compose up -d
if errorlevel 1 (
  echo [ERROR] docker compose up failed.
  exit /b 1
)

echo [WAIT] Waiting for MySQL to report healthy…
set /a tries=0
:wait_loop
for /f "usebackq tokens=*" %%i in (`docker inspect --format "{{.State.Health.Status}}" %DB_CONTAINER% 2^>NUL`) do set HEALTH=%%i
if "%HEALTH%"=="healthy" goto healthy
set /a tries+=1
if %tries% GEQ 30 (
  echo [ERROR] MySQL did not become healthy in time.
  docker compose ps
  exit /b 2
)
timeout /t 2 >nul
goto wait_loop

:healthy
echo [OK] MySQL is healthy.

echo [INFO] Endpoints
echo   API     : %API_URL%
echo   Web     : %WEB_URL%
echo   Adminer : http://localhost:%ADMINER_PORT%

REM Optionally auto-open Adminer & Web in default browser
start "" http://localhost:%ADMINER_PORT%
start "" %WEB_URL%
endlocal
exit /b 0
