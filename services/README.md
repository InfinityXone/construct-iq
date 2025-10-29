# Money Loops v1

This folder contains two autonomous revenue loops ready for Cloud Run deployment:

- `revenue-autopilot/` – meetings-as-a-service
- `ecom-growth-studio/` – SKU uplift engine

Each service exposes `/healthz`, `/jobs/tick`, and loop-specific endpoints; each ships with `deploy.sh`, `scheduler.sh`, and `.env.example`.
