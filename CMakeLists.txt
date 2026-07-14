cmake_minimum_required(VERSION 3.20)
project(RubySapphireRecomp C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ─────────────────────────────────────────────────────────────────────
# RubySapphireRecomp — Pokémon Ruby + Pokémon Sapphire (GBA).
#
# Two games sharing one engine (pokeruby decomp), hosted as separate
# native targets — the Sonic3AndKnucklesRecomp pattern. Per-variant data
# lives under variants/<name>/ (game.toml + config/ + symbols/ +
# generated/ + roms/).
#
#   Target             Game               ROM rev   Debug port
#   RubyRecomp         Pokémon Ruby       rev1      19872
#   SapphireRecomp     Pokémon Sapphire   rev1      19882
# ─────────────────────────────────────────────────────────────────────

set(GBARECOMP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../gbarecomp"
    CACHE PATH "Path to the gbarecomp platform-core checkout")

if(NOT EXISTS "${GBARECOMP_ROOT}/CMakeLists.txt")
    message(FATAL_ERROR
        "GBARECOMP_ROOT does not point to a gbarecomp checkout:\n"
        "  ${GBARECOMP_ROOT}\n"
        "Point it at the engine checkout (default ../gbarecomp) or pass\n"
        "-DGBARECOMP_ROOT=<path> at configure time.")
endif()

add_subdirectory("${GBARECOMP_ROOT}" gbarecomp_build EXCLUDE_FROM_ALL)

add_executable(verify_rom_hash tools/verify_rom_hash/main.cpp)

# add_gba_variant(<target> <name> <port> <win_title> <game_name> <sha1>)
function(add_gba_variant TARGET NAME PORT WIN_TITLE GAME_NAME ROM_SHA1)
    set(VARIANT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/variants/${NAME}")
    file(GLOB VARIANT_GENERATED CONFIGURE_DEPENDS
        "${VARIANT_DIR}/generated/*.c"
        "${VARIANT_DIR}/generated/*.cpp")

    add_executable(${TARGET} src/main.cpp ${VARIANT_GENERATED})

    # Keep generated guest translation units at a bounded optimization and
    # debug-info cost. This covers both legacy monolithic output and the
    # deterministic recompiled_NNN.cpp shards emitted by current gbarecomp.
    set(VARIANT_RECOMPILED ${VARIANT_GENERATED})
    list(FILTER VARIANT_RECOMPILED INCLUDE REGEX
        "/recompiled(_[0-9]+)?\\.cpp$")
    if(VARIANT_RECOMPILED)
        set_source_files_properties(${VARIANT_RECOMPILED} PROPERTIES
            COMPILE_OPTIONS "-O1;-g0")
    endif()

    target_include_directories(${TARGET} PRIVATE
        "${GBARECOMP_ROOT}/src/armv4t"
        "${GBARECOMP_ROOT}/src/gba"
        "${GBARECOMP_ROOT}/src/runtime"
        "${GBARECOMP_ROOT}/src/debug"
        src)

    target_link_libraries(${TARGET} PRIVATE
        "-Wl,--start-group"
        gbarecomp_runtime
        gbarecomp_debug
        gbarecomp_gba
        gbarecomp_armv4t
        "-Wl,--end-group")

    target_compile_definitions(${TARGET} PRIVATE
        GBARECOMP_DEFAULT_DEBUG_PORT=${PORT}
        GBARECOMP_WINDOW_TITLE="${WIN_TITLE}"
        GBARECOMP_DEFAULT_GAME_CONFIG="variants/${NAME}/game.toml"
        GBARECOMP_BUILTIN_NAME="${GAME_NAME}"
        GBARECOMP_BUILTIN_SHA1="${ROM_SHA1}")

    # 256 MB stack reserve — see FireRedRecomp/CMakeLists.txt rationale.
    if(MSVC)
        target_link_options(${TARGET} PRIVATE /STACK:268435456)
    elseif(MINGW OR WIN32)
        target_link_options(${TARGET} PRIVATE -Wl,--stack,268435456)
    endif()
endfunction()

# Ruby     — rev1, sha1 610b96a9…
add_gba_variant(RubyRecomp     ruby     19872 "RubyRecomp"
    "Pokemon Ruby (USA)"     "610b96a9c9a7d03d2bafb655e7560ccff1a6d894")

# Sapphire — rev1, sha1 4722efb8…
add_gba_variant(SapphireRecomp sapphire 19882 "SapphireRecomp"
    "Pokemon Sapphire (USA)" "4722efb8cd45772ca32555b98fd3b9719f8e60a9")
