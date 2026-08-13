#!/usr/bin/env bash
# Shared paths for Pokemon This Gym of Mine on macOS (mkxp-z)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export TGOM_ROOT="$ROOT"
export TGOM_GAME="$ROOT/game/Pokemon TGOM 4.2.3"
export TGOM_LOGS="$ROOT/logs"
export MKXP_APP="${MKXP_APP:-$HOME/Library/Application Support/RPGM-Launcher/Z-universal.app}"
export MKXP_BIN="${MKXP_BIN:-$MKXP_APP/Contents/MacOS/Z-universal}"
export TGOM_SOUNDFONT="${TGOM_SOUNDFONT:-$HOME/Library/Application Support/RPGM-Launcher/GMGSx.SF2}"

tg_open_game_dir() {
  mkdir -p "$TGOM_ROOT/game"
  open "$TGOM_ROOT/game" 2>/dev/null || true
}

tg_missing_game_help() {
  echo "The game files are not at:" >&2
  echo "  $TGOM_GAME" >&2
  echo >&2
  echo "Extract Pokémon This Gym of Mine 4.2.3 into that folder" >&2
  echo "(you should see Game.exe and Data/Scripts.rxdata)." >&2
  echo "See game/README.md — this repo does not include the game." >&2
  tg_open_game_dir
}

# Newest errorlog.txt from the game tree → logs/errorlog-latest.txt
tg_copy_errorlog() {
  mkdir -p "$TGOM_LOGS"
  local src="" f
  for f in "$TGOM_GAME/errorlog.txt" "$TGOM_GAME/Game.rxdata.errorlog.txt"; do
    if [[ -f "$f" ]]; then
      if [[ -z "$src" || "$f" -nt "$src" ]]; then
        src="$f"
      fi
    fi
  done
  if [[ -n "$src" ]]; then
    cp "$src" "$TGOM_LOGS/errorlog-latest.txt"
    return 0
  fi
  return 1
}
