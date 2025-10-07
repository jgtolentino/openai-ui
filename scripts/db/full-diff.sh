#!/bin/bash
BASE="https://openai-bo264hvgh-jake-tolentinos-projects-c0369c83.vercel.app"

echo "=== TESTING ALL API ENDPOINTS ==="
echo ""

echo "1. GET /api/v1/expenses"
curl -sS "$BASE/api/v1/expenses?limit=1" -H "Idempotency-Key: t1" | jq -c '{ok, error, data_count: (.data | length)}'

echo ""
echo "2. POST /api/v1/expenses"
curl -sS -X POST "$BASE/api/v1/expenses" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: t2" \
  -d '{"employee_email":"test@test.com","expense_type":"Meals","txn_date":"2025-01-01","amount":100,"currency":"PHP"}' \
  | jq -c '{ok, error}'

echo ""
echo "3. POST /api/v1/approvals/submit"
curl -sS -X POST "$BASE/api/v1/approvals/submit" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: t3" \
  -d '{"report_id":1,"actor_email":"test@test.com"}' \
  | jq -c '{ok, error}'

echo ""
echo "4. POST /api/v1/approvals/step"
curl -sS -X POST "$BASE/api/v1/approvals/step" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: t4" \
  -d '{"report_id":1,"action":"approve","actor_email":"test@test.com"}' \
  | jq -c '{ok, error}'

echo ""
echo "5. POST /api/v1/payments/generate"
curl -sS -X POST "$BASE/api/v1/payments/generate" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: t5" \
  -d '{"report_ids":[1]}' \
  | jq -c '{ok, error}'

echo ""
echo "6. GET /api/v1/analytics/summary"
curl -sS "$BASE/api/v1/analytics/summary" -H "Idempotency-Key: t6" | jq -c '{ok, error}'

echo ""
echo ""
echo "=== REPO EXPECTS THESE RPC FUNCTIONS ==="
grep -h "\.rpc(" ~/openai-ui/pages/api/v1/**/*.ts 2>/dev/null | grep -o "rpc('[^']*'" | sort -u

echo ""
echo "=== REPO EXPECTS THESE VIEWS/TABLES ==="
grep -h "\.from(" ~/openai-ui/lib/services/*.ts 2>/dev/null | grep -o "from('[^']*'" | sort -u

