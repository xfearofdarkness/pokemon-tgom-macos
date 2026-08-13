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
- Stock macOS `bash`, `curl`, and `unzip` — no Homebrew, Python, or Xcode to play

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

### Controls

| Action  | Keys              |
|---------|-------------------|
| Move    | Arrow keys        |
| Confirm | Z / Enter / Space |
| Cancel  | X / Esc           |

## Layout

```text
patches/        Preload shims and Kawariki ports
game-overlay/   Runtime fixes applied into the game folder
scripts/        Setup and launch
docs/           Development notes
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
| Display      | Window and fullscreen scaling |
| Input        | Native mkxp key handling |
| Fonts        | Bundled Power Green family |
| Ruby         | 1.8-era Essentials APIs on modern MRI |
| Game content | Bag helpers, intro pictures, missing-map guards |

## Development

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md). Local game trees are gitignored.

## Credits

- **Pokémon This Gym of Mine** — original authors and distributors  
- **mkxp-z** / launcher builds and Kawariki-style ports — respective maintainers  
- **Pokémon** — trademark of Nintendo / Creatures Inc. / GAME FREAK  

Unofficial project. Obtain the game from its authors. Provided as-is, without warranty.
