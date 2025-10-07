import type { NextApiRequest, NextApiResponse } from 'next';
import { toRes } from '@/lib/http/dto';

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  return toRes(res, { ok: false, error: { code: 'NOT_FOUND', message: 'Unknown /api/v1 endpoint' } }, 404);
}
