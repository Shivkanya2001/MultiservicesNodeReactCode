#!/usr/bin/env bash
set -euo pipefail
IMAGE_TAG="${1:-latest}"

echo "[LOGIN]"
docker login -u shivkanyadoiphode

echo "[BUILD]"
IMAGE_TAG="$IMAGE_TAG" docker compose build api web

echo "[PUSH]"
IMAGE_TAG="$IMAGE_TAG" docker compose push api web

echo "[DONE] Published:"
echo "  shivkanyadoiphode/microservicesdeployment-api:${IMAGE_TAG}"
echo "  shivkanyadoiphode/microservicesdeployment-web:${IMAGE_TAG}"
