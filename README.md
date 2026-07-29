# TGOM on macOS (mkxp-z)

Unofficial **macOS / Apple Silicon** compatibility stack for  
**Pokémon This Gym of Mine 4.2.3** (RPG Maker XP / Pokémon Essentials ~18).

Uses **[mkxp-z](https://github.com/mkxp-z/mkxp-z)** (Metal) + Kawariki-style patches instead of Wine.

> **This repository does not include the game.**  
> Fangame assets and Pokémon IP stay off GitHub. You supply TGOM 4.2.3 locally  
> (see [`game/README.md`](game/README.md)).

## Quick start

```bash
# 1) Engine + Kawariki (once)
./scripts/setup-mkxpz.sh

# 2) Install the game yourself
#    Extract TGOM 4.2.3 to:  game/Pokemon TGOM 4.2.3/

# 3) Apply macOS overlays into that folder
./scripts/setup-game.sh

# 4) Sanity-check (works partially without game; full checks with game)
./scripts/test-smoke.sh

# 5) Play
./scripts/play.sh
```

Fenster einfach über die normalen macOS-Bedienelemente schließen.

### Controls

| Action  | Keys                 |
|---------|----------------------|
| Move    | Arrow keys           |
| Confirm | **Z** / Enter / Space |
| Cancel  | **X** / Esc          |

## What’s in this repo

```text
patches/          Ruby 1.8→3 shims, Win32API, Essentials utilities port
game-overlay/     *.kawariki.rb runtime fixes copied into the game folder
scripts/          setup-mkxpz / setup-game / play / smoke / map patch
docs/             RUBY_COMPAT.md and notes
game/README.md    where to put TGOM (game data is gitignored)
```

Installed outside the repo by `setup-mkxpz.sh`:

- `~/Library/Application Support/RPGM-Launcher/Z-universal.app`
- `…/kawariki/` ports
- `…/GMGSx.SF2` MIDI soundfont

## What the overlays fix

| Area | Fix |
|------|-----|
| Display | 512×384 framebuffer + window scaling |
| Input | Native mkxp keys (no Win32 `GetAsyncKeyState`) |
| Fonts | Skip Windows font installer; Power Green |
| Ruby 1.8→3 | `sprintf`/`s[0]`, `Thread.critical`, `File.exists?`, … |
| Bag / items | Essentials 18 `ItemStorageHelper` (no PE17 `POCKETAUTOSORT`) |
| Forms | `pbGetSpeciesFromFSpecies` etc. |
| Intro gender | Picture coordinates + optional portrait swap |
| Empty charsets | No `EISDIR` on `Graphics/Characters/` |

Details: [`docs/RUBY_COMPAT.md`](docs/RUBY_COMPAT.md).

## Development

```bash
# After editing patches/
./scripts/setup-mkxpz.sh
./scripts/setup-game.sh    # if game is present
./scripts/test-smoke.sh
```

Do **not** commit anything under `game/Pokemon TGOM 4.2.3/` — `.gitignore` blocks it.

## Credits & legal

- **Game:** Pokémon This Gym of Mine — original authors / their distribution channels  
- **Engine:** mkxp-z / m5kro launcher builds + Kawariki-style ports  
- **Pokémon** is a trademark of Nintendo / Creatures / GAME FREAK  

This project is an **unofficial launcher & compatibility layer** only.  
You must obtain the game legally from its authors. No warranty.
