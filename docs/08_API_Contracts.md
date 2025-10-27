# API Contracts (MVP)

## GET /health
- 200: `{ ok: true, db: "up" }`

## GET /search?q=&limit=&offset=
- Returns `{ items: [{id,title,due_at,est_value,source,url,score}], count }`

## POST /intake/solicitation (x-api-key)
- Body: `{ source, source_id, url, title, due_at, est_value, raw }`
- Upsert on (source, source_id)

## GET /templates
## POST /templates (x-api-key)
- CRUD for bid templates (name, trade, lines[])

## POST /render/bid (x-api-key)
- Inputs: `takeoff`, `template_id`, `margin_pct`
- Output: `{ total, lines[], pdf_url }`
