#!/usr/bin/env python3
"""
Let every class learn every weapon skill from the weapon masters.

Two server side DBCs decide whether a trainer will teach a weapon skill.
Player::IsSpellFitByClassAndRace(), which Trainer.cpp consults both when
listing spells and when selling one, checks:

  SkillLineAbility.dbc  - the ClassMask on the ability row; 0 means no class
                          restriction at all
  SkillRaceClassInfo.dbc - there has to be a row whose race and class masks
                          match the character

So this script clears the class restriction on the trainer-taught weapon
proficiencies and opens up the race/class rows for those skills. Neither file
is used by the client for this - trainer lists are built server side - so no
client patch is needed.

Deliberately untouched: the automatic abilities that share these skill lines
(Shoot, Throw) and every other skill line, including the racial weapon
specialisations, which live elsewhere and stay class/race locked.

Idempotent: the originals are kept as <file>.orig and every run starts from
them.
"""

import argparse
import os
import shutil
import struct

HEADER = struct.Struct("<4siiii")

# id -> name, for the log
WEAPON_SKILLS = {
    43: "Swords", 44: "Axes", 45: "Bows", 46: "Guns", 54: "Maces",
    55: "Two-Handed Swords", 136: "Staves", 160: "Two-Handed Maces",
    172: "Two-Handed Axes", 173: "Daggers", 176: "Thrown", 226: "Crossbows",
    228: "Wands", 229: "Polearms", 473: "Fist Weapons",
}

ALL_MASK = 0xFFFFFFFF

# SkillLineAbility field indices (see SkillLineAbilityEntry)
SLA_SKILL_LINE, SLA_SPELL, SLA_RACE_MASK, SLA_CLASS_MASK, SLA_ACQUIRE = 1, 2, 3, 4, 9
ACQUIRE_FROM_TRAINER = 2

# SkillRaceClassInfo field indices (see SkillRaceClassInfoEntry)
SRCI_SKILL, SRCI_RACE_MASK, SRCI_CLASS_MASK = 1, 2, 3


def original_of(path):
    backup = path + ".orig"
    if not os.path.exists(backup):
        shutil.copy2(path, backup)
    return backup


def read_dbc(path):
    with open(path, "rb") as handle:
        blob = handle.read()

    magic, records, fields, record_size, string_size = HEADER.unpack_from(blob, 0)
    if magic != b"WDBC":
        raise SystemExit(f"{path}: not a WDBC file")

    start = HEADER.size
    rows = [bytearray(blob[start + i * record_size: start + (i + 1) * record_size])
            for i in range(records)]
    strings = blob[start + records * record_size:][:string_size]
    return rows, fields, record_size, strings


def write_dbc(path, rows, fields, record_size, strings):
    with open(path, "wb") as handle:
        handle.write(HEADER.pack(b"WDBC", len(rows), fields, record_size, len(strings)))
        for row in rows:
            handle.write(row)
        handle.write(strings)


def field(row, index):
    return struct.unpack_from("<I", row, index * 4)[0]


def set_field(row, index, value):
    struct.pack_into("<I", row, index * 4, value)


def patch_skill_line_ability(path):
    rows, fields, record_size, strings = read_dbc(original_of(path))
    changed = []

    for row in rows:
        skill = field(row, SLA_SKILL_LINE)
        if skill not in WEAPON_SKILLS:
            continue

        # Only the proficiencies a trainer teaches. The automatic abilities on
        # these lines (Shoot, Throw) keep their class restrictions.
        if field(row, SLA_ACQUIRE) != ACQUIRE_FROM_TRAINER:
            continue

        if field(row, SLA_CLASS_MASK) == 0:
            continue

        changed.append((WEAPON_SKILLS[skill], field(row, SLA_SPELL), field(row, SLA_CLASS_MASK)))
        set_field(row, SLA_CLASS_MASK, 0)   # 0 = every class
        set_field(row, SLA_RACE_MASK, 0)    # already 0 for these, kept explicit

    write_dbc(path, rows, fields, record_size, strings)
    return changed


def patch_skill_race_class_info(path):
    rows, fields, record_size, strings = read_dbc(original_of(path))
    changed = 0

    for row in rows:
        if field(row, SRCI_SKILL) not in WEAPON_SKILLS:
            continue

        if field(row, SRCI_RACE_MASK) == ALL_MASK and field(row, SRCI_CLASS_MASK) == ALL_MASK:
            continue

        set_field(row, SRCI_RACE_MASK, ALL_MASK)
        set_field(row, SRCI_CLASS_MASK, ALL_MASK)
        changed += 1

    write_dbc(path, rows, fields, record_size, strings)
    return changed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dbc-dir", default="/root/classic/run/data/dbc")
    args = parser.parse_args()

    opened = patch_skill_line_ability(os.path.join(args.dbc_dir, "SkillLineAbility.dbc"))
    print(f"SkillLineAbility.dbc:   opened up {len(opened)} weapon proficiency/proficiencies")
    for name, spell, old_mask in sorted(opened):
        print(f"  {name:<18} spell {spell:<6} class mask {old_mask:#x} -> 0 (any class)")

    rows = patch_skill_race_class_info(os.path.join(args.dbc_dir, "SkillRaceClassInfo.dbc"))
    print(f"SkillRaceClassInfo.dbc: opened up {rows} race/class row(s) for weapon skills")


if __name__ == "__main__":
    main()
