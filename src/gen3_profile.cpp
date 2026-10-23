#include "profile.h"

namespace gen3 {
const Profile& game_profile() {
#if defined(GEN3_VARIANT_RUBY)
    // ruby USA rev1: variants/ruby/symbols/imported*_symbols.tsv.
    // Map-group pointer independently checked in the ROM lookup literal.
    static constexpr Profile profile{
        "ruby", false, 0x03001770, 0x080543C4, 0x0202E828,
        0x03004870, 0x02025734, 0x03000590, 0x083085A0, false,
        0x030048A0, 0x02020004, 0x030024D0, 0x030027E0, 0,
        0x0830F9CC, 34, 0x0836DC70, 0x0836DC21, 0x0837560C,
        0x08376078, 0x083739B4, 0x030005A4, 0x030005A6, 218,
        77, 0xC20, 0x1220, 0x1340, 0x900,
        0x0202E8E2, 0x030005AC, 0x030005AE, 0x0203A3D0
    };
#elif defined(GEN3_VARIANT_SAPPHIRE)
    // sapphire USA rev1: variants/sapphire/symbols/imported*_symbols.tsv.
    // Map-group pointer independently checked in the ROM lookup literal.
    static constexpr Profile profile{
        "sapphire", false, 0x03001770, 0x080543C8, 0x0202E828,
        0x03004870, 0x02025734, 0x03000590, 0x08308530, false,
        0x030048A0, 0x02020004, 0x030024D0, 0x030027E0, 0,
        0x0830F95C, 34, 0x0836DC00, 0x0836DBB1, 0x0837559C,
        0x08376008, 0x08373944, 0x030005A4, 0x030005A6, 218,
        77, 0xC20, 0x1220, 0x1340, 0x900,
        0x0202E8E2, 0x030005AC, 0x030005AE, 0x0203A3D0
    };
#else
#error Select a reviewed Gen III ROM profile
#endif
    return profile;
}
}
