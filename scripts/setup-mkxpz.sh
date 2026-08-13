#!/usr/bin/env bash
# Download mkxp-z (Z-universal), MIDI soundfont, Kawariki + project ports.
# Then, if the game tree is present, apply game-overlay via setup-game.sh.
set -euo pipefail

_tg_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [[ ! -f "$_tg_dir/env.sh" ]]; then
  echo "Missing $_tg_dir/env.sh" >&2
  exit 1
fi
# shellcheck source=env.sh
source "$_tg_dir/env.sh"

SUPPORT="$TGOM_SUPPORT"
tg_require_abs SUPPORT "$SUPPORT"

TG_CURL="$(tg_bin curl)"
TG_UNZIP="$(tg_bin unzip)"
TG_MKTEMP="$(tg_bin mktemp)"

if ! mkdir -p "$SUPPORT" "$TGOM_ROOT/patches" "$TGOM_LOGS"; then
  echo "Cannot create engine/log directories under $SUPPORT or $TGOM_LOGS." >&2
  exit 1
fi

_tg_tmp=""
_tg_cleanup() {
  if [[ -n "${_tg_tmp:-}" && -d "$_tg_tmp" ]]; then
    rm -rf "$_tg_tmp"
  fi
}
trap _tg_cleanup EXIT

_tg_mktemp_dir() {
  local base="${TMPDIR:-/tmp}"
  tg_require_abs TMPDIR "$base"
  "$TG_MKTEMP" -d "${base}/tg-mkxp.XXXXXX"
}

_tg_curl() {
  local url="$1" dest="$2"
  "$TG_CURL" -fL --retry 3 --retry-delay 1 --connect-timeout 30 -o "$dest" "$url"
}

_tg_zip_safe() {
  local zip="$1" names
  names="$("$TG_UNZIP" -Z1 "$zip")"
  if printf '%s\n' "$names" | grep -E -q '(^\.\./|/\.\./|/\.\.$|^\.\.$|^/)'; then
    echo "Refusing zip with unsafe member paths: $zip" >&2
    exit 1
  fi
}

