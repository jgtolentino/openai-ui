-- 0001_expense_init.sql - Core expense management schema
-- TBWA\SMP Cash Advance + Expense Management System

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create schema
-- Schema: using public

-- ============================================
-- MASTER DATA TABLES
-- ============================================

-- Employees table
CREATE TABLE public.employees (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  employee_id TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  department_id UUID,
  manager_id UUID,
  role TEXT NOT NULL CHECK (role IN ('employee', 'approver', 'finance', 'admin')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Departments table
CREATE TABLE public.departments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  parent_id UUID REFERENCES public.departments(id),
  manager_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Cost centers table
CREATE TABLE public.cost_centers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  department_id UUID REFERENCES public.departments(id),
  budget_amount NUMERIC(12,2),
  fiscal_year INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'closed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Expense types table
CREATE TABLE public.expense_types (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('travel', 'meals', 'supplies', 'services', 'other')),
  requires_receipt BOOLEAN NOT NULL DEFAULT true,
  max_amount NUMERIC(12,2),
  description TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Policies table
CREATE TABLE public.policies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  version TEXT NOT NULL,
  effective_date DATE NOT NULL,
  expiry_date DATE,
  rules JSONB NOT NULL,
  created_by UUID NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'archived')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================
-- TRANSACTION TABLES
-- ============================================

-- Expense reports table
CREATE TABLE public.expense_reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  report_number TEXT NOT NULL UNIQUE,
  employee_id UUID NOT NULL REFERENCES public.employees(id),
  title TEXT NOT NULL,
  description TEXT,
  purpose TEXT NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'approved', 'rejected', 'paid', 'cancelled')),
  submitted_at TIMESTAMPTZ,
  approved_at TIMESTAMPTZ,
  approved_by UUID REFERENCES public.employees(id),
  paid_at TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Expenses table
CREATE TABLE public.expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  report_id UUID NOT NULL REFERENCES public.expense_reports(id) ON DELETE CASCADE,
  expense_type_id UUID NOT NULL REFERENCES public.expense_types(id),
  cost_center_id UUID REFERENCES public.cost_centers(id),
  transaction_date DATE NOT NULL,
  vendor TEXT NOT NULL,
  description TEXT NOT NULL,
  amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  currency TEXT NOT NULL DEFAULT 'PHP',
  exchange_rate NUMERIC(10,4) DEFAULT 1.0,
  base_amount NUMERIC(12,2),
  tax_amount NUMERIC(12,2) DEFAULT 0,
  has_receipt BOOLEAN NOT NULL DEFAULT false,
  receipt_id UUID,
  notes TEXT,
  policy_violations JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Cash advances table
CREATE TABLE public.cash_advances (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  advance_number TEXT NOT NULL UNIQUE,
  employee_id UUID NOT NULL REFERENCES public.employees(id),
  purpose TEXT NOT NULL,
  requested_amount NUMERIC(12,2) NOT NULL CHECK (requested_amount > 0),
  approved_amount NUMERIC(12,2),
  currency TEXT NOT NULL DEFAULT 'PHP',
  needed_by DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'disbursed', 'liquidated', 'cancelled')),
  approved_at TIMESTAMPTZ,
  approved_by UUID REFERENCES public.employees(id),
  disbursed_at TIMESTAMPTZ,
  liquidated_at TIMESTAMPTZ,
  liquidation_report_id UUID REFERENCES public.expense_reports(id),
  rejection_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Approvals table
