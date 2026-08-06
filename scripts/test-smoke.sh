#!/usr/bin/env bash
# Contributor offline checks. Not part of normal play setup.
# See docs/SMOKE_TESTS.md
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/env.sh"

echo "TGOM smoke tests (offline)"
echo "Game: $TGOM_GAME"
echo

ruby "$TGOM_ROOT/scripts/test-smoke.rb"
exit $?
