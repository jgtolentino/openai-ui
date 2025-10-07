-- 0005_submit_report.sql
CREATE OR REPLACE FUNCTION public.submit_report(
  p_report_id   bigint,
  p_actor_email text
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.expense_reports
  SET approval_status = 'submitted', updated_at = NOW()
  WHERE id = p_report_id;

  INSERT INTO public.audit_log(entity, entity_id, action, actor_email, details)
  VALUES ('expense_reports', p_report_id, 'submit', p_actor_email, jsonb_build_object('status','submitted'));

  RETURN json_build_object('ok', true, 'status', 'submitted', 'report_id', p_report_id);
END $$;

REVOKE ALL ON FUNCTION public.submit_report(bigint,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_report(bigint,text) TO authenticated, service_role;