CREATE TABLE public.approvals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  entity_type TEXT NOT NULL CHECK (entity_type IN ('expense_report', 'cash_advance')),
  entity_id UUID NOT NULL,
  approver_id UUID NOT NULL REFERENCES public.employees(id),
  level INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'delegated')),
  decision_date TIMESTAMPTZ,
  comments TEXT,
  delegated_to UUID REFERENCES public.employees(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Receipts table
CREATE TABLE public.receipts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  expense_id UUID REFERENCES public.expenses(id) ON DELETE SET NULL,
  storage_path TEXT NOT NULL,
  file_name TEXT NOT NULL,
  file_type TEXT NOT NULL,
  file_size INTEGER NOT NULL,
  ocr_data JSONB,
  ocr_confidence NUMERIC(5,4),
  uploaded_by UUID NOT NULL REFERENCES public.employees(id),
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  verified BOOLEAN NOT NULL DEFAULT false,
  verified_at TIMESTAMPTZ,
  verified_by UUID REFERENCES public.employees(id)
);

-- Corporate cards table
CREATE TABLE public.corporate_cards (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  card_number_last4 TEXT NOT NULL,
  card_holder_id UUID NOT NULL REFERENCES public.employees(id),
  card_type TEXT NOT NULL CHECK (card_type IN ('physical', 'virtual')),
  issuer TEXT NOT NULL,
  credit_limit NUMERIC(12,2),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'cancelled')),
  issued_date DATE NOT NULL,
  expiry_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Card transactions table
CREATE TABLE public.card_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  card_id UUID NOT NULL REFERENCES public.corporate_cards(id),
  transaction_date TIMESTAMPTZ NOT NULL,
  merchant TEXT NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'PHP',
  description TEXT,
  category TEXT,
  matched_expense_id UUID REFERENCES public.expenses(id),
  matched_at TIMESTAMPTZ,
  matched_by UUID REFERENCES public.employees(id),
  import_batch_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Audit log table
CREATE TABLE public.audit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('create', 'update', 'delete', 'approve', 'reject', 'submit')),
  user_id UUID NOT NULL REFERENCES public.employees(id),
  changes JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX idx_employees_department ON public.employees(department_id);
CREATE INDEX idx_employees_manager ON public.employees(manager_id);
CREATE INDEX idx_employees_status ON public.employees(status);

CREATE INDEX idx_departments_parent ON public.departments(parent_id);
CREATE INDEX idx_cost_centers_department ON public.cost_centers(department_id);
CREATE INDEX idx_cost_centers_fiscal_year ON public.cost_centers(fiscal_year);

CREATE INDEX idx_expense_reports_employee ON public.expense_reports(employee_id);
CREATE INDEX idx_expense_reports_status ON public.expense_reports(status);
CREATE INDEX idx_expense_reports_dates ON public.expense_reports(period_start, period_end);

CREATE INDEX idx_expenses_report ON public.expenses(report_id);
CREATE INDEX idx_expenses_type ON public.expenses(expense_type_id);
CREATE INDEX idx_expenses_cost_center ON public.expenses(cost_center_id);
CREATE INDEX idx_expenses_date ON public.expenses(transaction_date);

CREATE INDEX idx_cash_advances_employee ON public.cash_advances(employee_id);
CREATE INDEX idx_cash_advances_status ON public.cash_advances(status);

CREATE INDEX idx_approvals_entity ON public.approvals(entity_type, entity_id);
CREATE INDEX idx_approvals_approver ON public.approvals(approver_id);
CREATE INDEX idx_approvals_status ON public.approvals(status);

CREATE INDEX idx_receipts_expense ON public.receipts(expense_id);
CREATE INDEX idx_card_transactions_card ON public.card_transactions(card_id);
CREATE INDEX idx_card_transactions_matched ON public.card_transactions(matched_expense_id);

CREATE INDEX idx_audit_log_entity ON public.audit_log(entity_type, entity_id);
CREATE INDEX idx_audit_log_user ON public.audit_log(user_id);
CREATE INDEX idx_audit_log_created ON public.audit_log(created_at DESC);

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Function to get current employee role
CREATE OR REPLACE FUNCTION public.current_employee_role()
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
  SELECT role FROM public.employees WHERE email = auth.jwt()->>'email' LIMIT 1;
$$;

