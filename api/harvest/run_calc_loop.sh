#!/usr/bin/env bash
set -Eeuo pipefail
PAGES="${CALC_PAGES:-5}"
INTERVAL="${CALC_INTERVAL_SECS:-21600}"
echo "==> CALC harvester starting (pages=$PAGES, interval=${INTERVAL}s)"
pip install -q -r /app/requirements.txt
run_once() {
  echo "==> Harvesting CALC+ (pages=$PAGES)…"
  python -u /app/harvest/gsa_calc_rates.py --pages "$PAGES"
}
run_once
while true; do
  echo "==> Sleeping ${INTERVAL}s before next run…"
  sleep "$INTERVAL"
  run_once
done
