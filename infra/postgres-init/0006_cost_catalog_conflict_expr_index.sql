BEGIN;

-- Unique index that exactly matches the harvester’s ON CONFLICT target:
-- (trade, basis, region, COALESCE(csi_code,''))
CREATE UNIQUE INDEX IF NOT EXISTS uq_cost_catalog_conflict_expr
ON cost_catalog (trade, basis, region, (COALESCE(csi_code, '')));

COMMIT;
