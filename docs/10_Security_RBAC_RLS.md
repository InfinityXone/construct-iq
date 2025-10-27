# Security, RBAC & RLS (Phased)

- Phase 1: x-api-key required on POST/PUT/DELETE; per-org API keys.
- Phase 2: RLS in Postgres/Cloud SQL; ensure `org_id = current_setting('ciq.org_id')::uuid`
- Roles: owner | estimator | viewer
- Audit log table: `audit_events(org_id, actor_id, action, target, meta, at)`
- Encrypt at rest: GCP defaults + Secret Manager for keys
- Principle of least privilege for service accounts
