-- Allow Admins to update reports (so they can resolve/acknowledge them)
CREATE POLICY "Admins can update all reports" ON reports FOR UPDATE USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin' AND status = 'approved')
);

-- Allow Residents to update their own reports (e.g. to confirm resolution or cancel)
CREATE POLICY "Residents can update own reports" ON reports FOR UPDATE USING (
  resident_id = auth.uid()
);
