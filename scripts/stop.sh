#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/env.sh"

if [[ -f "$TGOM_LOGS/mkxp.pid" ]]; then
  pid="$(cat "$TGOM_LOGS/mkxp.pid" 2>/dev/null || true)"
  if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    echo "Stopped mkxp-z (PID $pid)."
  fi
  rm -f "$TGOM_LOGS/mkxp.pid"
fi

# Match only the Z-universal binary path (not this shell's argv)
while read -r pid cmd; do
  case "$cmd" in
    *"/Z-universal.app/Contents/MacOS/Z-universal"*)
      kill "$pid" 2>/dev/null || true
      echo "Stopped leftover Z-universal (PID $pid)."
      ;;
  esac
done < <(ps -ax -o pid=,command=)

echo "Done."
