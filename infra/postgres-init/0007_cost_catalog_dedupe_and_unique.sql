BEGIN;

ALTER TABLE cost_catalog
  ADD COLUMN IF NOT EXISTS csi_norm text GENERATED ALWAYS AS (COALESCE(csi_code, '')) STORED;

WITH ranked AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY trade, basis, region, COALESCE(csi_code, '')
      ORDER BY updated_at DESC, id DESC
    ) AS rn
  FROM cost_catalog
)
DELETE FROM cost_catalog cc
USING ranked r
WHERE cc.id = r.id
  AND r.rn > 1;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_cost_catalog_conflict_expr') THEN
    ALTER TABLE cost_catalog DROP CONSTRAINT uq_cost_catalog_conflict_expr;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_cost_catalog_key') THEN
    ALTER TABLE cost_catalog DROP CONSTRAINT uq_cost_catalog_key;
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uniq_cost_catalog_trade_basis_region_csi') THEN
    ALTER TABLE cost_catalog
      ADD CONSTRAINT uniq_cost_catalog_trade_basis_region_csi
      UNIQUE (trade, basis, region, csi_norm);
  END IF;
END$$;

COMMIT;
