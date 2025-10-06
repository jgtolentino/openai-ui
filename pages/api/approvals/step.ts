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

  const { report_id, actor_email, action, comments } = req.body;

  if (!report_id || !actor_email || !action) {
    return res.status(400).json({
      error: 'Missing required fields: report_id, actor_email, action'
    });
  }

  if (!['approve', 'reject'].includes(action)) {
    return res.status(400).json({ error: 'Invalid action. Must be "approve" or "reject"' });
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

  if (report.approval_status !== 'pending') {
    return res.status(400).json({ error: 'Report is not pending approval' });
  }

  const currentStep = report.approval_step || 1;

  // Get current step rule
  const { data: currentRule, error: ruleError } = await supabase
    .from('approval_rules')
    .select('*')
    .eq('cost_center_code', report.cost_center_code)
    .lte('min_amount', report.total_amount)
    .gte('max_amount', report.total_amount)
    .eq('step_order', currentStep)
    .single();

  if (ruleError || !currentRule) {
    return res.status(400).json({ error: 'No approval rule found for current step' });
  }

  // Verify actor is the expected approver
  if (currentRule.approver_email !== actor_email) {
    return res.status(403).json({
      error: 'Not authorized to approve at this step',
      expected: currentRule.approver_email
    });
  }

  // Get actor employee ID
  const { data: actor, error: actorError } = await supabase
    .from('employees')
    .select('id')
    .eq('email', actor_email)
    .single();

  if (actorError || !actor) {
    return res.status(404).json({ error: 'Actor employee not found' });
  }

  // Update approval record
  await supabase
    .from('approvals')
    .update({
      status: action === 'approve' ? 'approved' : 'rejected',
      decision_date: new Date().toISOString(),
      comments: comments || null
    })
    .eq('entity_type', 'expense_report')
    .eq('entity_id', report_id)
    .eq('level', currentStep);

  if (action === 'reject') {
    // Rejection: Mark report as rejected
    const { data: rejected } = await supabase
      .from('expense_reports')
      .update({
        approval_status: 'rejected',
        rejection_reason: comments || 'Rejected by approver'
      })
      .eq('id', report_id)
      .select()
      .single();

    return res.status(200).json({
      ok: true,
      message: 'Report rejected',
      report: rejected,
      final_status: 'rejected'
    });
  }

  // Approval: Check if there's a next step
  const nextStep = currentStep + 1;
  const { data: nextRule } = await supabase
    .from('approval_rules')
    .select('*')
    .eq('cost_center_code', report.cost_center_code)
    .lte('min_amount', report.total_amount)
    .gte('max_amount', report.total_amount)
    .eq('step_order', nextStep)
    .single();

  if (nextRule) {
    // Move to next step
    const { data: updated } = await supabase
      .from('expense_reports')
      .update({
        approval_step: nextStep
      })
      .eq('id', report_id)
      .select()
      .single();

    // Create approval record for next step
    const { data: nextApprover } = await supabase
      .from('employees')
      .select('id')
      .eq('email', nextRule.approver_email)
      .single();

    if (nextApprover) {
      await supabase
        .from('approvals')
        .insert({
          entity_type: 'expense_report',
          entity_id: report_id,
          approver_id: nextApprover.id,
          level: nextStep,
          status: 'pending'
        });
    }

    return res.status(200).json({
      ok: true,
      message: `Approved - moving to step ${nextStep}`,
      report: updated,
      next_approver: nextRule.approver_email,
      step: nextStep
    });
  } else {
    // Final approval: Mark report as approved
    const { data: approved } = await supabase
      .from('expense_reports')
      .update({
        approval_status: 'approved',
        approved_at: new Date().toISOString(),
        approved_by: actor.id
      })
      .eq('id', report_id)
      .select()
      .single();

    return res.status(200).json({
      ok: true,
      message: 'Report fully approved',
      report: approved,
      final_status: 'approved'
    });
  }
}
