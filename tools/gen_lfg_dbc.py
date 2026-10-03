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

and two rows are appended: "Random Dungeon", every normal dungeon at once, and
"Random Heroic", every heroic. They point at the two synthetic groups the core
fills by kind (LFG_GROUP_ALL_DUNGEONS and LFG_GROUP_ALL_HEROICS in LFGMgr.h),
because a dungeon carries exactly one GroupID and no stock group means "all of
them". Level appropriateness needs no help: GetCompatibleDungeons strips
whatever is locked for the party, so a level 15 picking Random Dungeon draws
from the three dungeons open at 15 and an eighty draws from all of them.

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
I_NAME = 1
I_TARGET_LEVEL, I_TARGET_LEVEL_MIN = 20, 21
I_MAP, I_DIFFICULTY, I_FLAGS = 23, 24, 25
I_FACTION, I_TEXTURE, I_EXPANSION, I_ORDER_INDEX, I_GROUP = 27, 28, 29, 30, 31
I_NAME_LANG_MASK, I_DESCRIPTION_LANG_MASK = 17, 48

LFG_TYPE_DUNGEON = 1
LFG_TYPE_HEROIC = 5
LFG_TYPE_RANDOM = 6

RAISE_TO = 80

# Appending a row means appending its name to the string block, so these carry
# the whole row rather than a patch. Field numbers follow LFGDungeonEntry.
#
# The template for every other value is the stock Random Classic Dungeon row
# (258): Faction -1, Flags 3, no map, no texture, no description. TargetLevel is
# the field the client tints the entry by; the stock randoms set it to the
# middle of their range, so Random Dungeon mirrors that and reads grey to an
# eighty, which is what was asked for elsewhere. Random Heroic spans 70 to 80
# and takes 80, as the Lich King heroic row does.
NEW_ROWS = [
    {
        "id": 300,
        "name": "Random Dungeon",
        "min_level": 15,
        "max_level": 80,
        "target_level": 55,
        "target_level_min": 15,
        "target_level_max": 80,
        "difficulty": 0,
        "expansion": 0,
        "group": 255,          # LFG_GROUP_ALL_DUNGEONS
    },
    {
        "id": 301,
        "name": "Random Heroic",
        # 70, because the TBC heroics start there; the Lich King ones are
        # min 80 and simply stay locked until then.
        "min_level": 70,
        "max_level": 80,
        "target_level": 80,
        "target_level_min": 70,
        "target_level_max": 80,
        "difficulty": 1,
        "expansion": 1,
        "group": 254,          # LFG_GROUP_ALL_HEROICS
    },
]

# Values every row shares, read out of the stock randoms.
NAME_LANG_MASK = 16712190
DESCRIPTION_LANG_MASK = 16712188
FACTION_ANY = 0xFFFFFFFF
RANDOM_FLAGS = 3


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


def build_row(spec, fields, name_offset):
    """One record as a tuple of `fields` uint32s."""
    row = [0] * fields

    row[I_ID] = spec["id"]
    row[I_NAME] = name_offset
    row[I_NAME_LANG_MASK] = NAME_LANG_MASK
    row[I_DESCRIPTION_LANG_MASK] = DESCRIPTION_LANG_MASK

    row[I_MIN_LEVEL] = spec["min_level"]
    row[I_MAX_LEVEL] = spec["max_level"]
    row[I_TARGET_LEVEL] = spec["target_level"]
    row[I_TARGET_LEVEL_MIN] = spec["target_level_min"]
    row[I_TARGET_LEVEL_MAX] = spec["target_level_max"]

    row[I_MAP] = 0                      # a random entry has no map of its own
    row[I_DIFFICULTY] = spec["difficulty"]
    row[I_FLAGS] = RANDOM_FLAGS
    row[I_TYPE] = LFG_TYPE_RANDOM
    row[I_FACTION] = FACTION_ANY
    row[I_TEXTURE] = 0
    row[I_EXPANSION] = spec["expansion"]
    row[I_ORDER_INDEX] = 0
    row[I_GROUP] = spec["group"]

    return row


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

    # --- the appended rows ------------------------------------------------
    #
    # Records come first and the string block follows, so a new row has to be
    # spliced in between the two and the header's counts corrected. The block
    # already begins with a NUL, which is why an unset string field reading 0
    # means "empty" rather than pointing at the first name.
    header = bytes(data[:20])
    body = bytearray(data[20:20 + records * record_size])
    strings = bytearray(data[20 + records * record_size:])

    existing_ids = {
        struct.unpack_from("<I", body, record * record_size + I_ID * 4)[0]
        for record in range(records)
    }

    added = []

    for spec in NEW_ROWS:
        if spec["id"] in existing_ids:
            sys.exit(f"id {spec['id']} is already in the file; pick another for {spec['name']!r}")

        name_offset = len(strings)
        strings += spec["name"].encode("utf8") + b"\0"

        row = build_row(spec, fields, name_offset)
        body += struct.pack(f"<{fields}I", *row)
        added.append(spec)

    out = bytearray(header)
    struct.pack_into("<II", out, 4, records + len(added), fields)
    struct.pack_into("<I", out, 16, len(strings))
    out += body
    out += strings

    SERVER_DBC.write_bytes(out)
    print(f"{SERVER_DBC}: raised MaxLevel to {RAISE_TO} on {len(changed)} of {records} rows, "
          f"appended {len(added)}")

    if STAGING_DBC.parent.is_dir():
        STAGING_DBC.write_bytes(out)
        print(f"{STAGING_DBC}: same file staged for patch-Z.MPQ")
    else:
        print(f"note: {STAGING_DBC.parent} is missing, so nothing was staged for the client")

    counts = {LFG_TYPE_DUNGEON: 0, LFG_TYPE_HEROIC: 0, LFG_TYPE_RANDOM: 0}
    for _, _, _, kind in changed:
        counts[kind] += 1

    print(f"  {counts[LFG_TYPE_DUNGEON]} normal dungeon(s), {counts[LFG_TYPE_HEROIC]} heroic(s), "
          f"{counts[LFG_TYPE_RANDOM]} random option(s); MinLevel untouched throughout")

    for spec in added:
        print(f"  + id {spec['id']} {spec['name']!r}: levels {spec['min_level']}-{spec['max_level']}, "
              f"group {spec['group']}")


if __name__ == "__main__":
    main()
