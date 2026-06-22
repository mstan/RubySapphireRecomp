# RubySapphireRecomp

Static recompilation of *Pokémon Ruby* and *Pokémon Sapphire* (GBA),
built on top of [`gbarecomp`](../gbarecomp).

One repo hosts **both** games as separate native targets that share one
source tree and one engine — the
[Sonic3AndKnucklesRecomp](../../segagenesisrecomp/Sonic3AndKnucklesRecomp)
pattern (an `add_gba_variant()` CMake function emits one executable per
game). Ruby and Sapphire are the same engine built from one decomp
(`pret/pokeruby`, different `GAME_VERSION` target), so they belong
together exactly as FireRed + LeafGreen do in `../FireRedRecomp`.

These are **recomps**, not ports or decomps. Only symbol metadata from
[`pret/pokeruby`](https://github.com/pret/pokeruby) enters the repo.

## Layout

```
RubySapphireRecomp/
  CMakeLists.txt              two add_gba_variant() targets
  src/main.cpp                variant-agnostic entry (builtins via compile-defs)
  variants/ruby/             ┐ each: game.toml + config/ + symbols/
  variants/sapphire/         ┘       + generated/ + roms/
  tools/import_decomp_symbols/, tools/verify_rom_hash/
```

| Target          | Game     | ROM rev | sha1       | Debug port |
|-----------------|----------|---------|------------|------------|
| `RubyRecomp`    | Ruby     | rev1    | `610b96a9…`| 19872      |
| `SapphireRecomp`| Sapphire | rev1    | `4722efb8…`| 19882      |

Both on-disk USA dumps are **rev1**, so the variants target the
`ruby_rev1` / `sapphire_rev1` decomp builds.

## Build & run

Builds against the live `../gbarecomp` checkout on `main`.

```sh
# 1. (one-time) symbols from byte-matching pokeruby WSL builds
#    (../_gen3_build_symbols.sh) → tools/import_decomp_symbols/.
# 2. recompile each variant → variants/<v>/generated/:
../gbarecomp/build/gba_recompile.exe \
    --rom variants/ruby/roms/ruby_usa.gba \
    --config variants/ruby/symbols/ruby_usa.toml \
    --out variants/ruby/generated
#    (repeat for sapphire)
# 3. build (MSYS2 mingw64 + Ninja, from PowerShell):
cmake -G Ninja -S . -B build
cmake --build build --target RubyRecomp -j
cmake --build build --target SapphireRecomp -j
# 4. run (BIOS + ROM both hash-verify):
./build/RubyRecomp.exe
./build/SapphireRecomp.exe
```

## Status

Scaffolded against gbarecomp `main` @ `a4e22d7`. Both ROMs hash-verified,
symbols imported (11,455 functions each), recompiled. Bring-up follows the
same milestone ladder as FireRed (see `CLAUDE.md`).
