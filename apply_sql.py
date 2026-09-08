"""Deprecated database helper.

Use Supabase migrations rather than embedding credentials or applying an
unversioned schema from a machine-specific path.
"""

raise SystemExit(
    "Deprecated: apply the ordered SQL files in supabase/migrations instead."
)
