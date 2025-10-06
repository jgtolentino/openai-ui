# 15-Box Architecture - SAP Concur-Class Expense Management

## Overview

This project implements a comprehensive expense management system using a 15-box architecture pattern, ensuring separation of concerns, deterministic contracts, and SAP Concur-class functionality.

## Architecture Layers

### Frontend (5 Boxes)

#### F1. Tokens & Theme
- **Location**: `spec/design-tokens.json` → `build/tokens.css`
- **Purpose**: Single source of truth for design tokens (colors, spacing, typography)
- **Tech**: JSON tokens → CSS variables/Tailwind
- **Determinism**: Version-controlled tokens prevent visual drift

#### F2. UI Kit / Primitives
- **Location**: `components/ui/*`
- **Purpose**: Reusable UI components (buttons, inputs, tables, dialogs)
- **Tech**: Radix UI + Tailwind CSS
- **Status**: ✅ Implemented

#### F3. Feature Views (Pages)
- **Location**: `pages/*`
- **Purpose**: Main application pages (Expenses, Reports, Approvals, Payments, Dashboard)
- **Tech**: Next.js Pages Router
- **Status**: ✅ Implemented

#### F4. Client Data/State
- **Purpose**: Client-side data fetching and state management
- **Tech**: React Query/SWR for server data, Zustand for local state
- **Status**: 🟡 Partial (using existing patterns)

#### F5. Client Auth
- **Location**: Supabase Auth integration
- **Purpose**: Authentication and RLS-based authorization
- **Tech**: Supabase Auth with anon key, RLS policies
- **Status**: ✅ Implemented

### Edge/BFF (4 Boxes)

#### E1. API Gateway / Router
- **Location**: `pages/api/v1/*`, `middleware.ts`
- **Purpose**: Centralized API routing with versioning
- **Tech**: Next.js API routes + Edge middleware
- **Status**: ✅ Implemented

#### E2. Validation & Mapping
- **Location**: `lib/http/handler.ts`, `lib/http/dto.ts`
- **Purpose**: Request validation, DTO envelope enforcement, error handling
- **Tech**: Zod validation, custom DTO helpers
- **Status**: ✅ Implemented

#### E3. File/OCR Ingress
- **Purpose**: Receipt upload and OCR processing
- **Tech**: Supabase Storage + LandingAI OCR
- **Status**: 🟡 Planned

#### E4. Caching & Limits
- **Location**: `middleware.ts`
- **Purpose**: Edge caching for GETs, rate limiting
- **Tech**: Vercel Edge + KV (optional)
- **Status**: ✅ Partial (caching headers implemented)

### Backend (6 Boxes)

#### B1. Controllers (HTTP/RPC)
- **Location**: `pages/api/v1/*`
- **Purpose**: HTTP endpoints for expenses, approvals, payments, analytics
- **Tech**: Next.js API routes with contract enforcement
- **Status**: ✅ Implemented

#### B2. Services / Use-Cases
- **Location**: `lib/services/*`
- **Purpose**: Business logic layer (expenses, approvals, payments, analytics)
- **Tech**: Pure TypeScript functions
- **Status**: ✅ Implemented

#### B3. Workflow Engine
- **Location**: `supabase/migrations/0003_approval_rules.sql`
- **Purpose**: Multi-step approval routing by cost center and amount
- **Tech**: PostgreSQL + RPC functions
- **Status**: ✅ Implemented

#### B4. Integration Ports
- **Purpose**: External integrations (payments, ERP, email/ICS trips)
- **Tech**: ISO20022 pain.001, CSV/JSON exports
- **Status**: 🟡 Partial (payments module exists)

#### B5. Persistence / Repos
- **Location**: `lib/supabaseAdmin.ts`, `lib/sbAdmin.ts`
- **Purpose**: Database access layer
- **Tech**: Supabase admin client (service role)
- **Status**: ✅ Implemented

#### B6. Database
- **Location**: `supabase/migrations/*`
- **Purpose**: PostgreSQL schema, RLS, indexes, health monitoring
- **Tech**: Supabase PostgreSQL
- **Status**: ✅ Core schema implemented

## API Contracts

### Base Path
All v1 APIs: `/api/v1/*`

### Response Envelope

**Success**:
```json
{
  "ok": true,
  "data": <T>,
  "meta"?: {
    "cursor"?: string,
    "total"?: number
  }
}
```

**Error**:
```json
{
  "ok": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message"
  }
}
```

### Idempotency

- **Required**: All POST/PUT/PATCH/DELETE must include `Idempotency-Key` header (≥8 chars)
- **Enforcement**: Middleware at `/api/v1/*` level
- **Window**: 24-hour deduplication window
- **Failure**: Returns 400 if header missing or too short

### Pagination

- **Query params**: `?limit` (1-100, default 25), `?cursor` (opaque string)
- **Response**: Includes `meta.nextCursor` when more data available
- **EOF**: Omit `meta.nextCursor` or set to null

### Versioning

- **Additive only**: Never remove or rename fields in v1
- **Breaking changes**: Require new version `/api/v2/*`
- **Backward compatibility**: Minimum 6 months

