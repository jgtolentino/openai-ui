import { sbAdmin } from '@/lib/sbAdmin';

export async function listExpenses(limit = 25) {
  const q = await sbAdmin
    .from('expenses_view')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(Math.min(Math.max(limit, 1), 100));

  if (q.error) {
    throw Object.assign(new Error(q.error.message), { status: 500, code: 'DB_ERROR' });
  }

  return q.data;
}

export async function createExpense(body: {
  employee_email: string;
  expense_type: string;
  txn_date: string;
  amount: number;
  currency: string;
  merchant?: string;
  receipt_url?: string;
}) {
  // Resolve employee_email to employee_id
  const { data: emp, error: e1 } = await sbAdmin
    .from('employees')
    .select('id')
    .eq('email', body.employee_email)
    .maybeSingle();
  
  if (e1) throw Object.assign(new Error(e1.message), { status: 500, code: 'DB_ERROR' });
  if (!emp) throw Object.assign(new Error('Employee not found'), { status: 404, code: 'EMPLOYEE_NOT_FOUND' });

  // Insert with employee_id FK
  const payload = {
    employee_id: emp.id,
    expense_type: body.expense_type,
    txn_date: body.txn_date,
    amount: body.amount,
    currency: body.currency,
    merchant: body.merchant || null,
    receipt_url: body.receipt_url || null,
  };

  const { data, error } = await sbAdmin
    .from('expenses')
    .insert(payload)
    .select('id')
    .single();

  if (error) throw Object.assign(new Error(error.message), { status: 400, code: 'DB_ERROR' });
  
  return { id: data.id };
}
