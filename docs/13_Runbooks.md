# Runbooks

## Deploy (Cloud Run)
- Build & push image, set `--add-cloudsql-instances`, set env, roll
- Smoke: `/health` db:up, `/search?q=test` 200

## Rollback
- `gcloud run services update-traffic --to-revisions=<prev>=100`
- Verify health; diff logs

## Adapter outage
- Capture error_reason metrics
- Backoff & retry policy
- File issue with source; temp disable in scheduler
