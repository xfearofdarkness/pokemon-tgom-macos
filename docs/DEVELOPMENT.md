# Development

How the compatibility layer is structured and how to change it.

## Requirements

Smoke tests need Ruby. Set `RUBY` to an interpreter, or use one from Command Line Tools / Homebrew.

The game folder and `TGOM_SUPPORT` (default `~/Library/Application Support/RPGM-Launcher`) must be writable. First engine install needs network access. A failed soundfont download is a warning; mkxp-z and Kawariki failing to download is a hard error.

Optional overrides (absolute paths): `TGOM_SUPPORT`, `MKXP_APP`, `MKXP_BIN`, `TGOM_SOUNDFONT`, `RUBY`.

## Workflow

```bash
./scripts/setup-mkxpz.sh   # engine, Kawariki, soundfont; copies ports into kawariki/
./scripts/setup-game.sh    # copy game-overlay/ and write Game.ini + mkxp.json
./scripts/play.sh          # launch
./scripts/test-smoke.sh    # offline checks
```

`play.sh` runs `setup-mkxpz.sh` if `MKXP_BIN` is missing, and `setup-game.sh` if the game has no `mkxp.json`. It does not recopy overlays on every launch.

| After you edit | Run |
|----------------|-----|
| `game-overlay/` | `setup-game.sh` |
| `patches/dummyPSystem_Utilities.rb`, `ruby18.rb`, `Win32API.rb` | `setup-mkxpz.sh` (copies into `kawariki/`) |
| `patches/early_compat.rb`, `input_fix.rb` | next launch (`mkxp.json` already points at these files) |

`TGOM_VERBOSE=1 ./scripts/play.sh` prints the last lines of the mkxp log after launch. `play.sh` copies the newest `errorlog.txt` or `Game.rxdata.errorlog.txt` from the game folder to `logs/errorlog-latest.txt` at launch, and again if the process exits within a few seconds.

Engine files go in `TGOM_SUPPORT`: `Z-universal.app`, `kawariki/`, `GMGSx.SF2`.

## How a boot is assembled

Runtime shims are preferred over rewriting `Data/Scripts.rxdata`. The Map001 gender-picture patch is a data edit, applied only when a real Ruby is available.

`mkxp.json` `preloadScript` order: `patches/early_compat.rb`, then Kawariki `preload.rb`, then `patches/input_fix.rb`. Kawariki then loads `*.kawariki.rb` from the game folder (cwd) after `Scripts.rxdata`, in filename order.

| Layer | File | When |
|-------|------|------|
| `ruby18` | `patches/ruby18.rb`, copied to `kawariki/libs/ruby18.rb` | Required from `early_compat` (support copy first, then the file next to `early_compat.rb`) |
| sprintf, MRI snapshot, TEMP | `patches/early_compat.rb` (`TGMriCompat`) | First `preloadScript` |
| Win32 stubs | `patches/Win32API.rb`, copied to `kawariki/libs/Win32API.rb` | Kawariki load |
| `PSystem_Utilities` replace | `patches/dummyPSystem_Utilities.rb`, copied to `kawariki/ports/` | Kawariki port replace |
| Input | `input_fix.kawariki.rb` (real hook). `patches/input_fix.rb` only logs that preload ran. | Overlay after scripts |
| Boot nets | `fonts_fix`, `map_fix`, `safety_net`, `utilities_fix` | After scripts |
| Display | `display_fix.kawariki.rb` | After scripts |
| In-engine smoke | `zz_smoke_boot.kawariki.rb` (last by name) | Always loads; checks run only if `TGOM_SMOKE=1` |

`setup-game.sh` also writes `Game.ini`, copies `introBoy`/`introGirl` to `trainer000`/`trainer001` when those pictures exist, and may patch Map001 coordinates.

`TGMriCompat.restore!` runs from `safety_net` on boot, after PE scripts have clobbered MRI methods.

## Display

Logical size is 512×384. `mkxp.json` sets `fixedAspectRatio` on and integer scaling off.

On boot, `display_fix` sizes the window to the largest integer multiple of 512×384 that fits the Finder desktop bounds minus a 64×120 inset, then centers it. If desktop size cannot be read, it uses 2×.

In-game **Options → Screen Size** is the game’s setting:

| Screen Size | Meaning |
|-------------|---------|
| S / M / L   | 1× / 2× / 3×, capped to the same max as boot |
| Full        | Fullscreen 4:3 fill (`Graphics.fullscreen = true`) |

Alt+Enter also toggles mkxp fullscreen (`anyAltToggleFS`). Integer scaling stays off so 512×384 grows uniformly until one side of the monitor is filled (side bars on a 16:9 screen).

The macOS green button only resizes the window. `display_fix` applies the 4:3 fill if `Graphics.fullscreen` becomes true; if the OS never sets that flag, fill mode does not change.

## Ruby 1.8 / Windows shims

Pokémon Essentials / RPG Maker XP was written for Ruby 1.8.7 inside RGSS. mkxp-z runs modern MRI (3/4).

