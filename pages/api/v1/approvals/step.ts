import type { NextApiRequest, NextApiResponse } from 'next';
import { withContracts } from '@/lib/http/handler';
import { step } from '@/lib/services/approvals';

export default withContracts({
  methods: ['POST'],
  handler: async (req: NextApiRequest, res: NextApiResponse) => {
    const { report_id, actor_email, action, remark } = req.body ?? {};
    if (!report_id || !actor_email || !action) {
      throw Object.assign(new Error('report_id, actor_email, action required'), {
        status: 400,
        code: 'VALIDATION',
      });
    }
    return await step(Number(report_id), String(actor_email), action, remark);
  },
});
