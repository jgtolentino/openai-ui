import { sbAdmin } from '@/lib/sbAdmin';

export async function submitReport(report_id: number, actor_email: string) {
  const { data, error } = await sbAdmin.rpc('submit_report', {
    p_report_id: report_id,
    p_actor_email: actor_email,
  });

  if (error) {
    throw Object.assign(new Error(error.message), { status: 400, code: 'SUBMIT_FAILED' });
  }

  return data;
}

export async function step(
  report_id: number,
  actor_email: string,
  action: 'approve' | 'reject',
  remark?: string
) {
  const { data, error } = await sbAdmin.rpc('approve_or_reject_step', {
    p_report_id: report_id,
    p_actor_email: actor_email,
    p_action: action,
    p_remark: remark ?? null,
  });

  if (error) {
    throw Object.assign(new Error(error.message), { status: 400, code: 'STEP_FAILED' });
  }

  return data;
}
