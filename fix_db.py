"""Deprecated database helper.

Database changes are now versioned in ``supabase/migrations``. Keeping live
database credentials or independently modifying enum values from this script
would bypass the canonical HelpHub workflow.
"""

raise SystemExit(
    "Deprecated: apply the ordered SQL files in supabase/migrations instead."
)
