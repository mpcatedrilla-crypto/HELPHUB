-- A report may be submitted and acknowledged before dispatch selection, but it
-- cannot enter the response stage or any later lifecycle state unassigned.

begin;

alter table public.reports
  drop constraint if exists reports_response_requires_dispatch;

alter table public.reports
  add constraint reports_response_requires_dispatch
  check (
    status not in (
      'in_progress'::public.report_status,
      'resolved'::public.report_status,
      'referred'::public.report_status,
      'false_alarm'::public.report_status,
      'closed'::public.report_status,
      'archived'::public.report_status
    )
    or routing_destination_id is not null
  ) not valid;

comment on constraint reports_response_requires_dispatch on public.reports is
  'Requires a dispatch destination before in_progress and every later status.';

commit;
