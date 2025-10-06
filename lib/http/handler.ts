import type { NextApiHandler, NextApiRequest, NextApiResponse } from 'next';
import { fail, toRes } from './dto';

type Method = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

export function withContracts(opts: {
  methods: Method[];
  requireIdempotency?: boolean;
  validate?: (req: NextApiRequest) => void | Promise<void>;
  handler: (req: NextApiRequest, res: NextApiResponse) => Promise<any>;
}): NextApiHandler {
  const methods = opts.methods;
  return async (req, res) => {
    try {
      if (!methods.includes(req.method as Method)) {
        return toRes(
          res,
          {
            ok: false,
            error: { code: 'METHOD_NOT_ALLOWED', message: 'Method not allowed' },
          },
          405
        );
      }

      const nonGet = req.method !== 'GET';
      const wantIdem = opts.requireIdempotency ?? nonGet;
      if (wantIdem) {
        const k = req.headers['idempotency-key'];
        if (!k || typeof k !== 'string' || k.trim().length < 8) {
          throw Object.assign(new Error('Missing or too-short Idempotency-Key'), {
            status: 400,
            code: 'IDEMPOTENCY_REQUIRED',
          });
        }
      }

      if (opts.validate) await opts.validate(req);
      const data = await opts.handler(req, res);
      return toRes(res, { ok: true, data }, 200);
    } catch (e: any) {
      const status = Number(e.status) || 400;
      const code = e.code || 'BAD_REQUEST';
      return toRes(res, { ok: false, error: { code, message: e.message || 'Error' } }, status);
    }
  };
}
