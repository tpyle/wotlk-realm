#!/usr/bin/env python3
"""
Let every class learn lockpicking, not just rogues.

Two DBC rows say it is a rogue skill, and the server reads both:

  SkillRaceClassInfo   row 601 - skill 633 with ClassMask 8 (rogue).
                       Player::LearnDefaultSkill looks the skill up with
                       GetSkillRaceClassInfo(skill, race, class) and returns
                       without doing anything when no row matches, so a
                       non-rogue who somehow knew Pick Lock would still have
                       no lockpicking skill to pick with.
  SkillLineAbility     row 8439 - spell 1804 (Pick Lock) with ClassMask 8.
                       This is what Player::IsSpellFitByClassAndRace tests, so
                       it decides whether a trainer will teach the spell at
                       all.

Both masks are opened here, the same way tools/gen_all_weapons_dbc.py opens
the weapon skills. Note that Player.cpp grants the skill automatically when
the *spell* is learned (the SKILL_LOCKPICKING special case, which fires
because row 8439 has TrivialSkillLineRankHigh 0), so learning Pick Lock is
the whole of it - there is no second step.

Server side only. The client is told a character's skills and the trainer's
spell list by the server, so nothing here has to reach the client - the same
was true of the weapon skills.

Idempotent: the original is kept as <file>.orig and every run starts from it.

Usage:
  tools/gen_lockpicking_dbc.py [--dbc-dir /root/classic/run/data/dbc]
"""

import argparse
import os
import shutil
import struct

HEADER = struct.Struct("<4siiii")

LOCKPICKING = 633
PICK_LOCK = 1804
ALL_MASK = 0xFFFFFFFF

SLA_SKILL_LINE, SLA_SPELL, SLA_CLASS_MASK = 1, 2, 4
SRCI_SKILL, SRCI_CLASS_MASK = 1, 3


def read_dbc(path):
    with open(path, "rb") as handle:
        data = handle.read()

    magic, records, fields, record_size, string_size = HEADER.unpack_from(data, 0)
    if magic != b"WDBC":
        raise SystemExit(f"{path}: not a DBC file")

    body = data[HEADER.size:HEADER.size + records * record_size]
    strings = data[HEADER.size + records * record_size:]
    rows = [list(struct.unpack_from(f"<{fields}I", body, i * record_size)) for i in range(records)]
    return rows, fields, record_size, strings


def write_dbc(path, rows, fields, record_size, strings):
    with open(path, "wb") as handle:
        handle.write(HEADER.pack(b"WDBC", len(rows), fields, record_size, len(strings)))
        for row in rows:
            handle.write(struct.pack(f"<{fields}I", *row))
        handle.write(strings)


def keep_original(path):
    """Back the file up once, but read the *live* file.

    The other two generators start from their .orig copy, because each one
    owns the whole of what it writes. This one does not: it opens two masks
    that gen_all_weapons_dbc.py has also been editing in the same two files,
    so reading .orig here would silently undo "every class can learn every
    weapon". (It did, once.) The edits are additive and the script checks
    before writing, so working from the live file is idempotent anyway.

    The order in tools/install_worgoblin_dbc.sh is therefore: classes,
    weapons (both from .orig), then lockpicking on top.
    """
    backup = path + ".orig"
    if not os.path.exists(backup):
        shutil.copy2(path, backup)
    return path


def open_skill_line_ability(path):
    rows, fields, record_size, strings = read_dbc(keep_original(path))
    changed = 0

    for row in rows:
        if row[SLA_SKILL_LINE] != LOCKPICKING or row[SLA_SPELL] != PICK_LOCK:
            continue
        if row[SLA_CLASS_MASK] == 0:
            continue

        print(f"  SkillLineAbility {row[0]}: spell {PICK_LOCK} class mask {row[SLA_CLASS_MASK]:#x} -> 0 (any class)")
        row[SLA_CLASS_MASK] = 0
        changed += 1

    write_dbc(path, rows, fields, record_size, strings)
    return changed


def open_skill_race_class_info(path):
    rows, fields, record_size, strings = read_dbc(keep_original(path))
    changed = 0

    for row in rows:
        if row[SRCI_SKILL] != LOCKPICKING:
            continue
        if row[SRCI_CLASS_MASK] == ALL_MASK:
            continue

        print(f"  SkillRaceClassInfo {row[0]}: class mask {row[SRCI_CLASS_MASK]:#x} -> every class")
        row[SRCI_CLASS_MASK] = ALL_MASK
        changed += 1

    write_dbc(path, rows, fields, record_size, strings)
    return changed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dbc-dir", default="/root/classic/run/data/dbc")
    args = parser.parse_args()

    print("Lockpicking for every class:")
    abilities = open_skill_line_ability(os.path.join(args.dbc_dir, "SkillLineAbility.dbc"))
    rows = open_skill_race_class_info(os.path.join(args.dbc_dir, "SkillRaceClassInfo.dbc"))

    if not abilities and not rows:
        print("  nothing to do - both masks are already open")

    print("The world server has to be restarted to read the changed files.")


if __name__ == "__main__":
    main()
