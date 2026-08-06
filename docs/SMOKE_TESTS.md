# Smoke tests

Optional checks for people working on patches. Not required to play.

```bash
./scripts/test-smoke.sh
```

With a local game install under `game/Pokemon TGOM 4.2.3/`, more checks run (map data, scripts, overlays). Without it, tooling and Ruby shims are still exercised.

In-engine smoke (mkxp boots, writes a result file, exits):

```bash
TGOM_SMOKE=1 ./scripts/play.sh
```

Result: `logs/smoke_boot_result.txt` when that path is available.
