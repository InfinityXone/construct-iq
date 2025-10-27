#!/usr/bin/env bash
# Chromebook (Crostini) quick clean
# Usage:
#   ./clean_chromebook.sh           # interactive
#   ./clean_chromebook.sh -a        # aggressive (larger cleanup)
#   ./clean_chromebook.sh -a -y     # aggressive + auto-yes
set -euo pipefail

YES=false
AGGRESSIVE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y)        YES=true; shift ;;
    --aggressive|-a) AGGRESSIVE=true; shift ;;
    -h|--help)
      cat <<'HELP'
Usage: clean_chromebook.sh [--aggressive|-a] [--yes|-y]

  --aggressive, -a    Heavier cleanup (journal size limit 100M; full docker prune)
  --yes,        -y    Auto-confirm prompts (non-interactive)

This cleans apt caches, pip/npm/yarn/pnpm caches, Python __pycache__,
~/.cache, old /tmp, trims journald (if present), and optionally prunes Docker/Podman.
HELP
      exit 0
      ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

ask() {
  if $YES; then return 0; fi
  read -rp "$1 [y/N]: " ans
  [[ "${ans:-N}" =~ ^[Yy]$ ]]
}

bytes_to_h() {
  if command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec --suffix=B --padding=7 "$1"
  else
    # Fallback: print raw bytes
    printf "%7dB" "$1"
  fi
}

before=$(df -B1 / | awk 'NR==2{print $4}')
echo "==> Free space before: $(bytes_to_h "$before")"

# 1) APT caches & old packages (Debian-based Crostini)
if command -v apt-get >/dev/null 2>&1; then
  echo "==> Cleaning APT caches"
  sudo apt-get -y autoremove || true
  sudo apt-get -y autoclean || true
  sudo apt-get -y clean || true
fi

# 2) Pip cache
if command -v pip >/dev/null 2>&1 || command -v pip3 >/dev/null 2>&1; then
  if ask "Clear pip cache (~/.cache/pip)?"; then
    rm -rf "${HOME}/.cache/pip" 2>/dev/null || true
  fi
fi

# 3) Node / package manager caches
if command -v npm >/dev/null 2>&1; then
  if ask "Clear npm cache?"; then
    npm cache clean --force || true
  fi
fi
if command -v yarn >/dev/null 2>&1; then
  if ask "Clear yarn cache?"; then
    yarn cache clean || true
  fi
fi
if command -v pnpm >/dev/null 2>&1; then
  if ask "Prune pnpm store?"; then
    pnpm store prune || true
  fi
fi

# 4) Python build cruft
if ask "Remove Python build artifacts (__pycache__, *.pyc) under current dir?"; then
  find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
  find . -type f -name "*.py[co]" -delete 2>/dev/null || true
fi

# 5) Thumbnails & general user cache
if ask "Clear ~/.cache and ~/.thumbnails?"; then
  rm -rf "${HOME}/.cache/"* "${HOME}/.thumbnails" 2>/dev/null || true
fi

# 6) /tmp cleanup (safe age-based)
if ask "Purge /tmp files older than 2 days?"; then
  sudo find /tmp -xdev -type f -mtime +2 -delete 2>/dev/null || true
  sudo find /tmp -xdev -type d -empty -mtime +2 -delete 2>/dev/null || true
fi

# 7) Journald logs (if systemd/journalctl present)
if command -v journalctl >/dev/null 2>&1; then
  if $AGGRESSIVE; then
    echo "==> Vacuuming journal to 100M"
    sudo journalctl --vacuum-size=100M || true
  else
    echo "==> Vacuuming journal to keep 7d"
    sudo journalctl --vacuum-time=7d || true
  fi
fi

# 8) Docker / Podman (optional heavy cleanup)
if command -v docker >/dev/null 2>&1; then
  if ask "Prune Docker images/containers/volumes? (will re-pull later)"; then
    if $AGGRESSIVE; then
      docker system prune -af --volumes || true
    else
      docker system prune -f || true
    fi
  fi
fi
if command -v podman >/dev/null 2>&1; then
  if ask "Prune Podman images/containers/volumes?"; then
    if $AGGRESSIVE; then
      podman system prune -af || true
    else
      podman system prune -f || true
    fi
  fi
fi

# 9) Flatpak cache (if installed)
if command -v flatpak >/dev/null 2>&1; then
  if ask "Clean Flatpak unused refs/cache?"; then
    flatpak uninstall --unused -y || true
  fi
fi

# 10) Show big items (you choose to delete)
echo "==> Top 15 largest items under \$HOME (scan)"
du -ah "${HOME}" 2>/dev/null | sort -hr | head -n 15 || true

after=$(df -B1 / | awk 'NR==2{print $4}')
echo "==> Free space after:  $(bytes_to_h "$after")"
saved=$((after-before))
[[ $saved -gt 0 ]] && echo "==> Freed:            $(bytes_to_h "$saved")" || echo "==> Freed:            0B"

echo "Done."