_tg_replace_dir() {
  # Move $1 into $2 only after the new tree is present. Never rm a path we
  # did not just construct from SUPPORT + a fixed name.
  local src="$1" dest="$2" bak
  if [[ "$dest" != "$SUPPORT"/* || "$dest" == "$SUPPORT" || "$dest" == "$SUPPORT/" ]]; then
    echo "Refusing to replace unexpected path: $dest" >&2
    exit 1
  fi
  if [[ ! -e "$src" ]]; then
    echo "Replace source missing: $src" >&2
    exit 1
  fi
  bak="${dest}.bak.$$"
  rm -rf "$bak"
  if [[ -e "$dest" ]]; then
    mv "$dest" "$bak"
  fi
  if ! mv "$src" "$dest"; then
    if [[ -e "$bak" ]]; then
      mv "$bak" "$dest" || true
    fi
    echo "Failed to install $dest" >&2
    exit 1
  fi
  rm -rf "$bak"
}

if [[ ! -x "$SUPPORT/Z-universal.app/Contents/MacOS/Z-universal" ]]; then
  echo "Downloading mkxp-z (Z-universal)..."
  _tg_tmp="$(_tg_mktemp_dir)"
  _tg_curl \
    "https://github.com/m5kro/mkxp-z/releases/download/launcher/Z-universal.zip" \
    "$_tg_tmp/Z-universal.zip"
  if ! "$TG_UNZIP" -tqq "$_tg_tmp/Z-universal.zip" >/dev/null; then
    echo "Downloaded Z-universal.zip failed the zip integrity check." >&2
    exit 1
  fi
  _tg_zip_safe "$_tg_tmp/Z-universal.zip"
  mkdir -p "$_tg_tmp/extract"
  "$TG_UNZIP" -q "$_tg_tmp/Z-universal.zip" -d "$_tg_tmp/extract"
  if [[ ! -d "$_tg_tmp/extract/Z-universal.app/Contents/MacOS" ]]; then
    echo "Z-universal.zip did not contain Z-universal.app." >&2
    exit 1
  fi
  chmod +x "$_tg_tmp/extract/Z-universal.app/Contents/MacOS/Z-universal" 2>/dev/null || true
  if [[ ! -x "$_tg_tmp/extract/Z-universal.app/Contents/MacOS/Z-universal" ]]; then
    echo "Z-universal binary is missing or not executable." >&2
    exit 1
  fi
  _tg_replace_dir "$_tg_tmp/extract/Z-universal.app" "$SUPPORT/Z-universal.app"
  xattr -dr com.apple.quarantine "$SUPPORT/Z-universal.app" 2>/dev/null || true
  echo "Installed: $SUPPORT/Z-universal.app"
  rm -rf "$_tg_tmp"
  _tg_tmp=""
else
  echo "mkxp-z already installed."
fi

if [[ ! -f "$SUPPORT/GMGSx.SF2" ]]; then
  echo "Downloading MIDI soundfont GMGSx.SF2..."
  _tg_tmp="$(_tg_mktemp_dir)"
  if _tg_curl \
    "https://musical-artifacts.com/artifacts/841/GMGSx.SF2" \
    "$_tg_tmp/GMGSx.SF2" \
    && [[ -s "$_tg_tmp/GMGSx.SF2" ]]; then
    sz="$(wc -c < "$_tg_tmp/GMGSx.SF2" | tr -d '[:space:]')"
    if [[ "$sz" =~ ^[0-9]+$ ]] && [[ "$sz" -gt 1000000 ]]; then
      mv "$_tg_tmp/GMGSx.SF2" "$SUPPORT/GMGSx.SF2"
    else
      echo "Warning: soundfont download looked too small (${sz:-0} bytes)." >&2
    fi
  else
    echo "Warning: soundfont download failed." >&2
    echo "Music may be silent until GMGSx.SF2 exists at:" >&2
    echo "  $SUPPORT/GMGSx.SF2" >&2
  fi
  rm -rf "$_tg_tmp"
  _tg_tmp=""
fi

if [[ ! -f "$SUPPORT/kawariki/preload.rb" ]]; then
  echo "Downloading Kawariki patches..."
  _tg_tmp="$(_tg_mktemp_dir)"
  _tg_curl \
    "https://github.com/m5kro/mkxp-z/releases/download/launcher/kawariki.zip" \
    "$_tg_tmp/kawariki.zip"
  if ! "$TG_UNZIP" -tqq "$_tg_tmp/kawariki.zip" >/dev/null; then
    echo "Downloaded kawariki.zip failed the zip integrity check." >&2
    exit 1
  fi
  _tg_zip_safe "$_tg_tmp/kawariki.zip"
  mkdir -p "$_tg_tmp/extract"
  "$TG_UNZIP" -q "$_tg_tmp/kawariki.zip" -d "$_tg_tmp/extract"
  if [[ -f "$_tg_tmp/extract/kawariki/preload.rb" ]]; then
    _tg_replace_dir "$_tg_tmp/extract/kawariki" "$SUPPORT/kawariki"
  elif [[ -f "$_tg_tmp/extract/preload.rb" ]]; then
    _tg_replace_dir "$_tg_tmp/extract" "$SUPPORT/kawariki"
  else
    echo "kawariki.zip did not contain preload.rb." >&2
    exit 1
  fi
  rm -rf "$_tg_tmp"
  _tg_tmp=""
fi

apply_if_present() {
  local src="$1" dst="$2"
  if [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "Applied patch: $(basename "$src")"
  fi
}
apply_if_present "$TGOM_ROOT/patches/dummyPSystem_Utilities.rb" \
  "$SUPPORT/kawariki/ports/dummyPSystem_Utilities.rb"
apply_if_present "$TGOM_ROOT/patches/ruby18.rb" \
  "$SUPPORT/kawariki/libs/ruby18.rb"
apply_if_present "$TGOM_ROOT/patches/Win32API.rb" \
  "$SUPPORT/kawariki/libs/Win32API.rb"

if [[ -f "$TGOM_GAME/Data/Scripts.rxdata" ]]; then
  echo "Game tree found. Applying overlays..."
  "$TGOM_ROOT/scripts/setup-game.sh"
else
  echo
  echo "No game at: $TGOM_GAME"
  echo "Extract TGOM 4.2.3 there (see game/README.md), then ./scripts/play.sh"
fi

echo "Done. Engine ready. Start with: ./scripts/play.sh"
