#!/usr/bin/env bash
# Only player-facing command: install engine if needed, then launch.
# Contributor steps stay in setup-mkxpz.sh / setup-game.sh.
set -euo pipefail

_tg_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [[ ! -f "$_tg_dir/env.sh" ]]; then
  echo "Missing $_tg_dir/env.sh" >&2
  exit 1
fi
# shellcheck source=env.sh
source "$_tg_dir/env.sh"
mkdir -p "$TGOM_LOGS"

if [[ ! -x "$MKXP_BIN" ]]; then
  echo "Engine not installed yet. Downloading mkxp-z (once)..."
  "$TGOM_ROOT/scripts/setup-mkxpz.sh"
fi

if [[ ! -x "$MKXP_BIN" ]]; then
  echo "mkxp-z still not found at: $MKXP_BIN" >&2
  echo "Try: ./scripts/setup-mkxpz.sh" >&2
  exit 1
fi

if [[ ! -f "$TGOM_GAME/Data/Scripts.rxdata" ]]; then
  tg_missing_game_help
  exit 1
fi

if [[ ! -f "$TGOM_GAME/mkxp.json" ]]; then
  echo "Applying game overlays..."
  "$TGOM_ROOT/scripts/setup-game.sh"
fi

if [[ -f "$TGOM_LOGS/mkxp.pid" ]]; then
  old="$(tr -d '[:space:]' < "$TGOM_LOGS/mkxp.pid" 2>/dev/null || true)"
  if [[ "$old" =~ ^[0-9]+$ ]] && kill -0 -- "$old" 2>/dev/null; then
    echo "Game already running (PID $old). Bring the window to the front."
    exit 0
  fi
  rm -f "$TGOM_LOGS/mkxp.pid"
fi

# Pokémon Essentials expects Windows-style TEMP (AnimatedBitmap Dir.chdir)
export TMPDIR="${TMPDIR:-/tmp}"
tg_require_abs TMPDIR "$TMPDIR"
export TEMP="${TEMP:-$TMPDIR}"
export TMP="${TMP:-$TMPDIR}"
tg_require_abs TEMP "$TEMP"
mkdir -p "$TEMP"

tg_copy_errorlog >/dev/null || true

: > "$TGOM_LOGS/mkxpz_run.log"
cd "$TGOM_GAME"
"$MKXP_BIN" "$TGOM_GAME" >> "$TGOM_LOGS/mkxpz_run.log" 2>&1 &
echo "$!" > "$TGOM_LOGS/mkxp.pid"

sleep 3
pid="$(tr -d '[:space:]' < "$TGOM_LOGS/mkxp.pid" 2>/dev/null || true)"
if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 -- "$pid" 2>/dev/null; then
  echo "Running. Close the window to quit."
  echo "Log: $TGOM_LOGS/mkxpz_run.log"
  if [[ "${TGOM_VERBOSE:-}" == "1" ]]; then
    tail -n 40 "$TGOM_LOGS/mkxpz_run.log" || true
  fi
else
  echo "The game exited before a window stayed open." >&2
  echo "Last lines of $TGOM_LOGS/mkxpz_run.log:" >&2
  tail -n 30 "$TGOM_LOGS/mkxpz_run.log" >&2 || true
  if tg_copy_errorlog; then
    echo "Copied game error log to $TGOM_LOGS/errorlog-latest.txt" >&2
  fi
  echo "Include that log (and errorlog-latest.txt if present) in a bug report." >&2
  exit 1
fi
