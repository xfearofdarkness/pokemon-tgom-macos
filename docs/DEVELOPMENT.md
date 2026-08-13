# Development

How the compatibility layer is structured and how to change it.

## Requirements

Smoke tests need Ruby. Set `RUBY` to an interpreter, or use one from Command Line Tools / Homebrew.

The game folder and `TGOM_SUPPORT` (default `~/Library/Application Support/RPGM-Launcher`) must be writable. First engine install needs network access.

Optional overrides (absolute paths): `TGOM_SUPPORT`, `MKXP_APP`, `MKXP_BIN`, `TGOM_SOUNDFONT`, `RUBY`.

## Workflow

```bash
./scripts/setup-mkxpz.sh   # engine, Kawariki, soundfont (once)
./scripts/setup-game.sh    # copy overlays + write mkxp.json
./scripts/play.sh          # launch (bootstraps the two above if needed)
./scripts/test-smoke.sh    # optional offline checks
```

`play.sh` recopies overlays only when `game/Pokemon TGOM 4.2.3/mkxp.json` is missing. After editing `patches/` or `game-overlay/`, run `setup-game.sh` again. `setup-mkxpz.sh` is only required when the engine install itself changed.

`TGOM_VERBOSE=1 ./scripts/play.sh` prints the mkxp log tail after launch. Failed boots copy the newest game `errorlog.txt` to `logs/errorlog-latest.txt`.

Engine files live under `~/Library/Application Support/RPGM-Launcher/` (`Z-universal.app`, `kawariki/`, `GMGSx.SF2`).

## How a boot is assembled

We prefer **runtime shims** over rewriting `Data/Scripts.rxdata`, so game updates stay mergeable and RGSS-ish APIs apply globally. Surgical data patches (intro portrait coords) stay as data when they are content bugs, not language bugs.

| Layer | File | When |
|-------|------|------|
| Kawariki / `ruby18` | `patches/ruby18.rb` → `kawariki/libs/ruby18.rb` | Via `early_compat` |
| sprintf, MRI snapshot, TEMP | `patches/early_compat.rb` (`TGMriCompat`) | First `preloadScript` |
| Win32 stubs | `patches/Win32API.rb` → `kawariki/libs/Win32API.rb` | Kawariki load |
| Game script replace | `patches/dummyPSystem_Utilities.rb` | Replaces `PSystem_Utilities` |
| Input | `patches/input_fix.rb`, `input_fix.kawariki.rb` | Preload + overlay |
| Boot nets | `utilities_fix`, `safety_net`, `map_fix`, `fonts_fix` | After Scripts.rxdata |
| Display | `display_fix.kawariki.rb` | After Scripts.rxdata |
| In-engine smoke | `zz_smoke_boot.kawariki.rb` | Last overlay; only if `TGOM_SMOKE=1` |

`setup-game.sh` also writes `Game.ini`, copies intro portraits to `trainer000`/`trainer001`, and may patch Map001 gender-picture coordinates.

## Display

Logical size is 512×384. mkxp scales that framebuffer to the OS window. `mkxp.json` keeps `fixedAspectRatio` on and integer scaling off.

On boot the window is the largest integer N× of 512×384 that fits the desktop (room for the menu bar and Dock), then centered.

In-game **Options → Screen Size** is the game’s setting, not a macOS display preference:

| Screen Size | Meaning |
|-------------|---------|
| S / M / L   | 1× / 2× / 3×, capped to what fits this Mac |
| Full        | Fullscreen 4:3 fill |

Fullscreen is Screen Size → Full, Alt+Enter, or the macOS green button. Integer scaling stays off so 512×384 grows uniformly until one side of the monitor is filled (side bars on 16:9). Integer lock in a wide window is a postage-stamp picture.

The green button only resizes the window; it does not call `Graphics.fullscreen=`. `display_fix` watches `Graphics.fullscreen` on update so OS fullscreen still gets the 4:3 fill.

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
| Missing Map052–075 / 87 | leftover Essentials IDs | Fly / heal / roam `load_data` | `safety_net` refuses missing rxdata |
| `File.open(directory)` | `EISDIR` on macOS | charset / bitmap | `safeExists?` treats dirs as missing |
| `.PNG` vs `.png` | case-sensitive volume | Bag / PC / Town Map | `pbResolveBitmap` tries `.PNG` |
| `RegOpenKeyExA` / registry | stub used to return 0 (success) | PE thought a key opened | Advapi32 open/query return 1 (fail) |
| `SHGetSpecialFolderLocation` | stub 0 looked like success | bad Windows folder paths | Shell32 stubs fail |
| `GetUserNameA` missing | empty / crash | trainer / save name | Advapi32 writes `$USER` |
| Unknown `Win32API.new` | used to return `nil` | `if api.call != 0` TypeError | default stub returns `0` |

Hotspots still in TGOM scripts: `Sockets` URL-encode `sprintf('%%%02x', s[0])`, `Thread.critical` in BitmapCache/Audio, `File.exists?` in Compiler_PBS, high-byte `.chr` in FileTests, Win32 sockets. Lower risk: `when 1:` colon form, `Hash#select` return type, UTF-8 default encoding. Still fine: `each_line`, `Proc.new`, `?\n`, `pack`/`unpack`, normal `sprintf("%03d", int)`.

When adding PE plugins, watch for string byte indexing used as integers, `sprintf`/`%` with non-Integer numeric formats, removed 1.8 APIs above, Win32-only DLLs, map/fly/roam IDs whose `Data/MapXXX.rxdata` is not in the TGOM tree, and PE `Ruby Utilities` redefining `String#bytesize` / `Array#first`.

To re-audit: extend `./scripts/test-smoke.sh`, or inflate `Scripts.rxdata` and grep for `Fixnum`, `exists?`, `sprintf` + `[0]`, `Thread.critical`.

## Smoke tests

```bash
./scripts/test-smoke.sh
```

With a local game under `game/Pokemon TGOM 4.2.3/`, more checks run (map data, scripts, overlays). Without it, tooling and Ruby shims are still exercised. Window-scale assertions live in `scripts/test-smoke.rb`.

In-engine smoke (mkxp boots, writes a result file, exits) is `game-overlay/zz_smoke_boot.kawariki.rb`. The `zz_` prefix is so it runs after `utilities_fix` and `safety_net`.

```bash
TGOM_SMOKE=1 ./scripts/play.sh
```

Result: `logs/smoke_boot_result.txt` when that path is available. Recopy overlays with `setup-game.sh` first if you changed them.

A check is a pass only if it returns literal `true`. Skipped or unrun paths (for example “no bag yet”) are failures. The bag check constructs a `PokemonBag` and stores a Potion; it does not wait for New Game.
