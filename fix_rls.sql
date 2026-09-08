-- Legacy one-off helper. Prefer migration
-- 202609080003_admin_owned_report_resolution.sql.

DROP POLICY IF EXISTS "Residents can update own reports" ON public.reports;
DROP POLICY IF EXISTS "Admins can update all reports" ON public.reports;

CREATE POLICY "Approved admins can update reports"
ON public.reports
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
      AND profiles.status = 'approved'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
      AND profiles.status = 'approved'
  )
);
