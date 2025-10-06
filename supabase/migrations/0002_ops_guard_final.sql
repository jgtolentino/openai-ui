-- Drop and recreate with working syntax
DROP FUNCTION IF EXISTS public.health_db_report();

CREATE OR REPLACE VIEW public.introspection_columns AS
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns WHERE table_schema='public';

CREATE OR REPLACE FUNCTION public.health_db_report()
RETURNS json LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  req_tables text[] := ARRAY['employees','expense_types','expense_reports','expenses','cash_advances',
    'approvals','receipts','corporate_cards','card_transactions','audit_log'];
  req_views  text[] := ARRAY['expenses_view','pending_approvals_view','cash_advances_view'];
  req_funcs  text[] := ARRAY['upsert_expense(text,text,date,numeric,text,text,text)',
    'approve_or_reject_report(bigint,text,text,text)','create_cash_advance(text,numeric,text,text)'];
  mt text[]; mv text[]; mf text[];
  rls json;
  i text;
BEGIN
  -- Find missing tables
  mt := ARRAY[]::text[];
  FOREACH i IN ARRAY req_tables LOOP
    IF to_regclass('public.' || i) IS NULL THEN
      mt := mt || i;
    END IF;
  END LOOP;

  -- Find missing views
  mv := ARRAY[]::text[];
  FOREACH i IN ARRAY req_views LOOP
    IF to_regclass('public.' || i) IS NULL THEN
      mv := mv || i;
    END IF;
  END LOOP;

  -- Find missing functions
  mf := ARRAY[]::text[];
  FOREACH i IN ARRAY req_funcs LOOP
    IF to_regprocedure(i) IS NULL THEN
      mf := mf || i;
    END IF;
  END LOOP;

  -- Get RLS status
  SELECT json_agg(row_to_json(r)) INTO rls FROM (
    SELECT c.relname AS table, c.relrowsecurity AS rls_enabled,
           (SELECT json_agg(p.policyname) FROM pg_policies p WHERE p.schemaname='public' AND p.tablename=c.relname) AS policies
    FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind='r' AND c.relname = ANY(req_tables)
    ORDER BY c.relname
  ) r;

  RETURN json_build_object(
    'missing_tables', COALESCE(mt, ARRAY[]::text[]),
    'missing_views', COALESCE(mv, ARRAY[]::text[]),
    'missing_functions', COALESCE(mf, ARRAY[]::text[]),
    'rls', COALESCE(rls, '[]'::json),
    'ok', (array_length(mt, 1) IS NULL AND array_length(mv, 1) IS NULL AND array_length(mf, 1) IS NULL)
  );
END $$;

REVOKE ALL ON FUNCTION public.health_db_report() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.health_db_report() TO authenticated, service_role;
