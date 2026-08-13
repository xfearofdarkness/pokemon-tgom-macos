#!/usr/bin/env bash
# Contributor offline checks. Not part of normal play setup.
# See docs/DEVELOPMENT.md
set -euo pipefail

_tg_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [[ ! -f "$_tg_dir/env.sh" ]]; then
  echo "Missing $_tg_dir/env.sh" >&2
  exit 1
fi
# shellcheck source=env.sh
source "$_tg_dir/env.sh"

_tg_ruby="$(tg_ruby || true)"
if [[ -z "${_tg_ruby}" ]]; then
  echo "Smoke tests need a real Ruby." >&2
  echo "macOS /usr/bin/ruby is a stub unless Xcode or Command Line Tools are installed." >&2
  echo "Install those, or put another ruby on PATH (or set RUBY=...)." >&2
  exit 1
fi

if [[ ! -f "$TGOM_ROOT/scripts/test-smoke.rb" ]]; then
  echo "Missing $TGOM_ROOT/scripts/test-smoke.rb" >&2
  exit 1
fi

echo "TGOM smoke tests (offline)"
echo "Game: $TGOM_GAME"
echo

"$_tg_ruby" "$TGOM_ROOT/scripts/test-smoke.rb"
