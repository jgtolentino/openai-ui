# API Contract (v1)

## Base Path
`/api/v1/*`

## Response Envelope

### Success Response
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

### Error Response
```json
{
  "ok": false,
  "error": {
    "code": string,
    "message": string
  }
}
```

## Idempotency

All non-GET requests MUST include `Idempotency-Key` header (minimum 8 characters).

- Same key MUST return same result within 24-hour window
- Implementation uses in-memory cache or database table
- Returns 400 if header missing or too short

## Pagination

- Query params: `?limit` (1-100, default 25), `?cursor` (opaque string)
- Response includes `meta.nextCursor` when more data available
- Omit `meta.nextCursor` or set to null when at end

## Versioning Rules

- **Additive only** - Never remove or rename fields in `v1`
- Add new optional fields as needed
- Breaking changes require new version (`/api/v2/*`)
- Maintain backward compatibility for minimum 6 months

## Standard Error Codes

- `VALIDATION` - Invalid request parameters
- `IDEMPOTENCY_REQUIRED` - Missing or invalid Idempotency-Key header
- `METHOD_NOT_ALLOWED` - HTTP method not supported
- `DB_ERROR` - Database operation failed
- `NOT_FOUND` - Resource not found
- `UNAUTHORIZED` - Authentication required
- `FORBIDDEN` - Insufficient permissions
