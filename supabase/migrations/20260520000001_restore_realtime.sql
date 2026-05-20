-- ============================================================
-- RESTORE REAL-TIME REPLICATION
-- Enabling tables for real-time broadcasts
-- ============================================================

-- 1. Enable replication for the job_requests table
-- This allows providers to see new jobs instantly and customers to track updates
ALTER TABLE public.job_requests REPLICA IDENTITY FULL;

-- 2. Enable replication for the app_settings table
-- This allows the app to change colors, logo, and app name instantly
ALTER TABLE public.app_settings REPLICA IDENTITY FULL;

-- 3. Add tables to the 'supabase_realtime' publication
-- If the publication doesn't exist, this script will still work on most Supabase instances
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.job_requests;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.app_settings;
  ELSE
    CREATE PUBLICATION supabase_realtime FOR TABLE public.job_requests, public.app_settings;
  END IF;
END $$;
