#!/usr/bin/env python3
"""
Give the realm's custom spells a row in the client's Spell.dbc, so an item can
say what it does.

Why this is needed at all
-------------------------

An item's "Use:" line is not sent by the server. The client builds it from the
DESCRIPTION of the item's spell, read out of its own Spell.dbc, and the same
lookup decides whether right-clicking the item sends CMSG_USE_ITEM at all. The
server never even reads that field: the format string it loads Spell.dbc with
(SpellEntryfmt in DBCfmt.h) marks all 34 description fields 'x', skipped.

So a spell meant to be visible has to exist in two places. `spell_dbc` in the
world database is one of them, but it is a server-side overlay the client never
sees, and an item carrying a spell that exists only there shows no Use: line
and right-clicks into nothing. This puts the same rows in the other place.

What it ships, and what it does not
-----------------------------------

Only ids in SHIP_RANGE, which is reserved for exactly this, plus the handful
named in SHIP_OVERRIDES. That restraint is the point: 4492 of the 4517 rows in
spell_dbc exist only server-side, and six stock items point spellid_1 at spells
named, literally, '... serverside spell'. A rule like "ship every spell an item
references" would hand the client spells that were deliberately kept from it,
and "ship every row that shares an id with the stock file" would be worse
still.

SHIP_OVERRIDES is for the other case: a stock spell whose own data is wrong,
where the server already reads the correction out of spell_dbc and the client
has to be told the same thing. Those rows do not add a record; their numeric
fields are written over the stock row in place.

The base is the stock Spell.dbc, which is read and never written. Unlike
Item.dbc there is no reason to put our rows in the server's copy - the server
ignores the only field we are here for - and keeping that file pristine is what
lets this run again and again from a known starting point.

The cost is in the output: Spell.dbc is 68 MB and packs to about 16 MB, which
is most of patch-W. Nothing can be done about that. A DBC is loaded whole, so
shipping six rows means shipping all 49855.

It also checks each tooltip against statbonus_item_reward. The description is
plain text - a $s1 would resolve against this spell's own empty effect values
and print 0 - so the number in it is written by hand and can drift from the
amount actually granted. That check is the whole reason to generate this rather
than hand-build it.
"""

import re
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Read, never written: see the docstring.
SOURCE = ROOT / "run/data/dbc/Spell.dbc"

STAGING_DIR = ROOT / "client-patch/staging-items"
STAGING = STAGING_DIR / "DBFilesClient/Spell.dbc"
ARCHIVE = ROOT / "client-patch/patch-W.MPQ"
PACKER = ROOT / "tools/mpq_pack"

# Reserved for spells the client has to know about. Declared in
# sql/28_custom_spells.sql, which is also where the convention
# "spell = item entry + 100" is written down.
SHIP_RANGE = (90100, 90199)

# Stock spells whose `spell_dbc` row is a CORRECTION to ship, not a
# server-side overlay to keep back. Listed one by one on purpose: most rows in
# that table share an id with the stock file deliberately and must never reach
# the client, so "ship every row that overlaps" would be wrong. These two are
# the language spells whose EffectMiscValue_1 says Common when every other file
# says Demonic and Kalimag - see sql/29_language_spells.sql, which generates
# the rows, and tools/gen_language_spells.py, which explains why.
SHIP_OVERRIDES = {815, 817}

FIELDS = 234        # a file of any other width is not the Spell.dbc this was
ROW_SIZE = 936      # written for, so stop rather than corrupt it

# The four localised string fields: 16 locale slots then a mask. The server's
# format string only admits to the first two groups; the client reads all four.
STRING_GROUPS = {136: "Name", 153: "NameSubtext", 170: "Description", 187: "AuraDescription"}
LOCALES = 16

# Stock rows fill locale slots 0-8 and leave 9-15 empty, with this mask. We
# have only English, so the same string goes in all nine rather than leaving a
# non-enUS client to read offset 0 and find nothing.
FILLED_LOCALES = 9
LOCALE_MASK = 16712190

# The server's own format string, as the authority on which fields are floats
# and which are text - checked against the column types, not trusted blindly.
SERVER_FORMAT = (
    "niiiiiiiiiiiixixiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiifxiiiiiiiiiiiiiiiiiiiiiiii"
    "iiiifffiiiiiiiiiiiiiiiiiiiiifffiiiiiiiiiiiiiiifffiiiiiiiiiiiiiissssssssss"
    "ssssssxssssssssssssssssxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxiiiiiiiiiiixfff"
    "xxxiiiiixxfffxx"
)


def sql(query):
    result = subprocess.run(["mysql", "-uroot", "-N", "-B", "--raw", "acore_world", "-e", query],
                            capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"query failed: {result.stderr.strip()}\n{query}")
    return [line.split("\t") for line in result.stdout.split("\n") if line]


