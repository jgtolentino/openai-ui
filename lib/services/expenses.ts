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
