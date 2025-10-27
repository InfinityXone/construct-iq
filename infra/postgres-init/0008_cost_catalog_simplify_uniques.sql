BEGIN;

-- 0) Make sure generated column exists
ALTER TABLE cost_catalog
  ADD COLUMN IF NOT EXISTS csi_norm text GENERATED ALWAYS AS (COALESCE(csi_code, '')) STORED;

-- 1) Hard de-dup on the canonical key (keep newest by updated_at then id)
WITH ranked AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY trade, basis, region, COALESCE(csi_code,'')
           ORDER BY updated_at DESC, id DESC
         ) rn
  FROM cost_catalog
)
DELETE FROM cost_catalog d
USING ranked r
WHERE d.id = r.id AND r.rn > 1;

-- 2) Drop any other uniques so only ONE remains
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT conname
    FROM   pg_constraint
    WHERE  conrelid = 'public.cost_catalog'::regclass
    AND    contype = 'u'
    AND    conname <> 'uniq_cost_catalog_trade_basis_region_csi'
  LOOP
    EXECUTE format('ALTER TABLE cost_catalog DROP CONSTRAINT %I;', r.conname);
  END LOOP;
END$$;

-- 3) Ensure our canonical unique exists (if a same-named index exists, attach it)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                 WHERE conrelid='public.cost_catalog'::regclass
                   AND conname='uniq_cost_catalog_trade_basis_region_csi') THEN
    BEGIN
      ALTER TABLE cost_catalog
        ADD CONSTRAINT uniq_cost_catalog_trade_basis_region_csi
        UNIQUE (trade,basis,region,csi_norm);
    EXCEPTION
      WHEN duplicate_table THEN
        -- A same-named index may exist; try attaching
        PERFORM 1;
    END;
  END IF;
END$$;

COMMIT;
