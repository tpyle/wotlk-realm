#!/usr/bin/env python3
"""
Make the client agree with mod-openskills about who may hold a skill.

mod-openskills opens two DBC columns so that any class can hold a weapon
proficiency or Lockpicking:

    SkillLineAbility.ClassMask      whether a trainer will teach the spell
    SkillRaceClassInfo.ClassMask    whether learning it grants the skill, and
                                    whether a character keeps it at login

It opens them in memory at startup and deliberately touches no file, which is
right for the server - a skill dropped from the configuration closes again on
"reload config", and re-extracting the DBCs cannot revert it. But the CLIENT
reads its own copy, and that copy still says Lockpicking belongs to rogues. So
a warrior who has the skill, with a value the server is happily raising, sees
nothing on the skill sheet: the server sends it and the client declines to draw
a skill its own data says that class cannot have.

This writes the patched file for the client only. The server's copy is left
exactly as it is, so the module stays the single authority there and the
.orig-restore trap that the module was written to escape cannot come back.

Only ClassMask moves, and only to 0. RaceMask, Flags, MinLevel and SkillTierID
are untouched, so nothing else about the skill changes.

The skill list is read from the module itself - WeaponSkills() and LOCKPICKING
in src/SkillIdList.h - and gated on the live configuration, so this cannot
drift from what the module actually opens.

After running it, repack the client patch and recopy it:

    tools/install_worgoblin_dbc.sh --client-only

No server restart: nothing the server reads has changed.
"""

import re
import struct
import sys
from pathlib import Path

ROOT = Path("/root/classic")
SOURCE = ROOT / "run/data/dbc/SkillRaceClassInfo.dbc"
STAGING = ROOT / "client-patch/staging/DBFilesClient/SkillRaceClassInfo.dbc"
SKILL_ID_LIST = ROOT / "server/modules/mod-openskills/src/SkillIdList.h"
CONF = ROOT / "run/etc/modules/mod_openskills.conf"

# Field indices from the core's SkillRaceClassInfoEntry (DBCStructure.h).
I_SKILL_ID, I_CLASS_MASK = 1, 3


def module_skills():
    """The ids the module would open, from its own header and the live conf."""
    header = SKILL_ID_LIST.read_text()

    weapons_match = re.search(r"WeaponSkills\(\)\s*\{\s*return\s*\{([^}]*)\}", header, re.S)
    if not weapons_match:
        sys.exit(f"{SKILL_ID_LIST}: could not find WeaponSkills()")
    weapons = [int(n) for n in re.findall(r"\d+", weapons_match.group(1))]

    lock_match = re.search(r"LOCKPICKING\s*=\s*(\d+)", header)
    if not lock_match:
        sys.exit(f"{SKILL_ID_LIST}: could not find LOCKPICKING")
    lockpicking = int(lock_match.group(1))

    conf = CONF.read_text() if CONF.exists() else ""

    def option(name, default="1"):
        found = re.search(rf"^{re.escape(name)}\s*=\s*(.*)$", conf, re.M)
        return (found.group(1).strip() if found else default).strip('"')

    if option("OpenSkills.Enable") != "1":
        sys.exit("OpenSkills.Enable is 0; the server is not opening anything, so neither will this")

    wanted = []
    if option("OpenSkills.Weapons") == "1":
        wanted += weapons
    if option("OpenSkills.Lockpicking") == "1":
        wanted.append(lockpicking)
    wanted += [int(n) for n in re.findall(r"\d+", option("OpenSkills.Extra", ""))]

    # Preserve order, drop duplicates, exactly as SkillsToOpen does.
    seen = []
    for skill in wanted:
        if skill not in seen:
            seen.append(skill)

    return seen


def main():
    skills = module_skills()
    print(f"{len(skills)} skill(s) configured open: {', '.join(map(str, skills))}")

    data = bytearray(SOURCE.read_bytes())
    magic, records, fields, record_size, _ = struct.unpack_from("<4sIIII", data, 0)

    if magic != b"WDBC":
        sys.exit(f"{SOURCE}: not a WDBC file")

    if fields * 4 != record_size:
        sys.exit(f"{SOURCE}: {fields} fields do not fill a {record_size} byte record")

    if I_CLASS_MASK >= fields:
        sys.exit(f"{SOURCE}: only {fields} fields, expected ClassMask at {I_CLASS_MASK}")

    opened = 0
    already = 0

    for record in range(records):
        base = 20 + record * record_size
        skill_id = struct.unpack_from("<I", data, base + I_SKILL_ID * 4)[0]

        if skill_id not in skills:
            continue

        class_mask = struct.unpack_from("<I", data, base + I_CLASS_MASK * 4)[0]
        if class_mask == 0:
            already += 1
            continue

        struct.pack_into("<I", data, base + I_CLASS_MASK * 4, 0)
        opened += 1

    if not STAGING.parent.is_dir():
        sys.exit(f"{STAGING.parent} is missing; run tools/install_worgoblin_dbc.sh first")

    STAGING.write_bytes(data)

    print(f"{STAGING}: opened {opened} row(s), {already} already open, of {records}")
    print(f"{SOURCE}: left untouched - mod-openskills owns the server side in memory")
    print("now: tools/install_worgoblin_dbc.sh --client-only, then recopy patch-Z.MPQ")


if __name__ == "__main__":
    main()