-- Function to calculate report total
CREATE OR REPLACE FUNCTION public.sum_report_amount(report_id UUID)
RETURNS NUMERIC(12,2)
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(SUM(amount), 0) FROM public.expenses WHERE report_id = $1;
$$;

-- Trigger to update expense report total
CREATE OR REPLACE FUNCTION public.update_report_total()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.expense_reports
  SET total_amount = public.sum_report_amount(NEW.report_id),
      updated_at = NOW()
  WHERE id = NEW.report_id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_update_report_total
AFTER INSERT OR UPDATE OR DELETE ON public.expenses
FOR EACH ROW
EXECUTE FUNCTION public.update_report_total();

-- Trigger to update timestamps
CREATE OR REPLACE FUNCTION public.update_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_employees_timestamp BEFORE UPDATE ON public.employees FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();
CREATE TRIGGER trg_departments_timestamp BEFORE UPDATE ON public.departments FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();
CREATE TRIGGER trg_cost_centers_timestamp BEFORE UPDATE ON public.cost_centers FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();
CREATE TRIGGER trg_expense_types_timestamp BEFORE UPDATE ON public.expense_types FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();
CREATE TRIGGER trg_policies_timestamp BEFORE UPDATE ON public.policies FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();
CREATE TRIGGER trg_expense_reports_timestamp BEFORE UPDATE ON public.expense_reports FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();
CREATE TRIGGER trg_expenses_timestamp BEFORE UPDATE ON public.expenses FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();
CREATE TRIGGER trg_cash_advances_timestamp BEFORE UPDATE ON public.cash_advances FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();
CREATE TRIGGER trg_approvals_timestamp BEFORE UPDATE ON public.approvals FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();
CREATE TRIGGER trg_corporate_cards_timestamp BEFORE UPDATE ON public.corporate_cards FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS on all tables
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cost_centers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_advances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.corporate_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.card_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- Employees: All authenticated users can read, only admin can modify
CREATE POLICY employees_select ON public.employees FOR SELECT TO authenticated USING (true);
CREATE POLICY employees_insert ON public.employees FOR INSERT TO authenticated WITH CHECK (public.current_employee_role() = 'admin');
CREATE POLICY employees_update ON public.employees FOR UPDATE TO authenticated USING (public.current_employee_role() = 'admin');
CREATE POLICY employees_delete ON public.employees FOR DELETE TO authenticated USING (public.current_employee_role() = 'admin');

-- Departments: All authenticated users can read, only admin can modify
CREATE POLICY departments_select ON public.departments FOR SELECT TO authenticated USING (true);
CREATE POLICY departments_insert ON public.departments FOR INSERT TO authenticated WITH CHECK (public.current_employee_role() = 'admin');
CREATE POLICY departments_update ON public.departments FOR UPDATE TO authenticated USING (public.current_employee_role() = 'admin');
CREATE POLICY departments_delete ON public.departments FOR DELETE TO authenticated USING (public.current_employee_role() = 'admin');

-- Cost centers: All authenticated users can read, only finance/admin can modify
CREATE POLICY cost_centers_select ON public.cost_centers FOR SELECT TO authenticated USING (true);
CREATE POLICY cost_centers_insert ON public.cost_centers FOR INSERT TO authenticated WITH CHECK (public.current_employee_role() IN ('finance', 'admin'));
CREATE POLICY cost_centers_update ON public.cost_centers FOR UPDATE TO authenticated USING (public.current_employee_role() IN ('finance', 'admin'));
CREATE POLICY cost_centers_delete ON public.cost_centers FOR DELETE TO authenticated USING (public.current_employee_role() IN ('finance', 'admin'));

