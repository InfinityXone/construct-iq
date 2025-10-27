import os, sys, json, math, time, urllib.parse, urllib.request
import psycopg

BASE = "https://api.gsa.gov/acquisition/calc/v3/api/ceilingrates/"
PAGE_SIZE = int(os.getenv("CALC_PAGE_SIZE","200"))
MAX_PAGES = int(os.getenv("CALC_MAX_PAGES","10"))  # safety cap; lift later
API_KEY = os.getenv("GSA_API_KEY")  # optional; API is public but key works too

def fetch(page:int):
    q = [
        ("page", str(page)),
        ("page_size", str(PAGE_SIZE)),
        ("ordering","current_price"),
        ("sort","asc"),
        ("filter","price_range:10,500"),
        ("filter","experience_range:0,45"),
    ]
    if API_KEY:
        q.append(("api_key", API_KEY))
    url = BASE + "?" + urllib.parse.urlencode(q)
    req = urllib.request.Request(url, headers={"Accept":"application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode())

dsn = os.getenv("DATABASE_URL","postgresql://ciq:ciqpass@db:5432/ciq")
now = time.time()

with psycopg.connect(dsn, autocommit=True) as conn, conn.cursor() as cur:
    j = fetch(1)
    total = j["hits"]["total"]["value"]
    pages = min(MAX_PAGES, math.ceil(total / PAGE_SIZE))
    upserts = 0
    raws = 0

    for pg in range(1, pages+1):
        if pg>1:
            j = fetch(pg)
        hits = j["hits"]["hits"]
        for h in hits:
            s = h["_source"]
            ext_id = int(s["id"])
            # raw
            cur.execute("""
                INSERT INTO external_rates_raw (ext_id, hit)
                VALUES (%s, %s)
                ON CONFLICT (ext_id) DO UPDATE SET hit=EXCLUDED.hit, fetched_at=now()
            """, (ext_id, json.dumps(s)))
            raws += 1

            # map → cost_catalog
            trade = s.get("labor_category","").strip()
            if not trade:
                continue
            unit_cost = float(s.get("current_price"))
            meta = {
                "education_level": s.get("education_level"),
                "min_years_experience": s.get("min_years_experience"),
                "worksite": s.get("worksite"),
                "business_size": s.get("business_size"),
                "sin": s.get("sin"),
                "vendor_name": s.get("vendor_name"),
                "idv_piid": s.get("idv_piid"),
                "_timestamp": s.get("_timestamp"),
                "contract_start": s.get("contract_start"),
                "contract_end": s.get("contract_end"),
            }
            cur.execute("""
                INSERT INTO cost_catalog (trade, csi_code, unit_cost, basis, region, meta, updated_at)
                VALUES (%s, NULL, %s, 'labor', 'US-ceiling', %s, now())
                ON CONFLICT (trade, COALESCE(csi_code,''), basis, region)
                DO UPDATE SET unit_cost=EXCLUDED.unit_cost,
                              meta=EXCLUDED.meta,
                              updated_at=now()
            """, (trade, unit_cost, json.dumps(meta)))
            upserts += 1

    print(json.dumps({"raw_saved": raws, "catalog_upserts": upserts, "pages_processed": pages}))
