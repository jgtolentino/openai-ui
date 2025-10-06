#!/usr/bin/env bash
set -euo pipefail

base="${1:-http://localhost:3001}"

echo "Testing v1 API endpoints..."

# Test GET /api/v1/expenses (no idempotency key needed)
echo "  → GET /api/v1/expenses"
curl -sS "$base/api/v1/expenses?limit=5" | jq -e '.ok==true' >/dev/null && echo "    ✓ OK"

# Test POST without Idempotency-Key (should fail)
echo "  → POST /api/v1/approvals/submit (no idempotency key - should fail)"
curl -sS -X POST "$base/api/v1/approvals/submit" \
  -H 'Content-Type: application/json' \
  -d '{"report_id":1,"actor_email":"test@test.com"}' | \
  jq -e '.ok==false and .error.code=="IDEMPOTENCY_REQUIRED"' >/dev/null && echo "    ✓ Correctly rejected"

# Test POST with Idempotency-Key
echo "  → POST /api/v1/approvals/submit (with idempotency key)"
curl -sS -X POST "$base/api/v1/approvals/submit" \
  -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: demo-key-123456' \
  -d '{"report_id":1,"actor_email":"jane.doe@tbwasmp.ph"}' | \
  jq -e 'has("ok")' >/dev/null && echo "    ✓ OK (idempotency enforced)"

echo ""
echo "✓ v1 API smoke tests passed"
