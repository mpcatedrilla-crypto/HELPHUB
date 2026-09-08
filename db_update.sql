-- Legacy one-off helper. Prefer the ordered files in supabase/migrations.
-- Resident confirmation is intentionally not part of the canonical lifecycle.

ALTER TABLE public.reports
  ADD COLUMN IF NOT EXISTS admin_resolution_notes text,
  ADD COLUMN IF NOT EXISTS admin_proof_url text;