def columns():
    """spell_dbc's columns in ordinal order, which is DBC field order.

    DBCDatabaseLoader walks the format string and the SELECT * columns in
    lockstep, one column per format character including the skipped ones, and
    asserts the two counts match - so the table is a 1:1 image of the row
    layout and needs no mapping by hand.
    """
    rows = sql("""
        SELECT column_name, data_type FROM information_schema.columns
        WHERE table_schema = 'acore_world' AND table_name = 'spell_dbc'
        ORDER BY ordinal_position
    """)
    if len(rows) != FIELDS:
        sys.exit(f"spell_dbc has {len(rows)} columns, expected {FIELDS}")
    return [(name, kind) for name, kind in rows]


def kind_of(data_type):
    if data_type in ("float", "double", "decimal"):
        return "f"
    if data_type in ("varchar", "text", "char", "tinytext", "mediumtext"):
        return "s"
    return "i"


def check_types(cols):
    """The format string and the column types have to agree where both speak.

    Only about the fields the server actually reads: it marks the description
    groups 'x' and says nothing about their type, which is precisely why the
    columns are the authority here.
    """
    for i, (name, data_type) in enumerate(cols):
        fmt, kind = SERVER_FORMAT[i], kind_of(data_type)
        if fmt in "fs" and fmt != kind:
            sys.exit(f"field {i} ({name}): format says {fmt!r}, column is {data_type} ({kind!r})")
        if fmt in "ni" and kind != "i":
            sys.exit(f"field {i} ({name}): format says int, column is {data_type}")


def read_dbc(path):
    data = path.read_bytes()
    magic, records, fields, row_size, string_size = struct.unpack_from("<4sIIII", data, 0)

    if magic != b"WDBC":
        sys.exit(f"{path}: not a DBC file")
    if fields != FIELDS or row_size != ROW_SIZE:
        sys.exit(f"{path}: {fields} fields of {row_size} bytes, expected {FIELDS} of {ROW_SIZE}")

    body_at = 20
    strings_at = body_at + records * row_size
    return {
        "records": records,
        "body": data[body_at:strings_at],
        "strings": data[strings_at:strings_at + string_size],
    }


def existing_ids(dbc):
    return {struct.unpack_from("<I", dbc["body"], i * ROW_SIZE)[0] for i in range(dbc["records"])}


def to_ship(cols):
    lo, hi = SHIP_RANGE
    names = ", ".join(f"`{name}`" for name, _ in cols)
    rows = sql(f"SELECT {names} FROM `spell_dbc` WHERE `ID` BETWEEN {lo} AND {hi} ORDER BY `ID`")
    return rows


def to_override(cols):
    """The `spell_dbc` rows that correct a stock row, read from the same table
    the server overrides from, so the client's copy and the server's cannot
    disagree about what a spell does."""
    if not SHIP_OVERRIDES:
        return []

    names = ", ".join(f"`{name}`" for name, _ in cols)
    ids = ", ".join(str(spell) for spell in sorted(SHIP_OVERRIDES))
    rows = sql(f"SELECT {names} FROM `spell_dbc` WHERE `ID` IN ({ids}) ORDER BY `ID`")

    missing = SHIP_OVERRIDES - {int(row[0]) for row in rows}
    if missing:
        sys.exit(f"no spell_dbc row for {sorted(missing)}, which SHIP_OVERRIDES says to correct; "
                 "apply sql/29_language_spells.sql first")
    return rows