-- Expense types: All can read, only finance/admin can modify
CREATE POLICY expense_types_select ON public.expense_types FOR SELECT TO authenticated USING (true);
CREATE POLICY expense_types_insert ON public.expense_types FOR INSERT TO authenticated WITH CHECK (public.current_employee_role() IN ('finance', 'admin'));
CREATE POLICY expense_types_update ON public.expense_types FOR UPDATE TO authenticated USING (public.current_employee_role() IN ('finance', 'admin'));
CREATE POLICY expense_types_delete ON public.expense_types FOR DELETE TO authenticated USING (public.current_employee_role() IN ('finance', 'admin'));

-- Policies: All can read, only admin can modify
CREATE POLICY policies_select ON public.policies FOR SELECT TO authenticated USING (true);
CREATE POLICY policies_insert ON public.policies FOR INSERT TO authenticated WITH CHECK (public.current_employee_role() = 'admin');
CREATE POLICY policies_update ON public.policies FOR UPDATE TO authenticated USING (public.current_employee_role() = 'admin');
CREATE POLICY policies_delete ON public.policies FOR DELETE TO authenticated USING (public.current_employee_role() = 'admin');

-- Expense reports: Users can see own reports, approvers/finance/admin can see all
CREATE POLICY expense_reports_select ON public.expense_reports FOR SELECT TO authenticated USING (
  employee_id IN (SELECT id FROM public.employees WHERE email = auth.jwt()->>'email')
  OR public.current_employee_role() IN ('approver', 'finance', 'admin')
);
CREATE POLICY expense_reports_insert ON public.expense_reports FOR INSERT TO authenticated WITH CHECK (
  employee_id IN (SELECT id FROM public.employees WHERE email = auth.jwt()->>'email')
);
CREATE POLICY expense_reports_update ON public.expense_reports FOR UPDATE TO authenticated USING (
  employee_id IN (SELECT id FROM public.employees WHERE email = auth.jwt()->>'email')
  OR public.current_employee_role() IN ('approver', 'finance', 'admin')
);
CREATE POLICY expense_reports_delete ON public.expense_reports FOR DELETE TO authenticated USING (
  employee_id IN (SELECT id FROM public.employees WHERE email = auth.jwt()->>'email')
  AND status = 'draft'
);

-- Expenses: Follow report visibility
CREATE POLICY expenses_select ON public.expenses FOR SELECT TO authenticated USING (
  report_id IN (
    SELECT id FROM public.expense_reports WHERE employee_id IN (SELECT id FROM public.employees WHERE email = auth.jwt()->>'email')
  )
  OR public.current_employee_role() IN ('approver', 'finance', 'admin')
);
CREATE POLICY expenses_insert ON public.expenses FOR INSERT TO authenticated WITH CHECK (
  report_id IN (
    SELECT id FROM public.expense_reports WHERE employee_id IN (SELECT id FROM public.employees WHERE email = auth.jwt()->>'email')
  )
);
CREATE POLICY expenses_update ON public.expenses FOR UPDATE TO authenticated USING (
  report_id IN (
    SELECT id FROM public.expense_reports WHERE employee_id IN (SELECT id FROM public.employees WHERE email = auth.jwt()->>'email')
  )
);
CREATE POLICY expenses_delete ON public.expenses FOR DELETE TO authenticated USING (
  report_id IN (
    SELECT id FROM public.expense_reports WHERE employee_id IN (SELECT id FROM public.employees WHERE email = auth.jwt()->>'email') AND status = 'draft'
  )
);

-- Cash advances: Users can see own advances, approvers/finance/admin can see all
CREATE POLICY cash_advances_select ON public.cash_advances FOR SELECT TO authenticated USING (
  employee_id IN (SELECT id FROM public.employees WHERE email = auth.jwt()->>'email')
  OR public.current_employee_role() IN ('approver', 'finance', 'admin')
);
CREATE POLICY cash_advances_insert ON public.cash_advances FOR INSERT TO authenticated WITH CHECK (
  employee_id IN (SELECT id FROM public.employees WHERE email = auth.jwt()->>'email')
);
CREATE POLICY cash_advances_update ON public.cash_advances FOR UPDATE TO authenticated USING (
  employee_id IN (SELECT id FROM public.employees WHERE email = auth.jwt()->>'email')
  OR public.current_employee_role() IN ('approver', 'finance', 'admin')
);
CREATE POLICY cash_advances_delete ON public.cash_advances FOR DELETE TO authenticated USING (
  employee_id IN (SELECT id FROM public.employees WHERE email = auth.jwt()->>'email')
  AND status = 'pending'
);

