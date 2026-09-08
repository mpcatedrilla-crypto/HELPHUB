# HelpHub

HelpHub is a Flutter and Supabase community emergency reporting and response
system.

## Report lifecycle

The canonical lifecycle is:

`submitted -> acknowledged -> in_progress -> resolved/referred/false_alarm -> closed -> archived`

Resident confirmation is **not required** for resolution or closure. A
resident may be offline, unreachable, or unable to respond during an emergency,
so confirmation cannot safely block operational closure. Approved
administrators own status transitions; residents can view the current status,
resolution notes, and evidence.

If resident feedback or dispute handling is added later, it should be modeled
as a separate feedback or follow-up record. It must not overload the report
status or restore the removed `pending_confirmation` state.

Apply the SQL files in `supabase/migrations` in filename order before deploying
the matching Flutter build.
