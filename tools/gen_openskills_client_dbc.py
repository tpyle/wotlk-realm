#!/usr/bin/env python3
"""
Make the client agree with mod-openskills about who may hold a skill.

mod-openskills opens two DBC columns so that any class can hold a weapon
proficiency, an armour proficiency or Lockpicking:

    SkillLineAbility.ClassMask      whether a trainer will teach the spell
    SkillRaceClassInfo.ClassMask    whether learning it grants the skill, and
                                    whether a character keeps it at login

BOTH are patched here, and the second one was the whole lesson. The first cut
of this script did SkillRaceClassInfo only, on the reasoning that it is what
decides whether a class may hold a skill - and it was not enough. A level 80
hunter at a hunter trainer saw no Plate Mail, because the client checks its own
SkillLineAbility.ClassMask before listing a trainer spell, and that still said
0x23: warrior, paladin, death knight.

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

It packs its own archive, client-patch/patch-Y.MPQ, so there is nothing to run
afterwards but the copy into the client's Data folder. No server restart:
nothing the server reads has changed.
"""

import re
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path("/root/classic")
# (source, staged name, the field to open, what to open it to)
#
# SkillRaceClassInfo takes 0xFFFFFFFF rather than 0, which is what
# mod-openskills writes server side. Both read as "every class" to the core,
# whose test is `ClassMask && !(ClassMask & bit)` - a zero short-circuits - but
# only the full mask is also right under the other convention, and what the
# client does with these columns is not ours to read. Matching the server
# exactly costs nothing.
#
# SkillLineAbility takes 0, because there 0 is unambiguously "no restriction":
# most rows in the file carry it, including every mount.
SOURCE = ROOT / "run/data/dbc/SkillRaceClassInfo.dbc"
SOURCE_ABILITY = ROOT / "run/data/dbc/SkillLineAbility.dbc"
# Its own staging directory and its own archive, rather than riding along in
# patch-Z.
#
# patch-Z is 32MB, almost all of it the goblin model folder and the merged HD
# DBCs, and it has to be recopied in full every time this one small file
# changes - which is every time OpenSkills.Extra changes. This is a few
# kilobytes instead.
#
# The name has to sort after patch-A, because mod-worgoblin ships its own
# SkillRaceClassInfo.dbc there and the client loads patch-?.MPQ in name order
# with later ones winning. Y is after A, F, G and H, and before Z - which is
# fine as long as Z does not also carry this file, or Z would win and the split
# would quietly do nothing. The pack step below is what keeps that honest: it
# removes the file from patch-Z's staging if it is there.
STAGING_DIR = ROOT / "client-patch/staging-skills"
STAGING = STAGING_DIR / "DBFilesClient/SkillRaceClassInfo.dbc"
STAGING_ABILITY = STAGING_DIR / "DBFilesClient/SkillLineAbility.dbc"
SHARED_STAGING = ROOT / "client-patch/staging/DBFilesClient/SkillRaceClassInfo.dbc"
ARCHIVE = ROOT / "client-patch/patch-Y.MPQ"
PACKER = ROOT / "tools/mpq_pack"
SKILL_ID_LIST = ROOT / "server/modules/mod-openskills/src/SkillIdList.h"
CONF = ROOT / "run/etc/modules/mod_openskills.conf"

# Field indices from the core's SkillRaceClassInfoEntry (DBCStructure.h).
I_SKILL_ID, I_CLASS_MASK = 1, 3

# And from SkillLineAbilityEntry: SkillLine at 1, ClassMask at 4.
I_ABILITY_SKILL_LINE, I_ABILITY_CLASS_MASK = 1, 4

ALL_CLASSES = 0xFFFFFFFF
UNRESTRICTED = 0


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


def open_masks(source, staged, skills, skill_field, mask_field, open_to):
    """Rewrite one DBC with the configured skills' ClassMask opened."""
    data = bytearray(source.read_bytes())
    magic, records, fields, record_size, _ = struct.unpack_from("<4sIIII", data, 0)

    if magic != b"WDBC":
        sys.exit(f"{source}: not a WDBC file")

    if fields * 4 != record_size:
        sys.exit(f"{source}: {fields} fields do not fill a {record_size} byte record")

    if max(skill_field, mask_field) >= fields:
        sys.exit(f"{source}: only {fields} fields, expected the mask at {mask_field}")

    opened = 0
    already = 0

    for record in range(records):
        base = 20 + record * record_size
        skill_id = struct.unpack_from("<I", data, base + skill_field * 4)[0]

        if skill_id not in skills:
            continue

        if struct.unpack_from("<I", data, base + mask_field * 4)[0] == open_to:
            already += 1
            continue

        struct.pack_into("<I", data, base + mask_field * 4, open_to)
        opened += 1

    staged.parent.mkdir(parents=True, exist_ok=True)
    staged.write_bytes(data)

    print(f"{staged.name}: opened {opened} row(s), {already} already open, of {records}")
    return opened + already


def main():
    skills = module_skills()
    print(f"{len(skills)} skill(s) configured open: {', '.join(map(str, skills))}")

    touched = 0
    touched += open_masks(SOURCE, STAGING, skills, I_SKILL_ID, I_CLASS_MASK, ALL_CLASSES)
    touched += open_masks(SOURCE_ABILITY, STAGING_ABILITY, skills,
                          I_ABILITY_SKILL_LINE, I_ABILITY_CLASS_MASK, UNRESTRICTED)

    if not touched:
        sys.exit("no row matched any configured skill - check the ids")

    print(f"{SOURCE.parent}: left untouched - mod-openskills owns the server side in memory")

    # patch-Z must not carry these as well, or it would win on name order and
    # this archive would be decorative.
    for stale in (ROOT / "client-patch/staging/DBFilesClient/SkillRaceClassInfo.dbc",
                  ROOT / "client-patch/staging/DBFilesClient/SkillLineAbility.dbc"):
        if stale.exists():
            stale.unlink()
            print(f"{stale}: removed, so patch-Z stops shipping it")
            print("  patch-Z needs one more repack to drop it: tools/install_worgoblin_dbc.sh --client-only")

    if not PACKER.exists():
        sys.exit(f"{PACKER} is missing; build it before packing")

    result = subprocess.run([str(PACKER), str(ARCHIVE), str(STAGING_DIR)],
                            capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"packing {ARCHIVE} failed: {result.stderr.strip()}")

    print(result.stdout.strip().splitlines()[-1] if result.stdout.strip() else f"wrote {ARCHIVE}")
    print(f"copy {ARCHIVE.name} into the client's Data folder")


if __name__ == "__main__":
    main()
