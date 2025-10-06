CREATE OR REPLACE VIEW public.introspection_columns AS
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns WHERE table_schema='public';

CREATE OR REPLACE FUNCTION public.health_db_report()
RETURNS json LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  req_tables text[] := ARRAY['employees','expense_types','card_feed','org_policies',
    'expenses','expense_reports','expense_items','cash_advances',
    'approvals','reimbursements','receipts','audit_log','policies_effective'];
  req_views  text[] := ARRAY['expenses_view','pending_approvals_view','cash_advances_view','payable_reimbursements_view'];
  req_funcs  text[] := ARRAY['upsert_expense(text,text,date,numeric,text,text,text)',
    'approve_or_reject_report(bigint,text,text,text)','create_cash_advance(text,numeric,text,text)',
    'export_gl(date,date,text)','mark_reimbursement_paid(bigint)'];
  mt text[] := ARRAY[]::text[]; mv text[] := ARRAY[]::text[]; mf text[] := ARRAY[]::text[];
  rls json;
BEGIN
  WITH missing_tables AS (SELECT unnest(req_tables) AS tbl WHERE to_regclass('public.'||unnest(req_tables)) IS NULL)
  SELECT array_agg(tbl) FROM missing_tables INTO mt;

  WITH missing_views AS (SELECT unnest(req_views) AS vw WHERE to_regclass('public.'||unnest(req_views)) IS NULL)
  SELECT array_agg(vw) FROM missing_views INTO mv;

  WITH missing_funcs AS (SELECT unnest(req_funcs) AS fn WHERE to_regprocedure(unnest(req_funcs)) IS NULL)
  SELECT array_agg(fn) FROM missing_funcs INTO mf;

  SELECT json_agg(row_to_json(r)) INTO rls FROM (
    SELECT c.relname AS table, c.relrowsecurity AS rls_enabled,
           (SELECT json_agg(p.policyname) FROM pg_policies p WHERE p.schemaname='public' AND p.tablename=c.relname) AS policies
    FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind='r' AND c.relname = ANY(req_tables)
    ORDER BY c.relname
  ) r;

  RETURN json_build_object('missing_tables', coalesce(mt,'{}'::text[]),
                           'missing_views',  coalesce(mv,'{}'::text[]),
                           'missing_functions', coalesce(mf,'{}'::text[]),
                           'rls', coalesce(rls,'[]'::json),
                           'ok', (coalesce(array_length(mt,1),0)=0
                               AND coalesce(array_length(mv,1),0)=0
                               AND coalesce(array_length(mf,1),0)=0));
END $$;

REVOKE ALL ON FUNCTION public.health_db_report() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.health_db_report() TO authenticated, service_role;
