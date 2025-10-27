-- Idempotent constraints + indexes for cost_catalog

BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Add a normalized CSI column we can index uniquely (safe if it already exists)
ALTER TABLE cost_catalog
  ADD COLUMN IF NOT EXISTS basis  TEXT NOT NULL DEFAULT 'labor',
  ADD COLUMN IF NOT EXISTS region TEXT NOT NULL DEFAULT 'US-ceiling',
  ADD COLUMN IF NOT EXISTS csi_norm TEXT GENERATED ALWAYS AS (COALESCE(csi_code, '')) STORED;

-- Useful search indexes
CREATE INDEX IF NOT EXISTS idx_cost_catalog_trade_trgm
  ON cost_catalog USING gin (trade gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_cost_catalog_unit_cost
  ON cost_catalog (unit_cost);

-- Replace any older expression-based unique index with one on the generated column
DROP INDEX IF EXISTS uniq_cost_catalog_trade_basis_region_csi;

-- This will succeed only if no dup keys remain; if it fails, run the dedupe snippet I gave you earlier, then rerun.
CREATE UNIQUE INDEX IF NOT EXISTS uniq_cost_catalog_trade_basis_region_csi
  ON cost_catalog (trade, basis, region, csi_norm);

COMMIT;
