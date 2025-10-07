import type { NextApiRequest, NextApiResponse } from 'next';
import { withContracts } from '@/lib/http/handler';
import { sbAdmin } from '@/lib/sbAdmin';

export default withContracts({
  methods: ['POST'],
  handler: async (req: NextApiRequest, res: NextApiResponse) => {
    const { report_id, actor_email } = req.body ?? {};

    if (!report_id || !actor_email) {
      throw Object.assign(new Error('report_id and actor_email required'), { status: 400, code: 'VALIDATION' });
    }

    const { data, error } = await sbAdmin.rpc('submit_report', {
      p_report_id: Number(report_id),
      p_actor_email: String(actor_email)
    });

    if (error) {
      throw Object.assign(new Error(error.message), { status: 400, code: 'RPC_ERROR' });
    }

    return data;
  }
});
