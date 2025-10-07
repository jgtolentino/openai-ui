import type { NextApiRequest, NextApiResponse } from 'next';
import { withContracts } from '@/lib/http/handler';
import { listExpenses, createExpense } from '@/lib/services/expenses';

export default withContracts({
  methods: ['GET','POST'],
  handler: async (req: NextApiRequest, res: NextApiResponse) => {
    if (req.method === 'GET') {
      const limit = Number(req.query.limit ?? 25);
      return await listExpenses(limit);
    }
    
    const { employee_email, expense_type, txn_date, amount, currency, merchant, receipt_url } = req.body ?? {};
    
    if (!employee_email || !expense_type || !txn_date || amount == null || !currency) {
      throw Object.assign(new Error('employee_email, expense_type, txn_date, amount, currency required'), { status: 400, code: 'VALIDATION' });
    }
    
    return await createExpense({ employee_email, expense_type, txn_date, amount, currency, merchant, receipt_url });
  }
});
