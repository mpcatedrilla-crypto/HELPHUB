-- Dispatch assignment is no longer part of the HelpHub report workflow.
-- Keep the legacy column and any existing values for compatibility, but do not
-- require it for status transitions.

begin;

alter table public.reports
  drop constraint if exists reports_response_requires_dispatch;

comment on column public.reports.routing_destination_id is
  'Legacy optional routing destination; not required by the report lifecycle.';

commit;
