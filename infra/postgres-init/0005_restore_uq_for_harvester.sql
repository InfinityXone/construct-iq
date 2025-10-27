-- Re-assert what we want, idempotently
BEGIN;

-- make sure csi_code stays nullable
ALTER TABLE cost_catalog
  ALTER COLUMN csi_code DROP NOT NULL;

-- recreate the unique index the harvester targets
-- (Postgres allows IF NOT EXISTS with CREATE INDEX)
CREATE UNIQUE INDEX IF NOT EXISTS uq_cost_catalog_key
  ON cost_catalog (trade, csi_code, basis, region);

-- keep the normalized uniqueness too (fine to have both)
CREATE UNIQUE INDEX IF NOT EXISTS uniq_cost_catalog_trade_basis_region_csi
  ON cost_catalog (trade, basis, region, csi_norm);

COMMIT;
