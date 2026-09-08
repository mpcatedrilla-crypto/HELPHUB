-- Reject report lifecycle changes that skip or reverse canonical workflow steps.
-- This trigger is authoritative: it applies to Flutter clients, SQL, REST,
-- Realtime consumers, Edge Functions, and service-role requests.

begin;

create or replace function public.is_valid_report_status_transition(
  from_status public.report_status,
  to_status public.report_status
)
returns boolean
language sql
immutable
strict
set search_path = public, pg_temp
as $$
  select case from_status
    when 'submitted'::public.report_status then
      to_status = 'acknowledged'::public.report_status
    when 'acknowledged'::public.report_status then
      to_status = 'in_progress'::public.report_status
    when 'in_progress'::public.report_status then
      to_status in (
        'resolved'::public.report_status,
        'referred'::public.report_status,
        'false_alarm'::public.report_status
      )
    when 'resolved'::public.report_status then
      to_status = 'closed'::public.report_status
    when 'referred'::public.report_status then
      to_status = 'closed'::public.report_status
    when 'false_alarm'::public.report_status then
      to_status = 'closed'::public.report_status
    when 'closed'::public.report_status then
      to_status = 'archived'::public.report_status
    when 'archived'::public.report_status then false
  end;
$$;

comment on function public.is_valid_report_status_transition(
  public.report_status,
  public.report_status
) is 'Returns true only for a permitted canonical report status transition.';

create or replace function public.enforce_report_status_transition()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'submitted'::public.report_status then
      raise exception using
        errcode = '23514',
        message = format(
          'New reports must start with status submitted, not %s',
          new.status
        ),
        constraint = 'reports_valid_status_transition';
    end if;

    return new;
  end if;

  if new.status is distinct from old.status
     and not public.is_valid_report_status_transition(old.status, new.status) then
    raise exception using
      errcode = '23514',
      message = format(
        'Invalid report status transition: %s -> %s',
        old.status,
        new.status
      ),
      constraint = 'reports_valid_status_transition';
  end if;

  return new;
end;
$$;

comment on function public.enforce_report_status_transition() is
  'Enforces the canonical HelpHub report lifecycle on inserts and updates.';

drop trigger if exists reports_enforce_status_transition on public.reports;

create trigger reports_enforce_status_transition
before insert or update of status on public.reports
for each row
execute function public.enforce_report_status_transition();

commit;
