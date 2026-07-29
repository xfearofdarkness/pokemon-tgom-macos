#!/usr/bin/env bash
# Fast offline smoke tests — no intro, no game window required.
# Usage: ./scripts/test-smoke.sh
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/env.sh"

echo "TGOM smoke tests (offline, ~1s)"
echo "Game: $TGOM_GAME"
echo

ruby "$TGOM_ROOT/scripts/test-smoke.rb"
status=$?

if [[ $status -eq 0 ]]; then
  echo
  echo "Tip: for real play after a green smoke test:"
  echo "  ./scripts/play.sh"
else
  echo
  echo "Smoke failed — fix patches before grinding the intro." >&2
fi
exit $status
