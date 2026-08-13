# Game install location

This directory is where a local copy of **Pokémon This Gym of Mine 4.2.3** lives.

The public repository ships tooling and patches only. Game assets stay on your machine and are gitignored.

## Expected layout

After extraction:

```text
game/Pokemon TGOM 4.2.3/Game.exe
game/Pokemon TGOM 4.2.3/Data/Scripts.rxdata
game/Pokemon TGOM 4.2.3/Graphics/
…
```

Obtain **4.2.3** from the original TGOM release (for example via PokeCommunity or the authors’ download).

Saves are `Game.rxdata` next to these game files (same folder as `Game.exe`).

## Apply tooling

From the repository root:

```bash
./scripts/play.sh
```

That installs the engine if needed and applies overlays when `mkxp.json` is missing. After changing files in `game-overlay/` or `patches/`, run `./scripts/setup-game.sh` from the repo root again — `play.sh` will not recopy them if `mkxp.json` already exists.

`setup-game.sh` copies `game-overlay/` into the game folder, writes `Game.ini` and `mkxp.json`, and applies small local fixes (intro portraits / Map001 gender pictures when needed).
