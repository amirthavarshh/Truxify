-- Migration: 20260924000000_offline_location_sync.sql
-- Description: Adds offline location buffering and sync capabilities

-- 1. Create a table to track chronological history of driver locations
CREATE TABLE IF NOT EXISTS public.driver_location_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    heading DOUBLE PRECISION,
    speed DOUBLE PRECISION,
    recorded_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure we don't insert duplicate events
CREATE UNIQUE INDEX IF NOT EXISTS driver_location_history_dedup_idx ON public.driver_location_history (driver_id, recorded_at);

-- 2. Add recorded_at to driver_locations if it doesn't exist
ALTER TABLE public.driver_locations ADD COLUMN IF NOT EXISTS recorded_at TIMESTAMPTZ;

-- 3. Update existing rows in driver_locations to have a recorded_at if it's missing
UPDATE public.driver_locations SET recorded_at = NOW() WHERE recorded_at IS NULL;

-- 4. Enable RLS for driver_location_history
ALTER TABLE public.driver_location_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Drivers can view their own location history" ON public.driver_location_history
    FOR SELECT USING (auth.uid() = driver_id);

CREATE POLICY "Drivers can insert their own location history" ON public.driver_location_history
    FOR INSERT WITH CHECK (auth.uid() = driver_id);

-- Also allow service role full access
CREATE POLICY "Service role full access on location history" ON public.driver_location_history
    FOR ALL USING (current_setting('request.jwt.claims', true)::json->>'role' = 'service_role');
