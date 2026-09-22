/*
 * mpq_pack - pack a directory into a WoW 3.3.5a compatible MPQ patch archive.
 *
 *   mpq_pack <archive.MPQ> <staging-dir>
 *
 * Every file under <staging-dir> is added to the archive keeping its relative
 * path, with '/' translated to the '\' separator the client expects, e.g.
 * <staging-dir>/DBFilesClient/CharBaseInfo.dbc becomes
 * DBFilesClient\CharBaseInfo.dbc inside the archive.
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
    if (argc != 3)
    {
        std::fprintf(stderr, "usage: %s <archive.MPQ> <staging-dir>\n", argv[0]);
        return 2;
    }

    fs::path const archivePath = argv[1];
    fs::path const stagingDir  = argv[2];

    if (!fs::is_directory(stagingDir))
    {
        std::fprintf(stderr, "error: %s is not a directory\n", stagingDir.c_str());
        return 1;
    }

    std::vector<fs::path> files;
    for (auto const& entry : fs::recursive_directory_iterator(stagingDir))
        if (entry.is_regular_file())
            files.push_back(entry.path());

    if (files.empty())
    {
        std::fprintf(stderr, "error: no files found under %s\n", stagingDir.c_str());
        return 1;
    }

    std::sort(files.begin(), files.end());
    std::error_code ignored;
    fs::remove(archivePath, ignored);

    // Hash table size must be a power of two and larger than the file count.
    DWORD hashTableSize = 16;
    while (hashTableSize < files.size() * 2)
        hashTableSize *= 2;

    HANDLE archive = nullptr;
    if (!SFileCreateArchive(archivePath.c_str(), MPQ_CREATE_ARCHIVE_V1 | MPQ_CREATE_LISTFILE,
                            hashTableSize, &archive))
    {
        std::fprintf(stderr, "error: SFileCreateArchive failed (%u)\n", SErrGetLastError());
        return 1;
    }

    for (fs::path const& file : files)
    {
        std::string internalName = fs::relative(file, stagingDir).string();
        std::replace(internalName.begin(), internalName.end(), '/', '\\');

        if (!SFileAddFileEx(archive, file.c_str(), internalName.c_str(),
                            MPQ_FILE_COMPRESS | MPQ_FILE_REPLACEEXISTING,
                            MPQ_COMPRESSION_ZLIB, MPQ_COMPRESSION_ZLIB))
        {
            std::fprintf(stderr, "error: cannot add %s (%u)\n", internalName.c_str(), SErrGetLastError());
            SFileCloseArchive(archive);
            return 1;
        }

        std::printf("added %s\n", internalName.c_str());
    }

    SFileCloseArchive(archive);
    std::printf("wrote %s (%zu file(s))\n", archivePath.c_str(), files.size());
    return 0;
}
