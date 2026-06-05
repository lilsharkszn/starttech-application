#!/bin/bash
# ============================================================
# deploy-backend.sh
# Manual backend deployment script
# Usage: ./scripts/deploy-backend.sh [image-tag]
# If no tag provided, defaults to "latest"
# ============================================================

set -euo pipefail

AWS_REGION="us-east-1"
ECR_REPOSITORY="dev-starttech-backend"
IMAGE_TAG="${1:-latest}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  StartTech Backend Deployment"
echo "  Tag: $IMAGE_TAG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Resolve AWS account ID dynamically
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_URI="${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"

echo "[1/5] Logging into ECR..."
aws ecr get-login-password --region "${AWS_REGION}" | \
  docker login --username AWS --password-stdin "${ECR_REGISTRY}"

echo "[2/5] Pulling image: $IMAGE_URI"
docker pull "${IMAGE_URI}"

echo "[3/5] Stopping existing container..."
docker stop muchtodo-backend 2>/dev/null || true
docker rm muchtodo-backend 2>/dev/null || true

echo "[4/5] Starting new container..."
docker run -d \
  --name muchtodo-backend \
  --env-file /opt/starttech/.env \
  -p 8080:8080 \
  --restart unless-stopped \
  --log-driver json-file \
  --log-opt max-size=50m \
  --log-opt max-file=3 \
  "${IMAGE_URI}"

echo "[5/5] Verifying container health..."
sleep 10
if docker ps | grep -q muchtodo-backend; then
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time 5 http://localhost:8080/ping || echo "000")
  if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ Deployment successful — /ping returned 200"
  else
    echo "⚠️  Container running but /ping returned: $HTTP_STATUS"
  fi
else
  echo "❌ Container failed to start"
  docker logs muchtodo-backend 2>&1 | tail -20
  exit 1
fi
