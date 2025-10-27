# Construct‑IQ — Strategy v1.1 (Revised)

## Thesis
Win by surfacing **earlier, truer signals** (pre‑bid intent + funding readiness) and compressing the **takeoff → bid** loop to minutes. Deliver this as a dead‑simple, multi‑tenant SaaS for GCs, specialty subs (MEP/envelope/interiors), and suppliers.

## What we uniquely do
- **Early signals**: planholders & sign‑ins, council agendas/minutes, capital improvement plans (CIPs), grants/bonds, DOT bid tabs, pre‑app & zoning dockets.
- **Normalization**: de‑duplicate, geocode, map to CSI/Uniformat, enrich with funding & award history.
- **Speed to bid**: calibrated takeoffs, cost catalogs (CALC + internal), margin sliders, branded exports.
- **Proof & provenance**: source URLs + timestamps + FOIA workflow when needed.

## Product pillars
1. **Signals** — search, saved filters, alerts, provenance.
2. **Takeoff** — PDF import, smart scopes, quantities, alternates/add‑deducts.
3. **Bid Composer** — unit rates + margin, schedule of values, branded outputs.
4. **Integrations** — Google Drive, email, CRM, Stripe billing.
5. **Governance** — orgs, roles, audit log, secure data boundaries.

## Roadmap (phased)
- **Phase 0 (Week 0–1):** infra, DB schema, CALC harvester, health/telemetry.
- **Phase 1 (Week 1–3):** Source adapters (3–5 portals), opportunities index + search API, UI /opportunities.
- **Phase 2 (Week 3–6):** Saved searches & alerts, FOIA concierge workflow, awards/funding join.
- **Phase 3 (Week 6–9):** Takeoff (MVP) + Bid Composer (MVP), exports.
- **Phase 4 (Week 9–12):** SaaS hardening (auth/RBAC/RLS, Stripe), Sentry/OTel, canaries/runbooks.

## Success metrics
- Time‑to‑first‑result (TTV) < 5 min.
- P95 search < 400 ms @ 10k opportunities.
- 30‑day free → paid conversion ≥ 12%.
- Net revenue retention (NRR) ≥ 120% by month 9.

## Risks (and mitigations)
- **Portal ToS / scraping fragility** → Prefer official APIs & open data; FOIA for the rest; rotating adapters with tests.
- **PDF chaos** → scope templates + human‑in‑the‑loop review.
- **Tenant isolation** → API key on writes now; RLS and role gating in Phase 4.
- **Freshness lag** → adapter watermarks + backoff + retries; daily diff reports.