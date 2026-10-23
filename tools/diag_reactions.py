#!/usr/bin/env python3
"""Replay the core's reputation/reaction maths offline for a character.

Mirrors ReputationMgr::Initialize + LoadFromDB, then mod-factionchoice's
ReconcileFactionFlags and PinReactions, then Unit::GetFactionReactionTo, so the
set of NPCs a cross-faction character cannot talk to can be worked out without
a game client.

Run it with character names (or nothing, for every non-bot character), or with
--neutral to simulate a fresh neutral character of every playable race.
"""
import os, struct, subprocess, sys

DBC = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "run/data/dbc")

VISIBLE, AT_WAR, HIDDEN, INVISIBLE_FORCED, PEACE_FORCED, INACTIVE = 1, 2, 4, 8, 16, 32
FACTION_TEMPLATE_FLAG_ATTACK_PVP_ACTIVE_PLAYERS = 0x800
POINTS_IN_RANK = [36000, 3000, 3000, 3000, 6000, 12000, 21000, 1000]
REP_BOTTOM = -42000
RANKS = ["HATED", "HOSTILE", "UNFRIENDLY", "NEUTRAL", "FRIENDLY", "HONORED", "REVERED", "EXALTED"]
HATED, HOSTILE, UNFRIENDLY, NEUTRAL, FRIENDLY = 0, 1, 2, 3, 4


def read_dbc(name):
    d = open(f"{DBC}/{name}.dbc", "rb").read()
    _, rows, fields, rsz, _ = struct.unpack("<4siiii", d[:20])
    out = []
    for r in range(rows):
        out.append(struct.unpack("<%di" % fields, d[20 + r * rsz: 20 + (r + 1) * rsz]))
    return out


def rep_to_rank(standing):
    limit = REP_BOTTOM
    for i, pts in enumerate(POINTS_IN_RANK):
        limit += pts
        if standing < limit:
            return i
    return len(POINTS_IN_RANK) - 1


factions = {}       # id -> dict
by_replist = {}
for v in read_dbc("Faction"):
    f = dict(ID=v[0], repList=v[1], raceMask=v[2:6], classMask=v[6:10],
             baseRep=v[10:14], repFlags=v[14:18])
    factions[v[0]] = f
    if v[1] >= 0:
        by_replist[v[1]] = f

templates = {}
for v in read_dbc("FactionTemplate"):
    templates[v[0]] = dict(ID=v[0], faction=v[1], flags=v[2], ourMask=v[3],
                           friendlyMask=v[4], hostileMask=v[5],
                           enemies=v[6:10], friends=v[10:14])

races = {v[0]: v[2] for v in read_dbc("ChrRaces")}
playable = {v[0] for v in read_dbc("ChrRaces") if not v[1] & 1}   # CHRRACES_FLAGS_NOT_PLAYABLE


def base_row(f, race_mask, class_mask):
    """ReputationMgr::GetBaseReputation / GetDefaultStateFlags, for any mask."""
    for i in range(4):
        if ((f["raceMask"][i] & race_mask or (f["raceMask"][i] == 0 and f["classMask"][i] != 0))
                and (f["classMask"][i] & class_mask or f["classMask"][i] == 0)):
            return f["baseRep"][i], f["repFlags"][i]
    return 0, 0


NEUTRAL_TEMPLATE = 1665       # FactionChoice.Neutral.FactionTemplate
SIDE_NAMES = ["Alliance", "Horde", "neither side"]


def side_row(f, side, race_mask, class_mask):
    """mod-factionchoice BaselineFor: a side's starting value and flags. For
    neutral (2) the friendliest of the own race, the Alliance proxy and the
    Horde proxy - higher value first, then not at war - taken whole."""
    if side in (0, 1):
        return base_row(f, 1 << ((1 if side == 0 else 2) - 1), class_mask)
    best = None
    for mask in (race_mask, 1 << 0, 1 << 1):
        value, flags = base_row(f, mask, class_mask)
        if (best is None or value > best[0]
                or (value == best[0] and best[1] & AT_WAR and not flags & AT_WAR)):
            best = (value, flags)
    return best


def is_friendly_to(a, b):
    if a["faction"] == b["faction"]:
        return True
    if b["faction"]:
        if b["faction"] in a["enemies"]:
            return False
        if b["faction"] in a["friends"]:
            return True
    return bool(a["friendlyMask"] & b["ourMask"]) or bool(a["ourMask"] & b["friendlyMask"])


def is_hostile_to(a, b):
    if b["faction"]:
        if b["faction"] in a["enemies"]:
            return True
        if b["faction"] in a["friends"]:
            return False
    return bool(a["hostileMask"] & b["ourMask"])


def q(sql):
    out = subprocess.run(["mysql", "-uacore", "-pacore", "-h127.0.0.1", "-N", "-B", "-e", sql],
                         capture_output=True, text=True).stdout
    return [line.split("\t") for line in out.splitlines() if line]


