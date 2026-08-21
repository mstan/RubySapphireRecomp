#!/usr/bin/env bash
# import-symbols.sh — build the pinned pret decomp and import its symbols.
#
# Run under WSL. End to end: submodule -> byte-exact ROM -> readelf -> the
# engine's shared importer -> symbols/. Nothing here needs root.
#
# The submodule at third_party/<decomp> is the PROVENANCE record: it pins the
# exact upstream revision whose build reproduces this project's ROM. It is not
# the build sandbox — agbcc installs INTO a decomp tree, and a Windows-side
# build over /mnt is slow, so the script maintains a WSL-side clone checked out
# to the submodule's pinned SHA and builds there. Same split MKSC uses
# (see MarioKartSuperCircuitRecomp/tools/decomp/provision.sh).
#
# The gate is each target's ROM SHA-1 against the identity this project
# declares. A decomp revision that does not reproduce our exact ROM produces
# symbols that are wrong for it, so a mismatch aborts instead of importing.
#
# Usage: tools/decomp/import-symbols.sh [--force-clone]
set -euo pipefail

# ── per-project configuration ───────────────────────────────────────
DECOMP_NAME="pokeruby"
DECOMP_URL="https://github.com/pret/pokeruby"
# make target | elf | rom | variant dir | program id | expected rom sha1
TARGETS=(
  "ruby_rev1|pokeruby_rev1.elf|pokeruby_rev1.gba|ruby|AXVE|610b96a9c9a7d03d2bafb655e7560ccff1a6d894"
  "sapphire_rev1|pokesapphire_rev1.elf|pokesapphire_rev1.gba|sapphire|AXPE|4722efb8cd45772ca32555b98fd3b9719f8e60a9"
)
PROGRAM_NAME_ruby="Pokemon Ruby Version (USA)"
PROGRAM_NAME_sapphire="Pokemon Sapphire Version (USA)"
# Runtime IWRAM code copies, expressed as symbol pairs so the importer resolves
# the addresses itself. RSE and Emerald export the IRQ entry as `IntrMain`;
# FRLG spells it `intr_main`.
CODE_COPY_PAIRS=(
  "IntrMain_Buffer=IntrMain:arm"
  "SoundMainRAM_Buffer=SoundMainRAM:thumb"
)

# ── locations ───────────────────────────────────────────────────────
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SANDBOX="${DECOMP_SANDBOX:-$HOME/${DECOMP_NAME}-build}"
AGBCC_SRC="${AGBCC_SRC:-}"
J="${J:-$(nproc)}"
IMPORTER="$REPO/gbarecomp/tools/symbol_import/import_decomp_symbols.py"

say() { printf '==> %s\n' "$*"; }

[ -f "$IMPORTER" ] || {
    echo "missing $IMPORTER — is the gbarecomp submodule checked out?" >&2
    exit 1
}

# The pinned revision, read from the submodule rather than hardcoded here, so
# bumping the decomp is a submodule update and nothing else.
PINNED="$(git -C "$REPO" ls-tree HEAD "third_party/$DECOMP_NAME" | awk '{print $3}')"
[ -n "$PINNED" ] || { echo "third_party/$DECOMP_NAME is not a submodule" >&2; exit 1; }
say "pinned $DECOMP_NAME revision: $PINNED"

# ── 1. build sandbox at the pinned revision ─────────────────────────
if [ "${1:-}" = "--force-clone" ]; then rm -rf "$SANDBOX"; fi
if [ ! -d "$SANDBOX/.git" ]; then
    say "cloning $DECOMP_URL into $SANDBOX"
    git clone --quiet "$DECOMP_URL" "$SANDBOX"
fi
git -C "$SANDBOX" fetch --quiet origin
git -C "$SANDBOX" checkout --quiet --detach "$PINNED"

# ── 2. agbcc ────────────────────────────────────────────────────────
if [ ! -x "$SANDBOX/tools/agbcc/bin/old_agbcc" ]; then
    if [ -z "$AGBCC_SRC" ]; then
        for c in "$HOME"/*/tools/agbcc; do
            [ -x "$c/bin/old_agbcc" ] && AGBCC_SRC="$c" && break
        done
    fi
    if [ -z "$AGBCC_SRC" ]; then
        say "building pret/agbcc (no existing install found)"
        rm -rf "$HOME/agbcc-src"
        git clone --quiet https://github.com/pret/agbcc "$HOME/agbcc-src"
        (cd "$HOME/agbcc-src" && ./build.sh >/dev/null && ./install.sh "$SANDBOX")
    else
        say "installing agbcc from $AGBCC_SRC"
        mkdir -p "$SANDBOX/tools/agbcc"
        cp -r "$AGBCC_SRC/." "$SANDBOX/tools/agbcc/"
    fi
fi

# ── 3. build + gate + import, per target ────────────────────────────
cd "$SANDBOX"
for row in "${TARGETS[@]}"; do
    IFS='|' read -r target elf rom variant id want <<<"$row"
    say "building $target"
    nice -n 10 make -j"$J" "$target" >/dev/null

    got="$(sha1sum "$rom" | cut -d' ' -f1)"
    if [ "$got" != "$want" ]; then
        echo "SHA-1 MISMATCH for $target: built $got, expected $want" >&2
        echo "This decomp revision does not reproduce our ROM; refusing to" >&2
        echo "import symbols that would be wrong for it." >&2
        exit 1
    fi
    say "$target sha1 $got OK"

    out="$REPO/variants/$variant/symbols"
    mkdir -p "$out"
    readelf -sW "$elf" > "$out/${DECOMP_NAME}_${variant}_syms.txt"
    readelf -SW "$elf" > "$out/${DECOMP_NAME}_${variant}_sections.txt"
    echo "$PINNED" > "$out/${DECOMP_NAME}_revision.txt"

    name_var="PROGRAM_NAME_${variant}"
    ccargs=()
    for p in "${CODE_COPY_PAIRS[@]}"; do ccargs+=(--code-copy-pair "$p"); done

    say "importing $id"
    python3 "$IMPORTER" \
        --id "$id" --name "${!name_var}" \
        --syms     "$out/${DECOMP_NAME}_${variant}_syms.txt" \
        --sections "$out/${DECOMP_NAME}_${variant}_sections.txt" \
        --rom      "$REPO/variants/$variant/roms/${variant}_usa.gba" \
        "${ccargs[@]}" \
        --out "$out"
done

say "done. Next: regenerate and rebuild, e.g."
say "  gba_recompile --rom variants/<v>/roms/<v>_usa.gba \\"
say "      --config variants/<v>/game.toml \\"
say "      --config variants/<v>/symbols/<ID>_symbols.toml \\"
say "      [--config variants/<v>/symbols/<ID>_reviewed_seeds.toml] \\"
say "      --symbols variants/<v>/symbols/imported_symbols.tsv \\"
say "      --data-symbols variants/<v>/symbols/imported_data_symbols.tsv \\"
say "      --out variants/<v>/generated --max-functions 65536"
