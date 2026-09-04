-- HelpHub production-readiness migration.
-- Run this once in the Supabase SQL editor before testing the admin queue.

-- Avoid recursive profiles RLS checks by evaluating admin membership through a
-- security-definer function owned by the migration owner.
CREATE OR REPLACE FUNCTION public.is_approved_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid()
      AND role = 'admin'
      AND status = 'approved'
  );
$$;

REVOKE ALL ON FUNCTION public.is_approved_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_approved_admin() TO authenticated;

DO $$
BEGIN
  CREATE POLICY "Admins can read report profiles"
    ON public.profiles
    FOR SELECT
    TO authenticated
    USING (id = auth.uid() OR public.is_approved_admin());
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

-- These indexes support the admin queue's join and sort path.
CREATE INDEX IF NOT EXISTS reports_resident_id_idx
  ON public.reports (resident_id);

CREATE INDEX IF NOT EXISTS reports_priority_queue_idx
  ON public.reports (is_critical_override DESC, priority_score DESC, created_at ASC);

COMMENT ON FUNCTION public.is_approved_admin()
  IS 'RLS helper used by HelpHub admin policies without profiles recursion.';
