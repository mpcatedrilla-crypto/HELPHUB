ALTER TYPE public.report_status ADD VALUE IF NOT EXISTS 'in_progress';
ALTER TYPE public.report_status ADD VALUE IF NOT EXISTS 'referred';
ALTER TYPE public.report_status ADD VALUE IF NOT EXISTS 'false_alarm';
