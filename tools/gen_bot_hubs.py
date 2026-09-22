#!/usr/bin/env python3
"""Build sql/14_bot_teleport_hubs.sql - quest hub destinations for random bots.

mod-playerbots picks a random bot's destination from TravelMgr's
locsPerLevelCache, which is built in PrepareDestinationCache() from *creature
spawn clusters* - and only from creatures that pass this filter:

    creatureTemplate->npcflag == 0 && creatureTemplate->lootid != 0 &&
    maxlevel - minlevel < 3 && spawntimesecs < 1000 && rank == 0 &&
    faction not in (11, 71, 79, 85, 188, 1575) && ...

Every quest giver, innkeeper, vendor and trainer carries an npcflag, so every
quest hub in the game is excluded by the first clause. That is deliberate - the
cache is a list of places worth grinding - but it means bots are only ever
found out in the mob fields, never at Goldshire or Eastvale where a player
actually spends time.

This script derives the hubs the cache leaves out, from the same spawn data:

  1. Take every creature carrying an npcflag - the quest givers, innkeepers,
     vendors, trainers and guards the filter above throws away - and group
     their spawns into the same 50 yard cells PrepareDestinationCache uses.
  2. Keep a cell when it holds at least one quest giver *and* at least two
     service NPCs. Both halves matter: quest givers alone miss Westbrook
     Garrison, where Deputy Rainer is the only one, while any pair of service
     NPCs lets in every roadside guard post (1519 cells rather than 962).
     A quest giver with somebody else standing next to them is a hub.
  3. Give each hub the level band of the country around it, by taking the
     median level of the grindable mobs within 250 yards and applying the same
     spread the fork uses for its own destinations (randomBotTeleLowerLevel 1,
     randomBotTeleHigherLevel 3). The mobs are the honest signal: a hub exists
     to send you at what is nearby, and this is the same population the rest
     of the cache is built from.
  4. Where a hub has no mobs near it at all - the inside of a capital, mostly -
     fall back to the median MinLevel of the quests handed out there. Cities
     are already covered by GetCityLocations, so this only rescues the odd
     outlying camp.
  5. Game event spawns are excluded throughout. 3125 of the level 1 Wild
     Turkeys from Pilgrim's Bounty sit in the world's creature table, and
     186 of them are within 250 yards of Goldshire - enough to drag its median
     to level 1 on their own. Holiday quest givers (Bountiful Table Hostess,
     Costumed Orphan Matron) would likewise invent hubs that only exist for a
     week a year.

The result is a table the module reads at startup, so adding or removing a hub
afterwards is a row and a restart, not a rebuild.
"""

import os
import statistics
import subprocess

CELL = 50.0          # the grid PrepareDestinationCache quantises to
MOB_RADIUS = 250.0   # how far around a hub to look for its level
LOWER, UPPER = 1, 3  # randomBotTeleLowerLevel / randomBotTeleHigherLevel
MIN_GIVERS = 1       # quest givers needed in a cell
MIN_SERVICE = 2      # npcflag-carrying NPCs needed in a cell
MAX_LEVEL = 80


