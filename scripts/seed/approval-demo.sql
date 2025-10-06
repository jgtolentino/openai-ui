-- Approval Matrix Demo Seed Data
-- Idempotent seed script for multi-step approval workflow demo
-- Safe to run multiple times with ON CONFLICT DO NOTHING

-- Ensure approver employees exist (no-op if already present)
INSERT INTO public.employees (email, full_name, role, cost_center_code, status)
VALUES
  ('jane.doe@tbwasmp.ph', 'Jane Doe', 'employee', 'MKT-001', 'active'),
  ('manager@tbwasmp.ph', 'Marketing Manager', 'approver', 'MKT-001', 'active'),
  ('finance@tbwasmp.ph', 'Finance Officer', 'finance', 'FIN-000', 'active')
ON CONFLICT (email) DO UPDATE SET
  cost_center_code = EXCLUDED.cost_center_code,
  role = EXCLUDED.role;

-- Approval rules: MKT cost center up to 50k -> Manager first, then Finance
INSERT INTO public.approval_rules(cost_center_code, min_amount, max_amount, step_order, approver_email, escalate_after_hours)
VALUES
  ('MKT-001', 0, 50000, 1, 'manager@tbwasmp.ph', 48),
  ('MKT-001', 0, 50000, 2, 'finance@tbwasmp.ph', 72)
ON CONFLICT (cost_center_code, min_amount, max_amount, step_order) DO NOTHING;

-- Demo expense report in draft
INSERT INTO public.expense_reports (
  report_number,
  employee_id,
  title,
  description,
  purpose,
  period_start,
  period_end,
  total_amount,
  currency,
  cost_center_code,
  approval_status,
  approval_step
)
SELECT
  'RPT-DEMO-001',
  e.id,
  'Marketing Campaign Expenses',
  'Q4 campaign expenses for digital marketing',
  'Campaign execution',
  CURRENT_DATE - INTERVAL '7 days',
  CURRENT_DATE,
  1250.00,
  'PHP',
  'MKT-001',
  'draft',
  0
FROM public.employees e
WHERE e.email = 'jane.doe@tbwasmp.ph'
ON CONFLICT (report_number) DO NOTHING;

-- Create two demo expenses tied to the demo report
WITH rpt AS (
  SELECT id FROM public.expense_reports
  WHERE report_number = 'RPT-DEMO-001'
),
expense_type_meals AS (
  SELECT id FROM public.expense_types WHERE code = 'MEALS' LIMIT 1
),
expense_type_transport AS (
  SELECT id FROM public.expense_types WHERE code = 'TRANSPORT' LIMIT 1
)
INSERT INTO public.expenses (
  report_id,
  expense_type_id,
  transaction_date,
  vendor,
  description,
  amount,
  currency,
  status
)
SELECT rpt.id, meals.id, CURRENT_DATE - 1, 'GrabFood', 'Team lunch meeting', 450.00, 'PHP', 'approved'
FROM rpt, expense_type_meals meals
WHERE NOT EXISTS (
  SELECT 1 FROM public.expenses e
  WHERE e.report_id = rpt.id AND e.vendor = 'GrabFood'
)
UNION ALL
SELECT rpt.id, transport.id, CURRENT_DATE - 2, 'Grab', 'Client meeting transport', 800.00, 'PHP', 'approved'
FROM rpt, expense_type_transport transport
WHERE NOT EXISTS (
  SELECT 1 FROM public.expenses e
  WHERE e.report_id = rpt.id AND e.vendor = 'Grab'
);

-- Recompute report total from child expenses
WITH tot AS (
  SELECT report_id, SUM(amount)::numeric AS total
  FROM public.expenses
  WHERE report_id IN (SELECT id FROM public.expense_reports WHERE report_number = 'RPT-DEMO-001')
  GROUP BY report_id
)
UPDATE public.expense_reports r
SET total_amount = t.total
FROM tot t
WHERE r.id = t.report_id;
