# TBWA\SMP Expense Management MVP

**Production**: https://openai-bo264hvgh-jake-tolentinos-projects-c0369c83.vercel.app  
**Database**: xkxyvboeubffxxbebsll.supabase.co

## Architecture

- **Next.js 13.2.4** (Pages Router)
- **Supabase PostgreSQL** with RLS
- **PostgREST** for read operations (anon key)
- **Next.js API** for write operations (service_role key)

## API Endpoints

### Read (PostgREST)
- `GET /rest/v1/expenses_view?select=*&limit=25`
- Auth: `apikey: <ANON_KEY>`

### Write (Next.js)
- `POST /api/v1/expenses` - Create expense
- `POST /api/v1/approvals/submit` - Submit report
- `POST /api/v1/approvals/step` - Approve/reject
- `POST /api/v1/payments/generate` - Generate payment file
- Auth: Server-side service_role key
- Required header: `Idempotency-Key` (≥8 chars)

## GPT Action Setup

1. Create Custom GPT
2. Add Action with schema from `docs/gpt-action-schema.yaml`
3. Configure Auth:
   - **API Key**: `apikey` header = `<NEXT_PUBLIC_SUPABASE_ANON_KEY>`
4. Test with: "List my expenses" and "Create expense for lunch $50"

## Local Development

```bash
pnpm install
pnpm dev  # http://localhost:3001
```

## Deployment

```bash
vercel build
vercel deploy --prebuilt --yes
vercel promote <deployment-url>
```

## Database Migrations

New migrations in `supabase/migrations/` are applied via CI or manual push:

```bash
supabase db push
```

## Error Envelope

All responses use:
```json
{
  "ok": true,
  "data": { ... }
}
```
or
```json
{
  "ok": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable message"
  }
}
```
