-- ─────────────────────────────────────────────────────────────────────────────
-- Views required by health_db_report() & PostgREST read paths
-- ─────────────────────────────────────────────────────────────────────────────

-- 1) expenses_view
CREATE OR REPLACE VIEW public.expenses_view AS
SELECT e.*
FROM public.expenses e;

-- 2) cash_advances_view
CREATE OR REPLACE VIEW public.cash_advances_view AS
SELECT ca.*
FROM public.cash_advances ca;

-- 3) payable_reimbursements_view
--   Reports that are approved (simplified version without reimbursements table check).
CREATE OR REPLACE VIEW public.payable_reimbursements_view AS
SELECT r.id AS report_id, e.email AS employee_email, r.total_amount, r.cost_center_code
FROM public.expense_reports r
JOIN public.employees e ON r.employee_id = e.id
WHERE r.approval_status = 'approved';

-- Also ensure pending_approvals_view exists (REPLACE is safe)
CREATE OR REPLACE VIEW public.pending_approvals_view AS
SELECT r.id AS report_id, e.email AS employee_email, r.total_amount, r.cost_center_code,
       r.approval_step, r.approval_status
FROM public.expense_reports r
JOIN public.employees e ON r.employee_id = e.id
WHERE r.approval_status IN ('pending', 'in_review');

-- ─────────────────────────────────────────────────────────────────────────────
-- RPCs: upsert_expense, approve_or_reject_report, create_cash_advance
-- (signatures must match health_db_report() expectations)
-- ─────────────────────────────────────────────────────────────────────────────

SET search_path = public;

-- 4) upsert_expense(employee_email text, expense_type text, txn_date date,
--                   amount numeric, currency text, merchant text, receipt_url text)
CREATE OR REPLACE FUNCTION public.upsert_expense(
  p_employee_email text,
  p_expense_type   text,
  p_txn_date       date,
  p_amount         numeric,
  p_currency       text,
  p_merchant       text,
  p_receipt_url    text
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id bigint;
BEGIN
  INSERT INTO public.expenses(
    employee_email, expense_type, txn_date, amount, currency, merchant, receipt_url, status
  )
  VALUES (
    p_employee_email, p_expense_type, p_txn_date, p_amount, p_currency, NULLIF(p_merchant,''), NULLIF(p_receipt_url,''), 'new'
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END $$;

REVOKE ALL ON FUNCTION public.upsert_expense(text,text,date,numeric,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.upsert_expense(text,text,date,numeric,text,text,text) TO authenticated, service_role;

-- 5) approve_or_reject_report(report_id bigint, actor_email text, action text, remark text)
-- Wraps step-wise engine to satisfy legacy integrations.
CREATE OR REPLACE FUNCTION public.approve_or_reject_report(
  p_report_id   bigint,
  p_actor_email text,
  p_action      text,
  p_remark      text
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Simple approval/rejection without multi-step for now
  IF p_action = 'approve' THEN
    UPDATE public.expense_reports
    SET approval_status = 'approved', updated_at = NOW()
    WHERE id = p_report_id;
    RETURN json_build_object('ok', true, 'status', 'approved', 'report_id', p_report_id);
  ELSIF p_action = 'reject' THEN
    UPDATE public.expense_reports
    SET approval_status = 'rejected', updated_at = NOW()
    WHERE id = p_report_id;
    RETURN json_build_object('ok', true, 'status', 'rejected', 'report_id', p_report_id);
  ELSE
    RAISE EXCEPTION 'Unsupported action %', p_action USING ERRCODE = '22023';
  END IF;
END $$;

REVOKE ALL ON FUNCTION public.approve_or_reject_report(bigint,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.approve_or_reject_report(bigint,text,text,text) TO authenticated, service_role;

-- 6) create_cash_advance(employee_email text, amount numeric, currency text, purpose text)
CREATE OR REPLACE FUNCTION public.create_cash_advance(
  p_employee_email text,
  p_amount         numeric,
  p_currency       text,
  p_purpose        text
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id bigint;
BEGIN
  INSERT INTO public.cash_advances(employee_email, amount, currency, purpose, status)
  VALUES (p_employee_email, p_amount, p_currency, p_purpose, 'submitted')
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

REVOKE ALL ON FUNCTION public.create_cash_advance(text,numeric,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_cash_advance(text,numeric,text,text) TO authenticated, service_role;
