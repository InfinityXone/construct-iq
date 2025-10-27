BEGIN;

-- 1) Drop the legacy unique that conflicts with the harvester’s ON CONFLICT target
DROP INDEX IF EXISTS uq_cost_catalog_key;

-- 2) Do NOT force empty string as default for csi_code (let it be NULL when unknown)
ALTER TABLE cost_catalog ALTER COLUMN csi_code DROP DEFAULT;

-- (Optional) sanity: keep the canonical unique the harvester uses
--   trade, basis, region, COALESCE(csi_code,'')
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM   pg_indexes
    WHERE  schemaname = 'public'
    AND    indexname  = 'uq_cost_catalog_conflict_expr'
  ) THEN
    CREATE UNIQUE INDEX uq_cost_catalog_conflict_expr
      ON cost_catalog (trade, basis, region, COALESCE(csi_code, ''));
  END IF;
END$$;

COMMIT;
