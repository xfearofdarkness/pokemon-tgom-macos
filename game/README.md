# Game data (not in git)

This folder holds **Pokémon This Gym of Mine 4.2.3** after you install it yourself.

The public GitHub repo **does not ship the game** (fangame / Pokémon IP — redistributing the full package is a bad idea).

## Install

1. Get **TGOM 4.2.3** from the original release (e.g. PokeCommunity / the authors’ download).
2. Extract so you have:

   ```text
   game/Pokemon TGOM 4.2.3/Game.exe
   game/Pokemon TGOM 4.2.3/Data/Scripts.rxdata
   game/Pokemon TGOM 4.2.3/Graphics/
   …
   ```

3. From the repo root:

   ```bash
   ./scripts/setup-mkxpz.sh   # engine + Kawariki
   ./scripts/setup-game.sh    # apply macOS overlays into the game folder
   ./scripts/play.sh
   ```

`setup-game.sh` copies `game-overlay/*`, writes `Game.ini` + `mkxp.json`, optionally fixes gender-select pictures/map data, and never uploads your game files.
