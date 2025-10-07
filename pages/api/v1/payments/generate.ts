import type { NextApiRequest, NextApiResponse } from 'next';
import { withContracts } from '@/lib/http/handler';
import { sbAdmin } from '@/lib/sbAdmin';

export default withContracts({
  methods: ['POST'],
  handler: async (req: NextApiRequest, res: NextApiResponse) => {
    const { report_ids, payment_date } = req.body ?? {};

    if (!report_ids || !Array.isArray(report_ids) || report_ids.length === 0) {
      throw Object.assign(new Error('report_ids array required'), { status: 400, code: 'VALIDATION' });
    }

    const { data, error } = await sbAdmin.rpc('generate_payment_file', {
      p_report_ids: report_ids.map(Number),
      p_payment_date: payment_date ? String(payment_date) : new Date().toISOString().split('T')[0]
    });

    if (error) {
      throw Object.assign(new Error(error.message), { status: 400, code: 'RPC_ERROR' });
    }

    return {
      payment_file: data?.payment_file || null,
      payment_id: data?.payment_id || null,
      format: 'ISO20022_pain001'
    };
  }
});
