// game_launcher_boot.h — recomp-ui pre-boot launcher entry for this game.
//
// Implemented in game_launcher_boot.cpp, which is compiled into the isolated
// game_launcher_ui static lib (see CMakeLists) so the recomp-ui sources and
// the RECOMP_LAUNCHER define never touch the generated/*.c compile flags.
// main.cpp calls this before gbarecomp::run_game(); returns 1 when the user
// quit the launcher (main returns without booting), 0 to continue with
// `args` extended by the launcher-committed settings.

#pragma once

#include <string>
#include <vector>

#include "runtime.h"

int game_launcher_preboot(std::vector<std::string>& args,
                        const gbarecomp::RunOptions& opts);
