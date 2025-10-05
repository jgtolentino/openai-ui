-- 0001_expense_init.sql - Core expense management schema
-- TBWA\SMP Cash Advance + Expense Management System

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create schema
CREATE SCHEMA IF NOT EXISTS scout;

-- ============================================
-- MASTER DATA TABLES
-- ============================================

-- Employees table
CREATE TABLE scout.employees (
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
CREATE TABLE scout.departments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  parent_id UUID REFERENCES scout.departments(id),
  manager_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Cost centers table
CREATE TABLE scout.cost_centers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  department_id UUID REFERENCES scout.departments(id),
  budget_amount NUMERIC(12,2),
  fiscal_year INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'closed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Expense types table
CREATE TABLE scout.expense_types (
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
CREATE TABLE scout.policies (
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
CREATE TABLE scout.expense_reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  report_number TEXT NOT NULL UNIQUE,
  employee_id UUID NOT NULL REFERENCES scout.employees(id),
  title TEXT NOT NULL,
  description TEXT,
  purpose TEXT NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'approved', 'rejected', 'paid', 'cancelled')),
  submitted_at TIMESTAMPTZ,
  approved_at TIMESTAMPTZ,
  approved_by UUID REFERENCES scout.employees(id),
  paid_at TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Expenses table
CREATE TABLE scout.expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  report_id UUID NOT NULL REFERENCES scout.expense_reports(id) ON DELETE CASCADE,
  expense_type_id UUID NOT NULL REFERENCES scout.expense_types(id),
  cost_center_id UUID REFERENCES scout.cost_centers(id),
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
CREATE TABLE scout.cash_advances (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  advance_number TEXT NOT NULL UNIQUE,
  employee_id UUID NOT NULL REFERENCES scout.employees(id),
  purpose TEXT NOT NULL,
  requested_amount NUMERIC(12,2) NOT NULL CHECK (requested_amount > 0),
  approved_amount NUMERIC(12,2),
  currency TEXT NOT NULL DEFAULT 'PHP',
  needed_by DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'disbursed', 'liquidated', 'cancelled')),
  approved_at TIMESTAMPTZ,
  approved_by UUID REFERENCES scout.employees(id),
  disbursed_at TIMESTAMPTZ,
  liquidated_at TIMESTAMPTZ,
  liquidation_report_id UUID REFERENCES scout.expense_reports(id),
  rejection_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Approvals table
CREATE TABLE scout.approvals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  entity_type TEXT NOT NULL CHECK (entity_type IN ('expense_report', 'cash_advance')),
  entity_id UUID NOT NULL,
  approver_id UUID NOT NULL REFERENCES scout.employees(id),
  level INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'delegated')),
  decision_date TIMESTAMPTZ,
  comments TEXT,
  delegated_to UUID REFERENCES scout.employees(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Receipts table
CREATE TABLE scout.receipts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  expense_id UUID REFERENCES scout.expenses(id) ON DELETE SET NULL,
  storage_path TEXT NOT NULL,
  file_name TEXT NOT NULL,
  file_type TEXT NOT NULL,
  file_size INTEGER NOT NULL,
  ocr_data JSONB,
  ocr_confidence NUMERIC(5,4),
  uploaded_by UUID NOT NULL REFERENCES scout.employees(id),
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  verified BOOLEAN NOT NULL DEFAULT false,
  verified_at TIMESTAMPTZ,
  verified_by UUID REFERENCES scout.employees(id)
);

