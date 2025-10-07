import type { NextApiRequest, NextApiResponse } from 'next';
import { withContracts } from '@/lib/http/handler';
import { sbAdmin } from '@/lib/sbAdmin';

export default withContracts({
  methods: ['POST'],
  handler: async (req: NextApiRequest, res: NextApiResponse) => {
    const { report_id, action, actor_email, comments } = req.body ?? {};

    if (!report_id || !action || !actor_email) {
      throw Object.assign(new Error('report_id, action, and actor_email required'), { status: 400, code: 'VALIDATION' });
    }

    if (!['approve', 'reject'].includes(action)) {
      throw Object.assign(new Error('action must be approve or reject'), { status: 400, code: 'VALIDATION' });
    }

    const { data, error } = await sbAdmin.rpc('process_approval_step', {
      p_report_id: Number(report_id),
      p_action: String(action),
      p_actor_email: String(actor_email),
      p_comments: comments ? String(comments) : null
    });

    if (error) {
      throw Object.assign(new Error(error.message), { status: 400, code: 'RPC_ERROR' });
    }

    return data;
  }
});
