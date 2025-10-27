#!/usr/bin/env python3
# Construct IQ — GSA calc rates harvester (stdlib-only version)
# - Robust HTTPS fetch with retries/backoff using urllib + ssl
# - UPSERT targets the *constraint name* to avoid drift
# - No external deps beyond psycopg (already in image)

import os
import ssl
import json
import time
import math
import logging
import urllib.request
import urllib.error
from typing import List, Dict, Any, Optional

import psycopg

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger("gsa_calc_rates")

# ---- Configuration ----
GSA_BASE_URL = os.getenv("GSA_BASE_URL", "https://example.gov/gsa/rates")  # <-- set your real endpoint
PAGE_PARAM = os.getenv("GSA_PAGE_PARAM", "page")
REQUEST_TIMEOUT = int(os.getenv("REQUEST_TIMEOUT_SEC", "60"))
MAX_RETRIES = int(os.getenv("MAX_FETCH_RETRIES", "5"))
BACKOFF_BASE = float(os.getenv("BACKOFF_BASE_SEC", "0.6"))

DB_URL = os.getenv("DATABASE_URL", "postgresql://ciq:ciqpass@db:5432/ciq")

# ---- HTTPS fetch with retries/backoff, stdlib-only ----
def fetch_page(page: int) -> bytes:
    url = f"{GSA_BASE_URL}?{PAGE_PARAM}={page}"
    headers = {
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) ConstructIQHarvester/1.0",
        "Accept": "application/json, text/html;q=0.9,*/*;q=0.8",
        "Connection": "close",
    }
    req = urllib.request.Request(url, headers=headers, method="GET")

    # Default secure context; we only flip knobs that help with flaky servers
    ctx = ssl.create_default_context()
    # Optionally tighten/loosen if your endpoint is old/proxying weirdly:
    # ctx.check_hostname = True
    # ctx.verify_mode = ssl.CERT_REQUIRED

    last_err: Optional[Exception] = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT, context=ctx) as r:
                data = r.read()
                if not data:
                    raise IOError("empty response")
                return data
        except (urllib.error.URLError, ssl.SSLError, TimeoutError, IOError) as e:
            last_err = e
            sleep_s = BACKOFF_BASE * (2 ** (attempt - 1))  # 0.6,1.2,2.4,4.8,...
            log.warning("fetch attempt %s failed (%s). retrying in %.1fs", attempt, e, sleep_s)
            time.sleep(sleep_s)
    assert last_err is not None
    raise last_err

# ---- Parse helpers (adjust to your real payload) ----
def parse_records(payload: bytes) -> List[Dict[str, Any]]:
    """
    Return a list of records with keys:
      trade, csi_code, unit_cost, basis, region, meta (dict)
    You likely have HTML/JSON. Illustrative parser supports JSON list/dict.
    """
    try:
        obj = json.loads(payload.decode("utf-8", errors="replace"))
    except json.JSONDecodeError:
        # If HTML, plug your own parser here (bs4/lxml if you allow deps).
        raise RuntimeError("Non-JSON response; implement HTML parsing for this source.")

    recs: List[Dict[str, Any]] = []
    if isinstance(obj, list):
        iterable = obj
    elif isinstance(obj, dict) and "results" in obj:
        iterable = obj["results"]
    else:
        iterable = []

    for row in iterable:
        # Map your source fields to our schema. Fallbacks keep us resilient.
        trade = str(row.get("trade") or row.get("title") or "").strip() or "Unknown"
        csi_code = str(row.get("csi") or row.get("csi_code") or "").strip()
        basis = str(row.get("basis") or "labor").strip()
        region = str(row.get("region") or "US-ceiling").strip()

        # Unit cost coercion
        raw_cost = row.get("unit_cost") or row.get("rate") or 0
        try:
            unit_cost = float(raw_cost)
        except Exception:
            unit_cost = 0.0

        meta = {
            "source": "gsa",
            "raw": row,
        }
        recs.append(
            {
                "trade": trade,
                "csi_code": csi_code,
                "unit_cost": unit_cost,
                "basis": basis,
                "region": region,
                "meta": meta,
            }
        )
    return recs

# ---- DB UPSERT (targets the constraint name) ----
UPSERT_SQL = """
INSERT INTO cost_catalog (trade, csi_code, unit_cost, basis, region, meta)
VALUES (%s, %s, %s, %s, %s, %s)
ON CONSTRAINT uniq_cost_catalog_trade_basis_region_csi
DO UPDATE SET
  unit_cost  = EXCLUDED.unit_cost,
  meta       = EXCLUDED.meta,
  updated_at = now();
"""

def upsert_records(conn: psycopg.Connection, records: List[Dict[str, Any]]) -> int:
    if not records:
        return 0
    done = 0
    with conn.cursor() as cur:
        for r in records:
            try:
                cur.execute(
                    UPSERT_SQL,
                    (
                        r["trade"],
                        r["csi_code"],
                        r["unit_cost"],
                        r["basis"],
                        r["region"],
                        json.dumps(r["meta"]),
                    ),
                )
                done += 1
            except psycopg.Error as e:
                # Log and continue rather than crash the whole run
                log.error("UPSERT failed for %s / %s / %s / %s: %s",
                          r["trade"], r["basis"], r["region"], r["csi_code"], e)
        conn.commit()
    return done

# ---- Main loop (paginate until empty) ----
def main():
    log.info("Starting GSA calc harvester")
    conn = psycopg.connect(DB_URL)
    total = 0
    page = 1
    consecutive_empties = 0
    MAX_EMPTY_PAGES = 2  # stop after a couple of empty pages

    try:
        while True:
            log.info("Fetching page %s", page)
            payload = fetch_page(page)
            recs = parse_records(payload)
            if not recs:
                consecutive_empties += 1
                log.info("No records on page %s (%s empty pages)", page, consecutive_empties)
                if consecutive_empties >= MAX_EMPTY_PAGES:
                    break
                page += 1
                continue

            consecutive_empties = 0
            inserted = upsert_records(conn, recs)
            total += inserted
            log.info("Upserted %s records (cumulative %s)", inserted, total)
            page += 1

        log.info("Done. Upserted total: %s", total)
    finally:
        try:
            conn.close()
        except Exception:
            pass

if __name__ == "__main__":
    main()
