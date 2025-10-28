#!/bin/bash
echo "⚙️ Scaling all Infinity-X services to 0.25 CPU, 256Mi memory, and max 1 instance..."
PROJECT="infinity-x-one-swarm-system"
REGION="us-east1"

for svc in $(gcloud run services list --project $PROJECT --region $REGION --format="value(metadata.name)"); do
  echo "🔹 Updating $svc..."
  gcloud run services update "$svc" \
    --project=$PROJECT \
    --region=$REGION \
    --cpu=0.25 \
    --memory=256Mi \
    --max-instances=1 \
    --timeout=300 \
    --no-traffic \
    --quiet
done

echo "✅ All Cloud Run services scaled down successfully."
