create extension if not exists pg_trgm;
create table if not exists opportunities(
  id uuid primary key default gen_random_uuid(),
  source text not null,
  source_id text not null,
  title text not null,
  description text,
  phase text,
  naics text[],
  trade_tags text[],
  scopes text[],
  due_date timestamptz,
  est_value numeric,
  location jsonb,
  score numeric default 0,
  raw_ref jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(source, source_id)
);
create table if not exists staging_opportunities(
  id bigserial primary key,
  payload jsonb not null,
  source text not null,
  seen_at timestamptz default now()
);
insert into opportunities (source, source_id, title, description, phase, scopes, due_date, est_value, location, score)
values
('demo','FED-001','Small bridge rehab – District 3','Superstructure + deck overlay','prebid',array['structure','site'], now() + interval '21 days', 2500000, '{"state":"CA","city":"Sacramento"}', 72),
('demo','CITY-042','Library HVAC replacement','RTUs + controls','bid',array['mep'], now() + interval '10 days', 900000, '{"state":"WA","city":"Tacoma"}', 64)
on conflict do nothing;
create extension if not exists pg_trgm;
create extension if not exists pgcrypto;
