#!/bin/bash
# ============================================================
# health-check.sh
# Validates backend health via ALB endpoint
# Usage: ./scripts/health-check.sh <alb-dns-name> [retries]
# ============================================================

set -euo pipefail

ALB_HOST="${1:-}"
MAX_RETRIES="${2:-5}"
RETRY_DELAY=10

if [ -z "$ALB_HOST" ]; then
  echo "Usage: $0 <alb-dns-name> [max-retries]"
  exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  StartTech Health Check"
echo "  Target: http://$ALB_HOST"
echo "  Retries: $MAX_RETRIES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_endpoint() {
  local path="$1"
  local expected="$2"
  local label="$3"

  HTTP_STATUS=$(curl -s -o /tmp/hc_response.json \
    -w "%{http_code}" \
    --max-time 10 \
    "http://$ALB_HOST$path" || echo "000")

  if [ "$HTTP_STATUS" = "$expected" ]; then
    echo "  ✅ $label — HTTP $HTTP_STATUS"
    return 0
  else
    echo "  ❌ $label — HTTP $HTTP_STATUS (expected $expected)"
    cat /tmp/hc_response.json 2>/dev/null || true
    return 1
  fi
}

ATTEMPT=0
while [ $ATTEMPT -lt $MAX_RETRIES ]; do
  ATTEMPT=$((ATTEMPT + 1))
  echo ""
  echo "Attempt $ATTEMPT of $MAX_RETRIES..."

  PASS=true

  check_endpoint "/ping"   "200" "Ping endpoint"   || PASS=false
  check_endpoint "/"       "200" "Root endpoint"    || PASS=false
  check_endpoint "/health" "200" "Health endpoint"  || PASS=false

  if [ "$PASS" = "true" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ All health checks passed!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
  fi

  if [ $ATTEMPT -lt $MAX_RETRIES ]; then
    echo "Retrying in ${RETRY_DELAY}s..."
    sleep $RETRY_DELAY
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "❌ Health checks failed after $MAX_RETRIES attempts"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
exit 1
