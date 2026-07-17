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

set(GBARECOMP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/gbarecomp"
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

# add_gba_variant(<target> <name> <port> <win_title> <game_name> <sha1>
#                  <crc32>)
function(add_gba_variant TARGET NAME PORT WIN_TITLE GAME_NAME ROM_SHA1 ROM_CRC32)
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
        GBARECOMP_BUILTIN_SHA1="${ROM_SHA1}"
        GBARECOMP_BUILTIN_CRC32=${ROM_CRC32}
        GBARECOMP_BUILTIN_REGION="USA")

    if(GBAGAME_RECOMP_UI)
        target_link_libraries(${TARGET} PRIVATE game_launcher_ui)
        # Per-variant box art: variants share one build dir, so each stages
        # its own file and points its exe at it (RunOptions.launcher_boxart).
        set(VARIANT_BOXART "${VARIANT_DIR}/launcher/boxart.tga")
        if(EXISTS "${VARIANT_BOXART}")
            add_custom_command(TARGET ${TARGET} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E make_directory
                    $<TARGET_FILE_DIR:${TARGET}>/assets/img
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${VARIANT_BOXART}"
                    $<TARGET_FILE_DIR:${TARGET}>/assets/img/boxart_${NAME}.tga
                VERBATIM)
            target_compile_definitions(${TARGET} PRIVATE
                GBARECOMP_BOXART="assets/img/boxart_${NAME}.tga")
        endif()
    endif()

    # 256 MB stack reserve — see FireRedRecomp/CMakeLists.txt rationale.
    if(MSVC)
        target_link_options(${TARGET} PRIVATE /STACK:268435456)
    elseif(MINGW OR WIN32)
        target_link_options(${TARGET} PRIVATE -Wl,--stack,268435456)
    endif()
endfunction()

# ─────────────────────────────────────────────────────────────────────
# recomp-ui pre-boot launcher (Dear ImGui), consumed as a git submodule
# (junctioned locally to the shared checkout). Isolated in its own
# static lib so recomp-ui's sources + RECOMP_LAUNCHER define never
# touch the giant generated/*.c TU flags — only main.cpp (gated on
# GBAGAME_RECOMP_UI) and launcher_boot.cpp know the launcher exists.
# ─────────────────────────────────────────────────────────────────────
option(GBAGAME_RECOMP_UI "Build the recomp-ui pre-boot launcher" ON)
if(GBAGAME_RECOMP_UI)
    include(${CMAKE_CURRENT_SOURCE_DIR}/recomp-ui/recomp_ui.cmake)
    add_library(game_launcher_ui STATIC src/game_launcher_boot.cpp)
    target_include_directories(game_launcher_ui PRIVATE
        "${GBARECOMP_ROOT}/src/runtime"   # launcher_seam.h + runtime.h
        "${GBARECOMP_ROOT}/src/gba"
        src
    )
    recomp_target_launcher_ui(game_launcher_ui)   # sources, includes, RECOMP_LAUNCHER, asset staging
    find_package(SDL2 REQUIRED)
    target_link_libraries(game_launcher_ui PUBLIC SDL2::SDL2)
    if(WIN32)
        target_link_libraries(game_launcher_ui PUBLIC opengl32)
    endif()
    set_property(SOURCE src/main.cpp APPEND PROPERTY COMPILE_DEFINITIONS GBAGAME_RECOMP_UI)
endif()

# Ruby     — rev1, sha1 610b96a9…
add_gba_variant(RubyRecomp     ruby     19872 "RubyRecomp"
    "Pokemon Ruby (USA)"     "610b96a9c9a7d03d2bafb655e7560ccff1a6d894" 0x61641576)

# Sapphire — rev1, sha1 4722efb8…
add_gba_variant(SapphireRecomp sapphire 19882 "SapphireRecomp"
    "Pokemon Sapphire (USA)" "4722efb8cd45772ca32555b98fd3b9719f8e60a9" 0xBAFEDAE5)
