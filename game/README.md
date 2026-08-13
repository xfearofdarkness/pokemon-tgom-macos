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

That installs the engine if needed and applies overlays. How overlays, display, and shims work is in [docs/DEVELOPMENT.md](../docs/DEVELOPMENT.md).
