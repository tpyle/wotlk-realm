#!/usr/bin/env python3
"""
Make every hunter's starting ranged weapon match the proficiency their race
actually gets.

The bug this fixes: a Night Elf hunter was created holding an Old Blunderbuss
and Light Shot while `playercreateinfo_skills` gives Night Elves the *Bows*
skill, so the gun could not be fired and the bow was nowhere. It arrived when
mod-worgoblin's CharStartOutfit.dbc replaced ours - install_worgoblin_dbc.sh
refreshes the .orig baselines from the module, so its table became the
starting point, and it carries the gun kit for several bow races.

Rather than hand-correcting rows, the kit is *derived* from the skill:

    playercreateinfo_skills (classMask 4)   ->   starting ranged kit
        skill  45 Bows       ->  Worn Shortbow    + Light Quiver      + Rough Arrow
        skill  46 Guns       ->  Old Blunderbuss  + Small Ammo Pouch  + Light Shot
        skill 226 Crossbows  ->  Weathered Crossbow + Light Quiver    + Rough Arrow

so the two cannot disagree again: change the skill mask and the kit follows.
Races with an established starter weapon of their own keep it (Blood Elf's
Warder's Shortbow, Draenei's Weathered Crossbow).

Display data is never invented. Each item's DisplayItemID and InventoryType
are copied from a row that already uses that item somewhere in the file, so
the character-creation preview stays correct.

Runs against the live DBC rather than the .orig backup, because
gen_all_classes_dbc.py owns that file's baseline and fills in the missing
race/class combinations first. The order in install_worgoblin_dbc.sh is
therefore: classes, weapons, lockpicking, then this.

Usage:
  tools/gen_hunter_start_kits.py [--dbc-dir /root/classic/run/data/dbc]
"""

import argparse
import os
import shutil
import struct
import subprocess

HEADER = struct.Struct("<4siiii")
HUNTER_CLASS = 3
OUTFIT_ITEMS = 24

SKILL_BOWS, SKILL_GUNS, SKILL_CROSSBOWS = 45, 46, 226

# weapon, container, ammo - by the skill the race starts with
KITS = {
    SKILL_BOWS:      (2504, 2101, 2512),   # Worn Shortbow,      Light Quiver,     Rough Arrow
    SKILL_GUNS:      (2508, 2102, 2516),   # Old Blunderbuss,    Small Ammo Pouch, Light Shot
    SKILL_CROSSBOWS: (23347, 2101, 2512),  # Weathered Crossbow, Light Quiver,     Rough Arrow
}

# Races whose own starter weapon is kept instead of the generic one.
RACE_WEAPON = {
    10: 20980,   # Blood Elf - Warder's Shortbow
    11: 23347,   # Draenei   - Weathered Crossbow
}

# Everything that counts as part of a starting ranged kit, so the old one can
# be recognised whatever it is.
WEAPONS    = {2504, 2508, 23347, 20980}
CONTAINERS = {2101, 2102}
AMMO       = {2512, 2516}


def query_skill_masks():
    """raceMask per ranged skill, straight out of playercreateinfo_skills."""
    sql = ("SELECT skill, raceMask FROM playercreateinfo_skills "
           f"WHERE classMask = 4 AND skill IN ({SKILL_BOWS}, {SKILL_GUNS}, {SKILL_CROSSBOWS})")
    out = subprocess.run(
        ["mysql", "-uacore", "-pacore", "-h127.0.0.1", "acore_world", "-N", "-B", "-e", sql],
        capture_output=True, text=True, check=True).stdout

    masks = {}
    for line in out.splitlines():
        if not line.strip():
            continue
        skill, mask = line.split("\t")
        masks[int(skill)] = int(mask)
    return masks


def read_dbc(path):
    with open(path, "rb") as handle:
        data = handle.read()

    magic, records, fields, record_size, string_size = HEADER.unpack_from(data, 0)
    if magic != b"WDBC":
        raise SystemExit(f"{path}: not a DBC file")

    # The header's field count disagrees with the record size in this file
    # (77 against 296/4 = 74), so the record size is what is trusted.
    count = record_size // 4
    body = data[HEADER.size:HEADER.size + records * record_size]
    strings = data[HEADER.size + records * record_size:]
    rows = [list(struct.unpack_from(f"<{count}I", body, i * record_size)) for i in range(records)]
    return rows, fields, record_size, strings


def write_dbc(path, rows, fields, record_size, strings):
    count = record_size // 4
    with open(path, "wb") as handle:
        handle.write(HEADER.pack(b"WDBC", len(rows), fields, record_size, len(strings)))
        for row in rows:
            handle.write(struct.pack(f"<{count}I", *row))
        handle.write(strings)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dbc-dir", default="/root/classic/run/data/dbc")
    args = parser.parse_args()

    path = os.path.join(args.dbc_dir, "CharStartOutfit.dbc")
    if not os.path.exists(path + ".hunterkits.orig"):
        shutil.copy2(path, path + ".hunterkits.orig")

    masks = query_skill_masks()
    if not masks:
        raise SystemExit("no hunter ranged skills found in playercreateinfo_skills")

    rows, fields, record_size, strings = read_dbc(path)

    # ItemID[24] at 2, DisplayItemID[24] at 26, InventoryType[24] at 50.
    ITEM, DISPLAY, INVTYPE = 2, 2 + OUTFIT_ITEMS, 2 + 2 * OUTFIT_ITEMS

    # What display id and inventory type the game already uses for each item.
    known = {}
    for row in rows:
        for slot in range(OUTFIT_ITEMS):
            item = row[ITEM + slot]
            if item and item != 0xFFFFFFFF:
                known.setdefault(item, (row[DISPLAY + slot], row[INVTYPE + slot]))

    def skill_for(race):
        for skill, mask in masks.items():
            if mask & (1 << (race - 1)):
                return skill
        return None

    changed = 0
    for row in rows:
        packed = row[1]
        race, class_ = packed & 0xFF, (packed >> 8) & 0xFF
        if class_ != HUNTER_CLASS:
            continue

        skill = skill_for(race)
        if skill is None:
            print(f"  race {race}: no ranged skill in playercreateinfo_skills, left alone")
            continue

        weapon, container, ammo = KITS[skill]
        weapon = RACE_WEAPON.get(race, weapon)
        wanted = {"weapon": weapon, "container": container, "ammo": ammo}

        for slot in range(OUTFIT_ITEMS):
            item = row[ITEM + slot]
            kind = ("weapon" if item in WEAPONS else
                    "container" if item in CONTAINERS else
                    "ammo" if item in AMMO else None)
            if kind is None:
                continue

            target = wanted[kind]
            if item == target:
                continue

            if target not in known:
                print(f"  race {race}: item {target} appears nowhere in the file, skipped")
                continue

            row[ITEM + slot] = target
            row[DISPLAY + slot], row[INVTYPE + slot] = known[target]
            print(f"  race {race} gender {(packed >> 16) & 0xFF}: {kind} {item} -> {target}")
            changed += 1

    write_dbc(path, rows, fields, record_size, strings)
    print(f"CharStartOutfit.dbc: {changed} hunter kit item(s) corrected")
    if changed:
        print("The world server has to be restarted to read the changed file.")


if __name__ == "__main__":
    main()
