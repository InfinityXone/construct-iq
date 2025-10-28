#!/bin/bash
# ======================================================
# Infinity-X One Swarm  —  System Snapshot / Inventory
# ======================================================
OUTPUT=~/infinity-x-one-swarm/system_snapshot_$(date -u +"%Y-%m-%dT%H-%M-%SZ").yaml

echo "system_snapshot:" > "$OUTPUT"
echo "  generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$OUTPUT"
echo "  host: $(hostname)" >> "$OUTPUT"
echo "  user: $USER" >> "$OUTPUT"

echo -e "\n  directories:" >> "$OUTPUT"
ls -1d ~/infinity-x-one-swarm/* | sed 's/^/    - /' >> "$OUTPUT"

echo -e "\n  docker_containers:" >> "$OUTPUT"
docker ps --format "    - name: {{.Names}}\n      image: {{.Image}}\n      ports: {{.Ports}}\n      status: {{.Status}}" >> "$OUTPUT"

echo -e "\n  cloud_run_services:" >> "$OUTPUT"
gcloud run services list --platform=managed --project=infinity-x-one-swarm-system \
  --format="value(name,region,url)" | awk '{print "    - name: "$1"\n      region: "$2"\n      url: "$3}' >> "$OUTPUT"

echo -e "\n  health_checks:" >> "$OUTPUT"
for port in 8080 8081 8085 8090 8095; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$port/health)
  echo "    - port: $port" >> "$OUTPUT"
  echo "      http_status: $STATUS" >> "$OUTPUT"
done

echo -e "\n✅ Snapshot written to $OUTPUT"
