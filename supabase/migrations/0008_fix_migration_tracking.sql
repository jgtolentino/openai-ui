-- Fix "Invalid Date" in Supabase UI by recording migrations
CREATE SCHEMA IF NOT EXISTS supabase_migrations;

CREATE TABLE IF NOT EXISTS supabase_migrations.schema_migrations(
  version text PRIMARY KEY,
  inserted_at timestamptz DEFAULT now()
);

INSERT INTO supabase_migrations.schema_migrations(version)
VALUES 
  ('0001_expense_init'),
  ('0002_ops_guard'),
  ('0003_approval_rules'),
  ('0004_views_and_rpcs'),
  ('0005_submit_report'),
  ('0006_upsert_expense_email'),
  ('0007_expenses_view_anon_policy'),
  ('0008_fix_migration_tracking')
ON CONFLICT (version) DO NOTHING;
