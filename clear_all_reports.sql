-- Temporarily disable triggers (specifically the append-only audit trigger)
SET session_replication_role = 'replica';

-- Delete all evidence, locations, and the reports themselves
DELETE FROM public.report_evidence;
DELETE FROM public.report_locations;
DELETE FROM public.reports;

-- Re-enable normal trigger behavior
SET session_replication_role = 'origin';
