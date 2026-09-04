-- Allow anyone (or at least authenticated users) to insert audit events
CREATE POLICY "Authenticated users can insert audit events" ON audit_events FOR INSERT WITH CHECK (
  auth.uid() = actor_id
);
