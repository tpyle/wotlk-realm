#!/usr/bin/env python3
"""
Let an overlevelled player queue for a dungeon in the Dungeon Finder.

The finder hides a dungeon once you pass its level range, and that decision is
made twice. The server locks it (LFG_LOCKSTATUS_TOO_HIGH_LEVEL in
LFGMgr::InitializeLockedDungeons) and the client, independently, declines to
list it at all from its own copy of LFGDungeons.dbc. Unlocking it server side
therefore changes nothing on screen - which is exactly what we measured - so
the fix has to be in the DBC, and in both copies: run/data/dbc for the server
and the client patch for the client.

What this changes, and nothing else:

    MaxLevel       -> 80   for LFG_TYPE_DUNGEON (1), LFG_TYPE_HEROIC (5) and
                           LFG_TYPE_RANDOM (6) where it is currently lower
    TargetLevelMax -> 80   for LFG_TYPE_RANDOM (6) only, same condition

MinLevel is left exactly as it is, so a dungeon keeps the lower bound the base
game gave it - a level 20 still cannot queue for Karazhan. Raids (type 2) are
not touched: every one of them already sits at 83. Type 4 is left alone because
the server does not even load it (LFGMgr::LoadLFGDungeons only keeps types 1,
2, 5 and 6).

The random entries (type 6) need raising as well, and it is easy to miss them.
Unlocking the dungeons is not enough on its own: "Random Classic Dungeon" is
itself an LFGDungeons row with its own range, capped at 58, so an eighty could
reach every classic dungeon individually and still not be offered the random
option. Their pools are unaffected either way, being built per GroupID
(CachedDungeonMapStore[dungeon.group]) and then filtered only by what is locked
for the party - GetCompatibleDungeons - so raising the cap widens who may pick
the option and not what the option contains.

MaxLevel alone did not make them selectable, and TargetLevelMax is why. The
server is satisfied by MaxLevel - GetRandomAndSeasonalDungeons tests
minlevel <= level <= maxlevel and nothing else - but the client went on
offering an eighty only the two Lich King options, which were the only randoms
whose TargetLevelMax reached 80 (58, 68 and 73 for the other three). So the
client filters the random list on the target range instead, and that field has
to move too.

TargetLevel itself is deliberately left alone, here and on the dungeons, so an
outlevelled entry still shows grey. The server never reads any of the target
fields - LFGDungeonData keeps only minlevel and maxlevel - so they are free to
change, but TargetLevel is what tints the entry, it is static, and one value
serves every viewer.

Entry requirements are a different system and are not affected: walking into an
instance portal is gated by dungeon_access_template and
dungeon_access_requirements in the world database, not by this file.

Random dungeon pools are also unaffected. They are built per GroupID
(CachedDungeonMapStore[dungeon.group]), not per level, so raising a cap cannot
put Wailing Caverns into a level 80's random roll.

The first run keeps the stock file as LFGDungeons.dbc.orig and every run
patches from that baseline, so re-running is idempotent and the original is
always recoverable.

After this, repack the client patch:

    tools/install_worgoblin_dbc.sh --client-only

and restart the world server, which reads the DBCs once at startup.
"""

import shutil
import struct
import sys
from pathlib import Path

ROOT = Path("/root/classic")
SERVER_DBC = ROOT / "run/data/dbc/LFGDungeons.dbc"
STAGING_DBC = ROOT / "client-patch/staging/DBFilesClient/LFGDungeons.dbc"

# Field indices from the core's LFGDungeonEntry (src/server/shared/DataStores/
# DBCStructure.h). Name occupies 1-17, which is why these start so late.
I_ID, I_MIN_LEVEL, I_MAX_LEVEL, I_TYPE = 0, 18, 19, 26
I_TARGET_LEVEL_MAX = 22

LFG_TYPE_DUNGEON = 1
LFG_TYPE_HEROIC = 5
LFG_TYPE_RANDOM = 6

RAISE_TO = 80


def read_dbc(path):
    data = bytearray(path.read_bytes())
    magic, records, fields, record_size, string_size = struct.unpack_from("<4sIIII", data, 0)

    if magic != b"WDBC":
        sys.exit(f"{path}: not a WDBC file")

    if fields * 4 != record_size:
        sys.exit(f"{path}: {fields} fields do not fill a {record_size} byte record")

    return data, records, fields, record_size


def field_offset(index, record, fields, record_size):
    if index >= fields:
        sys.exit(f"field {index} is past the end of a {fields} field record")

    return 20 + record * record_size + index * 4


def main():
    baseline = SERVER_DBC.with_suffix(".dbc.orig")

    if not baseline.exists():
        shutil.copy2(SERVER_DBC, baseline)
        print(f"kept the stock file as {baseline.name}")

    data, records, fields, record_size = read_dbc(baseline)

    changed = []

    for record in range(records):
        def get(index):
            return struct.unpack_from("<I", data, field_offset(index, record, fields, record_size))[0]

        if get(I_TYPE) not in (LFG_TYPE_DUNGEON, LFG_TYPE_HEROIC, LFG_TYPE_RANDOM):
            continue

        if get(I_MAX_LEVEL) >= RAISE_TO:
            continue

        changed.append((get(I_ID), get(I_MIN_LEVEL), get(I_MAX_LEVEL), get(I_TYPE)))
        struct.pack_into("<I", data, field_offset(I_MAX_LEVEL, record, fields, record_size), RAISE_TO)

        # Only the random options, and only because the client reads this one
        # rather than MaxLevel when deciding which randoms to offer.
        if get(I_TYPE) == LFG_TYPE_RANDOM and get(I_TARGET_LEVEL_MAX) < RAISE_TO:
            struct.pack_into("<I", data, field_offset(I_TARGET_LEVEL_MAX, record, fields, record_size), RAISE_TO)

    SERVER_DBC.write_bytes(data)
    print(f"{SERVER_DBC}: raised MaxLevel to {RAISE_TO} on {len(changed)} of {records} rows")

    if STAGING_DBC.parent.is_dir():
        STAGING_DBC.write_bytes(data)
        print(f"{STAGING_DBC}: same file staged for patch-Z.MPQ")
    else:
        print(f"note: {STAGING_DBC.parent} is missing, so nothing was staged for the client")

    counts = {LFG_TYPE_DUNGEON: 0, LFG_TYPE_HEROIC: 0, LFG_TYPE_RANDOM: 0}
    for _, _, _, kind in changed:
        counts[kind] += 1

    print(f"  {counts[LFG_TYPE_DUNGEON]} normal dungeon(s), {counts[LFG_TYPE_HEROIC]} heroic(s), "
          f"{counts[LFG_TYPE_RANDOM]} random option(s); MinLevel untouched throughout")


if __name__ == "__main__":
    main()
