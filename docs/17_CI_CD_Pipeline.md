# CI/CD Pipeline (MVP)

- GitHub Actions → Cloud Build (OIDC workload identity)
- Jobs: lint/test, build images, push to Artifact Registry, deploy to Cloud Run
- Migrations step (sql files) gated by manual approval
- Post-deploy smoke tests → notify Slack