## Implemented v1 Endpoints

### GET /api/v1/expenses
- **Purpose**: List expenses with pagination
- **Auth**: Required (RLS-based)
- **Params**: `?limit` (optional)

### POST /api/v1/approvals/submit
- **Purpose**: Submit expense report for approval
- **Body**: `{ report_id, actor_email }`
- **Idempotency**: Required

### POST /api/v1/approvals/step
- **Purpose**: Approve or reject approval step
- **Body**: `{ report_id, actor_email, action, remark? }`
- **Idempotency**: Required

### POST /api/v1/payments/generate
- **Purpose**: Generate ISO20022 pain.001 XML
- **Idempotency**: Required

### GET /api/v1/analytics/summary
- **Purpose**: Get spend summary and policy violations
- **Auth**: Required (RLS-based)

## Database Health Monitoring

### health_db_report() Function
- **Location**: `supabase/migrations/0002_ops_guard_final.sql`
- **Purpose**: Validate database schema completeness
- **Returns**: JSON with missing tables/views/functions and RLS status
- **Status**: ✅ Working

### Current Health Status
```json
{
  "missing_tables": [],
  "missing_views": [],
  "missing_functions": [],
  "rls": [...],  // All 10 tables have RLS enabled with proper policies
  "ok": true
}
```

**Status**: ✅ All database objects created successfully. Health check passes.

## Testing

### Smoke Tests
```bash
# Run v1 API smoke tests
pnpm run api:v1:smoke

# Or manually
bash tests/e2e/api-v1-smoke.sh http://localhost:3001
```

### Test Coverage
- ✅ DTO envelope format
- ✅ Idempotency-Key enforcement
- ✅ Method validation
- ✅ Error handling
- 🟡 Functional endpoint testing (partial)

## Deployment Status

### Completed ✅
- [x] 15-box folder structure
- [x] API contracts documentation
- [x] DTO envelope helpers
- [x] Contract enforcement middleware
- [x] v1 API routes (expenses, approvals, payments, analytics)
- [x] Service layer
- [x] Database migrations (0001, 0002, 0003)
- [x] Health monitoring function
- [x] Smoke test scripts
- [x] package.json scripts updated

### Pending 🟡
- [x] Complete views (expenses_view, payable_reimbursements_view, pending_approvals_view, cash_advances_view)
- [x] Complete RPC functions (upsert_expense, approve_or_reject_report, create_cash_advance)
- [ ] OCR integration (E3)
- [ ] Rate limiting (E4)
- [ ] Trips ICS import
- [ ] Full E2E test coverage
- [ ] Fix Next.js version mismatch (global vs local)

## Next Steps

1. **Implement Missing Views**
   - Create materialized views for expenses, approvals, cash advances

2. **Implement Missing RPC Functions**
   - `upsert_expense()` - Insert or update expense with validation
   - `approve_or_reject_report()` - Multi-step approval workflow
   - `create_cash_advance()` - Cash advance creation with policy checks

3. **Seed Demo Data**
   - Load approval rules from `scripts/seed/approval-demo.sql`
   - Create sample employees, expense types, policies

4. **Run Full Smoke Tests**
   - Test complete approval workflow (submit → manager → finance → approved)
   - Verify payment generation
   - Validate analytics endpoints

5. **Production Hardening**
   - Add rate limiting
   - Implement idempotency cache (database or Redis)
   - Add comprehensive logging
   - Set up monitoring and alerts

## File Organization

```
openai-ui/
├── contracts/
│   └── CONTRACT.md              # API contract documentation
├── lib/
│   ├── http/
│   │   ├── dto.ts               # DTO envelope helpers
│   │   └── handler.ts           # Contract enforcement wrapper
│   ├── services/
│   │   ├── expenses.ts          # Expense business logic
│   │   ├── approvals.ts         # Approval workflow logic
│   │   ├── payments.ts          # Payment generation logic
│   │   └── analytics.ts         # Analytics logic
│   ├── sbAdmin.ts               # Supabase admin client alias
│   └── supabaseAdmin.ts         # Supabase admin client
├── pages/api/v1/
│   ├── expenses/
│   │   └── index.ts             # GET /api/v1/expenses
│   ├── approvals/
│   │   ├── submit.ts            # POST /api/v1/approvals/submit
│   │   └── step.ts              # POST /api/v1/approvals/step
│   ├── payments/
│   │   └── generate.ts          # POST /api/v1/payments/generate
│   └── analytics/
│       └── summary.ts           # GET /api/v1/analytics/summary
├── supabase/migrations/
│   ├── 0001_expense_init.sql    # Core schema (public schema)
│   ├── 0002_ops_guard_final.sql # Health monitoring
│   └── 0003_approval_rules.sql  # Multi-step approval system
├── tests/e2e/
│   └── api-v1-smoke.sh          # API smoke tests
└── middleware.ts                # Idempotency + caching enforcement
```

## References

- **Contracts**: See `contracts/CONTRACT.md`
- **Migrations**: See `supabase/migrations/*`
- **API Docs**: (To be generated from OpenAPI spec)
- **Testing**: See `tests/e2e/*`
