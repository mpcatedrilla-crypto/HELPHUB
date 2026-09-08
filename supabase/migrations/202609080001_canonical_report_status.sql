-- Replace legacy and partially deployed report states with one canonical enum.
-- Canonical lifecycle:
-- submitted -> acknowledged -> in_progress
-- in_progress -> resolved | referred | false_alarm
-- resolved | referred | false_alarm -> closed -> archived

begin;

lock table public.reports in share row exclusive mode;

alter table public.reports
  alter column status drop default;

-- Convert to text first so legacy enum labels can be normalized safely.
alter table public.reports
  alter column status type text using status::text;

update public.reports
set status = case lower(coalesce(status, 'submitted'))
  when 'submitted' then 'submitted'
  when 'acknowledged' then 'acknowledged'
  when 'under_review' then 'acknowledged'
  when 'in_progress' then 'in_progress'
  when 'responding' then 'in_progress'
  when 'resolved' then 'resolved'
  when 'pending_confirmation' then 'resolved'
  when 'referred' then 'referred'
  when 'false_alarm' then 'false_alarm'
  when 'closed' then 'closed'
  when 'rejected' then 'closed'
  when 'archived' then 'archived'
  else 'submitted'
end;

-- This intentionally does not use CASCADE. If another database object still
-- depends on the legacy enum, the migration stops instead of deleting it.
drop type if exists public.report_status;

create type public.report_status as enum (
  'submitted',
  'acknowledged',
  'in_progress',
  'resolved',
  'referred',
  'false_alarm',
  'closed',
  'archived'
);

alter table public.reports
  alter column status type public.report_status
  using status::public.report_status,
  alter column status set default 'submitted'::public.report_status,
  alter column status set not null;

comment on type public.report_status is
  'Canonical HelpHub report lifecycle. Flutter uses ReportStatus.dbValue.';

commit;
