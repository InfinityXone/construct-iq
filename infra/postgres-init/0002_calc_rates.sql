BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Raw hits (optional, for debugging/lineage)
CREATE TABLE IF NOT EXISTS external_rates_raw (
  ext_id      BIGINT PRIMARY KEY,
  hit         JSONB NOT NULL,
  fetched_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Catalog of normalized costs
CREATE TABLE IF NOT EXISTS cost_catalog (
  id         BIGSERIAL PRIMARY KEY,
  trade      TEXT NOT NULL,
  csi_code   TEXT,                     -- can be NULL (some CALC rows have none)
  unit_cost  NUMERIC NOT NULL,
  basis      TEXT NOT NULL,            -- e.g., 'labor'
  region     TEXT NOT NULL,            -- e.g., 'US-ceiling'
  meta       JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- normalized csi for uniqueness (treat NULL and '' as same)
  csi_norm   TEXT GENERATED ALWAYS AS (COALESCE(csi_code, '')) STORED
);

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_cost_catalog_trade_trgm
  ON cost_catalog USING GIN (trade gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_cost_catalog_unit_cost
  ON cost_catalog (unit_cost);

CREATE INDEX IF NOT EXISTS idx_cost_catalog_basis
  ON cost_catalog (basis);

CREATE INDEX IF NOT EXISTS idx_cost_catalog_meta_education
  ON cost_catalog ((meta->>'education_level'));

CREATE INDEX IF NOT EXISTS idx_cost_catalog_meta_business
  ON cost_catalog ((meta->>'business_size'));

CREATE INDEX IF NOT EXISTS idx_cost_catalog_meta_worksite
  ON cost_catalog ((meta->>'worksite'));

-- Single conflict target used by the harvester
CREATE UNIQUE INDEX IF NOT EXISTS uniq_cost_catalog_trade_basis_region_csi
  ON cost_catalog (trade, basis, region, csi_norm);

COMMIT;
