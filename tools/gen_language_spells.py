#!/usr/bin/env python3
"""
Make spells 815 and 817 grant the languages they are named after.

The bug this exists to fix
--------------------------

Of the fourteen spells in Spell.dbc carrying SPELL_EFFECT_LANGUAGE (39), two
grant a language other than the one their name promises:

    815  'Language Demon Tongue'      EffectMiscValue_1 = 7  (Common)
    817  'Language Old Tongue (NYI)'  EffectMiscValue_1 = 7  (Common)

Everything else in both the client's data and the server's agrees that those
spells are Demonic and Kalimag - Languages.dbc names both languages,
LanguageWords.dbc holds 126 and 122 words for them, SkillLine.dbc has the two
skills, SkillLineAbility.dbc maps 815 -> skill 139 and 817 -> 141 with
AcquireMethod 2 ("grant the skill when the spell is learned"),
SkillRaceClassInfo.dbc allows both to every race and class, and the core's own
lang_description pairs them with LANG_DEMONIC and LANG_KALIMAG. One field in
one file disagrees, and it is the field the client reads to build a
character's chat language menu.

What that cost: selling 'Demonic' through mod-languages left a Human knowing
Common from two different spells, which is a state the stock game cannot
produce, and the client answered by showing an EMPTY language menu.

Why the fix goes in the database
--------------------------------

`spell_dbc` is the core's own override mechanism for Spell.dbc:
DBCDatabaseLoader::Load reads every row of it after the file and, in its own
words, "If exist in DBC file override from DB" - a row whose ID already exists
replaces the file's row outright. So the correction is data, it lives in git,
and it survives re-extracting the DBCs from the client.

Because the loader writes every numeric field from SQL, the row has to be a
complete copy of the stock row with the one field changed - which is what this
generates, from the stock file, rather than leaving 234 columns to be typed by
hand. String columns are left empty on purpose: this core treats an empty
string column as "not overridden" and keeps the file's own text.

The client needs the same change, because the menu is built client side.
gen_spell_dbc.py ships these two rows into patch-W by the same rule the server
applies here, reading them back out of `spell_dbc` so there is one source of
truth and the two copies cannot drift.

Usage
-----

    tools/gen_language_spells.py            write sql/29_language_spells.sql
    tools/gen_language_spells.py --verify   compare the LIVE spell_dbc rows
                                            against the stock file plus the
                                            intended change, field by field
"""

import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

SOURCE = ROOT / "run/data/dbc/Spell.dbc"
OUTPUT = ROOT / "sql/29_language_spells.sql"

FIELDS = 234
ROW_SIZE = 936

EFFECT_MISC_VALUE_1 = 110       # the field that lies
EFFECT_1 = 71                   # must be 39, SPELL_EFFECT_LANGUAGE

SPELL_EFFECT_LANGUAGE = 39

# spell -> the Languages.dbc id it is named for, and the skill that carries it
# (SkillLineAbility.dbc, which already agrees - only the spell effect does not).
FIXES = {
    815: (8,  "Demonic", 139),
    817: (12, "Kalimag", 141),
}

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

    One column per format character, including the skipped ones - the loader
    walks both in lockstep and asserts the counts match.
    """
    rows = sql("""
        SELECT column_name, data_type, column_type FROM information_schema.columns
        WHERE table_schema = 'acore_world' AND table_name = 'spell_dbc'
        ORDER BY ordinal_position
    """)
    if len(rows) != FIELDS:
        sys.exit(f"spell_dbc has {len(rows)} columns, expected {FIELDS}")
    if len(SERVER_FORMAT) != FIELDS:
        sys.exit(f"format string is {len(SERVER_FORMAT)} chars, expected {FIELDS}")
    return [(name, data_type, "unsigned" in column_type) for name, data_type, column_type in rows]


def read_row(spell):
    data = SOURCE.read_bytes()
    magic, records, fields, row_size, _ = struct.unpack_from("<4sIIII", data, 0)
    if magic != b"WDBC":
        sys.exit(f"{SOURCE}: not a DBC file")
    if fields != FIELDS or row_size != ROW_SIZE:
        sys.exit(f"{SOURCE}: {fields} fields of {row_size} bytes, expected {FIELDS} of {ROW_SIZE}")

    for i in range(records):
        at = 20 + i * ROW_SIZE
        if struct.unpack_from("<I", data, at)[0] == spell:
            return list(struct.unpack_from(f"<{FIELDS}I", data, at))

    sys.exit(f"spell {spell} is not in {SOURCE}")


def corrected(spell):
    """The stock row with the language fixed, and the row's own data checked."""
    language, name, skill = FIXES[spell]
    values = read_row(spell)

    if values[EFFECT_1] != SPELL_EFFECT_LANGUAGE:
        sys.exit(f"spell {spell} Effect_1 is {values[EFFECT_1]}, not {SPELL_EFFECT_LANGUAGE} "
                 "(SPELL_EFFECT_LANGUAGE) - this is not a language spell, refusing to touch it")
    if values[EFFECT_MISC_VALUE_1] == language:
        print(f"  spell {spell} already grants {language} ({name}); the stock file has been patched "
              "or the client is not 3.3.5a - emitting it anyway, which is a no-op")

    print(f"  {spell} -> language {language} ({name}), skill {skill}"
          f"   was {values[EFFECT_MISC_VALUE_1]}")
    values[EFFECT_MISC_VALUE_1] = language
    return values


