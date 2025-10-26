from fastapi import FastAPI, Query
from os import getenv
from datetime import datetime
from .db import connect

app = FastAPI(title="Construct-IQ API", openapi_url="/openapi.json")

@app.get("/api/health")
def health():
    return {"ok": True, "ts": int(datetime.utcnow().timestamp()*1000)}

@app.get("/api/version")
def version():
    return {
        "app": "Construct-IQ",
        "env": getenv("ENV","development"),
        "commit": getenv("COMMIT_SHA","dev"),
        "now": datetime.utcnow().isoformat()+"Z",
    }

@app.get("/api/opportunities")
def list_opps(limit: int = Query(25, ge=1, le=100), q: str | None = None):
    sql = "select id, source, source_id, title, phase, scopes, due_date, est_value, location, score from opportunities"
    args = []
    if q:
        sql += " where title ilike %s or description ilike %s"
        args = [f"%{q}%", f"%{q}%"]
    sql += " order by score desc nulls last, due_date asc nulls last limit %s"
    args.append(limit)
    with connect() as conn:
        rows = conn.execute(sql, args).fetchall()
        return {"items": rows, "count": len(rows)}
