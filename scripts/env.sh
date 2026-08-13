#!/usr/bin/env bash
# Shared paths for Pokemon This Gym of Mine on macOS (mkxp-z).
# Sourced by the other scripts. Callers should already have `set -euo pipefail`.
set -euo pipefail

_tg_src="${BASH_SOURCE[0]:-$0}"
_tg_script_dir="$(cd "$(dirname "$_tg_src")" && pwd)"
ROOT="$(cd "${_tg_script_dir}/.." && pwd)"

if [[ -z "$ROOT" || "$ROOT" != /* || ! -f "$ROOT/scripts/play.sh" ]]; then
  echo "Could not resolve the repository root from ${_tg_script_dir}." >&2
  exit 1
fi

: "${HOME:?HOME is not set}"
if [[ "$HOME" != /* ]]; then
  echo "HOME must be an absolute path." >&2
  exit 1
fi

export TGOM_ROOT="$ROOT"
export TGOM_GAME="$ROOT/game/Pokemon TGOM 4.2.3"
export TGOM_LOGS="$ROOT/logs"
export TGOM_SUPPORT="${TGOM_SUPPORT:-$HOME/Library/Application Support/RPGM-Launcher}"
export MKXP_APP="${MKXP_APP:-$TGOM_SUPPORT/Z-universal.app}"
export MKXP_BIN="${MKXP_BIN:-$MKXP_APP/Contents/MacOS/Z-universal}"
export TGOM_SOUNDFONT="${TGOM_SOUNDFONT:-$TGOM_SUPPORT/GMGSx.SF2}"

tg_require_abs() {
  local name="$1" val="$2"
  if [[ -z "$val" || "$val" != /* ]]; then
    echo "$name is not an absolute path: ${val:-<empty>}" >&2
    exit 1
  fi
}

tg_require_abs TGOM_ROOT "$TGOM_ROOT"
tg_require_abs TGOM_GAME "$TGOM_GAME"
tg_require_abs TGOM_LOGS "$TGOM_LOGS"
tg_require_abs TGOM_SUPPORT "$TGOM_SUPPORT"
tg_require_abs MKXP_APP "$MKXP_APP"
tg_require_abs MKXP_BIN "$MKXP_BIN"
tg_require_abs TGOM_SOUNDFONT "$TGOM_SOUNDFONT"

# Prefer stock macOS binaries so a Homebrew/PATH shim cannot change flags.
tg_bin() {
  local name="$1" p
  for p in "/usr/bin/$name" "/bin/$name"; do
    if [[ -x "$p" ]]; then
      printf '%s' "$p"
      return 0
    fi
  done
  p="$(command -v "$name" 2>/dev/null || true)"
  if [[ -n "$p" && -x "$p" ]]; then
    printf '%s' "$p"
    return 0
  fi
  echo "Missing required command: $name" >&2
  return 1
}

# Real Ruby only. /usr/bin/ruby without CLT/Xcode is a stub that opens a
# "install developer tools" dialog — never exec that for players.
tg_ruby() {
  local p
  if [[ -n "${RUBY:-}" && -x "${RUBY}" ]]; then
    printf '%s' "$RUBY"
    return 0
  fi
  p="$(command -v ruby 2>/dev/null || true)"
  if [[ -n "$p" && "$p" != /usr/bin/ruby && -x "$p" ]]; then
    printf '%s' "$p"
    return 0
  fi
  if [[ -x /usr/bin/ruby ]] && xcode-select -p >/dev/null 2>&1; then
    printf '%s' /usr/bin/ruby
    return 0
  fi
  return 1
}

tg_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

tg_atomic_write() {
  local dest="$1" tmp
  tmp="${dest}.tmp.$$"
  cat > "$tmp" || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$dest"
}

tg_open_game_dir() {
  mkdir -p "$TGOM_ROOT/game"
  if [[ -x /usr/bin/open ]]; then
    /usr/bin/open "$TGOM_ROOT/game" 2>/dev/null || true
  fi
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