def literal(value, data_type, unsigned):
    """One SQL literal, in the form the loader will read back unchanged.

    Numeric fields are written; string fields are left empty, which this core
    reads as "not overridden" so the file's own text survives.
    """
    if data_type in ("float", "double", "decimal"):
        return repr(struct.unpack("<f", struct.pack("<I", value))[0])
    if data_type in ("varchar", "text", "char", "tinytext", "mediumtext"):
        return "''"
    if unsigned:
        return str(value)
    return str(value - (1 << 32) if value >= (1 << 31) else value)


def generate(cols):
    names = ", ".join(f"`{name}`" for name, _, _ in cols)
    statements = []

    for spell in sorted(FIXES):
        values = corrected(spell)
        row = ", ".join(literal(v, data_type, unsigned)
                        for v, (_, data_type, unsigned) in zip(values, cols))
        statements.append(f"REPLACE INTO `spell_dbc` ({names}) VALUES\n({row});")

    language_notes = "\n".join(
        f"--   {spell:>4}  grants {FIXES[spell][0]:>2} ({FIXES[spell][1]}), carried by skill {FIXES[spell][2]}"
        for spell in sorted(FIXES))

    OUTPUT.write_text(f"""\
-- ---------------------------------------------------------------------------
-- Make spells 815 and 817 grant the languages they are named after
--
-- GENERATED by tools/gen_language_spells.py from the stock
-- run/data/dbc/Spell.dbc - do not edit these rows by hand. Run that script
-- again to rebuild them, and with --verify to check the live table against
-- the stock file field by field.
--
-- Stock Spell.dbc gives both of these EffectMiscValue_1 = 7, which is Common,
-- although every other file in the client and the core's own lang_description
-- call them Demonic and Kalimag. The client builds a character's chat language
-- menu from the languages its known spells grant, so buying 'Demonic' left a
-- Human knowing Common from two spells and EMPTIED the menu.
--
-- Corrected here:
{language_notes}
--
-- Each row is a full copy of the stock row with that one field changed,
-- because DBCDatabaseLoader::Load writes every numeric field from SQL. String
-- columns are deliberately empty: this core reads an empty string column as
-- "not overridden" and keeps the file's own text.
--
-- The client needs the same correction, since the menu is built client side.
-- tools/gen_spell_dbc.py ships these two rows into patch-W, reading them back
-- out of this table so the two copies cannot drift.
--
-- Takes effect at WORLD SERVER STARTUP ONLY: spell_dbc is read once, while the
-- DBC stores are built. There is no reload for it.
--
-- To revert: DELETE FROM spell_dbc WHERE ID IN ({", ".join(str(s) for s in sorted(FIXES))});
-- and remove the two teacher rows from sql/05_language_teachers.sql again.
--
-- Idempotent: REPLACE, so safe to run more than once.
-- ---------------------------------------------------------------------------

{chr(10).join(statements)}
""")
    print(f"wrote {OUTPUT.relative_to(ROOT)} ({OUTPUT.stat().st_size / 1024:.0f} KB)")


def verify(cols):
    """Compare the live table against the stock file plus the intended change.

    A 234 column row written by a script is only as good as the field mapping,
    and a wrong mapping would quietly redefine a stock spell. This reads back
    what the server will actually load.
    """
    names = ", ".join(f"`{name}`" for name, _, _ in cols)
    bad = 0

    for spell in sorted(FIXES):
        rows = sql(f"SELECT {names} FROM `spell_dbc` WHERE `ID` = {spell}")
        if not rows:
            print(f"  spell {spell}: NOT in spell_dbc - apply {OUTPUT.name}")
            bad += 1
            continue

        want = corrected(spell)
        for i, (raw, (name, data_type, unsigned)) in enumerate(zip(rows[0], cols)):
            if SERVER_FORMAT[i] in "xs":
                continue                     # skipped by the loader, or kept from the file
            expected = literal(want[i], data_type, unsigned)
            got = raw.strip()
            if data_type in ("float", "double", "decimal"):
                if float(got) != float(expected):
                    print(f"  spell {spell} field {i} ({name}): live {got}, stock {expected}")
                    bad += 1
            elif int(got) != int(expected):
                print(f"  spell {spell} field {i} ({name}): live {got}, stock {expected}")
                bad += 1

    if bad:
        sys.exit(f"{bad} field(s) disagree with the stock file")
    print("  every numeric field matches the stock row, with the language corrected")


def main():
    cols = columns()
    if "--verify" in sys.argv[1:]:
        verify(cols)
    else:
        generate(cols)


if __name__ == "__main__":
    main()
