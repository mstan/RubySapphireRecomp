// verify_rom_hash — STUB.
//
// Eventually: SHA-1 the user-provided ROM and compare against the
// per-region `[rom] sha1` field in config/<region>.toml. Exit 0 on
// match, non-zero on mismatch or missing ROM.
//
// The runner calls this on startup; we also expose it as a standalone
// CLI so users can verify their dump before wasting build time.
//
// Expected USA v1.0 SHA-1: 41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc

#include <cstdio>

int main(int argc, char** argv) {
    if (argc < 2) {
        std::printf("usage: verify_rom_hash <rom_path> [region]\n");
        return 2;
    }
    std::printf("verify_rom_hash: stub. Would verify %s\n", argv[1]);
    return 0;
}
