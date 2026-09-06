-- Fix: Allow any authenticated admin to register push tokens
-- (Remove the overly strict 'status = approved' check that silently blocks inserts)
DROP POLICY IF EXISTS "Admins can register their push tokens" ON public.admin_push_tokens;
CREATE POLICY "Admins can register their push tokens"
  ON public.admin_push_tokens FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid() AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
  );

-- Also fix the SELECT policy so the Edge Function can read tokens
-- The Edge Function uses service role key so RLS is bypassed, but just in case:
DROP POLICY IF EXISTS "Service role can read all push tokens" ON public.admin_push_tokens;
CREATE POLICY "Service role can read all push tokens"
  ON public.admin_push_tokens FOR SELECT TO service_role
  USING (true);
