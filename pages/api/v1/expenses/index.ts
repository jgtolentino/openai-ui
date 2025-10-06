import type { NextApiRequest, NextApiResponse } from 'next';
import { withContracts } from '@/lib/http/handler';
import { listExpenses } from '@/lib/services/expenses';

export default withContracts({
  methods: ['GET'],
  requireIdempotency: false,
  handler: async (req: NextApiRequest, res: NextApiResponse) => {
    const limit = Number(req.query.limit ?? 25);
    return await listExpenses(limit);
  },
});