-- Corporate cards table
CREATE TABLE scout.corporate_cards (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  card_number_last4 TEXT NOT NULL,
  card_holder_id UUID NOT NULL REFERENCES scout.employees(id),
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
CREATE TABLE scout.card_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  card_id UUID NOT NULL REFERENCES scout.corporate_cards(id),
  transaction_date TIMESTAMPTZ NOT NULL,
  merchant TEXT NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'PHP',
  description TEXT,
  category TEXT,
  matched_expense_id UUID REFERENCES scout.expenses(id),
  matched_at TIMESTAMPTZ,
  matched_by UUID REFERENCES scout.employees(id),
  import_batch_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Audit log table
CREATE TABLE scout.audit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('create', 'update', 'delete', 'approve', 'reject', 'submit')),
  user_id UUID NOT NULL REFERENCES scout.employees(id),
  changes JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX idx_employees_department ON scout.employees(department_id);
CREATE INDEX idx_employees_manager ON scout.employees(manager_id);
CREATE INDEX idx_employees_status ON scout.employees(status);

CREATE INDEX idx_departments_parent ON scout.departments(parent_id);
CREATE INDEX idx_cost_centers_department ON scout.cost_centers(department_id);
CREATE INDEX idx_cost_centers_fiscal_year ON scout.cost_centers(fiscal_year);

CREATE INDEX idx_expense_reports_employee ON scout.expense_reports(employee_id);
CREATE INDEX idx_expense_reports_status ON scout.expense_reports(status);
CREATE INDEX idx_expense_reports_dates ON scout.expense_reports(period_start, period_end);

CREATE INDEX idx_expenses_report ON scout.expenses(report_id);
CREATE INDEX idx_expenses_type ON scout.expenses(expense_type_id);
CREATE INDEX idx_expenses_cost_center ON scout.expenses(cost_center_id);
CREATE INDEX idx_expenses_date ON scout.expenses(transaction_date);

CREATE INDEX idx_cash_advances_employee ON scout.cash_advances(employee_id);
CREATE INDEX idx_cash_advances_status ON scout.cash_advances(status);

CREATE INDEX idx_approvals_entity ON scout.approvals(entity_type, entity_id);
CREATE INDEX idx_approvals_approver ON scout.approvals(approver_id);
CREATE INDEX idx_approvals_status ON scout.approvals(status);

CREATE INDEX idx_receipts_expense ON scout.receipts(expense_id);
CREATE INDEX idx_card_transactions_card ON scout.card_transactions(card_id);
CREATE INDEX idx_card_transactions_matched ON scout.card_transactions(matched_expense_id);

CREATE INDEX idx_audit_log_entity ON scout.audit_log(entity_type, entity_id);
CREATE INDEX idx_audit_log_user ON scout.audit_log(user_id);
CREATE INDEX idx_audit_log_created ON scout.audit_log(created_at DESC);

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Function to get current employee role
CREATE OR REPLACE FUNCTION scout.current_employee_role()
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
  SELECT role FROM scout.employees WHERE email = auth.jwt()->>'email' LIMIT 1;
$$;

-- Function to calculate report total
CREATE OR REPLACE FUNCTION scout.sum_report_amount(report_id UUID)
RETURNS NUMERIC(12,2)
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(SUM(amount), 0) FROM scout.expenses WHERE report_id = $1;
$$;

-- Trigger to update expense report total
CREATE OR REPLACE FUNCTION scout.update_report_total()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE scout.expense_reports
  SET total_amount = scout.sum_report_amount(NEW.report_id),
      updated_at = NOW()
  WHERE id = NEW.report_id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_update_report_total
AFTER INSERT OR UPDATE OR DELETE ON scout.expenses
FOR EACH ROW
EXECUTE FUNCTION scout.update_report_total();

