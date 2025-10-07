#!/bin/bash
# Production vs Repo Schema Diff

echo "=== PRODUCTION DATABASE SCHEMA ==="
echo ""
echo "Checking tables, views, and functions..."

# Use the API to check what works
BASE="https://openai-bo264hvgh-jake-tolentinos-projects-c0369c83.vercel.app"

echo ""
echo "1. GET /api/v1/expenses (uses expenses_view)"
curl -sS "$BASE/api/v1/expenses?limit=1" | jq -r '.ok, .data | length'

echo ""
echo "2. POST /api/v1/expenses (calls upsert_expense RPC)"
curl -sS -X POST "$BASE/api/v1/expenses" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: schema-test-1" \
  -d '{"employee_email":"test@test.com","expense_type":"test","txn_date":"2025-01-01","amount":100,"currency":"PHP"}' \
  | jq -r '.ok, .error.code, .error.message'

echo ""
echo "=== REPO EXPECTATIONS ==="
echo ""
echo "From pages/api/v1/expenses/index.ts:"
grep -A 5 "upsert_expense" ~/openai-ui/pages/api/v1/expenses/index.ts

echo ""
echo "From lib/services/expenses.ts:"
grep "from.*expenses" ~/openai-ui/lib/services/expenses.ts

