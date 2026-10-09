#!/usr/bin/env python3
"""
Give custom items a row in Item.dbc, so the client knows how to draw them.

Why this is needed at all
-------------------------

A custom item is normally just an item_template row: the client asks for it
with CMSG_ITEM_QUERY_SINGLE and the server answers with the name, the stats,
the tooltip - everything. So the natural assumption is that a server-side row
is sufficient, and for most of the tooltip it is.

It is not sufficient for the icon. The client takes an item's display from its
OWN copy of Item.dbc:

    ID, ClassID, SubclassID, SoundOverrideSubclassID,
    Material, DisplayInfoID, InventoryType, SheatheType

DisplayInfoID is the one that matters here - it is what resolves to the icon
through ItemDisplayInfo.dbc. With no row at all there is no display info, and
the client falls back to the question mark, however complete and correct the
server's answer was.

That took measuring rather than guessing. The item's data was identical to the
stock item it had been cloned from - same displayid, same class, same subclass,
same InventoryType - and the stock one drew correctly. A temporary opcode log
showed the client asking for entry 90003 on a cold start with no cache present
at all, and the server answering. Everything about the exchange was right, and
the icon was still wrong, which is what ruled out the cache, the display id and
the response in turn and left only the file the client reads for itself.

What it does
------------

Reads item_template, finds every entry with no row in the STOCK Item.dbc, and
appends one built from the database columns, so the DBC cannot disagree with
the table it was generated from.

The base is the stock file, not the last output, and that is what makes a
rerun pick up a CHANGED row and not just a new one - the custom rows are
rebuilt from scratch every time rather than accumulated. An earlier version
read its own output, which meant retargeting an item's icon left the old
displayid in place with nothing to say so.

Nothing stock is ever modified. A stock row and item_template do legitimately
disagree in places, and the client's copy is the one it draws from, so
rewriting those from the table would be a change nobody asked for.

It writes both copies. The server's at run/data/dbc, because the server reads
the same file and there is no reason for the two to differ, and the client's
into its own staging directory for packing.

Unlike the openskills generator, nothing here is owned in memory by a module,
so there is no .orig-restore trap to avoid.

Needs no server restart for the icon, which is entirely client-side. The
server picks up the new rows at its next restart, and nothing depends on it
doing so.

tools/gen_spell_dbc.py fills the same staging directory and packs the same
archive, so whichever runs second picks up the other's file; after changing
items run both, or run this one and then that one.
"""

import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# The stock file, kept out of the repository because it is Blizzard's to
# distribute and not ours: client-patch/stock-dbc is gitignored, and
# tools/mpq_extract probes it back out of a client archive if it goes missing
# (patch-A carries an unmodified copy).
STOCK = ROOT / "client-patch/stock-dbc/Item.dbc"

# Where the server reads it from, and so what this writes. Regenerated whole
# from STOCK, which is why it must not be the input.
SERVER = ROOT / "run/data/dbc/Item.dbc"

# Its own staging directory and its own archive, so a repack of anything else
# cannot drop these rows and this cannot pick up anybody else's files.
STAGING_DIR = ROOT / "client-patch/staging-items"
STAGING = STAGING_DIR / "DBFilesClient/Item.dbc"
ARCHIVE = ROOT / "client-patch/patch-W.MPQ"
PACKER = ROOT / "tools/mpq_pack"

FIELDS = 8          # the row layout above; a file with any other width is not
                    # the Item.dbc this was written for

# item_template columns in Item.dbc field order, so the row build below is a
# straight read with nothing to line up by hand.
QUERY = """
    SELECT entry, class, subclass, SoundOverrideSubclass,
           Material, displayid, InventoryType, sheath
    FROM item_template
    ORDER BY entry
"""


def read_dbc(path):
    data = path.read_bytes()
    magic, records, fields, row_size, string_size = struct.unpack_from("<4sIIII", data, 0)

    if magic != b"WDBC":
        sys.exit(f"{path}: not a DBC file")
    if fields != FIELDS or row_size != FIELDS * 4:
        sys.exit(f"{path}: {fields} fields of {row_size} bytes, expected {FIELDS} of {FIELDS * 4} - "
                 "the layout this was written for has changed, so stop rather than corrupt it")

    body_at = 20
    strings_at = body_at + records * row_size
    return {
        "records": records,
        "row_size": row_size,
        "body": data[body_at:strings_at],
        "strings": data[strings_at:strings_at + string_size],
    }


def existing_ids(dbc):
    return {
        struct.unpack_from("<I", dbc["body"], i * dbc["row_size"])[0]
        for i in range(dbc["records"])
    }


def rows_from_db():
    result = subprocess.run(
        ["mysql", "-uroot", "-N", "-B", "acore_world", "-e", QUERY],
        capture_output=True, text=True)

    if result.returncode != 0:
        sys.exit(f"reading item_template failed: {result.stderr.strip()}")

    rows = {}
    for line in result.stdout.strip().splitlines():
        parts = line.split("\t")
        rows[int(parts[0])] = [int(p) for p in parts]
    return rows


def main():
    dbc = read_dbc(STOCK)
    have = existing_ids(dbc)
    table = rows_from_db()

    missing = sorted(entry for entry in table if entry not in have)

    if not missing:
        print(f"{STOCK}: every item_template entry already has a row; nothing to do")
        return

    added = b""
    for entry in missing:
        row = table[entry]
        # Packed signed, because SoundOverrideSubclassID is -1 on an ordinary
        # item and the stock rows hold it as 0xFFFFFFFF.
        added += struct.pack("<8i", *row)
        print(f"  + {entry:7} class {row[1]:2} subclass {row[2]:2} "
              f"material {row[4]:2} display {row[5]:6} invtype {row[6]:2}")

    out = bytearray()
    out += struct.pack("<4sIIII", b"WDBC", dbc["records"] + len(missing),
                       FIELDS, dbc["row_size"], len(dbc["strings"]))
    out += dbc["body"]
    out += added
    out += dbc["strings"]

    SERVER.write_bytes(out)
    print(f"{SERVER}: {len(missing)} row(s) appended, now {dbc['records'] + len(missing)}")

    STAGING.parent.mkdir(parents=True, exist_ok=True)
    STAGING.write_bytes(out)
    print(f"{STAGING}: written")

    if not PACKER.exists():
        sys.exit(f"{PACKER} is missing; build it before packing")

    # Both generators fill this directory and pack this one archive, so a run
    # here ships whatever gen_spell_dbc.py left behind. Its output is gitignored
    # for size, which means a fresh checkout has an Item.dbc and no Spell.dbc -
    # and packing that would quietly drop the Use: line off every custom item.
    spells = STAGING_DIR / "DBFilesClient/Spell.dbc"
    if not spells.exists():
        sys.exit(f"{spells} is missing, so packing now would ship a patch with no\n"
                 "custom spells in it and no Use: line on any custom item.\n"
                 "Run tools/gen_spell_dbc.py first; it packs the archive too.")

    result = subprocess.run([str(PACKER), str(ARCHIVE), str(STAGING_DIR)],
                            capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"packing {ARCHIVE} failed: {result.stderr.strip()}")

    print(result.stdout.strip().splitlines()[-1] if result.stdout.strip() else f"wrote {ARCHIVE}")
    print(f"copy {ARCHIVE.name} into the client's Data folder")


if __name__ == "__main__":
    main()
