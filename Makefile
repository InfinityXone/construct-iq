SHELL := /bin/bash
up:        ; docker compose -f docker/docker-compose.yml --env-file .env up -d
down:      ; docker compose -f docker/docker-compose.yml --env-file .env down -v
logs:      ; docker compose -f docker/docker-compose.yml logs -f --tail=200
ps:        ; docker compose -f docker/docker-compose.yml ps
curl-health: ; curl -sS http://localhost:8080/api/health | jq .
curl-opps:   ; curl -sS 'http://localhost:8080/api/opportunities?limit=5' | jq .
