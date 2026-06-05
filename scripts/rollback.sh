#!/bin/bash
# ============================================================
# rollback.sh
# Rolls backend back to a previous ECR image tag
# Usage: ./scripts/rollback.sh <image-tag>
# Example: ./scripts/rollback.sh a1b2c3d4
# ============================================================

set -euo pipefail

ROLLBACK_TAG="${1:-}"
AWS_REGION="us-east-1"
ECR_REPOSITORY="dev-starttech-backend"

if [ -z "$ROLLBACK_TAG" ]; then
  echo "Usage: $0 <image-tag>"
  echo ""
  echo "Available tags in ECR:"
  aws ecr list-images \
    --repository-name "$ECR_REPOSITORY" \
    --filter tagStatus=TAGGED \
    --query "imageIds[*].imageTag" \
    --output table
  exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  StartTech Backend ROLLBACK"
echo "  Tag: $ROLLBACK_TAG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚠️  This will re-tag $ROLLBACK_TAG as :latest"
echo "    and trigger an ASG instance refresh."
read -r -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Rollback cancelled."
  exit 0
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
SOURCE_IMAGE="${ECR_REGISTRY}/${ECR_REPOSITORY}:${ROLLBACK_TAG}"

echo ""
echo "[1/4] Logging into ECR..."
aws ecr get-login-password --region "${AWS_REGION}" | \
  docker login --username AWS --password-stdin "${ECR_REGISTRY}"

echo "[2/4] Pulling rollback image: $SOURCE_IMAGE"
docker pull "${SOURCE_IMAGE}"

echo "[3/4] Re-tagging as :latest and pushing..."
docker tag "${SOURCE_IMAGE}" "${ECR_REGISTRY}/${ECR_REPOSITORY}:latest"
docker push "${ECR_REGISTRY}/${ECR_REPOSITORY}:latest"

echo "[4/4] Triggering ASG instance refresh..."
ASG_NAME=$(aws autoscaling describe-auto-scaling-groups \
  --query "AutoScalingGroups[?contains(AutoScalingGroupName, 'dev-backend')].AutoScalingGroupName" \
  --output text)

REFRESH_ID=$(aws autoscaling start-instance-refresh \
  --auto-scaling-group-name "$ASG_NAME" \
  --preferences '{"MinHealthyPercentage": 50, "InstanceWarmup": 300}' \
  --query "InstanceRefreshId" \
  --output text)

echo "✅ Rollback instance refresh started: $REFRESH_ID"
echo ""
echo "Monitor progress with:"
echo "  aws autoscaling describe-instance-refreshes \\"
echo "    --auto-scaling-group-name $ASG_NAME \\"
echo "    --instance-refresh-ids $REFRESH_ID"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Rollback to tag [$ROLLBACK_TAG] initiated!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