def simulate(guid, name, race, klass, side, rebase=False, quiet=False):
    """side: 0 Alliance, 1 Horde, 2 neutral. rebase: the character has no saved
    rows yet, so apply the module's AlignReputations to its starting values."""
    race_mask, class_mask = 1 << (race - 1), 1 << (klass - 1)

    # --- ReputationMgr::Initialize(): flags from the character's own race ---
    state = {}
    for f in by_replist.values():
        _, flags = base_row(f, race_mask, class_mask)
        state[f["ID"]] = dict(standing=0, flags=flags)
        if rebase:
            own, _ = base_row(f, race_mask, class_mask)
            state[f["ID"]]["standing"] = side_row(f, side, race_mask, class_mask)[0] - own

    def effective(fid):
        f = factions[fid]
        base, _ = base_row(f, race_mask, class_mask)
        return base + state[fid]["standing"]

    def set_at_war(fid, on, respect_hidden=False):
        s = state[fid]
        if respect_hidden and s["flags"] & (INVISIBLE_FORCED | HIDDEN):
            return
        if on and s["flags"] & PEACE_FORCED:
            return
        s["flags"] = s["flags"] | AT_WAR if on else s["flags"] & ~AT_WAR

    # --- ReputationMgr::LoadFromDB ---
    for fid_s, standing_s, flags_s in q(
            f"SELECT faction,standing,flags FROM acore_characters.character_reputation WHERE guid={guid};"):
        fid = int(fid_s)
        if fid not in factions or factions[fid]["repList"] < 0:
            continue
        s = state[fid]
        s["standing"] = int(standing_s)
        db = int(flags_s)
        if db & VISIBLE:
            s["flags"] = (s["flags"] & ~HIDDEN) | VISIBLE      # SetVisible
        if db & AT_WAR:
            set_at_war(fid, not (db & HIDDEN) or rep_to_rank(effective(fid)) < NEUTRAL)
        elif s["flags"] & VISIBLE:
            set_at_war(fid, False)
        if rep_to_rank(effective(fid)) <= HOSTILE:
            set_at_war(fid, True)

    # --- mod-factionchoice: ReconcileFactionFlags ---
    # Adopt the whole flag set the chosen side would have been created with,
    # keeping a faction in the pane if it is already there and the new side
    # does not hide it outright. ADOPTED_FLAGS in mod_factionchoice.cpp.
    ADOPTED = VISIBLE | AT_WAR | HIDDEN | INVISIBLE_FORCED | PEACE_FORCED | 0x40 | 0x80
    reconciled = 0
    for f in by_replist.values():
        s = state[f["ID"]]
        _, flags = side_row(f, side, race_mask, class_mask)
        want = flags & ADOPTED
        if (s["flags"] & VISIBLE) and not (want & (HIDDEN | INVISIBLE_FORCED)):
            want |= VISIBLE
        if (s["flags"] & ADOPTED) == want:
            continue
        s["flags"] = (s["flags"] & ~ADOPTED) | want
        reconciled += 1

    # --- mod-factionchoice: PinReactions ---
    forced = {}
    for f in by_replist.values():
        _, flags = side_row(f, side, race_mask, class_mask)
        want_war = bool(flags & AT_WAR)
        if bool(state[f["ID"]]["flags"] & AT_WAR) == want_war:
            continue
        forced[f["ID"]] = HOSTILE if want_war else FRIENDLY

    # DesiredFaction: neutral wears its own template, a side its proxy race's
    player_tpl = templates[NEUTRAL_TEMPLATE if side == 2 else races[1 if side == 0 else 2]]
    if not quiet:
        print(f"\n=== {name} (guid {guid}, race {race}, class {klass}) -> {SIDE_NAMES[side]} ===")
        print(f"reconciled {reconciled} flag sets, pinned {len(forced)}: "
              + ", ".join(f"{fid}" for fid in sorted(forced)))
        print(f"player faction template {player_tpl['ID']} "
              f"(ourMask {player_tpl['ourMask']}, friendlyMask {player_tpl['friendlyMask']}, "
              f"hostileMask {player_tpl['hostileMask']})")

    def reaction(tpl):
        """Unit::GetFactionReactionTo(creature template, player)."""
        if tpl["flags"] & FACTION_TEMPLATE_FLAG_ATTACK_PVP_ACTIVE_PLAYERS:
            pass                                   # only when the player is contested-PvP flagged
        if tpl["faction"] in forced:
            return forced[tpl["faction"]], "forced"
        f = factions.get(tpl["faction"])
        if f and f["repList"] >= 0:
            rank = rep_to_rank(effective(tpl["faction"]))
            if state[tpl["faction"]]["flags"] & AT_WAR:
                rank = min(NEUTRAL, rank)
            return rank, "reputation"
        if is_hostile_to(tpl, player_tpl):
            return HOSTILE, "template"
        if is_friendly_to(tpl, player_tpl) or is_friendly_to(player_tpl, tpl):
            return FRIENDLY, "template"
        if tpl["flags"] & 0x4:                     # HATES_ALL_EXCEPT_FRIENDS
            return HOSTILE, "template"
        return NEUTRAL, "template"

    # which faction templates that NPCs actually use come out unfriendly?
    used = q("SELECT faction, COUNT(*), MIN(name) FROM acore_world.creature_template "
             "WHERE faction IN (SELECT DISTINCT faction FROM acore_world.creature_template) "
             "GROUP BY faction;")
    bad = []
    for tpl_id_s, count_s, example in used:
        tpl = templates.get(int(tpl_id_s))
        if not tpl:
            continue
        rank, why = reaction(tpl)
        if rank <= UNFRIENDLY:
            bad.append((int(count_s), int(tpl_id_s), tpl["faction"], RANKS[rank], why, example))
    bad.sort(reverse=True)
    if not quiet:
        print(f"{len(bad)} creature faction templates refuse interaction "
              f"({sum(b[0] for b in bad)} creature_template rows):")
        for count, tpl_id, fid, rank, why, example in bad[:25]:
            print(f"  tpl {tpl_id:<5} faction {fid:<5} {rank:<10} via {why:<10} "
                  f"{count:>6} npcs  e.g. {example}")
    return bad


