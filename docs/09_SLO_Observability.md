# SLOs & Observability

- Search p95 < 400ms @ 10k rows
- Ingest success rate ≥ 99%/day (excludes 4xx from sources)
- Alert latency < 10 min (instant) / < 24h (daily)

**Signals to collect (OTel):**
- adapter.fetch.duration, adapter.rows, adapter.error_reason
- api.search.duration, api.search.rows
- worker.upsert.count, worker.upsert.conflicts
- db.connections.open

**Alerts:**
- No new opportunities in 12h (per adapter)
- adapter.error_reason spikes > 5% in 1h
- search p95 > 800ms for 30m
