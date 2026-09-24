-- Migration: 20260924000000_offline_location_sync.sql
-- Description: Adds offline location buffering and sync capabilities

-- 1. Create a table to track chronological history of driver locations
CREATE TABLE IF NOT EXISTS public.user_location_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    heading DOUBLE PRECISION,
    speed DOUBLE PRECISION,
    recorded_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure we don't insert duplicate events
CREATE UNIQUE INDEX IF NOT EXISTS user_location_history_dedup_idx ON public.user_location_history (user_id, recorded_at);

-- 2. Add recorded_at to user_locations if it doesn't exist
ALTER TABLE public.user_locations ADD COLUMN IF NOT EXISTS recorded_at TIMESTAMPTZ;

-- 3. Update existing rows in user_locations to have a recorded_at if it's missing
UPDATE public.user_locations SET recorded_at = updated_at WHERE recorded_at IS NULL;

-- 4. Enable RLS for user_location_history
ALTER TABLE public.user_location_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own location history" ON public.user_location_history
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own location history" ON public.user_location_history
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Also allow service role full access
CREATE POLICY "Service role full access on location history" ON public.user_location_history
    FOR ALL USING (current_setting('request.jwt.claims', true)::json->>'role' = 'service_role');
