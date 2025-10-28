CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SCHEMA IF NOT EXISTS agent;

-- Event Sourcing + Idempotency
CREATE TABLE IF NOT EXISTS agent.events(
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  type TEXT NOT NULL,
  idempotency_key TEXT UNIQUE,
  payload JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_events_type_time ON agent.events(type, created_at DESC);

-- Minimal flows table for orchestrator (durable timers)
CREATE TABLE IF NOT EXISTS agent.flows(
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  input JSONB,
  state TEXT DEFAULT 'running',
  next_wake TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
