# ===== Construct IQ — Cloud Run worker Makefile (tabless) =====
.RECIPEPREFIX := >
SHELL := /bin/bash

PROJECT_ID ?= $(shell gcloud config get-value project)
REGION     ?= us-east1
INSTANCE   ?= ciq-postgres
SERVICE    ?= harvester
IMAGE      ?= gcr.io/$(PROJECT_ID)/harvester
CONN_NAME  := $(shell gcloud sql instances describe $(INSTANCE) --format='value(connectionName)' 2>/dev/null || true)

.PHONY: status build deploy pubsub smoke logs

status:
> echo "Project: $(PROJECT_ID)  Region: $(REGION)"
> echo "Instance: $(INSTANCE)  Conn: $(CONN_NAME)"
> gcloud run services describe $(SERVICE) --region $(REGION) --format='value(status.url)' || true
> gcloud sql instances describe $(INSTANCE) --format='value(state)' || true

build:
> cp -f Dockerfile.worker Dockerfile
> gcloud builds submit --tag $(IMAGE) .

deploy:
> test -n "$(CONN_NAME)" || (echo "No Cloud SQL connection name found"; exit 1)
> gcloud run deploy $(SERVICE) --image $(IMAGE) --region $(REGION) \
    --add-cloudsql-instances "$(CONN_NAME)" \
    --set-env-vars INSTANCE_CONN_NAME="$(CONN_NAME)",DB_NAME=ciq,DB_USER=ciq,DB_PASS=ciqpass \
    --no-allow-unauthenticated

pubsub:
> TOPIC=harvest-names; SUB=harvest-push; \
  URL=$$(gcloud run services describe $(SERVICE) --region $(REGION) --format='value(status.url)'); \
  SA=$$(gcloud run services describe $(SERVICE) --region $(REGION) --format='value(spec.template.spec.serviceAccountName)'); \
  gcloud pubsub topics create $$TOPIC || true; \
  gcloud pubsub subscriptions create $$SUB --topic $$TOPIC --push-endpoint "$$URL/" \
      --push-auth-service-account "$$SA" --ack-deadline 30 || true; \
  echo "Topic: $$TOPIC  Sub: $$SUB  URL: $$URL"

smoke:
> gcloud pubsub topics publish harvest-names --message '{"name":"Flagger","region":"US-ceiling","basis":"labor"}'

logs:
> gcloud logs tail --region $(REGION) "run.googleapis.com%2Frequests" --service=$(SERVICE)
