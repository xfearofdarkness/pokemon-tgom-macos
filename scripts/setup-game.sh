#!/usr/bin/env bash
# Apply macOS/mkxp overlays onto a locally installed TGOM game tree.
# Place the game under game/Pokemon TGOM 4.2.3/ first.
set -euo pipefail

_tg_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [[ ! -f "$_tg_dir/env.sh" ]]; then
  echo "Missing $_tg_dir/env.sh" >&2
  exit 1
fi
# shellcheck source=env.sh
source "$_tg_dir/env.sh"

OVERLAY="$TGOM_ROOT/game-overlay"
GAME="$TGOM_GAME"
SUPPORT="$TGOM_SUPPORT"

tg_require_abs OVERLAY "$OVERLAY"
tg_require_abs GAME "$GAME"
tg_require_abs SUPPORT "$SUPPORT"

if [[ ! -f "$GAME/Data/Scripts.rxdata" ]]; then
  tg_missing_game_help
  exit 1
fi

if [[ ! -d "$OVERLAY" ]]; then
  echo "Missing game-overlay/ in repo." >&2
  exit 1
fi

if [[ ! -w "$GAME" ]]; then
  echo "Game folder is not writable: $GAME" >&2
  exit 1
fi

echo "Applying overlays → $GAME"
# Runtime Kawariki user scripts (cwd = game dir when mkxp starts)
shopt -s nullglob
copied=0
for f in "$OVERLAY"/*; do
  [[ -f "$f" ]] || continue
  base="$(basename "$f")"
  [[ -n "$base" && "$base" != "." && "$base" != ".." ]] || continue
  cp "$f" "$GAME/$base"
  echo "  + $base"
  copied=$((copied + 1))
done
if [[ "$copied" -eq 0 ]]; then
  echo "game-overlay/ had no files to copy." >&2
  exit 1
fi

# Gender-select portraits: introBoy/Girl look correct as Show Picture assets
pic="$GAME/Graphics/Pictures"
if [[ -f "$pic/introBoy.png" && -f "$pic/introGirl.png" ]]; then
  cp "$pic/introBoy.png" "$pic/trainer000.png"
  cp "$pic/introGirl.png" "$pic/trainer001.png"
  echo "  + Pictures/trainer000|001.png ← introBoy|Girl"
fi

# Optional Map001 coordinate fix, only if a real Ruby is already there.
# Never call the macOS /usr/bin/ruby stub (it prompts for Xcode tools).
_tg_ruby="$(tg_ruby || true)"
if [[ -n "${_tg_ruby}" && -f "$GAME/Data/Map001.rxdata" && -f "$TGOM_ROOT/scripts/patch-map001-gender.rb" ]]; then
  "$_tg_ruby" "$TGOM_ROOT/scripts/patch-map001-gender.rb" "$GAME/Data/Map001.rxdata" || true
fi

{
  printf '%s\r\n' \
    '[Game]' \
    'Library=RGSS104E.dll' \
    'Scripts=Data\Scripts.rxdata' \
    'Title=Pokemon This Gym of Mine' \
    'RTP1=' \
    'RTP2=' \
    'RTP3='
} | tg_atomic_write "$GAME/Game.ini"
echo "  + Game.ini (CRLF)"

_game_j="$(tg_json_escape "$GAME")"
_sf_j="$(tg_json_escape "$TGOM_SOUNDFONT")"
_early_j="$(tg_json_escape "$TGOM_ROOT/patches/early_compat.rb")"
_kaw_j="$(tg_json_escape "$SUPPORT/kawariki/preload.rb")"
_input_j="$(tg_json_escape "$TGOM_ROOT/patches/input_fix.rb")"

tg_atomic_write "$GAME/mkxp.json" <<EOF
{
  "gameFolder": "${_game_j}",
  "rgssVersion": 1,
  "defScreenW": 512,
  "defScreenH": 384,
  "fixedAspectRatio": true,
  "integerScalingActive": false,
  "integerScalingLastMile": false,
  "winResizable": true,
  "smoothScaling": 0,
  "smoothScalingDown": 0,
  "vsync": true,
  "fullscreen": false,
  "anyAltToggleFS": true,
  "windowTitle": "Pokemon This Gym of Mine",
  "midiSoundFont": "${_sf_j}",
  "solidFonts": [
    "Power Green", "Power Clear", "Power Green Narrow", "Power Green Small",
    "Power Red and Blue", "Power Red and Green",
    "Arial", "Arial Narrow"
  ],
  "fontSub": [
    "Arial Narrow>Power Green Narrow",
    "Helvetica>Power Green",
    "Pokemon Emerald>Power Green",
    "Pokemon Emerald Narrow>Power Green Narrow",
    "Pokemon Emerald Small>Power Green Small",
    "Pokemon DP>Power Clear",
    "Pokemon RS>Power Red and Blue",
    "Pokemon FireLeaf>Power Red and Green"
  ],
  "preloadScript": [
    "${_early_j}",
    "${_kaw_j}",
    "${_input_j}"
  ]
}
EOF

if [[ -d "$SUPPORT/Z-universal.app/Contents" ]]; then
  mkdir -p "$SUPPORT/Z-universal.app/Contents/Game"
  cp "$GAME/mkxp.json" "$SUPPORT/Z-universal.app/Contents/Game/mkxp.json"
fi
echo "  + mkxp.json"

echo "Done. Start with: ./scripts/play.sh"
