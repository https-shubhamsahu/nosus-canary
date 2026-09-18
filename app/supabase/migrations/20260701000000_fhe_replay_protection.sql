-- Migration: 20260701000000_fhe_replay_protection.sql
-- Description: Creates the Isolated Replay Protection Nonces table.

CREATE TABLE IF NOT EXISTS public.fhe_nonces (
    nonce TEXT PRIMARY KEY,
    request_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS (Row Level Security)
ALTER TABLE public.fhe_nonces ENABLE ROW LEVEL SECURITY;

-- Define RLS policies: Server side only operations
CREATE POLICY "Enable insert access for authenticated server roles"
    ON public.fhe_nonces
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Enable read access for authenticated server roles"
    ON public.fhe_nonces
    FOR SELECT
    TO authenticated
    USING (true);

-- Index for auto-eviction sweeping queries
CREATE INDEX IF NOT EXISTS idx_fhe_nonces_created_at ON public.fhe_nonces (created_at);
