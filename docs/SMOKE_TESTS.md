# Smoke tests

Optional checks for people working on patches. Not required to play.

```bash
./scripts/test-smoke.sh
```

With a local game install under `game/Pokemon TGOM 4.2.3/`, more checks run (map data, scripts, overlays). Without it, tooling and Ruby shims are still exercised.

In-engine smoke (mkxp boots, writes a result file, exits) lives in `game-overlay/zz_smoke_boot.kawariki.rb`. The `zz_` prefix is so the hook runs after `utilities_fix` and `safety_net`.

```bash
TGOM_SMOKE=1 ./scripts/play.sh
```

Result: `logs/smoke_boot_result.txt` when that path is available.

A check is a pass only if it returns literal `true`. Skipped or unrun paths (for example “no bag yet”) are failures. The bag check constructs a `PokemonBag` and stores a Potion; it does not wait for New Game.

After changing overlays or patches, run `./scripts/setup-game.sh` before in-engine smoke. `play.sh` recopies overlays only when `mkxp.json` is missing.

Players normally just run `./scripts/play.sh`. Set `TGOM_VERBOSE=1` to print the mkxp log tail after launch.
