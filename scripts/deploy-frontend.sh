#!/bin/bash
# ============================================================
# deploy-frontend.sh
# Manual frontend deployment script
# Usage: ./scripts/deploy-frontend.sh <s3-bucket-name> [cloudfront-distribution-id]
# ============================================================

set -euo pipefail

S3_BUCKET="${1:-}"
CF_DIST_ID="${2:-}"

if [ -z "$S3_BUCKET" ]; then
  echo "Usage: $0 <s3-bucket-name> [cloudfront-distribution-id]"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$REPO_ROOT/Client/dist"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  StartTech Frontend Deployment"
echo "  Bucket: $S3_BUCKET"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verify build exists
if [ ! -d "$DIST_DIR" ] || [ -z "$(ls -A "$DIST_DIR")" ]; then
  echo "❌ Build directory $DIST_DIR is empty or missing."
  echo "   Run: cd Client && npm ci && npm run build"
  exit 1
fi

echo "[1/3] Syncing HTML files (no-cache)..."
aws s3 sync "$DIST_DIR/" "s3://${S3_BUCKET}/" \
  --delete \
  --exclude "*" \
  --include "*.html" \
  --cache-control "no-cache, no-store, must-revalidate"

echo "[2/3] Syncing static assets (immutable cache)..."
aws s3 sync "$DIST_DIR/" "s3://${S3_BUCKET}/" \
  --delete \
  --exclude "*.html" \
  --cache-control "public, max-age=31536000, immutable"

echo "✅ S3 sync complete"

if [ -n "$CF_DIST_ID" ]; then
  echo "[3/3] Invalidating CloudFront cache..."
  INVALIDATION_ID=$(aws cloudfront create-invalidation \
    --distribution-id "$CF_DIST_ID" \
    --paths "/*" \
    --query "Invalidation.Id" \
    --output text)
  echo "✅ CloudFront invalidation created: $INVALIDATION_ID"
else
  echo "[3/3] Skipping CloudFront invalidation — no distribution ID provided"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Frontend deployment complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
