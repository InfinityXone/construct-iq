# Source Adapters Spec

## Contract
- `uniqueness`: (source, source_id)
- `watermarks`: updated_at/seen_at
- `provenance`: source_url, fetched_at, checksum

## Python skeleton
- `fetch_page(cursor) -> { items:[], next_cursor }`
- normalize(item) -> `opportunity` dict
- upsert batch with ON CONFLICT

## Test fixture
- Save raw page to `fixtures/<adapter>/page_1.json`
- Unit test: stable keys, idempotent upsert count
