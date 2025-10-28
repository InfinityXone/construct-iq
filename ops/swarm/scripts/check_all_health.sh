#!/bin/bash
# Check health endpoints for all Alpha-Omega services

declare -A PORTS=(
  ["orchestrator"]=8081
  ["infinity-agent"]=8080
  ["memory-gateway"]=8090
  ["headless-agent"]=8085
  ["genesis-deployer"]=8095
)

echo "🧠 Checking Alpha-Omega container health endpoints..."
for name in "${!PORTS[@]}"; do
  port=${PORTS[$name]}
  printf "\n➡️  %-18s (port %-5s): " "$name" "$port"
  curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port/health"
done
echo -e "\n------------------------------------------------------------"
