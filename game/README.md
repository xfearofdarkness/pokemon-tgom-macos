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

## Apply tooling

From the repository root:

```bash
./scripts/setup-mkxpz.sh
./scripts/setup-game.sh
./scripts/play.sh
```

`setup-game.sh` copies `game-overlay/` into the game folder, writes `Game.ini` and `mkxp.json`, and applies small local fixes (intro portraits / Map001 gender pictures when needed).
