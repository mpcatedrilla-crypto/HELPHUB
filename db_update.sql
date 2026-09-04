-- 1. Add the missing status to the enum
ALTER TYPE report_status ADD VALUE IF NOT EXISTS 'pending_confirmation';

-- 2. Add the missing columns to the reports table
ALTER TABLE reports ADD COLUMN IF NOT EXISTS admin_resolution_notes TEXT;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS admin_proof_url TEXT;
