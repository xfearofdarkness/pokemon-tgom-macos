# TGOM on macOS

Unofficial compatibility layer for **[Pokémon This Gym of Mine](https://www.pokecommunity.com/) 4.2.3** on Apple Silicon / macOS.

Built on **[mkxp-z](https://github.com/mkxp-z/mkxp-z)** (Metal) and Kawariki-style runtime patches for RPG Maker XP / Pokémon Essentials ~18.

Game data is **not** part of this repository. Install TGOM 4.2.3 separately under [`game/`](game/README.md).

## Status: experimental

This repo patches the engine and common Ruby/Windows failure modes so the fan game can start on macOS. It does **not** certify the game. Crashes can still happen in content nobody has exercised, including cases a single playthrough would miss.

Bug reports are welcome. Include `logs/mkxpz_run.log` and, if it exists, `logs/errorlog-latest.txt`.

## Requirements

- macOS (Apple Silicon tested)
- TGOM **4.2.3** from the original release
- Network access once for engine / soundfont download

## Setup

Extract TGOM 4.2.3 to:

```text
game/Pokemon TGOM 4.2.3/
```

Then from the repo root:

```bash
./scripts/play.sh
```

That downloads mkxp-z if needed, applies overlays if needed, and launches. Close the game window with the usual macOS controls.

If the game folder is missing, Finder opens `game/` so you can drop the extract there.

Contributor-only split steps: `./scripts/setup-mkxpz.sh` then `./scripts/setup-game.sh`.

### Controls

| Action     | Keys / where |
|------------|----------------|
| Move       | Arrow keys |
| Confirm    | Z / Enter / Space |
| Cancel     | X / Esc |
| Fullscreen | Alt+Enter, in-game **Options → Screen Size → Full**, or the macOS green button |

S / M / L in that same Options menu are 1× / 2× / 3× of 512×384, capped to what fits this Mac. That is the game’s Screen Size setting, not a macOS display preference.

## Layout

```text
patches/        Preload shims and Kawariki ports
game-overlay/   Runtime fixes applied into the game folder
scripts/        Setup and launch
docs/           Technical notes
game/           Local game install (gitignored; see game/README.md)
logs/           Launch log and last copied game errorlog
```

`setup-mkxpz.sh` installs under `~/Library/Application Support/RPGM-Launcher/`:

- `Z-universal.app` — mkxp-z
- `kawariki/` — preload and ports
- `GMGSx.SF2` — MIDI soundfont

## Compatibility work

| Area        | Notes |
|-------------|--------|
| Display     | 512×384 logical. Windowed is the largest integer N× that fits this Mac (centered). Fullscreen fills 4:3 (side bars on widescreen); integer lock stays off so the green button is not a postage stamp |
| Input       | Native mkxp key handling |
| Fonts       | Bundled Power Green family; installer dialog suppressed |
| Ruby        | 1.8-era Essentials APIs on modern MRI ([docs/RUBY_COMPAT.md](docs/RUBY_COMPAT.md)) |
| Bag / items | Essentials 18 storage helpers |
| Forms       | fSpecies helpers restored where the utilities port omits them |
| Intro       | Gender-select picture placement |
| Characters  | Empty charset paths handled safely |
| Missing maps | Leftover Essentials IDs refused instead of crashing |

## Development

After changing patches or overlays, recopy them. `play.sh` only runs `setup-game.sh` when `mkxp.json` is missing:

```bash
./scripts/setup-mkxpz.sh
./scripts/setup-game.sh
```

Offline regression checks (optional, for contributors):

```bash
./scripts/test-smoke.sh
```

Details: [docs/SMOKE_TESTS.md](docs/SMOKE_TESTS.md).

`TGOM_VERBOSE=1 ./scripts/play.sh` prints the mkxp log tail after launch.

Local game trees are gitignored.

## Credits

- **Pokémon This Gym of Mine** — original authors and distributors  
- **mkxp-z** / launcher builds and Kawariki-style ports — respective maintainers  
- **Pokémon** — trademark of Nintendo / Creatures Inc. / GAME FREAK  

Unofficial project. Obtain the game from its authors. Provided as-is, without warranty.