-- Approvals: Approvers can see assigned approvals, finance/admin can see all
CREATE POLICY approvals_select ON public.approvals FOR SELECT TO authenticated USING (
  approver_id IN (SELECT id FROM public.employees WHERE email = auth.jwt()->>'email')
  OR public.current_employee_role() IN ('finance', 'admin')
);
CREATE POLICY approvals_insert ON public.approvals FOR INSERT TO authenticated WITH CHECK (public.current_employee_role() IN ('approver', 'finance', 'admin'));
CREATE POLICY approvals_update ON public.approvals FOR UPDATE TO authenticated USING (
  approver_id IN (SELECT id FROM public.employees WHERE email = auth.jwt()->>'email')
  OR public.current_employee_role() IN ('finance', 'admin')
);

-- Receipts: Follow expense visibility
CREATE POLICY receipts_select ON public.receipts FOR SELECT TO authenticated USING (
  uploaded_by IN (SELECT id FROM public.employees WHERE email = auth.jwt()->>'email')
  OR public.current_employee_role() IN ('approver', 'finance', 'admin')
);
CREATE POLICY receipts_insert ON public.receipts FOR INSERT TO authenticated WITH CHECK (
  uploaded_by IN (SELECT id FROM public.employees WHERE email = auth.jwt()->>'email')
);

-- Corporate cards: Users can see own cards, finance/admin can see all
CREATE POLICY corporate_cards_select ON public.corporate_cards FOR SELECT TO authenticated USING (
  card_holder_id IN (SELECT id FROM public.employees WHERE email = auth.jwt()->>'email')
  OR public.current_employee_role() IN ('finance', 'admin')
);
CREATE POLICY corporate_cards_insert ON public.corporate_cards FOR INSERT TO authenticated WITH CHECK (public.current_employee_role() IN ('finance', 'admin'));
CREATE POLICY corporate_cards_update ON public.corporate_cards FOR UPDATE TO authenticated USING (public.current_employee_role() IN ('finance', 'admin'));

-- Card transactions: Follow card visibility, finance/admin can modify
CREATE POLICY card_transactions_select ON public.card_transactions FOR SELECT TO authenticated USING (
  card_id IN (SELECT id FROM public.corporate_cards WHERE card_holder_id IN (SELECT id FROM public.employees WHERE email = auth.jwt()->>'email'))
  OR public.current_employee_role() IN ('finance', 'admin')
);
CREATE POLICY card_transactions_insert ON public.card_transactions FOR INSERT TO authenticated WITH CHECK (public.current_employee_role() IN ('finance', 'admin'));
CREATE POLICY card_transactions_update ON public.card_transactions FOR UPDATE TO authenticated USING (public.current_employee_role() IN ('finance', 'admin'));

-- Audit log: Read-only for all authenticated, system inserts only
CREATE POLICY audit_log_select ON public.audit_log FOR SELECT TO authenticated USING (true);

-- ============================================
-- SERVICE ROLE POLICIES (Bypass RLS)
-- ============================================

-- Allow service_role to bypass RLS for all tables
CREATE POLICY service_role_all ON public.employees FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON public.departments FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON public.cost_centers FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON public.expense_types FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON public.policies FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON public.expense_reports FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON public.expenses FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON public.cash_advances FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON public.approvals FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON public.receipts FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON public.corporate_cards FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON public.card_transactions FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON public.audit_log FOR ALL TO service_role USING (true) WITH CHECK (true);
