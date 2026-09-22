"""Replicate SpellMgr::CheckSpellGroupStackRules against the live spell_group data."""
import subprocess, collections

def q(sql):
    out = subprocess.run(["mysql","-uacore","-pacore","-h127.0.0.1","-N","-B","-e",sql],
                         capture_output=True, text=True).stdout
    return [l.split("\t") for l in out.splitlines() if l]

members = collections.defaultdict(list)
for gid, sid in q("SELECT id, spell_id FROM acore_world.spell_group;"):
    members[int(gid)].append(int(sid))
rules = {int(g): int(r) for g, r, _ in
         q("SELECT group_id, stack_rule, description FROM acore_world.spell_group_stack_rules;")}
ranks = {int(s): int(f) for f, s in
         q("SELECT first_spell_id, spell_id FROM acore_world.spell_ranks;")}

def reachable(gid, seen=None):
    """Every spell id under a group, following negative sub-group references."""
    seen = seen or set()
    if gid in seen:
        return set()
    seen.add(gid)
    out = set()
    for m in members.get(gid, []):
        if m < 0:
            out |= reachable(-m, seen)
        else:
            out.add(m)
    return out

reach = {g: reachable(g) for g in members}
spell_groups = collections.defaultdict(set)
for g, spells in reach.items():
    for s in spells:
        spell_groups[s].add(g)

def check(a, b):
    a, b = ranks.get(a, a), ranks.get(b, b)          # GetFirstRankSpell
    groups = set()
    for g in spell_groups.get(a, ()):
        if b not in reach[g]:
            continue
        add = True
        for m in members[g]:
            if m < 0 and a in reach[-m] and b in reach[-m]:
                add = False                            # same container: skip parent
                break
        if add:
            groups.add(g)
    rule = 0
    for g in sorted(groups):
        rule = rules.get(g, rule)
        if rule:
            break
    return rule, sorted(groups)

NAMES = {8118:"Scroll of Strength", 8115:"Scroll of Agility", 8099:"Scroll of Stamina",
         8096:"Scroll of Intellect", 8112:"Scroll of Spirit", 8091:"Scroll of Protection",
         57330:"Horn of Winter", 8076:"Strength of Earth", 1459:"Arcane Intellect",
         1243:"Power Word: Fortitude", 14752:"Divine Spirit"}
RULE = {0:"DEFAULT (stack)", 1:"EXCLUSIVE", 4:"EXCLUSIVE_HIGHEST"}

print("--- scroll vs scroll: all of these must stack ---")
scrolls = [8118, 8115, 8099, 8096, 8112, 8091]
bad = 0
for i, a in enumerate(scrolls):
    for b in scrolls[i+1:]:
        rule, gs = check(a, b)
        flag = "" if rule == 0 else "   <-- STILL BLOCKED"
        if rule: bad += 1
        print(f"  {NAMES[a]:<21} + {NAMES[b]:<21} {RULE.get(rule,rule):<18} via {gs}{flag}")

print("\n--- scroll vs class buff: these must stay exclusive-highest ---")
for a, b in [(8118,57330),(8115,57330),(8118,8076),(8115,8076),
             (8096,1459),(8099,1243),(8112,14752),(57330,8076)]:
    rule, gs = check(a, b)
    flag = "" if rule else "   <-- NOW STACKS, regression"
    print(f"  {NAMES[a]:<21} + {NAMES[b]:<21} {RULE.get(rule,rule):<18} via {gs}{flag}")

print(f"\nscroll pairs still blocked: {bad} (want 0)")
