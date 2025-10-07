import type { NextApiRequest, NextApiResponse } from 'next';
import { withContracts } from '@/lib/http/handler';
import { sbAdmin } from '@/lib/sbAdmin';

export default withContracts({
  methods: ['GET'],
  handler: async (req: NextApiRequest, res: NextApiResponse) => {
    // Get analytics summary from database
    const { data, error } = await sbAdmin.rpc('get_analytics_summary');

    if (error) {
      throw Object.assign(new Error(error.message), { status: 500, code: 'RPC_ERROR' });
    }

    return {
      summary: data || {
        total_expenses: 0,
        total_amount: 0,
        pending_approvals: 0,
        approved_count: 0,
        rejected_count: 0
      }
    };
  }
});
