#!/bin/bash
echo "⚙️ Rescaling Infinity-X One services with single concurrency mode..."
PROJECT="infinity-x-one-swarm-system"
REGION="us-east1"

for svc in $(gcloud run services list --project $PROJECT --region $REGION --format="value(metadata.name)"); do
  echo "🔹 Updating $svc..."
  gcloud run services update "$svc" \
    --project=$PROJECT \
    --region=$REGION \
    --cpu=0.25 \
    --memory=256Mi \
    --concurrency=1 \
    --max-instances=1 \
    --timeout=300 \
    --no-traffic \
    --quiet
done

echo "✅ All Cloud Run services updated successfully with 0.25 CPU + concurrency=1."
