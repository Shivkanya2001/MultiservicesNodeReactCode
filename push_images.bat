@echo off
setlocal ENABLEDELAYEDEXPANSION

REM =========================================
REM Usage: push_images.bat [TAG]
REM Default TAG = latest
REM =========================================

set "IMAGE_TAG=%~1"
if "%IMAGE_TAG%"=="" set "IMAGE_TAG=latest"

REM --- Your Docker Hub repos ---
set "API_IMAGE=shivkanyadoiphode/microservicesdeployment-api"
set "WEB_IMAGE=shivkanyadoiphode/microservicesdeployment-web"

REM --- Login to Docker Hub ---
if "%DOCKERHUB_TOKEN%"=="" (
  echo Enter your Docker Hub access token for user: shivkanyadoiphode
  set /p DOCKERHUB_TOKEN=Token:
)

echo [LOGIN] Logging into Docker Hub...
echo %DOCKERHUB_TOKEN% | docker login -u shivkanyadoiphode --password-stdin
if errorlevel 1 (
  echo [ERROR] Docker login failed.
  exit /b 1
)

echo [BUILD] Building images with tag: %IMAGE_TAG%
docker compose build api web
if errorlevel 1 (
  echo [ERROR] Build failed.
  exit /b 2
)

echo [TAG] Tagging images
docker tag %API_IMAGE%:local %API_IMAGE%:%IMAGE_TAG%
docker tag %WEB_IMAGE%:local %WEB_IMAGE%:%IMAGE_TAG%

echo [PUSH] Pushing images to Docker Hub...
docker push %API_IMAGE%:%IMAGE_TAG%
if errorlevel 1 (
  echo [ERROR] Push failed for API.
  exit /b 3
)

docker push %WEB_IMAGE%:%IMAGE_TAG%
if errorlevel 1 (
  echo [ERROR] Push failed for Web.
  exit /b 4
)

echo [DONE] Published successfully:
echo   %API_IMAGE%:%IMAGE_TAG%
echo   %WEB_IMAGE%:%IMAGE_TAG%

endlocal
exit /b 0
