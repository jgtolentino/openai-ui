-- 0003_approval_rules.sql - Multi-step approval system
-- Adds approval_rules table and required columns for multi-step approval workflow

-- Create approval_rules table
CREATE TABLE IF NOT EXISTS public.approval_rules (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  cost_center_code TEXT NOT NULL,
  min_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  max_amount NUMERIC(12,2) NOT NULL,
  step_order INTEGER NOT NULL,
  approver_email TEXT,
  approver_role TEXT CHECK (approver_role IN ('approver', 'finance', 'admin') OR approver_role IS NULL),
  escalate_after_hours INTEGER DEFAULT 48,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(cost_center_code, min_amount, max_amount, step_order)
);

-- Add cost_center_code to employees if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'employees'
    AND column_name = 'cost_center_code'
  ) THEN
    ALTER TABLE public.employees ADD COLUMN cost_center_code TEXT;
  END IF;
END $$;

-- Add approval workflow columns to expense_reports if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'expense_reports'
    AND column_name = 'cost_center_code'
  ) THEN
    ALTER TABLE public.expense_reports ADD COLUMN cost_center_code TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'expense_reports'
    AND column_name = 'approval_status'
  ) THEN
    ALTER TABLE public.expense_reports ADD COLUMN approval_status TEXT DEFAULT 'draft' CHECK (approval_status IN ('draft', 'pending', 'approved', 'rejected'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'expense_reports'
    AND column_name = 'approval_step'
  ) THEN
    ALTER TABLE public.expense_reports ADD COLUMN approval_step INTEGER DEFAULT 0;
  END IF;
END $$;

-- Add update timestamp trigger for approval_rules
CREATE TRIGGER trg_approval_rules_timestamp
  BEFORE UPDATE ON public.approval_rules
  FOR EACH ROW
  EXECUTE FUNCTION public.update_timestamp();

-- Enable RLS on approval_rules
ALTER TABLE public.approval_rules ENABLE ROW LEVEL SECURITY;

-- RLS Policies for approval_rules
-- Read: All authenticated users can see approval rules
CREATE POLICY approval_rules_select ON public.approval_rules
  FOR SELECT TO authenticated USING (true);

-- Insert/Update/Delete: Only finance and admin roles
CREATE POLICY approval_rules_insert ON public.approval_rules
  FOR INSERT TO authenticated
  WITH CHECK (public.current_employee_role() IN ('finance', 'admin'));

CREATE POLICY approval_rules_update ON public.approval_rules
  FOR UPDATE TO authenticated
  USING (public.current_employee_role() IN ('finance', 'admin'));

CREATE POLICY approval_rules_delete ON public.approval_rules
  FOR DELETE TO authenticated
  USING (public.current_employee_role() IN ('finance', 'admin'));

-- Service role bypass
CREATE POLICY service_role_all ON public.approval_rules
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Create index for efficient rule lookup
CREATE INDEX IF NOT EXISTS idx_approval_rules_cost_center
  ON public.approval_rules(cost_center_code, min_amount, max_amount, step_order);
