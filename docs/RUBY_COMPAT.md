# Ruby 1.8 (RGSS) → Ruby 3/4 (mkxp-z) compatibility

Pokémon Essentials / RPG Maker XP was written for **Ruby 1.8.7** inside RGSS.  
This project runs under **mkxp-z** with modern MRI (here: Ruby 3/4).

## Layers

| Layer | File | When loaded |
|-------|------|-------------|
| Kawariki / project `ruby18` | `patches/ruby18.rb` → `kawariki/libs/ruby18.rb` | Via `early_compat` preload |
| sprintf shim | `patches/early_compat.rb` | First `preloadScript` entry |
| Game script replace | `patches/dummyPSystem_Utilities.rb` | Kawariki patches `PSystem_Utilities` |
| Boot safety nets | `utilities_fix.kawariki.rb`, etc. | After scripts load |

Offline checks: `./scripts/test-smoke.sh`.

## Breaking changes that matter for PE

### Critical (fixed or shimmed)

| 1.8 behavior | Modern Ruby | Symptom | Mitigation |
|--------------|-------------|---------|------------|
| `s[0]` → **Fixnum** byte | `s[0]` → **String** | `sprintf("%02x", s[0])` ArgumentError | `early_compat` sprintf/`%` shim |
| `sprintf("%d", nil)` often coerced | TypeError | Crash on bad format args | sprintf shim (`nil` → `0`) |
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

### Known hotspots in TGOM scripts (audit)

| Pattern | Where | Risk under Ruby 3 |
|---------|-------|-------------------|
| `sprintf('%%%02x', s[0])` | `Sockets` URL-encode | **High** — fixed by sprintf shim |
| `Thread.critical` | `BitmapCache`, `Audio` | **High** without polyfill |
| `ObjectSpace` / finalizers | `BitmapCache`, resizer | Medium — works if critical polyfilled |
| `File.exists?` | `Compiler_PBS` | High only if recompiling PBS |
| `.chr` high bytes | `FileTests`, `PSystem_Utilities` UTF helpers | Medium — chr shim |
| `Win32API` / sockets DLL | many | Expected — Kawariki stubs / limited net |
| `when 1:` colon form | mostly comments / normal `when 1;` | Low in this build |
| `Hash#select` return type | various | Low if not treating result as Array of pairs only |
| Encoding / UTF-8 default | path + text | Usually OK with binary pack/unpack |

### Lower risk / already fine

- `String#each_line` / `IO#each_line` — still valid  
- `Proc.new { }` — still valid  
- `?\n` character literals — now Strings; `String#index(?\n)` still works  
- `pack` / `unpack` — fine for Win32 buffers  
- Most `sprintf("%03d", int)` paths — fine  

## Design choice: shims vs rewriting `Scripts.rxdata`

We prefer **runtime shims** (preload) over mass-editing `Data/Scripts.rxdata` so:

1. Updates to game data stay mergeable  
2. Behavior matches “RGSS-ish” expectations globally  
3. Smoke tests can assert the failure modes without playing the intro  

Surgical map/data fixes (e.g. gender picture coords) stay as data patches when they are content bugs, not language bugs.

## How to re-audit

```bash
# Extend patterns in an ad-hoc scanner, or:
./scripts/test-smoke.sh

# Manual: inflate Scripts and grep for Fixnum, exists?, sprintf + [0], Thread.critical, etc.
```

When adding new PE plugins, watch for:

1. String byte indexing used as integers  
2. `sprintf` / `%` with non-Integer numeric formats  
3. Removed 1.8 APIs listed above  
4. Win32-only DLLs (need Kawariki stubs or disable feature)  

## References

- Pokémon Essentials mkxp-z / Ruby 3 dual-compat notes (PokeCommunity, Maruno issues)  
- Ruby 1.9+ encoding and `String#[ ]` semantics  
- Ruby 3.2 `File.exists?` removal  
