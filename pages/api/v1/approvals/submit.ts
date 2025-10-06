import type { NextApiRequest, NextApiResponse } from 'next';
import { withContracts } from '@/lib/http/handler';
import { submitReport } from '@/lib/services/approvals';

export default withContracts({
  methods: ['POST'],
  handler: async (req: NextApiRequest, res: NextApiResponse) => {
    const { report_id, actor_email } = req.body ?? {};
    if (!report_id || !actor_email) {
      throw Object.assign(new Error('report_id, actor_email required'), {
        status: 400,
        code: 'VALIDATION',
      });
    }
    return await submitReport(Number(report_id), String(actor_email));
  },
});
