# TGOM on macOS

Unofficial compatibility layer for **[Pokémon This Gym of Mine](https://www.pokecommunity.com/) 4.2.3** on Apple Silicon / macOS.

Built on **[mkxp-z](https://github.com/mkxp-z/mkxp-z)** (Metal) and Kawariki-style runtime patches for RPG Maker XP / Pokémon Essentials ~18.

Game data is **not** part of this repository. Install TGOM 4.2.3 separately under [`game/`](game/README.md).

## Status: experimental

This project is early. Title and early game play on Apple Silicon with mkxp-z; later content may still crash or behave oddly.

Bug reports and pull requests are welcome.

## Requirements

- macOS (Apple Silicon tested)
- TGOM **4.2.3** from the original release
- Network access once for engine / soundfont download

## Setup

```bash
./scripts/setup-mkxpz.sh
```

Place the extracted game at:

```text
game/Pokemon TGOM 4.2.3/
```

Then:

```bash
./scripts/setup-game.sh
./scripts/play.sh
```

Close the game window with the usual macOS controls.

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
docs/           Technical notes
game/           Local game install (gitignored; see game/README.md)
```

`setup-mkxpz.sh` installs under `~/Library/Application Support/RPGM-Launcher/`:

- `Z-universal.app` — mkxp-z
- `kawariki/` — preload and ports
- `GMGSx.SF2` — MIDI soundfont

## Compatibility work

| Area        | Notes |
|-------------|--------|
| Display     | 512×384 logical resolution, OS window scaling |
| Input       | Native mkxp key handling |
| Fonts       | Bundled Power Green family; installer dialog suppressed |
| Ruby        | 1.8-era Essentials APIs on modern MRI ([docs/RUBY_COMPAT.md](docs/RUBY_COMPAT.md)) |
| Bag / items | Essentials 18 storage helpers |
| Forms       | fSpecies helpers restored where the utilities port omits them |
| Intro       | Gender-select picture placement |
| Characters  | Empty charset paths handled safely |

## Development

After changing patches or overlays:

```bash
./scripts/setup-mkxpz.sh
./scripts/setup-game.sh
```

Offline regression checks (optional, for contributors):

```bash
./scripts/test-smoke.sh
```

Details: [docs/SMOKE_TESTS.md](docs/SMOKE_TESTS.md).

Local game trees are gitignored.

## Credits

- **Pokémon This Gym of Mine** — original authors and distributors  
- **mkxp-z** / launcher builds and Kawariki-style ports — respective maintainers  
- **Pokémon** — trademark of Nintendo / Creatures Inc. / GAME FREAK  

Unofficial project. Obtain the game from its authors. Provided as-is, without warranty.
