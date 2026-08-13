#!/usr/bin/env bash
# Download mkxp-z (Z-universal), MIDI soundfont, Kawariki + project ports.
# Then, if the game tree is present, apply game-overlay via setup-game.sh.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/env.sh"

SUPPORT="$HOME/Library/Application Support/RPGM-Launcher"
mkdir -p "$SUPPORT" "$TGOM_ROOT/patches" "$TGOM_LOGS"

if [[ ! -x "$SUPPORT/Z-universal.app/Contents/MacOS/Z-universal" ]]; then
  echo "Downloading mkxp-z (Z-universal)..."
  curl -L --fail -o /tmp/Z-universal.zip \
    "https://github.com/m5kro/mkxp-z/releases/download/launcher/Z-universal.zip"
  rm -rf "$SUPPORT/Z-universal.app"
  unzip -q -o /tmp/Z-universal.zip -d "$SUPPORT"
  xattr -dr com.apple.quarantine "$SUPPORT/Z-universal.app" 2>/dev/null || true
  chmod +x "$SUPPORT/Z-universal.app/Contents/MacOS/Z-universal"
  echo "Installed: $SUPPORT/Z-universal.app"
else
  echo "mkxp-z already installed."
fi

if [[ ! -f "$SUPPORT/GMGSx.SF2" ]]; then
  echo "Downloading MIDI soundfont GMGSx.SF2..."
  if ! curl -L --fail -o "$SUPPORT/GMGSx.SF2" \
    "https://musical-artifacts.com/artifacts/841/GMGSx.SF2"; then
    rm -f "$SUPPORT/GMGSx.SF2"
    echo "Warning: soundfont download failed." >&2
    echo "Music may be silent until GMGSx.SF2 exists at:" >&2
    echo "  $SUPPORT/GMGSx.SF2" >&2
  fi
fi

if [[ ! -f "$SUPPORT/kawariki/preload.rb" ]]; then
  echo "Downloading Kawariki patches..."
  curl -L --fail -o /tmp/kawariki.zip \
    "https://github.com/m5kro/mkxp-z/releases/download/launcher/kawariki.zip"
  unzip -q -o /tmp/kawariki.zip -d "$SUPPORT"
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
  echo "Game tree found — applying overlays..."
  "$TGOM_ROOT/scripts/setup-game.sh"
else
  echo
  echo "No game at: $TGOM_GAME"
  echo "Extract TGOM 4.2.3 there (see game/README.md), then ./scripts/play.sh"
fi

echo "Done. Engine ready. Start with: ./scripts/play.sh"
