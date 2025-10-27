BEGIN;

-- 1) Allow NULLs for csi_code (the harvester provides many with no code)
ALTER TABLE cost_catalog
  ALTER COLUMN csi_code DROP NOT NULL;

-- 2) Ensure the generated/coalesced column exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'cost_catalog'
      AND column_name  = 'csi_norm'
  ) THEN
    ALTER TABLE cost_catalog
      ADD COLUMN csi_norm TEXT GENERATED ALWAYS AS (COALESCE(csi_code, '')) STORED;
  END IF;
END $$;

-- 3) Drop the old unique that used raw csi_code (redundant with csi_norm)
DROP INDEX IF EXISTS uq_cost_catalog_key;

-- 4) Make sure the normalized unique exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public' AND indexname = 'uniq_cost_catalog_trade_basis_region_csi'
  ) THEN
    CREATE UNIQUE INDEX uniq_cost_catalog_trade_basis_region_csi
      ON cost_catalog (trade, basis, region, csi_norm);
  END IF;
END $$;

COMMIT;
