# Architecture Overview
Users → Next.js (Vercel) → Sentry/OTel
                 │
                 │ REST/Edge routes
                 ▼
         Pub/Sub (GCP) / Queues
                 ▼
     Python workers (services/harvester)
                 ▼
   Postgres / Object Storage / Redis
Principles: deterministic first, clear lineage, tenant safety, observable by default.
