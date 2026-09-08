-- HelpHub does not require resident confirmation before a report can close.
-- Emergency resolution must not stall when a resident is offline, unreachable,
-- or unable to respond. Residents retain read access to their report outcome;
-- only approved administrators may change lifecycle status through the client.

begin;

-- Remove the legacy policy that allowed a resident to update every column on
-- their own report in order to confirm a resolution or cancel it.
drop policy if exists "Residents can update own reports" on public.reports;

-- Replace the legacy admin policy with an explicitly approved-admin policy.
drop policy if exists "Admins can update all reports" on public.reports;
drop policy if exists "Approved admins can update reports" on public.reports;

create policy "Approved admins can update reports"
on public.reports
for update
to authenticated
using (
  exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.role = 'admin'
      and profiles.status = 'approved'
  )
)
with check (
  exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.role = 'admin'
      and profiles.status = 'approved'
  )
);

comment on policy "Approved admins can update reports" on public.reports is
  'Residents view outcomes but do not confirm or change report lifecycle state.';

commit;
