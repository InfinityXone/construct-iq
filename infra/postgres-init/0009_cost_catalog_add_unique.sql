BEGIN;

-- ensure generated column exists
ALTER TABLE cost_catalog
  ADD COLUMN IF NOT EXISTS csi_norm text GENERATED ALWAYS AS (COALESCE(csi_code, '')) STORED;

-- create the unique index if it's missing
CREATE UNIQUE INDEX IF NOT EXISTS uniq_cost_catalog_trade_basis_region_csi
  ON cost_catalog (trade, basis, region, csi_norm);

-- attach the index as the named constraint (safe if already attached)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conrelid = 'public.cost_catalog'::regclass
       AND conname  = 'uniq_cost_catalog_trade_basis_region_csi'
  ) THEN
    ALTER TABLE cost_catalog
      ADD CONSTRAINT uniq_cost_catalog_trade_basis_region_csi
      UNIQUE USING INDEX uniq_cost_catalog_trade_basis_region_csi;
  END IF;
END$$;

COMMIT;
