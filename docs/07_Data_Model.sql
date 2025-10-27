-- Construct-IQ Core Data Model (MVP)
-- Uniqueness: (source, source_id) for opportunities
CREATE TABLE IF NOT EXISTS orgs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  stripe_customer_id text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS org_memberships (
  org_id uuid REFERENCES orgs(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  role text NOT NULL CHECK (role IN ('owner','estimator','viewer')),
  PRIMARY KEY (org_id, user_id)
);

CREATE TABLE IF NOT EXISTS opportunities (
  id bigserial PRIMARY KEY,
  org_id uuid REFERENCES orgs(id) ON DELETE CASCADE,
  source text NOT NULL,
  source_id text NOT NULL,
  title text NOT NULL,
  location text,
  due_at timestamptz,
  est_value numeric,
  url text,
  raw jsonb NOT NULL DEFAULT '{}'::jsonb,
  seen_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (source, source_id)
);

CREATE TABLE IF NOT EXISTS saved_searches (
  id bigserial PRIMARY KEY,
  org_id uuid REFERENCES orgs(id) ON DELETE CASCADE,
  name text NOT NULL,
  query jsonb NOT NULL,
  cadence text NOT NULL CHECK (cadence IN ('instant','daily','weekly')),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS alerts (
  id bigserial PRIMARY KEY,
  saved_search_id bigint REFERENCES saved_searches(id) ON DELETE CASCADE,
  last_sent_at timestamptz
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_opps_due_at ON opportunities(due_at);
CREATE INDEX IF NOT EXISTS idx_opps_source ON opportunities(source);
CREATE INDEX IF NOT EXISTS idx_opps_title_trgm ON opportunities USING GIN (title gin_trgm_ops);