-- Trigger to update timestamps
CREATE OR REPLACE FUNCTION scout.update_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_employees_timestamp BEFORE UPDATE ON scout.employees FOR EACH ROW EXECUTE FUNCTION scout.update_timestamp();
CREATE TRIGGER trg_departments_timestamp BEFORE UPDATE ON scout.departments FOR EACH ROW EXECUTE FUNCTION scout.update_timestamp();
CREATE TRIGGER trg_cost_centers_timestamp BEFORE UPDATE ON scout.cost_centers FOR EACH ROW EXECUTE FUNCTION scout.update_timestamp();
CREATE TRIGGER trg_expense_types_timestamp BEFORE UPDATE ON scout.expense_types FOR EACH ROW EXECUTE FUNCTION scout.update_timestamp();
CREATE TRIGGER trg_policies_timestamp BEFORE UPDATE ON scout.policies FOR EACH ROW EXECUTE FUNCTION scout.update_timestamp();
CREATE TRIGGER trg_expense_reports_timestamp BEFORE UPDATE ON scout.expense_reports FOR EACH ROW EXECUTE FUNCTION scout.update_timestamp();
CREATE TRIGGER trg_expenses_timestamp BEFORE UPDATE ON scout.expenses FOR EACH ROW EXECUTE FUNCTION scout.update_timestamp();
CREATE TRIGGER trg_cash_advances_timestamp BEFORE UPDATE ON scout.cash_advances FOR EACH ROW EXECUTE FUNCTION scout.update_timestamp();
CREATE TRIGGER trg_approvals_timestamp BEFORE UPDATE ON scout.approvals FOR EACH ROW EXECUTE FUNCTION scout.update_timestamp();
CREATE TRIGGER trg_corporate_cards_timestamp BEFORE UPDATE ON scout.corporate_cards FOR EACH ROW EXECUTE FUNCTION scout.update_timestamp();

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS on all tables
ALTER TABLE scout.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.cost_centers ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.expense_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.expense_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.cash_advances ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.corporate_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.card_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.audit_log ENABLE ROW LEVEL SECURITY;

-- Employees: All authenticated users can read, only admin can modify
CREATE POLICY employees_select ON scout.employees FOR SELECT TO authenticated USING (true);
CREATE POLICY employees_insert ON scout.employees FOR INSERT TO authenticated WITH CHECK (scout.current_employee_role() = 'admin');
CREATE POLICY employees_update ON scout.employees FOR UPDATE TO authenticated USING (scout.current_employee_role() = 'admin');
CREATE POLICY employees_delete ON scout.employees FOR DELETE TO authenticated USING (scout.current_employee_role() = 'admin');

-- Departments: All authenticated users can read, only admin can modify
CREATE POLICY departments_select ON scout.departments FOR SELECT TO authenticated USING (true);
CREATE POLICY departments_insert ON scout.departments FOR INSERT TO authenticated WITH CHECK (scout.current_employee_role() = 'admin');
CREATE POLICY departments_update ON scout.departments FOR UPDATE TO authenticated USING (scout.current_employee_role() = 'admin');
CREATE POLICY departments_delete ON scout.departments FOR DELETE TO authenticated USING (scout.current_employee_role() = 'admin');

-- Cost centers: All authenticated users can read, only finance/admin can modify
CREATE POLICY cost_centers_select ON scout.cost_centers FOR SELECT TO authenticated USING (true);
CREATE POLICY cost_centers_insert ON scout.cost_centers FOR INSERT TO authenticated WITH CHECK (scout.current_employee_role() IN ('finance', 'admin'));
CREATE POLICY cost_centers_update ON scout.cost_centers FOR UPDATE TO authenticated USING (scout.current_employee_role() IN ('finance', 'admin'));
CREATE POLICY cost_centers_delete ON scout.cost_centers FOR DELETE TO authenticated USING (scout.current_employee_role() IN ('finance', 'admin'));

-- Expense types: All can read, only finance/admin can modify
CREATE POLICY expense_types_select ON scout.expense_types FOR SELECT TO authenticated USING (true);
CREATE POLICY expense_types_insert ON scout.expense_types FOR INSERT TO authenticated WITH CHECK (scout.current_employee_role() IN ('finance', 'admin'));
CREATE POLICY expense_types_update ON scout.expense_types FOR UPDATE TO authenticated USING (scout.current_employee_role() IN ('finance', 'admin'));
CREATE POLICY expense_types_delete ON scout.expense_types FOR DELETE TO authenticated USING (scout.current_employee_role() IN ('finance', 'admin'));

