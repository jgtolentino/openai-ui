-- Wrapper RPC that accepts employee_email and resolves to employee_id
CREATE OR REPLACE FUNCTION public.upsert_expense_email(
  p_employee_email text,
  p_expense_type text,
  p_txn_date date,
  p_amount numeric,
  p_currency text,
  p_merchant text DEFAULT NULL,
  p_receipt_url text DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_emp_id bigint;
  v_expense_id bigint;
BEGIN
  -- Resolve employee email to ID
  SELECT id INTO v_emp_id 
  FROM public.employees 
  WHERE email = p_employee_email;
  
  IF v_emp_id IS NULL THEN
    RAISE EXCEPTION 'EMPLOYEE_NOT_FOUND: %', p_employee_email;
  END IF;

  -- Insert expense
  INSERT INTO public.expenses(employee_id, expense_type, txn_date, amount, currency, merchant, receipt_url)
  VALUES (v_emp_id, p_expense_type, p_txn_date, p_amount, p_currency, p_merchant, p_receipt_url)
  RETURNING id INTO v_expense_id;

  RETURN v_expense_id;
END $$;

REVOKE ALL ON FUNCTION public.upsert_expense_email(text,text,date,numeric,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.upsert_expense_email(text,text,date,numeric,text,text,text) TO authenticated, service_role;
