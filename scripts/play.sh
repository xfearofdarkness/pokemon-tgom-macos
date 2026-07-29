#!/usr/bin/env bash
# Preferred launcher: native mkxp-z (Metal) — best path on Apple Silicon
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/env.sh"
mkdir -p "$TGOM_LOGS"

if [[ ! -x "$MKXP_BIN" ]]; then
  echo "mkxp-z not found at: $MKXP_BIN" >&2
  echo "Run: ./scripts/setup-mkxpz.sh" >&2
  exit 1
fi

if [[ ! -f "$TGOM_GAME/Data/Scripts.rxdata" ]]; then
  echo "Game not installed at: $TGOM_GAME" >&2
  echo "See game/README.md — extract TGOM 4.2.3, then ./scripts/setup-game.sh" >&2
  exit 1
fi

if [[ ! -f "$TGOM_GAME/mkxp.json" ]]; then
  echo "Overlays missing — run: ./scripts/setup-game.sh" >&2
  exit 1
fi

if [[ -f "$TGOM_LOGS/mkxp.pid" ]]; then
  old="$(cat "$TGOM_LOGS/mkxp.pid" 2>/dev/null || true)"
  if [[ -n "${old:-}" ]] && kill -0 "$old" 2>/dev/null; then
    echo "Game already running (PID $old). Bring the window to the front."
    exit 0
  fi
fi

# Pokémon Essentials expects Windows-style TEMP (AnimatedBitmap Dir.chdir)
export TMPDIR="${TMPDIR:-/tmp}"
export TEMP="${TEMP:-$TMPDIR}"
export TMP="${TMP:-$TMPDIR}"
mkdir -p "$TEMP"

echo "Starting Pokemon This Gym of Mine via mkxp-z (Metal)..."
echo "TEMP=$TEMP"
echo "Log: $TGOM_LOGS/mkxpz_run.log"
: > "$TGOM_LOGS/mkxpz_run.log"
cd "$TGOM_GAME"
"$MKXP_BIN" "$TGOM_GAME" >> "$TGOM_LOGS/mkxpz_run.log" 2>&1 &
echo $! > "$TGOM_LOGS/mkxp.pid"
sleep 3
if kill -0 "$(cat "$TGOM_LOGS/mkxp.pid")" 2>/dev/null; then
  echo "Running (PID $(cat "$TGOM_LOGS/mkxp.pid"))."
  # Show only the interesting end of the log
  tail -n 40 "$TGOM_LOGS/mkxpz_run.log"
else
  echo "Process exited early. Log:" >&2
  cat "$TGOM_LOGS/mkxpz_run.log" >&2
  exit 1
fi
