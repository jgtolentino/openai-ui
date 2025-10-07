-- Allow anon to read expenses_view for GPT Action
DROP POLICY IF EXISTS expenses_view_select_anon ON public.expenses_view;
CREATE POLICY expenses_view_select_anon
ON public.expenses_view FOR SELECT
TO anon USING (true);
