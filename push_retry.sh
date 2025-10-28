#!/usr/bin/env bash
# push_retry.sh — switch origin to HTTPS, diagnose DNS, retry push, and fall back to a bundle.
set -Eeuo pipefail

BRANCH="${1:-$(git rev-parse --abbrev-ref HEAD)}"
HTTPS_URL="${HTTPS_URL:-https://github.com/InfinityXone/construct-iq.git}"
REMOTE="${REMOTE:-origin}"
BUNDLE="/tmp/construct-iq_${BRANCH}_$(date -u +%Y%m%dT%H%M%SZ).bundle"
REPORT="/tmp/push_retry_$(date -u +%Y%m%dT%H%M%SZ).log"

log(){ echo "[$(date +%H:%M:%S)] $*" | tee -a "$REPORT"; }

# 0) Preconditions
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Run inside a git repo"; exit 1; }
log "Branch: $BRANCH  Remote: $REMOTE"

# 1) Quick DNS check
DNS_OK=true
if ! getent hosts github.com >/dev/null 2>&1; then
  DNS_OK=false
  log "DNS lookup FAILED for github.com"
else
  log "DNS lookup OK for github.com"
fi

# 2) Connectivity sniff
PING_OK=true
if ! ping -c1 -W2 1.1.1.1 >/dev/null 2>&1; then
  PING_OK=false
  log "Ping to 1.1.1.1 FAILED (general network issue?)"
else
  log "Ping to 1.1.1.1 OK"
fi

# 3) Flip origin to HTTPS (avoids SSH + known_hosts + key agent issues)
CUR_URL="$(git remote get-url "$REMOTE")"
if [[ "$CUR_URL" != "$HTTPS_URL" ]]; then
  log "Switching $REMOTE to HTTPS: $HTTPS_URL"
  git remote set-url "$REMOTE" "$HTTPS_URL"
else
  log "$REMOTE already using HTTPS"
fi
git remote -v | tee -a "$REPORT"

# 4) Try a lightweight HTTPS request (DNS + TLS path)
CURL_OK=true
if ! curl -I --max-time 6 https://github.com >/dev/null 2>&1; then
  CURL_OK=false
  log "Simple HTTPS request to github.com FAILED"
else
  log "HTTPS to github.com OK"
fi

# 5) Attempt push
PUSH_OK=true
if ! git push -u "$REMOTE" "$BRANCH" 2>&1 | tee -a "$REPORT"; then
  PUSH_OK=false
  log "git push FAILED"
fi

# 6) If push failed, produce a bundle for manual upload
if [ "$PUSH_OK" = false ]; then
  log "Creating git bundle fallback: $BUNDLE"
  git bundle create "$BUNDLE" "$BRANCH"
  log "Bundle ready. You can transfer this file and run:"
  log "  git clone $HTTPS_URL ciq-tmp && cd ciq-tmp"
  log "  git pull"
  log "  git checkout -b $BRANCH"
  log "  git pull $BUNDLE $BRANCH"
  log "  git push -u origin $BRANCH"
fi

# 7) Summary
echo
echo "================ PUSH DIAGNOSTICS ================"
echo "Branch:       $BRANCH"
echo "Origin:       $(git remote get-url "$REMOTE")"
echo "DNS github:   $([[ "$DNS_OK" == true ]] && echo OK || echo FAIL)"
echo "Ping 1.1.1.1: $([[ "$PING_OK" == true ]] && echo OK || echo FAIL)"
echo "HTTPS curl:   $([[ "$CURL_OK" == true ]] && echo OK || echo FAIL)"
echo "git push:     $([[ "$PUSH_OK" == true ]] && echo OK || echo FAIL)"
[[ "$PUSH_OK" == false ]] && echo "Bundle:       $BUNDLE"
echo "Report:       $REPORT"
echo "=================================================="
