import { NextApiRequest, NextApiResponse } from 'next';
import { createClient } from '@supabase/supabase-js';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceKey) {
    return res.status(500).json({ error: 'Missing Supabase configuration' });
  }

  const { report_id, actor_email } = req.body;

  if (!report_id || !actor_email) {
    return res.status(400).json({ error: 'Missing required fields: report_id, actor_email' });
  }

  const supabase = createClient(url, serviceKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });

  // Get report details
  const { data: report, error: reportError } = await supabase
    .from('expense_reports')
    .select('id, cost_center_code, total_amount, approval_status, approval_step')
    .eq('id', report_id)
    .single();

  if (reportError || !report) {
    return res.status(404).json({ error: 'Report not found', details: reportError });
  }

  if (report.approval_status !== 'draft') {
    return res.status(400).json({ error: 'Report already submitted' });
  }

  // Get first approval rule for this cost center and amount
  const { data: rule, error: ruleError } = await supabase
    .from('approval_rules')
    .select('*')
    .eq('cost_center_code', report.cost_center_code)
    .lte('min_amount', report.total_amount)
    .gte('max_amount', report.total_amount)
    .eq('step_order', 1)
    .single();

  if (ruleError || !rule) {
    return res.status(400).json({
      error: 'No approval rule found for this cost center and amount',
      details: ruleError
    });
  }

  // Update report to submitted/pending status with step 1
  const { data: updated, error: updateError } = await supabase
    .from('expense_reports')
    .update({
      approval_status: 'pending',
      approval_step: 1,
      submitted_at: new Date().toISOString()
    })
    .eq('id', report_id)
    .select()
    .single();

  if (updateError) {
    return res.status(500).json({ error: 'Failed to submit report', details: updateError });
  }

  // Create approval record for step 1
  const { data: employee, error: empError } = await supabase
    .from('employees')
    .select('id')
    .eq('email', rule.approver_email)
    .single();

  if (!empError && employee) {
    await supabase
      .from('approvals')
      .insert({
        entity_type: 'expense_report',
        entity_id: report_id,
        approver_id: employee.id,
        level: 1,
        status: 'pending'
      });
  }

  return res.status(200).json({
    ok: true,
    message: 'Report submitted for approval',
    report: updated,
    next_approver: rule.approver_email,
    step: 1
  });
}
