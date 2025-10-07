import type { NextApiRequest, NextApiResponse } from 'next';
import { withContracts } from '@/lib/http/handler';
import { listExpenses } from '@/lib/services/expenses';
import { sbAdmin } from '@/lib/sbAdmin';

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
    const { data, error } = await sbAdmin.rpc('upsert_expense', {
      p_employee_email: String(employee_email),
      p_expense_type: String(expense_type),
      p_txn_date: String(txn_date),
      p_amount: Number(amount),
      p_currency: String(currency),
      p_merchant: merchant ? String(merchant) : null,
      p_receipt_url: receipt_url ? String(receipt_url) : null
    });
    if (error) throw Object.assign(new Error(error.message), { status: 400, code: 'RPC_ERROR' });
    return { id: data };
  }
});
