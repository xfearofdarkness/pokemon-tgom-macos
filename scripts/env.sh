#!/usr/bin/env bash
# Shared paths for Pokemon This Gym of Mine on macOS (mkxp-z)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export TGOM_ROOT="$ROOT"
export TGOM_GAME="$ROOT/game/Pokemon TGOM 4.2.3"
export TGOM_LOGS="$ROOT/logs"
export MKXP_APP="${MKXP_APP:-$HOME/Library/Application Support/RPGM-Launcher/Z-universal.app}"
export MKXP_BIN="${MKXP_BIN:-$MKXP_APP/Contents/MacOS/Z-universal}"
