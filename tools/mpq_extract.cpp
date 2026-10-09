/*
 * mpq_extract - pull named files out of a WoW 3.3.5a MPQ archive.
 *
 *   mpq_extract <archive.MPQ> <out-dir> <file...>
 *
 * The counterpart to mpq_pack, and needed for the same reason merge_dbc.py
 * exists: the client keeps only the LAST copy of a DBC it loads, so a patch
 * that ships one has to be built on top of whatever the patch below it ships,
 * not on top of the stock file. Finding out what that is means reading the
 * archive, and the files are compressed, so it cannot be done by hand.
 *
 * Names are given in the archive's own form with backslashes, e.g.
 * 'DBFilesClient\Spell.dbc', and are written under <out-dir> keeping that
 * path with '/' separators.
 *
 * Building it (the binary is gitignored, as mpq_pack's is):
 *
 *   for f in LibTomCrypt LibTomMath LibTomMathDesc; do
 *       gcc-14 -O2 -c -o /tmp/$f.o tools/StormLib/src/$f.c \
 *           -I tools/StormLib/src -I tools/StormLib/src/libtomcrypt/src/headers
 *   done
 *   g++-14 -O2 -std=c++17 -o tools/mpq_extract tools/mpq_extract.cpp \
 *       /tmp/LibTomCrypt.o /tmp/LibTomMath.o /tmp/LibTomMathDesc.o \
 *       -I tools/StormLib/src \
 *       -Wl,--start-group tools/StormLib/build/libstorm.a -Wl,--end-group -lz -lbz2
 *
 * The three amalgamation files are needed because the vendored libstorm.a was
 * built without them, so it is missing md5_*, sha1_*, crypt_argchk and ltc_mp -
 * which SFileOpenArchive needs and SFileCreateArchive (all mpq_pack uses) does
 * not. They are C and have to be compiled as C; g++ treats a .c file as C++
 * and libtomcrypt does not survive that.
 */

#include <StormLib.h>

#include <algorithm>
#include <cstdio>
#include <filesystem>
#include <string>
#include <vector>

namespace fs = std::filesystem;

int main(int argc, char** argv)
{
    if (argc < 4)
    {
        std::fprintf(stderr, "usage: %s <archive.MPQ> <out-dir> <file...>\n", argv[0]);
        return 2;
    }

    HANDLE mpq = nullptr;
    if (!SFileOpenArchive(argv[1], 0, MPQ_OPEN_READ_ONLY, &mpq))
    {
        std::fprintf(stderr, "cannot open %s: error %u\n", argv[1], SErrGetLastError());
        return 1;
    }

    fs::path const outDir = argv[2];
    int failed = 0;

    for (int i = 3; i < argc; ++i)
    {
        char const* name = argv[i];

        if (!SFileHasFile(mpq, name))
        {
            std::printf("  %-40s absent\n", name);
            ++failed;
            continue;
        }

        HANDLE file = nullptr;
        if (!SFileOpenFileEx(mpq, name, 0, &file))
        {
            std::fprintf(stderr, "  %-40s open failed: error %u\n", name, SErrGetLastError());
            ++failed;
            continue;
        }

        // Translate the archive's separator so the file lands in a real tree.
        std::string relative = name;
        std::replace(relative.begin(), relative.end(), '\\', '/');
        fs::path const target = outDir / relative;
        fs::create_directories(target.parent_path());

        DWORD const size = SFileGetFileSize(file, nullptr);
        std::vector<char> buffer(size);
        DWORD read = 0;

        // One read of the whole file: a DBC is a few tens of MB at most, and a
        // short read is a corrupt archive rather than something to loop over.
        if (!SFileReadFile(file, buffer.data(), size, &read, nullptr) || read != size)
        {
            std::fprintf(stderr, "  %-40s read %u of %u bytes: error %u\n",
                         name, read, size, SErrGetLastError());
            SFileCloseFile(file);
            ++failed;
            continue;
        }

        SFileCloseFile(file);

        if (std::FILE* out = std::fopen(target.c_str(), "wb"))
        {
            std::fwrite(buffer.data(), 1, size, out);
            std::fclose(out);
            std::printf("  %-40s %u bytes -> %s\n", name, size, target.c_str());
        }
        else
        {
            std::fprintf(stderr, "  cannot write %s\n", target.c_str());
            ++failed;
        }
    }

    SFileCloseArchive(mpq);
    return failed ? 1 : 0;
}