-- Policies: All can read, only admin can modify
CREATE POLICY policies_select ON scout.policies FOR SELECT TO authenticated USING (true);
CREATE POLICY policies_insert ON scout.policies FOR INSERT TO authenticated WITH CHECK (scout.current_employee_role() = 'admin');
CREATE POLICY policies_update ON scout.policies FOR UPDATE TO authenticated USING (scout.current_employee_role() = 'admin');
CREATE POLICY policies_delete ON scout.policies FOR DELETE TO authenticated USING (scout.current_employee_role() = 'admin');

-- Expense reports: Users can see own reports, approvers/finance/admin can see all
CREATE POLICY expense_reports_select ON scout.expense_reports FOR SELECT TO authenticated USING (
  employee_id IN (SELECT id FROM scout.employees WHERE email = auth.jwt()->>'email')
  OR scout.current_employee_role() IN ('approver', 'finance', 'admin')
);
CREATE POLICY expense_reports_insert ON scout.expense_reports FOR INSERT TO authenticated WITH CHECK (
  employee_id IN (SELECT id FROM scout.employees WHERE email = auth.jwt()->>'email')
);
CREATE POLICY expense_reports_update ON scout.expense_reports FOR UPDATE TO authenticated USING (
  employee_id IN (SELECT id FROM scout.employees WHERE email = auth.jwt()->>'email')
  OR scout.current_employee_role() IN ('approver', 'finance', 'admin')
);
CREATE POLICY expense_reports_delete ON scout.expense_reports FOR DELETE TO authenticated USING (
  employee_id IN (SELECT id FROM scout.employees WHERE email = auth.jwt()->>'email')
  AND status = 'draft'
);

-- Expenses: Follow report visibility
CREATE POLICY expenses_select ON scout.expenses FOR SELECT TO authenticated USING (
  report_id IN (
    SELECT id FROM scout.expense_reports WHERE employee_id IN (SELECT id FROM scout.employees WHERE email = auth.jwt()->>'email')
  )
  OR scout.current_employee_role() IN ('approver', 'finance', 'admin')
);
CREATE POLICY expenses_insert ON scout.expenses FOR INSERT TO authenticated WITH CHECK (
  report_id IN (
    SELECT id FROM scout.expense_reports WHERE employee_id IN (SELECT id FROM scout.employees WHERE email = auth.jwt()->>'email')
  )
);
CREATE POLICY expenses_update ON scout.expenses FOR UPDATE TO authenticated USING (
  report_id IN (
    SELECT id FROM scout.expense_reports WHERE employee_id IN (SELECT id FROM scout.employees WHERE email = auth.jwt()->>'email')
  )
);
CREATE POLICY expenses_delete ON scout.expenses FOR DELETE TO authenticated USING (
  report_id IN (
    SELECT id FROM scout.expense_reports WHERE employee_id IN (SELECT id FROM scout.employees WHERE email = auth.jwt()->>'email') AND status = 'draft'
  )
);

-- Cash advances: Users can see own advances, approvers/finance/admin can see all
CREATE POLICY cash_advances_select ON scout.cash_advances FOR SELECT TO authenticated USING (
  employee_id IN (SELECT id FROM scout.employees WHERE email = auth.jwt()->>'email')
  OR scout.current_employee_role() IN ('approver', 'finance', 'admin')
);
CREATE POLICY cash_advances_insert ON scout.cash_advances FOR INSERT TO authenticated WITH CHECK (
  employee_id IN (SELECT id FROM scout.employees WHERE email = auth.jwt()->>'email')
);
CREATE POLICY cash_advances_update ON scout.cash_advances FOR UPDATE TO authenticated USING (
  employee_id IN (SELECT id FROM scout.employees WHERE email = auth.jwt()->>'email')
  OR scout.current_employee_role() IN ('approver', 'finance', 'admin')
);
CREATE POLICY cash_advances_delete ON scout.cash_advances FOR DELETE TO authenticated USING (
  employee_id IN (SELECT id FROM scout.employees WHERE email = auth.jwt()->>'email')
  AND status = 'pending'
);

