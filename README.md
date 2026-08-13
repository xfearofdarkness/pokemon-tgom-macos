# TGOM on macOS

Unofficial compatibility layer for **[Pokémon This Gym of Mine](https://www.pokecommunity.com/) 4.2.3** on Apple Silicon / macOS.

Built on **[mkxp-z](https://github.com/mkxp-z/mkxp-z)** (Metal) and Kawariki-style runtime patches for RPG Maker XP / Pokémon Essentials ~18.

Install TGOM 4.2.3 separately under [`game/`](game/README.md).

## Status: experimental

The game can start on macOS. Later content can still crash or behave oddly, including cases a single playthrough would miss.

Bug reports are welcome. Include `logs/mkxpz_run.log` and, if it exists, `logs/errorlog-latest.txt`.

## Requirements

- macOS (Apple Silicon tested)
- TGOM **4.2.3** from the original release
- Network access for the first launch

## Setup

Extract TGOM 4.2.3 to:

```text
game/Pokemon TGOM 4.2.3/
```

Then from the repo root:

```bash
./scripts/play.sh
```

That installs the engine, applies overlays, and launches. Close the game window with the usual macOS controls.

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
game/           Local game install (see game/README.md)
logs/           Launch log and last copied game errorlog
```

`setup-mkxpz.sh` installs the engine under `~/Library/Application Support/RPGM-Launcher/` (`Z-universal.app`, `kawariki/`, `GMGSx.SF2`).

## Development

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Credits

- **Pokémon This Gym of Mine**: original authors and distributors
- **mkxp-z** / launcher builds and Kawariki-style ports: respective maintainers
- **Pokémon**: trademark of Nintendo / Creatures Inc. / GAME FREAK

Unofficial project. Obtain the game from its authors. Provided as-is, without warranty.
