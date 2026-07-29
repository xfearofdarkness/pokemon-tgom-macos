#!/usr/bin/env bash
# Apply macOS/mkxp overlays onto a locally installed TGOM game tree.
# Does not download the game — place it under game/Pokemon TGOM 4.2.3/ first.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/env.sh"

OVERLAY="$TGOM_ROOT/game-overlay"
GAME="$TGOM_GAME"
SUPPORT="$HOME/Library/Application Support/RPGM-Launcher"

if [[ ! -f "$GAME/Data/Scripts.rxdata" ]]; then
  echo "Game not found at:" >&2
  echo "  $GAME" >&2
  echo >&2
  echo "Extract Pokémon This Gym of Mine 4.2.3 there, then re-run." >&2
  echo "See game/README.md" >&2
  exit 1
fi

if [[ ! -d "$OVERLAY" ]]; then
  echo "Missing game-overlay/ in repo." >&2
  exit 1
fi

echo "Applying overlays → $GAME"
# Runtime Kawariki user scripts (cwd = game dir when mkxp starts)
shopt -s nullglob
for f in "$OVERLAY"/*; do
  base="$(basename "$f")"
  cp "$f" "$GAME/$base"
  echo "  + $base"
done

# Gender-select portraits: introBoy/Girl look correct as Show Picture assets
pic="$GAME/Graphics/Pictures"
if [[ -f "$pic/introBoy.png" && -f "$pic/introGirl.png" ]]; then
  cp "$pic/introBoy.png" "$pic/trainer000.png"
  cp "$pic/introGirl.png" "$pic/trainer001.png"
  echo "  + Pictures/trainer000|001.png ← introBoy|Girl"
fi

# Optional Map001 coordinate fix (safe if already applied)
if [[ -f "$GAME/Data/Map001.rxdata" ]]; then
  ruby "$TGOM_ROOT/scripts/patch-map001-gender.rb" "$GAME/Data/Map001.rxdata" || true
fi

# Game.ini (CRLF) + mkxp.json
export TGOM_GAME SUPPORT TGOM_ROOT
python3 - <<'PY'
from pathlib import Path
import json, os

game = Path(os.environ["TGOM_GAME"])
support = Path.home() / "Library/Application Support/RPGM-Launcher"
root = Path(os.environ["TGOM_ROOT"])

ini = (
    "[Game]\r\n"
    "Library=RGSS104E.dll\r\n"
    "Scripts=Data\\Scripts.rxdata\r\n"
    "Title=Pokemon This Gym of Mine\r\n"
    "RTP1=\r\n"
    "RTP2=\r\n"
    "RTP3=\r\n"
)
(game / "Game.ini").write_bytes(ini.encode("utf-8"))
print("  + Game.ini (CRLF)")

cfg = {
    "gameFolder": str(game),
    "rgssVersion": 1,
    "defScreenW": 512,
    "defScreenH": 384,
    "fixedAspectRatio": True,
    "integerScalingActive": False,
    "integerScalingLastMile": False,
    "winResizable": True,
    "smoothScaling": 0,
    "smoothScalingDown": 0,
    "vsync": True,
    "fullscreen": False,
    "anyAltToggleFS": True,
    "windowTitle": "Pokemon This Gym of Mine",
    "midiSoundFont": str(support / "GMGSx.SF2"),
    "solidFonts": [
        "Power Green", "Power Clear", "Power Green Narrow", "Power Green Small",
        "Power Red and Blue", "Power Red and Green",
        "Arial", "Arial Narrow",
    ],
    "fontSub": [
        "Arial Narrow>Power Green Narrow",
        "Helvetica>Power Green",
        "Pokemon Emerald>Power Green",
        "Pokemon Emerald Narrow>Power Green Narrow",
        "Pokemon Emerald Small>Power Green Small",
        "Pokemon DP>Power Clear",
        "Pokemon RS>Power Red and Blue",
        "Pokemon FireLeaf>Power Red and Green",
    ],
    "preloadScript": [
        str(root / "patches" / "early_compat.rb"),
        str(support / "kawariki" / "preload.rb"),
        str(root / "patches" / "input_fix.rb"),
    ],
}
text = json.dumps(cfg, indent=2) + "\n"
(game / "mkxp.json").write_text(text)
app = support / "Z-universal.app/Contents/Game"
if app.parent.is_dir():
    app.mkdir(parents=True, exist_ok=True)
    (app / "mkxp.json").write_text(text)
print("  + mkxp.json")
PY

echo "Done. Run: ./scripts/test-smoke.sh && ./scripts/play.sh"
