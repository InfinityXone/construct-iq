import os, time, json, math, sys
import urllib.parse, urllib.request
from typing import Any, Dict, Iterable, List, Tuple

import psycopg
from psycopg.rows import dict_row

DB_URL = os.getenv("DATABASE_URL", "postgresql://ciq:ciqpass@db:5432/ciq")
PAGES = int(os.getenv("CALC_PAGES", "5"))
SLEEP = int(os.getenv("CALC_INTERVAL_SECS", "21600"))
USER_AGENT = os.getenv("USER_AGENT", "construct-iq-harvester/1.0")
GSA_API_KEY = os.getenv("GSA_API_KEY", "")  # optional

# NOTE: This endpoint pattern has worked in practice; adjust if CALC changes.
BASE = "https://api.gsa.gov/analysis/calc/rates/search"
COMMON_QS = {
    "api_key": GSA_API_KEY,
    "q": "*",
    "size": 100,   # page size
    "from": 0,     # offset; we bump per page
}

def _fetch(page: int) -> Dict[str, Any]:
    params = COMMON_QS.copy()
    params["from"] = page * params["size"]
    # Drop api_key if blank to avoid 403 on some mirrors
    if not params["api_key"]:
        params.pop("api_key", None)

    url = f"{BASE}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as r:
        if r.status != 200:
            raise RuntimeError(f"HTTP {r.status}")
        return json.loads(r.read())

def _rows_from_hit(hit: Dict[str, Any]) -> Tuple[int, Dict[str, Any], Dict[str, Any]]:
    """
    Return (ext_id, raw_json_doc_for_audit, normalized_row)
    """
    # ext id: compose a stable key from vendor + trade + sin + hourly
    src = hit.get("_source") or hit
    vendor = str(src.get("vendor_name","")).strip()
    trade  = str(src.get("labor_category","")).strip() or str(src.get("labor_category_name","")).strip()
    sin    = str(src.get("sin","")).strip()
    unit   = float(src.get("hourly_rate_year1") or src.get("hourly_rate","0") or 0)
    worksite = str(src.get("worksite","")).strip() or str(src.get("worksite_type","")).strip()
    edu = str(src.get("education_level","")).strip()
    exp = src.get("min_years_experience")
    try:
        exp = int(exp) if exp is not None and str(exp).isdigit() else None
    except:
        exp = None

    # ext id hash-ish (not cryptographic; just stable-ish)
    ext_str = f"{vendor}|{trade}|{sin}|{unit:.4f}"
    ext_id = abs(hash(ext_str)) % (10**15)

    # normalize to our columns
    meta = {
        "vendor_name": vendor,
        "sin": sin,
        "worksite": worksite or "Both",
        "education_level": edu or None,
        "min_years_experience": exp,
        # extra CALC fields (best effort)
        "category": src.get("category"),
        "subcategory": src.get("subcategory"),
        "idv_piid": src.get("idv_piid"),
        "contractor_site": src.get("contractor_site"),
        "business_size": (str(src.get("business_size") or src.get("business_size_type") or "")[:1] or None),
    }

    row = {
        "trade": trade or "Unknown",
        "csi_code": src.get("csi_code") or None,
        "unit_cost": unit,
        "basis": "labor",
        "region": "US-ceiling",
        "meta": meta,
    }
    return ext_id, src, row

UPSERT_SQL = """
INSERT INTO cost_catalog (trade, csi_code, unit_cost, basis, region, meta, updated_at)
VALUES (%(trade)s, %(csi_code)s, %(unit_cost)s, %(basis)s, %(region)s, %(meta)s, now())
ON CONFLICT (trade, basis, region, csi_norm)
DO UPDATE SET unit_cost = EXCLUDED.unit_cost,
              meta      = EXCLUDED.meta,
              updated_at= now();
"""

RAW_SQL = """
INSERT INTO external_rates_raw (ext_id, hit, fetched_at)
VALUES (%s, %s, now())
ON CONFLICT (ext_id) DO NOTHING;
"""

def harvest_once(pages: int) -> Tuple[int,int]:
    saved_raw = 0
    upserts = 0
    with psycopg.connect(DB_URL, autocommit=True) as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            for p in range(pages):
                data = _fetch(p)
                items = (
                    data.get("items")
                    or data.get("results")
                    or data.get("hits", {}).get("hits", [])
                )
                if not items:
                    break

                for hit in items:
                    ext_id, raw, row = _rows_from_hit(hit)
                    try:
                        cur.execute(RAW_SQL, (ext_id, json.dumps(raw)))
                        saved_raw += 1
                    except Exception:
                        pass  # best-effort debug trail

                    cur.execute(UPSERT_SQL, {"trade": row["trade"],
                                             "csi_code": row["csi_code"],
                                             "unit_cost": row["unit_cost"],
                                             "basis": row["basis"],
                                             "region": row["region"],
                                             "meta": json.dumps(row["meta"])})
                    upserts += 1
    return saved_raw, upserts

def main():
    while True:
        try:
            raw, up = harvest_once(PAGES)
            print(json.dumps({"raw_saved": raw, "catalog_upserts": up}), flush=True)
        except Exception as e:
            print(f"[ERROR] {e}", file=sys.stderr, flush=True)
        time.sleep(SLEEP)

if __name__ == "__main__":
    main()
