-- Defense in depth: the Flutter UI also gates these features, but verification
-- must be enforced by PostgreSQL so a modified client cannot bypass it.

alter table public.reports enable row level security;

drop policy if exists "Only verified residents can create reports"
  on public.reports;
create policy "Only verified residents can create reports"
on public.reports
as restrictive
for insert
to authenticated
with check (
  resident_id = auth.uid()
  and exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.role = 'resident'
      and profiles.status = 'approved'
  )
);

drop policy if exists "Only verified residents or admins can read reports"
  on public.reports;
create policy "Only verified residents or admins can read reports"
on public.reports
as restrictive
for select
to authenticated
using (
  exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.status = 'approved'
      and (
        profiles.role = 'admin'
        or (profiles.role = 'resident' and reports.resident_id = auth.uid())
      )
  )
);
