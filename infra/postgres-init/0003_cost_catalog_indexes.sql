CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Search by trade (labor category) fast
CREATE INDEX IF NOT EXISTS idx_cost_catalog_trade_trgm
  ON cost_catalog USING gin (trade gin_trgm_ops);

-- Range filter on unit_cost fast
CREATE INDEX IF NOT EXISTS idx_cost_catalog_unit_cost
  ON cost_catalog (unit_cost);

-- Common JSON meta keys (optional, cheap)
CREATE INDEX IF NOT EXISTS idx_cost_catalog_meta_education
  ON cost_catalog ((meta->>'education_level'));
CREATE INDEX IF NOT EXISTS idx_cost_catalog_meta_business
  ON cost_catalog ((meta->>'business_size'));
CREATE INDEX IF NOT EXISTS idx_cost_catalog_meta_worksite
  ON cost_catalog ((meta->>'worksite'));
