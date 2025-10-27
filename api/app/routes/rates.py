from fastapi import APIRouter, Query
from typing import Optional, List, Any, Dict
import os, json
import psycopg
from psycopg.rows import dict_row

DB_URL = os.getenv("DATABASE_URL", "postgresql://ciq:ciqpass@db:5432/ciq")

router = APIRouter()

@router.get("/api/rates")
def list_rates(
    q: Optional[str] = Query(None),
    min_cost: Optional[float] = Query(None),
    max_cost: Optional[float] = Query(None),
    limit: int = Query(25, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    where = ["1=1"]
    args: List[Any] = []
    if q:
        where.append("trade ILIKE '%' || %s || '%'")
        args.append(q)
    if min_cost is not None:
        where.append("unit_cost >= %s")
        args.append(min_cost)
    if max_cost is not None:
        where.append("unit_cost <= %s")
        args.append(max_cost)

    sql = f"""
      SELECT trade, unit_cost,
             meta->>'education_level' AS education_level,
             (meta->>'min_years_experience')::int AS min_years_experience,
             meta->>'worksite' AS worksite,
             meta->>'business_size' AS business_size,
             meta->>'vendor_name' AS vendor_name,
             meta->>'idv_piid' AS idv_piid,
             meta->>'sin' AS sin,
             meta->>'category' AS category,
             meta->>'subcategory' AS subcategory
      FROM cost_catalog
      WHERE {' AND '.join(where)}
      ORDER BY unit_cost
      LIMIT %s OFFSET %s
    """
    args.extend([limit, offset])

    count_sql = f"SELECT COUNT(*) FROM cost_catalog WHERE {' AND '.join(where)}"

    with psycopg.connect(DB_URL, autocommit=True) as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(sql, args)
            rows = cur.fetchall()
            cur.execute(count_sql, args[:-2])  # without limit/offset
            c = cur.fetchone()["count"]
    return {"items": rows, "count": c}