-- Approvals: Approvers can see assigned approvals, finance/admin can see all
CREATE POLICY approvals_select ON scout.approvals FOR SELECT TO authenticated USING (
  approver_id IN (SELECT id FROM scout.employees WHERE email = auth.jwt()->>'email')
  OR scout.current_employee_role() IN ('finance', 'admin')
);
CREATE POLICY approvals_insert ON scout.approvals FOR INSERT TO authenticated WITH CHECK (scout.current_employee_role() IN ('approver', 'finance', 'admin'));
CREATE POLICY approvals_update ON scout.approvals FOR UPDATE TO authenticated USING (
  approver_id IN (SELECT id FROM scout.employees WHERE email = auth.jwt()->>'email')
  OR scout.current_employee_role() IN ('finance', 'admin')
);

-- Receipts: Follow expense visibility
CREATE POLICY receipts_select ON scout.receipts FOR SELECT TO authenticated USING (
  uploaded_by IN (SELECT id FROM scout.employees WHERE email = auth.jwt()->>'email')
  OR scout.current_employee_role() IN ('approver', 'finance', 'admin')
);
CREATE POLICY receipts_insert ON scout.receipts FOR INSERT TO authenticated WITH CHECK (
  uploaded_by IN (SELECT id FROM scout.employees WHERE email = auth.jwt()->>'email')
);

-- Corporate cards: Users can see own cards, finance/admin can see all
CREATE POLICY corporate_cards_select ON scout.corporate_cards FOR SELECT TO authenticated USING (
  card_holder_id IN (SELECT id FROM scout.employees WHERE email = auth.jwt()->>'email')
  OR scout.current_employee_role() IN ('finance', 'admin')
);
CREATE POLICY corporate_cards_insert ON scout.corporate_cards FOR INSERT TO authenticated WITH CHECK (scout.current_employee_role() IN ('finance', 'admin'));
CREATE POLICY corporate_cards_update ON scout.corporate_cards FOR UPDATE TO authenticated USING (scout.current_employee_role() IN ('finance', 'admin'));

-- Card transactions: Follow card visibility, finance/admin can modify
CREATE POLICY card_transactions_select ON scout.card_transactions FOR SELECT TO authenticated USING (
  card_id IN (SELECT id FROM scout.corporate_cards WHERE card_holder_id IN (SELECT id FROM scout.employees WHERE email = auth.jwt()->>'email'))
  OR scout.current_employee_role() IN ('finance', 'admin')
);
CREATE POLICY card_transactions_insert ON scout.card_transactions FOR INSERT TO authenticated WITH CHECK (scout.current_employee_role() IN ('finance', 'admin'));
CREATE POLICY card_transactions_update ON scout.card_transactions FOR UPDATE TO authenticated USING (scout.current_employee_role() IN ('finance', 'admin'));

-- Audit log: Read-only for all authenticated, system inserts only
CREATE POLICY audit_log_select ON scout.audit_log FOR SELECT TO authenticated USING (true);

-- ============================================
-- SERVICE ROLE POLICIES (Bypass RLS)
-- ============================================

-- Allow service_role to bypass RLS for all tables
CREATE POLICY service_role_all ON scout.employees FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON scout.departments FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON scout.cost_centers FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON scout.expense_types FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON scout.policies FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON scout.expense_reports FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON scout.expenses FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON scout.cash_advances FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON scout.approvals FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON scout.receipts FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON scout.corporate_cards FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON scout.card_transactions FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY service_role_all ON scout.audit_log FOR ALL TO service_role USING (true) WITH CHECK (true);
