import type { NextRequest } from 'next/server';
import { NextResponse } from 'next/server';

export const config = { matcher: ['/api/v1/:path*'] };

export default async function middleware(req: NextRequest) {
  // Cache for GET
  if (req.method === 'GET') {
    const res = NextResponse.next();
    res.headers.set('Cache-Control', 'private, max-age=30, stale-while-revalidate=60');
    return res;
  }

  // Enforce Idempotency-Key (case-insensitive)
  const key = req.headers.get('idempotency-key') || req.headers.get('Idempotency-Key');
  if (!key || key.trim().length < 8) {
    return NextResponse.json(
      {
        ok: false,
        error: {
          code: 'IDEMPOTENCY_REQUIRED',
          message: 'Provide Idempotency-Key header (>=8 chars).',
        },
      },
      { status: 400 }
    );
  }
  return NextResponse.next();
}