def load(path):
    with open(path) as handle:
        for line in handle:
            line = line.rstrip("\n")
            if line:
                yield line.split("\t")


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(here)

    # service NPCs -> hub cells
    cells = {}
    for mapid, x, y, z, entry, name, is_giver in load("/tmp/hubnpcs.tsv"):
        key = (int(mapid), round(float(x) / CELL), round(float(y) / CELL))
        cell = cells.setdefault(key, {"pos": [], "entries": set(), "givers": set(),
                                      "names": set()})
        cell["pos"].append((float(x), float(y), float(z)))
        cell["entries"].add(int(entry))
        cell["names"].add(name)
        if is_giver == "1":
            cell["givers"].add(int(entry))
            cell["names"].add(name)

    hubs = {k: v for k, v in cells.items()
            if len(v["givers"]) >= MIN_GIVERS and len(v["entries"]) >= MIN_SERVICE}

    # mobs bucketed by a coarse grid so the radius search stays cheap
    buckets = {}
    for mapid, x, y, level in load("/tmp/mobs.tsv"):
        key = (int(mapid), int(float(x) // MOB_RADIUS), int(float(y) // MOB_RADIUS))
        buckets.setdefault(key, []).append((float(x), float(y), float(level)))

    # quest MinLevel per giver, for the fallback
    giver_levels = {}
    for entry, minlevel in load("/tmp/questlevels.tsv"):
        giver_levels.setdefault(int(entry), []).append(int(minlevel))

    rows = []
    from_mobs = from_quests = skipped = 0
    for (mapid, gx, gy), cell in sorted(hubs.items()):
        cx = sum(p[0] for p in cell["pos"]) / len(cell["pos"])
        cy = sum(p[1] for p in cell["pos"]) / len(cell["pos"])
        cz = sum(p[2] for p in cell["pos"]) / len(cell["pos"])

        near = []
        bx, by = int(cx // MOB_RADIUS), int(cy // MOB_RADIUS)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for mx, my, lvl in buckets.get((mapid, bx + dx, by + dy), ()):
                    if (mx - cx) ** 2 + (my - cy) ** 2 <= MOB_RADIUS ** 2:
                        near.append(lvl)

        if near:
            mid = statistics.median(near)
            low, high = int(mid) - LOWER, int(mid) + UPPER
            source = "mobs"
            from_mobs += 1
        else:
            quest_levels = [l for e in cell["givers"] for l in giver_levels.get(e, ())]
            if not quest_levels:
                skipped += 1
                continue
            # Median, not min..max. A capital's quest board spans the whole
            # game - Stormwind hands out level 1 errands and Argent Dawn work
            # in the same courtyard - and a band of 1-80 would offer that hub
            # to every bot on the server.
            mid = statistics.median(quest_levels)
            low, high = int(mid) - LOWER, int(mid) + UPPER
            source = "quests"
            from_quests += 1

        low = max(1, min(low, MAX_LEVEL))
        high = max(low, min(high, MAX_LEVEL))

        names = sorted(cell["names"])
        label = ", ".join(names[:3]) + ("..." if len(names) > 3 else "")
        rows.append((mapid, cx, cy, cz, low, high,
                     f"{len(cell['givers'])} quest giver(s) of {len(cell['entries'])} "
                     f"npcs, level by {source}: {label}"[:190]))

    out = os.path.join(root, "sql", "14_bot_teleport_hubs.sql")
    with open(out, "w") as f:
        f.write(HEADER)
        f.write("INSERT INTO `playerbot_teleport_hub` "
                "(`MapId`, `PositionX`, `PositionY`, `PositionZ`, `MinLevel`, `MaxLevel`, `Comment`) VALUES\n")
        parts = []
        for mapid, x, y, z, low, high, comment in rows:
            safe = comment.replace("\\", "\\\\").replace("'", "''")
            parts.append(f"({mapid}, {x:.2f}, {y:.2f}, {z:.2f}, {low}, {high}, '{safe}')")
        f.write(",\n".join(parts) + ";\n")

    print(f"wrote {os.path.relpath(out, root)}: {len(rows)} hubs "
          f"({from_mobs} levelled from nearby mobs, {from_quests} from quest levels, "
          f"{skipped} dropped with neither)")
    by_map = {}
    for r in rows:
        by_map[r[0]] = by_map.get(r[0], 0) + 1
    for mapid in sorted(by_map):
        print(f"  map {mapid}: {by_map[mapid]}")


HEADER = """-- ---------------------------------------------------------------------------
-- Quest hub destinations for random bots
--
-- Generated by tools/gen_bot_hubs.py - edit that, not this file.
--
-- mod-playerbots builds its random teleport destinations from creature spawn
-- clusters, and its filter starts with `npcflag == 0`. Every quest giver,
-- innkeeper and vendor has an npcflag, so every quest hub in the game is
-- excluded and bots are only ever found out in the mob fields. This table is
-- the hubs it leaves out, so the places a player actually stands have people
-- in them.
--
-- Read once at startup by TravelMgr::PrepareDestinationCache. Bots reach these
-- through their own roll (AiPlayerbot.ProbTeleToQuestHubs) rather than through
-- the ordinary destination pool, because the pool holds some 17500 mob cells
-- and a few hundred hubs mixed into it would never be picked.
--
-- MinLevel/MaxLevel are the bot levels the hub is offered to. They come from
-- the median level of the grindable mobs within 250 yards, spread by the same
-- amounts the fork uses for its own destinations.
--
-- Idempotent: safe to run more than once.
-- ---------------------------------------------------------------------------

DROP TABLE IF EXISTS `playerbot_teleport_hub`;
CREATE TABLE `playerbot_teleport_hub` (
  `Id`        int unsigned NOT NULL AUTO_INCREMENT,
  `MapId`     int unsigned NOT NULL,
  `PositionX` float NOT NULL,
  `PositionY` float NOT NULL,
  `PositionZ` float NOT NULL,
  `MinLevel`  tinyint unsigned NOT NULL DEFAULT '1',
  `MaxLevel`  tinyint unsigned NOT NULL DEFAULT '80',
  `Comment`   varchar(255) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `idx_level` (`MinLevel`,`MaxLevel`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

"""

if __name__ == "__main__":
    main()
