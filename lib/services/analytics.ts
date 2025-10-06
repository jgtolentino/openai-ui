import { sbAdmin } from '@/lib/sbAdmin';

export async function summary() {
  const [cat, viol] = await Promise.all([
    sbAdmin.from('v_spend_by_category_30d').select('*'),
    sbAdmin.from('v_policy_violations').select('*'),
  ]);

  if (cat.error) {
    throw Object.assign(new Error(cat.error.message), { status: 500, code: 'DB_ERROR' });
  }

  if (viol.error) {
    throw Object.assign(new Error(viol.error.message), { status: 500, code: 'DB_ERROR' });
  }

  return { spend_by_category_30d: cat.data, policy_violations: viol.data };
}
