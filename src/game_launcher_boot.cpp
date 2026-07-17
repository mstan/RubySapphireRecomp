// game_launcher_boot.cpp — recomp-ui pre-boot launcher wrapper.
//
// The only TU in this repo compiled with RECOMP_LAUNCHER + the recomp-ui
// include dirs (via the game_launcher_ui static lib recomp_target_launcher_ui
// wires up). All real logic lives in gbarecomp's launcher_seam.h — this file
// just re-exports it behind a plain declaration main.cpp can call without
// inheriting any launcher compile flags.

#include "launcher_seam.h"

#include "game_launcher_boot.h"

int game_launcher_preboot(std::vector<std::string>& args,
                        const gbarecomp::RunOptions& opts) {
    return gbarecomp_launcher_preboot(args, opts);
}