def natives():
    """What a fresh native of each side refuses: a human and an orc warrior."""
    return ({t for _, t, *_ in simulate(0, "<native Alliance>", 1, 1, 0, rebase=True, quiet=True)},
            {t for _, t, *_ in simulate(0, "<native Horde>", 2, 1, 1, rebase=True, quiet=True)})


def report_neutral(name, refused, alliance, horde):
    """A neutral character should talk to anyone a native of either side would."""
    extra = refused - (alliance & horde)
    print(f"\n{name}: {len(extra)} faction templates refused that a native of either side "
          f"would talk to" + (": " + ", ".join(map(str, sorted(extra))) if extra else ""))
    return len(extra)


def check_neutral_pvp():
    """Unit::GetFactionReactionTo between player templates, both ways: a neutral
    character and the players of either side should be friendly, never hostile."""
    neutral = templates[NEUTRAL_TEMPLATE]
    print("\nplayer vs neutral (template masks, both directions):")
    for race in sorted(playable):
        tpl_id = races[race]
        tpl = templates[tpl_id]
        out = []
        for a, b in ((tpl, neutral), (neutral, tpl)):
            if is_hostile_to(a, b):
                out.append("HOSTILE")
            elif is_friendly_to(a, b) or is_friendly_to(b, a):
                out.append("friendly")
            else:
                out.append("neutral")
        print(f"  race {race:<2} template {tpl_id:<5} sees neutral as {out[0]:<8} and is seen as {out[1]}")


def main():
    if sys.argv[1:] == ["--neutral"]:
        alliance, horde = natives()
        failures = 0
        for race in sorted(playable):
            refused = simulate(0, f"<neutral race {race}>", race, 1, 2, rebase=True)
            failures += report_neutral(f"neutral race {race}", {t for _, t, *_ in refused}, alliance, horde)
        check_neutral_pvp()
        return 1 if failures else 0

    wanted = sys.argv[1:]
    where = ("AND c.name IN (" + ",".join(f"'{n}'" for n in wanted) + ")") if wanted else ""
    rows = q("SELECT c.guid, c.name, c.race, c.class, "
             "  COALESCE(SUBSTRING_INDEX(s.data, ' ', 1), '0') "
             "FROM acore_characters.characters c "
             "LEFT JOIN acore_characters.character_settings s "
             "  ON s.guid = c.guid AND s.source = 'mod-factionchoice' "
             "JOIN acore_auth.account a ON a.id = c.account "
             f"WHERE a.username NOT LIKE 'RNDBOT%' {where};")
    if not rows:
        print("no matching characters")
        return 1

    baseline = {}
    neutrals = {}
    for guid, name, race, klass, team in rows:
        if team not in ("1", "2", "3"):
            print(f"\n=== {name} plays its own race's side, nothing to check ===")
            continue
        refused = simulate(int(guid), name, int(race), int(klass), int(team) - 1)
        (neutrals if team == "3" else baseline)[name] = {t for _, t, *_ in refused}

    if neutrals:
        alliance, horde = natives()
        for name, s in neutrals.items():
            report_neutral(name, s, alliance, horde)

    # A cross-faction character should refuse interaction with the same NPCs a
    # native of the chosen side would. Anything extra is a bug in the rebase.
    if baseline:
        native = simulate(0, "<native>", 1, 1, 0)
        native_set = {t for _, t, *_ in native}
        for name, s in baseline.items():
            print(f"\n{name}: {len(s - native_set)} faction templates refused that a "
                  f"native Alliance human would talk to")
    return 0


if __name__ == "__main__":
    sys.exit(main())
