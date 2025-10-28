#!/bin/bash
# =========================================================
# Infinity-X One Docker Service Inspector
# Lists all running containers, their exposed ports,
# images, and quick identification (Orchestrator, Gateway, etc.)
# =========================================================

echo "🔍 Gathering active Docker containers..."
echo "------------------------------------------------------------"

docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}\t{{.Names}}" | sed 's/^/   /'

echo
echo "------------------------------------------------------------"
echo "🧠 Attempting to identify key Infinity-X services:"
echo

# Identify containers by port bindings or name hints
docker ps --format "{{.ID}} {{.Image}} {{.Ports}} {{.Names}}" | while read id image ports name; do
  service="unknown"
  case "$ports" in
    *8080*) service="🧩 Orchestrator (primary)" ;;
    *8090*) service="🧠 Memory Gateway" ;;
    *8081*) service="🛰 Satellite" ;;
    *8085*) service="🔧 Utility or Auto-Heal" ;;
    *8095*) service="🧬 Orchestrator Dev/Staging" ;;
    *3000*) service="📊 Dashboard UI" ;;
    *4000*) service="🌐 API Gateway / Proxy" ;;
  esac

  printf "➡️  %-15s | %-40s | %-25s | %s\n" "$id" "$image" "$ports" "$service"
done

echo
echo "------------------------------------------------------------"
echo "💡 Tip: To inspect logs for a container, run:"
echo "   docker logs -f <CONTAINER_ID>"
echo "   docker exec -it <CONTAINER_ID> /bin/bash"
echo "------------------------------------------------------------"