def apply_overrides(body, cols, rows, have):
    """Write each override row's numeric fields over the stock row in place.

    Only the numeric fields, which is the same rule the server follows: its
    loader treats an empty string column as "not overridden" and keeps the
    file's own text, and these rows carry no text.
    """
    index = {struct.unpack_from("<I", body, i * ROW_SIZE)[0]: i
             for i in range(len(body) // ROW_SIZE)}

    for row in rows:
        spell = int(row[0])
        if spell not in have:
            sys.exit(f"spell {spell} is in SHIP_OVERRIDES but not in the stock Spell.dbc - it is a "
                     f"new spell, so it belongs in {SHIP_RANGE[0]}-{SHIP_RANGE[1]} instead")

        at = index[spell] * ROW_SIZE
        changed = []

        for i, ((name, data_type), raw) in enumerate(zip(cols, row)):
            kind = kind_of(data_type)

            if kind == "s":
                if raw not in ("NULL", ""):
                    sys.exit(f"spell {spell} column {name} carries text ({raw!r}); overriding a stock "
                             "row's strings is not implemented, and the server would keep the file's "
                             "text anyway")
                continue
            if raw in ("NULL", ""):
                continue

            if kind == "f":
                value = struct.unpack("<I", struct.pack("<f", float(raw)))[0]
            else:
                value = int(raw) & 0xFFFFFFFF

            before = struct.unpack_from("<I", body, at + i * 4)[0]
            if before != value:
                changed.append(f"{name} {before} -> {value}")
            struct.pack_into("<I", body, at + i * 4, value)

        print(f"  ~ {spell:>7}  {', '.join(changed) if changed else 'already identical'}")


def check_tooltips(spells):
    """Does each description's number match what the item actually grants?

    A mote's amount lives in statbonus_item_reward and can be retuned with an
    UPDATE; the tooltip lives in a client patch and cannot. Catching the
    disagreement here is cheaper than shipping a lie.
    """
    granted = {}
    for item, spell, amount, count in sql("""
        SELECT i.entry, i.spellid_1, MIN(r.Amount), COUNT(*)
        FROM item_template i JOIN statbonus_item_reward r ON r.ItemId = i.entry
        GROUP BY i.entry, i.spellid_1
    """):
        granted[int(spell)] = (int(item), int(amount), int(count))

    complaints = []
    for spell_id, description in spells.items():
        if spell_id not in granted:
            continue                                  # not a grant spell; nothing to compare
        item, amount, count = granted[spell_id]
        if count != 1:
            continue                                  # a pool, so no single number to state
        stated = re.search(r"\bby (\d+)\b", description)
        if not stated:
            complaints.append(f"  spell {spell_id} (item {item}) states no amount, table grants {amount}")
        elif int(stated.group(1)) != amount:
            complaints.append(f"  spell {spell_id} (item {item}) says 'by {stated.group(1)}', "
                              f"table grants {amount}")

    if complaints:
        sys.exit("tooltip disagrees with statbonus_item_reward:\n" + "\n".join(complaints)
                 + "\n\nFix the description in sql/28_custom_spells.sql or the Amount in the table, "
                   "then run this again.")


def main():
    cols = columns()
    check_types(cols)

    dbc = read_dbc(SOURCE)
    have = existing_ids(dbc)
    rows = to_ship(cols)
    overrides = to_override(cols)

    if not rows:
        sys.exit(f"no spell_dbc rows in {SHIP_RANGE[0]}-{SHIP_RANGE[1]}; "
                 "apply sql/28_custom_spells.sql first")

    clash = [r[0] for r in rows if int(r[0]) in have]
    if clash:
        sys.exit(f"ids already in the stock Spell.dbc: {clash} - pick others, "
                 "overwriting a stock spell is not what this is for")

    body = bytearray(dbc["body"])
    apply_overrides(body, cols, overrides, have)

    # Strings go on the end of the existing block, so every stock offset in the
    # body stays valid and the rest of the rows copy through untouched.
    strings = bytearray(dbc["strings"])
    added = bytearray()
    descriptions = {}

    for row in rows:
        values = [0] * FIELDS

        for i, ((name, data_type), raw) in enumerate(zip(cols, row)):
            kind = kind_of(data_type)

            if kind == "s":
                continue                               # handled per group below
            if raw in ("NULL", ""):
                continue
            if kind == "f":
                values[i] = struct.unpack("<I", struct.pack("<f", float(raw)))[0]
            else:
                # Signed, because EquippedItemClass is -1 on a spell with no
                # weapon requirement and the stock rows hold it as 0xFFFFFFFF.
                values[i] = int(raw) & 0xFFFFFFFF

        for base, label in STRING_GROUPS.items():
            text = row[base]                           # the enUS slot of the group
            if text in ("NULL", ""):
                continue
            offset = len(strings)
            strings += text.encode("utf-8") + b"\x00"
            for slot in range(FILLED_LOCALES):
                values[base + slot] = offset
            values[base + LOCALES] = LOCALE_MASK
            if label == "Description":
                descriptions[int(row[0])] = text

        added += struct.pack(f"<{FIELDS}I", *values)
        print(f"  + {row[0]:>7}  {row[136]!r}")
        print(f"            {descriptions.get(int(row[0]), '(no description)')!r}")

    check_tooltips(descriptions)

    out = bytearray()
    out += struct.pack("<4sIIII", b"WDBC", dbc["records"] + len(rows), FIELDS, ROW_SIZE, len(strings))
    out += body
    out += added
    out += strings

    STAGING.parent.mkdir(parents=True, exist_ok=True)
    STAGING.write_bytes(out)
    print(f"{STAGING}: {len(rows)} row(s) added, {len(overrides)} corrected, "
          f"now {dbc['records'] + len(rows)} "
          f"({len(out) / 1e6:.1f} MB)")

    if not PACKER.exists():
        sys.exit(f"{PACKER} is missing; build it before packing")

    result = subprocess.run([str(PACKER), str(ARCHIVE), str(STAGING_DIR)],
                            capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"packing {ARCHIVE} failed: {result.stderr.strip()}")

    print(f"wrote {ARCHIVE} ({ARCHIVE.stat().st_size / 1e6:.1f} MB)")
    print(f"copy {ARCHIVE.name} into the client's Data folder")


if __name__ == "__main__":
    main()