| 1.8 behavior | Modern Ruby | Symptom | Mitigation |
|--------------|-------------|---------|------------|
| `s[0]` → **Fixnum** byte | `s[0]` → **String** | `sprintf("%02x", s[0])` ArgumentError | `early_compat` sprintf/`%` shim |
| `sprintf("%d", nil)` often coerced | TypeError | Crash on bad format args | sprintf shim (`nil` → `0`) |
| `str[i] == 0xNN` (byte) | `str[i]` is String | GIF magic, BOM, trailing `/` checks always fail | `String#==` single-byte vs Integer |
| `ENV["TEMP"]+"\\file"` | Unix TEMP + backslash | wrong path (`/tmp\\file`) | `String#+` joins as `File.join` on Unix |
| `Thread.critical` | Removed | BitmapCache WeakRef NameError | `ruby18` polyfill |
| `Object#type` | Removed | NoMethodError | `ruby18` → `class` |
| `Hash#index(val)` | Renamed `#key` | NoMethodError | `ruby18` alias |
| `Array#choice` | Removed | NoMethodError | `ruby18` → `sample` |
| `Array#nitems` | Removed | NoMethodError | `ruby18` polyfill |
| `methods.include?("x")` | Symbols only | false negatives | `ruby18` string-friendly arrays |
| `File.exists?` / `Dir.exists?` | Removed 3.2+ | NoMethodError (compiler/PBS) | `ruby18` → `exist?` |
| `Fixnum` / `Bignum` | Merged into `Integer` | NameError if referenced | constants aliased to `Integer` |
| `(0x80).chr` without encoding | May RangeError | Binary string build fails | `Integer#chr` → ASCII-8BIT for 0..255 |
| JSON regex `\x80-\x9f` without `/n` | invalid multibyte escape | Boot crash | E18 dummy + `/n` fix |
| Empty `character_name` path | `EISDIR` on `Characters/` | New Game crash | `map_fix` |
| Stale PE17 bag API | `POCKETAUTOSORT` | Item ball crash | E18 dummy + `utilities_fix` |
| PE `String#bytesize` → `size` | Bytes vs characters | Binary/`String#==` shim wrong | `TGMriCompat` snapshot + restore |
| PE `"".capitalize` | `nil.upcase` | Name/text crash | empty-safe capitalize restore |
| PE `Array#first` no-arg only | `first(n)` ArgumentError | Latent crash | restore MRI `first`/`last` |
| Missing Map052–075 / 87 | leftover Essentials IDs | Fly / heal / roam `load_data` | `safety_net` refuses any missing `MapXXX.rxdata` |
| `File.open(directory)` | `EISDIR` on macOS | charset / bitmap | `safeExists?` treats dirs as missing |
| `.PNG` vs `.png` | case-sensitive volume | Bag / PC / Town Map | `pbResolveBitmap` also tries `.PNG` / `.gif` / `.GIF` |
| `RegOpenKeyExA` / registry | stub used to return 0 (success) | PE thought a key opened | Advapi32 open/query return 1 (fail) |
| `SHGetSpecialFolderLocation` | stub 0 looked like success | bad Windows folder paths | Shell32 stubs fail |
| `GetUserNameA` missing | empty / crash | trainer / save name | Advapi32 writes `$USER`, else `$LOGNAME`, else `Player` |
| Unknown `Win32API.new` | used to return `nil` | `if api.call != 0` TypeError | default stub returns `0` |

Hotspots still in TGOM scripts: `Sockets` URL-encode `sprintf('%%%02x', s[0])`, `Thread.critical` in BitmapCache/Audio, `File.exists?` in Compiler_PBS, high-byte `.chr` in FileTests, Win32 sockets. Lower risk: `when 1:` colon form, `Hash#select` return type, UTF-8 default encoding. Still fine: `each_line`, `Proc.new`, `?\n`, `pack`/`unpack`, normal `sprintf("%03d", int)`.

When adding PE plugins, watch for string byte indexing used as integers, `sprintf`/`%` with non-Integer numeric formats, removed 1.8 APIs above, Win32-only DLLs, map/fly/roam IDs whose `Data/MapXXX.rxdata` is not in the TGOM tree, and PE `Ruby Utilities` redefining `String#bytesize` / `Array#first`.

To re-audit: extend `./scripts/test-smoke.sh`, or inflate `Scripts.rxdata` and grep for `Fixnum`, `exists?`, `sprintf` + `[0]`, `Thread.critical`.

## Smoke tests

```bash
./scripts/test-smoke.sh
```

With a local game under `game/Pokemon TGOM 4.2.3/`, more checks run (map data, scripts, overlays). Without it, tooling and Ruby shims still run; map and Scripts scans are skipped. Window-scale assertions live in `scripts/test-smoke.rb`.

In-engine smoke is `game-overlay/zz_smoke_boot.kawariki.rb`. The `zz_` name puts it last among overlays.

```bash
TGOM_SMOKE=1 ./scripts/play.sh
```

`TGOM_SMOKE=true` is also accepted. Result is written to `logs/smoke_boot_result.txt` when that directory exists, otherwise next to the game or `/tmp`. Recopy overlays with `setup-game.sh` first if you changed `zz_smoke_boot` or the hooks it calls.

A check is a pass only if it returns literal `true`. Skipped or unrun paths (for example “no bag yet”) are failures. The bag check constructs a `PokemonBag` and stores a Potion; it does not wait for New Game.
