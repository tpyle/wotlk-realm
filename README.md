# AzerothCore 3.3.5a server (Wrath of the Lich King) with playerbots

A complete WotLK server built from the playerbots fork of AzerothCore, set up
for solo/small-group play: 500 bots, every profession on one character,
world-wide level scaling, every class on every race, and large bags for every
character.

## Repositories

The tree is several git repositories, not one. This one holds the SQL, the
tools, the addons and this document; the server and every module are their
own.

**Forks of other people's work** (local changes on a branch, nothing pushed
upstream):

Every repository here uses `trunk` as its branch, and in every one `origin`
is the copy on GitHub that gets pushed to. The three forks carry a second
remote, `upstream`, pointing at the project they were forked from:
`git fetch upstream && git merge upstream/<branch>` is how other people's
changes come in.

`tools/bootstrap.sh` clones the whole tree - the core plus its
seventeen modules - in one go, and `tools/bootstrap.sh --status` prints where
each one is. `bootstrap.lock` records the commit every repository was on when
it was last written (`--lock`), and `--pinned` checks those commits back out;
that is the reproducibility submodules would have given, without a
`.gitmodules` in the core fork.

Submodules were considered and rejected for one structural reason:
AzerothCore's own `.gitignore` has `/modules/*`, deliberately leaving that
directory free for whatever the user puts there, and ships no `.gitmodules`.
Making the modules submodules would mean editing that tracked file and adding
a `.gitmodules` in the core fork - permanent drift in the one repository where
a 231-commit upstream merge has to stay easy - and nesting them under a
`server/` submodule on top of that. The cloning problem is worth a script;
it is not worth that.

| repository | origin (pushed to) | upstream (merged from) | what is local |
| --- | --- | --- | --- |
| `server/` | [tpyle/azerothcore-wotlk](https://github.com/tpyle/azerothcore-wotlk) | [liyunfan1223/azerothcore-wotlk](https://github.com/liyunfan1223/azerothcore-wotlk), branch `Playerbot` | five additive script hooks and their call sites, `ReputationMgr::AdoptFactionState`, the `extraBonusTalentCount` width fix, kill credit by reported level, bank reagents, multiple profession specializations |
| `server/modules/mod-ah-bot` | [tpyle/mod-ah-bot](https://github.com/tpyle/mod-ah-bot) | [azerothcore/mod-ah-bot](https://github.com/azerothcore/mod-ah-bot) | seller shuffle, full trade-good stacks, pricing for items with no vendor sell price, one log line demoted |
| `server/modules/mod-playerbots` | [tpyle/mod-playerbots](https://github.com/tpyle/mod-playerbots) | [liyunfan1223/mod-playerbots](https://github.com/liyunfan1223/mod-playerbots) | quest hubs as a random-teleport destination |

**Used unmodified** - no fork needed, each cloned straight from its own
project and left on its upstream branch (so `bootstrap.lock` is what pins
them): [mod-transmog](https://github.com/azerothcore/mod-transmog),
[mod-aoe-loot](https://github.com/azerothcore/mod-aoe-loot),
[mod-worgoblin](https://github.com/heyitsbench/mod-worgoblin),
[mod-autobalance](https://github.com/azerothcore/mod-autobalance).

**Written here**, one repository each under
[tpyle](https://github.com/tpyle), in the layout AzerothCore expects (clone
into `modules/`): [mod-worldscale](https://github.com/tpyle/mod-worldscale), [mod-factionchoice](https://github.com/tpyle/mod-factionchoice), [mod-botlore](https://github.com/tpyle/mod-botlore), [mod-talentgrant](https://github.com/tpyle/mod-talentgrant), [mod-extraglyphs](https://github.com/tpyle/mod-extraglyphs), [mod-bankreagents](https://github.com/tpyle/mod-bankreagents), [mod-languages](https://github.com/tpyle/mod-languages), [mod-spellcooldowns](https://github.com/tpyle/mod-spellcooldowns), [mod-aurastack](https://github.com/tpyle/mod-aurastack), [mod-bigbags](https://github.com/tpyle/mod-bigbags), [mod-transmog-collect](https://github.com/tpyle/mod-transmog-collect).

This repository is [tpyle/wotlk-realm](https://github.com/tpyle/wotlk-realm).

The two client addons written here, `BankReagents` and `ExtraGlyphs`, live in
`client-patch/addon/` in this repository rather than in the repositories of
the modules they talk to, so that there is one copy of each.

## Layout

| Path | What it is |
| --- | --- |
| `server/` | AzerothCore source (playerbots fork) plus the modules in `server/modules/` |
| `build/` | CMake build tree |
| `run/bin/` | `worldserver`, `authserver` |
| `run/etc/` | Server configuration (`worldserver.conf`, `authserver.conf`, `modules/*.conf`) |
| `run/data/` | Client data the server needs: `dbc`, `maps`, `vmaps`, `mmaps` |
| `sql/` | Custom SQL applied on top of the imported databases (all idempotent) |
| `tools/` | The DBC generators, the MPQ packer, the config script and the diagnostics |
| `client-patch/` | `patch-Z.MPQ` (all classes on all races) and `patch-A.MPQ` (Worgen and Goblin) for the game client, and the `addon/` folder (BankReagents, ExtraGlyphs, TransmogAzerothCore) |
| `logs/` | Server logs |
| `start.sh`, `stop.sh`, `status.sh` | Run the server |
| `ADMIN_CREDENTIALS.txt` | The game master account (root readable only) |

## Running it

```bash
/root/classic/start.sh     # starts MySQL, authserver, worldserver
/root/classic/status.sh    # what is up, and how many bots are online
/root/classic/stop.sh      # warn players, kick them, then graceful shutdown
/root/classic/stop.sh --now  # skip the warning (nothing but bots online)
```

`stop.sh` warns any real player, waits `STOP_GRACE` seconds (15 by default) and
kicks them *before* starting the shutdown. That is deliberate: the core's
shutdown calls `WorldSessionMgr::KickAll()`, which logs out and saves all 500
bots, and until that finishes the server answers nobody. A client left
connected through it can still walk around on its own prediction but gets no
reply to anything - including its own logout request - which looks exactly like
a hang. Kicking first returns it to the login screen immediately. The script
also waits up to 180s for the bot saves before resorting to killing the
session.

Each server runs in its own tmux session, so the console stays available:

```bash
tmux attach -t acore-world   # detach with Ctrl-B then D
tmux attach -t acore-auth
```

Useful console commands: `account create <user> <pass>`,
`account set gmlevel <user> 3 -1`, `server info`, `playerbots status`.

## Connecting

The client at `/root/chromie/ChromieCraft_3.3.5a` is already set up:

* `Data/patch-Z.MPQ` - the generated patch that unlocks every class on every
  race on the character creation screen.
* `Data/enUS/realmlist.wtf` - now reads `set realmlist 127.0.0.1`. The original
  (which pointed at chromiecraft.com) is kept next to it as
  `realmlist.wtf.orig`.

Log in with the game master account in `ADMIN_CREDENTIALS.txt` (the file is
readable by root only). Change it with `account set password admin <new> <new>`
on the world console, and create normal accounts with
`account create <user> <pass>`.

## Playing from the internet

The server is reachable from outside. The realm row hands each client an
address based on where it connects from, so both work at once:

| Client | Realm address it is given |
| --- | --- |
| On this machine (`127.0.0.1`) | `127.0.0.1:8085` |
| Anywhere else | `5.161.99.58:8085` |

**Ports to open on the external firewall** (inbound, TCP, IPv4):

| Port | Service | Needed |
| --- | --- | --- |
| 3724 | logon/auth server | yes - the client connects here first |
| 8085 | world server | yes - the client is redirected here after logon |

Nothing else has to be exposed. MySQL (3306, 33060) listens on `127.0.0.1`
only, SOAP (7878) is off (`SOAP.Enabled = 0`) and the remote access console
(3443) is off (`Ra.Enable = 0`). No outbound rules are needed.

Other players put this in their own `Data/enUS/realmlist.wtf`:

```
set realmlist 5.161.99.58
```

They also need `patch-Z.MPQ` and `patch-A.MPQ` from `client-patch/` in their
`Data/` folder (and the signature-check patch to `Wow.exe`, see the Worgen and
Goblin section), or
the character creation screen will not offer the extra class/race combinations.

`tools/check_login.py` logs in the way a real client does (SRP6 handshake plus
realm list request) and prints what the client is told, which is the quickest
way to check the server is reachable and an account works:

```bash
python3 tools/check_login.py 5.161.99.58 <account> <password>
```

Because the server is public: the game master password was rotated away from
`admin`, accounts can only be created from the console (there is no public
registration), and Warden (the anti-cheat) is off - it was only ever logging
(`Warden.ClientCheckFailAction = 0`) and a two-player realm has nothing to
police; `Warden.Enabled = 1` plus `ClientCheckFailAction = 1` brings it back
with teeth.

## The requested features

### Bots (500 by default)

`mod-playerbots` (the module that goes with this fork of the core). Its own
defaults are already 500 bots, and `run/etc/modules/playerbots.conf` pins them:

```ini
AiPlayerbot.Enabled = 1
AiPlayerbot.MinRandomBots = 500
AiPlayerbot.MaxRandomBots = 500
AiPlayerbot.RandomBotAutologin = 1
```

The bots need their own database (`acore_playerbots`), which is why
`Updates.EnableDatabases` is `15` (auth + characters + world + playerbots)
instead of the default `7`.

On the very first start the server creates 500 bot accounts and characters,
which takes a while and is logged in the world server console. Lower
`AiPlayerbot.MaxRandomBots` if the machine struggles - bots are the most
expensive thing on this server by a wide margin.

Useful in-game commands: `.bot add <name>`, `.bot init=<level>`,
`.playerbots` for the rest.

### All professions on one character

A core config option, no module needed:

```ini
MaxPrimaryTradeSkill = 11   # worldserver.conf, default 2
```

11 is the number of primary professions in 3.3.5a, so a character can learn
all of them (secondary skills - cooking, first aid, fishing - were never
limited). The value is re-applied on every login, so characters that already
exist also get the higher limit.

### Faster talents

```ini
Rate.Talent = 3        # worldserver.conf, default 1
```

Three times the talent points per level - 213 at level 80 instead of 71.
`Rate.Talent.Pet` (pet talents) is still 1; raise it the same way to match.

The rate applies to every character at once and cannot be pointed at one of
them, which is what `mod-talentgrant` below is for.

**Lowering this rate later is not free.** `Player::InitTalentForLevel` compares
what a character has spent against what the new rate allows, and if the total
has dropped below the spend it calls `resetTalents(true)` - a free but complete
wipe of the build. The points come back as unspent, so nothing is lost but the
arrangement; every existing character re-specs on next login.

### Crafting from the bank

The goal: craft using reagents that are sitting in the bank, from anywhere,
without shuffling stacks into the bags first. It took three pieces, and the
third exists because of something the client does that no amount of server
work can change.

#### 1. The server consumes from the bank

`Crafting.AllowBankReagents = 1`. Two lines, because half of it was already
written:

```cpp
bool HasItemCount(uint32 item, uint32 count = 1, bool inBankAlso = false) const;
```

`HasItemCount` has always been able to count bank slots *and* bank bags behind
that flag - nothing passed `true`. Its opposite number had no such parameter:
`DestroyItemCount` searches inventory, keyring, bags and equipped slots and
stops. So `Player::DestroyItemCount` gained the matching `inBankAlso`,
defaulted off, and `Spell::CheckItems` and `Spell::TakeReagents` now pass the
same config flag to both. Bags are consumed first; the bank only for the
shortfall.

Verified in the shipped binary by signature -
`Player::DestroyItemCount(unsigned int, unsigned int, bool, bool, bool)`, five
parameters up from four - and by disassembly of both `Spell` call sites
showing the `ConfigMgr::GetOption` call.

#### 2. The client refuses to send the craft anyway

This is the part that was wrong twice before it was right, and it is worth
recording exactly because the wrong reasoning was persuasive.

The stock trade skill window greys out the Create button by its own bag-only
count. Extracted from `Data/enUS/patch-enUS-2.MPQ`, the Lua gate is purely
cosmetic:

```lua
if ( playerReagentCount < reagentCount ) then
    creatable = nil;                      -- only disables the button
end
```

and the button's handler is an unguarded `DoTradeSkill(...)`. From that it was
concluded that the button was the only gate and a macro or an addon could
simply send the cast. **That conclusion was false.** Underneath the Lua, the
client's C-side cast code runs its own reagent check against the bags before
any packet leaves. Proven with `Logger.spells.aura` at debug for a few
minutes: several attempts to craft Bolt of Linen Cloth (spell 2963) with
twenty Linen Cloth in the bank produced "Missing Reagent: Linen Cloth" on the
client and **zero** `Spell::prepare` lines for 2963 in `Server.log`, against
2517 other player-originated casts in the same window. The server never saw
them.

So the reagents must be in the bags when the button is pressed. That
constraint belongs to the client, not the server, and the only way through it
without a modified `Wow.exe` is to put them there - as little as possible, as
late as possible.

Two delivery routes were also ruled out on the way, both by the client's
signature checks, and the strings are in `Wow.exe` for both:

| attempt | client's answer |
| --- | --- |
| patched `Blizzard_TradeSkillUI.lua` in an MPQ | `Couldn't load Blizzard_TradeSkillUI: Corrupt` |
| new FrameXML module + patched `FrameXML.toc` in an MPQ | `FrameXML is modified or corrupt` / "Your game interface files are missing or corrupt" |

UI mods shipped in `Data/` work when they are art, models or DBC data. Lua is
signed. The second attempt also hung the client at the end of the loading bar
before it got as far as the signature check, because the `FrameXML.toc` used
came from `patch-enUS-2.MPQ` while `patch-enUS-3.MPQ` carries a newer one
appending `BNet.xml`, `HistoryKeeper.lua` and `BNConversations.xml`. Two
lessons from that: take a stock file from the highest-numbered archive that
contains it, and edit it in binary mode (that file is CRLF; text mode silently
rewrote all 144 line endings).

#### 3. Just-in-time, per recipe

The client half is an ordinary addon, `client-patch/addon/BankReagents/`, which
carries no signature - that is the basis of the whole addon system:

```bash
cp -r client-patch/addon/BankReagents <client>/Interface/AddOns/
```

The server half is `mod-bankreagents`. The two talk over a channel the core
already provides: an addon message with the `AzerothCore` prefix and opcode
`i` is parsed by `AddonChannelCommandHandler::ParseCommands`, run as a
command from the player, and never delivered as chat. The addon sends

```
SendAddonMessage("AzerothCore", "i0001bankreagents pull <spellId>", "WHISPER", UnitName("player"))
```

when a recipe is selected and again after every craft (throttled to twice a
second). The module's `bankreagents pull <spellId>` - `SEC_PLAYER`, no target
argument, only the caller's own items - moves stacks of each reagent out of
the bank until the bags hold at least one full stack (or the recipe's own
count if larger), using the bank window's own `CanStoreItem` -> `RemoveItem`
-> `StoreItem` sequence. One slot per reagent, so the bag-space dependency the
client imposes is a slot or two rather than the whole stock. If the bags are
completely full nothing moves and the craft fails with the usual message -
the same state that blocks looting. `BankReagents.MinStacks` raises the
amount kept in the bags in exchange for fewer round trips.

The three pieces reinforce each other: the addon puts a stack in the bags so
the client will send the cast; the server consumes bags first; and because it
also consumes from the bank for any shortfall, a Create All that outruns the
top-up between casts still succeeds rather than stopping short.

The addon also corrects the display after Blizzard's own code has run:
reagent counts become `max(bag count, GetItemCount(link, true))`, the grey-out
is removed for reagents the bank covers, the `[N]` beside each recipe in the
list is recomputed with the bank counted, and `TradeSkillFrame.numAvailable`
is recomputed so Create All asks for a real number. It only ever raises counts
and enables buttons, never the reverse.

The Lua is validated with `luac5.1 -p` (5.1 is the client's own Lua version),
and every C API it relies on was confirmed present as a registered name inside
`Wow.exe` rather than assumed. `SetItemButtonTextureVertexColor` and
`FauxScrollFrame_GetOffset` are *not* in that list and do not need to be: they
are Lua functions from FrameXML, not C bindings.

To undo it, delete the addon folder; the server pieces are harmless without
it, and the module's command does nothing unless asked.

`client-patch/patch-Z.MPQ` (the DBC patch for all classes on all races) is
untouched by any of this and stays where it is.


### Research without the daily cooldown

`mod-spellcooldowns` removes the cooldown from a configured list of spells.
It exists for the two inscription research spells - Minor Inscription
Research (61288) and Northrend Inscription Research (61177), each a flat 20
hour `RecoveryTime` in `Spell.dbc` with no category - so a scribe can research
as often as the ink allows rather than once a day.

```
SpellCooldowns.Remove = 61288,61177
```

**Why not `spell_cooldown_overrides`:** it looks like the tool for this and it
is not. That table is consulted from exactly one place,
`Creature::AddSpellCooldown`, for charmed creatures reporting a cooldown to
their charmer. A player's own cooldowns are read from the `SpellInfo` at cast
time (`rec = spellInfo->RecoveryTime`), so the `SpellInfo` is what has to
change. The module zeroes `RecoveryTime` and `CategoryRecoveryTime` on the
listed spells after the spell store loads - the same startup-patch shape as
`mod-aurastack`, with originals remembered so `reload config` can put a spell
back. The core's own `LoadSpellInfoCorrections` edits these fields for dozens
of spells, and the client follows the server's cooldown packets rather than its
own DBC, so nothing client-side is involved.

A cooldown a character already carries is stored in `character_spell_cooldown`
and is not affected by the spell's `RecoveryTime` changing, so it is cleared
explicitly - at login, and on `reload config` for everyone online. Without
that, a scribe who researched in the morning would still be waiting out the
old twenty hours.

The `.conf.dist` lists the other day-scale profession cooldowns (read from
`Spell.dbc`, not remembered - a first draft named three spells that turned
out to be wrong, one of them a belt): Northrend Alchemy Research at 68h, the
transmutes, Brilliant Glass, Icy Prism. Any of them is one id in the list.

### More than one profession specialisation

`Professions.MultipleSpecializations = 1` lets one character hold Armorsmith
*and* Weaponsmith, every alchemy mastery, both engineering schools, and so on.

Nothing in the game engine ever enforced the exclusivity. A specialisation is
an ordinary spell, and the recipes behind it are gated by
`trainer_spell.ReqAbility1` naming that spell - so a character holding both
9787 and 9788 is simply offered both sets (6 weaponsmith recipes and 24
armorsmith ones) with no further change. The only thing standing in the way was
the gossip in `src/server/scripts/World/npc_professions.cpp`, which hides the
"learn" option once the player holds *any* specialisation of that profession:

```cpp
if (!player->HasSpell(S_ARMOR) && !player->HasSpell(S_WEAPON))
    AddGossipItemFor(player, ..., GOSSIP_ARMOR_LEARN, ...);
```

Each of those nine guards now reads "offer this one if the player does not
already have *it*", with the "and none of the others" half applied only when
the config is off. Default is **0**, so stock behaviour is the default and the
diff is safe across an upstream merge. The option is read per gossip, so
`reload config` applies it without a restart.

| profession | where | prerequisites |
| --- | --- | --- |
| Blacksmithing | Ironus Coldsteel / Borgosh Corebender (weapon), Grumnus Steelshaper / Okothos Ironrager (armour) | skill 225, one of quests 5283/5284/5302 |
| Blacksmithing sub-specs | Lilith the Lithe (hammer), Kilram (axe), Seril Scourgebane (sword) | Weaponsmith, level 50, skill 250 |
| Alchemy | Zarevhi (transmute), Lorokeem (elixir), Lauranna Thar'well (potion) | skill 325, level 68, one of the master quests |
| Tailoring | Gidge Spellweaver (spellfire), Nasmara Moonsong (mooncloth), Andrion Darkspinner (shadoweave) | one of quests 10831/10832/10833 |
| Leatherworking | the *Soothsaying for Dummies* book | skill 225, level 40, one of quests 5141-5148 |

The sub-specialisations still require Weaponsmith first. That is progression
rather than exclusivity - Swordsmith sits *under* Weaponsmith - so it is left
alone.

**Engineering is the exception** and needs
`sql/16_multiple_specializations.sql` as well, because it is chosen by quest
rather than by gossip. Its nine quests share one exclusive group, and
`ExclusiveGroup > 0` means taking one locks out the rest
(`Player::SatisfyQuestExclusiveGroup`). Rather than clearing the group -
which would also let a character take the several race and faction variants of
the *same* branch, all granting the same spell - the script splits it in two,
keyed on each branch's lowest quest id the way the data already does it:

```
3526, 3629, 3633, 4181        Goblin -> group 3526 (unchanged)
3630, 3632, 3634, 3635, 3637  Gnome  -> group 3630
```

So it is still one Gnome quest and one Goblin quest per character, but no
longer one *or* the other. Reversible with the matching `_revert.sql`, which
restores from `quest_exclusive_group_backup`.

Unlearning is untouched throughout, and still works one specialisation at a
time at the usual cost.

### Talent points on demand

`mod-talentgrant` (`server/modules/mod-talentgrant`,
`run/etc/modules/mod_talentgrant.conf`) hands talent points to one character:

```
.talents show  [player]            what they have, and how much of it was granted
.talents grant <count> [player]    add to the grant
.talents take  <count> [player]    subtract from it
.talents set   <count> [player]    set it outright
```

Omit the player to use your selection, or yourself. Offline characters work by
name and the change applies at their next login.

There is no new mechanism here, which is the point. The core already carries a
per-character `m_extraBonusTalentCount`, already adds it inside
`CalculateTalentsPoints`, and already persists it as
`characters.extraBonusTalentCount` through both save paths. What it does not
ship is any way to set the thing: `RewardExtraBonusTalentPoints` has no caller
and no command touches it. So granted points are not a parallel pool - they are
part of the same total as the ones level-up hands out, and they survive logout,
relog, a talent reset and a spec switch for free.

Three things about the total are worth knowing:

* **The grant is a base figure, applied before `Rate.Talent` multiplies it.** At
  a rate of 3, granting 1 yields 3 spendable points. Every message the module
  prints states both numbers for that reason.
* **`TalentGrant.MaxBonus` (255) is policy, not a technical ceiling.** It was
  both until this feature went in. The column is declared `int`
  (`characters.sql:103`) and `Player::SaveToDB` writes a `uint32`, but
  `Player::LoadFromDB` read it back with `Field::Get<uint8>` (field 73) - and
  for a prepared statement `Field::GetData` is a `reinterpret_cast` of the raw
  four-byte buffer, so it kept the low byte and dropped the rest. A stored 300
  came back as **44**, silently, on every login. Three places in the core, two
  widths, and the schema agreeing with neither.

  The read now uses the declared width, with negatives floored to 0 (nothing
  writes one, but a hand-edited `-1` read as unsigned would be four billion,
  and `CalculateTalentsPoints` multiplies this by `Rate.Talent` before handing
  the result to `SetFreeTalentPoints`). So the cap is now just a guard against a
  mistyped grant and can be raised freely. The command *refuses* a value above
  it rather than quietly clamping - a GM who types 300 should be told, not
  given 255.
* **Reducing a grant below what is already spent is refused.** The core's
  reaction to a shortfall depends on the *target's* own permissions -
  `resetTalents(true)` for a player, but `SetFreeTalentPoints(0)` and a build
  left over cap for anyone holding
  `RBAC_PERM_SKIP_CHECK_MORE_TALENTS_THAN_ALLOWED`, which a GM's own session
  usually does. Rather than pick one of those, the module declines and says to
  run `.reset talents` first.

`show` is `SEC_GAMEMASTER`; the three that change anything are
`SEC_ADMINISTRATOR`. Grants are logged to `Server.log` with who made them.

### Glyphs beyond the six sockets

`mod-extraglyphs` (`server/modules/mod-extraglyphs`,
`run/etc/modules/mod_extraglyphs.conf`) with the `ExtraGlyphs` addon
(`client-patch/addon/ExtraGlyphs`, copy the folder into `Interface/AddOns`).

The six glyph sockets are a client limit, not a server one. The glyph tab is
drawn from six fixed update fields (`PLAYER_FIELD_GLYPHS_1` has a size of six
in a protocol layout shared with `Wow.exe`, and the unlock bits sit in
`PLAYER_GLYPHS_ENABLED`), so a seventh socket would need the executable
patched. But what a socketed glyph *does* is nothing to do with the socket:
`Spell::EffectApplyGlyph` runs `CastSpell(player, glyphEntry->SpellId, true)`
and then `SetGlyph` to write the id into the field - the glyph's effect is a
passive aura, and that is all it is. Spec switching removes and re-casts those same
spells, and login casts them from `_LoadGlyphAuras`.

So extra glyphs skip the sockets entirely. The module keeps its own list, per
character and per talent spec, in `acore_characters.character_extra_glyphs`
(created on first start), and applies each entry's spell the same way the core
applies socketed ones - on login, on spec switch, and the moment one is added.
Removal drops the aura, unless a socket of the current spec still grants the
same spell. The client never learns about any of it, which is why it needs its
own panel.

Getting a glyph on is not the standard drag-into-socket: the glyph item's own
use spell (`SPELL_EFFECT_APPLY_GLYPH`) targets a socket and is left alone.
Instead the addon panel (`/extraglyphs`, `/eg`, or the **Extra** button on the
glyph tab) lists every glyph the class can use, with the state of each - in a
socket, applied as an extra, or neither - and how many of the glyph item are in
the bags. **Apply** sends `extraglyphs add <glyphId>` over the addon command
channel; the server checks class and level, that the glyph is not already
active either way, that there is room under `ExtraGlyphs.Max` (set to 0 here, no
limit; the shipped default is 6 per spec), consumes one glyph item from the bags exactly as
socketing would, and casts the passive. **Remove** loses the glyph, as
overwriting a socket does. `ExtraGlyphs.RequireItem = 0` drops the item
requirement and lets a class apply any of its glyphs for free.

Which glyphs a class may use is not in `GlyphProperties.dbc` (362 rows of id,
spell and major/minor flag). It comes from the glyph *items*: each one's use
spell names the glyph id in its `APPLY_GLYPH` effect and the item's
`AllowableClass` says who may use it. The module builds that map at startup
and logs the count. The addon takes names, icons and tooltips from the
passive's spell id (`GetSpellInfo`, `spell:` hyperlinks), so nothing localised
crosses the wire.

The replies are plain lines (`EG glyph <id> <spell> <item> <major|minor>
<extra|socketed|none>`), so the same commands work by hand from `/` in the
chat box for anyone who wants to script it, but not from the console: they are
`SEC_PLAYER`, `Console::No`, and only ever act on the caller.

### Area loot

`mod-aoe-loot` (community module, `server/modules/mod-aoe-loot`,
`run/etc/modules/mod_aoe_loot.conf`). Retail's Area Loot from Mists of
Pandaria on a client that has never heard of it: the module intercepts
`CMSG_LOOT` and merges the loot of every lootable corpse you have rights to
within `AOELoot.Range` (55 yd) into the window you opened, then marks those
corpses looted. Quest items only merge when you have the quest and still
need the item; group loot follows the group's method (free-for-all and
round-robin merge, need/greed and master loot stay per corpse). The login
banner is off (`AOELoot.Message = 0`); `.aoeloot on|off` toggles it per
character. This fork already carried the three loot hooks the module was
written against.

### Transmogrification, with an appearance collection

`mod-transmog` (community module, `server/modules/mod-transmog`,
`run/etc/modules/transmog.conf`) plus the `TransmogAzerothCore` wardrobe addon
(`client-patch/addon/TransmogAzerothCore`, copy into `Interface/AddOns`).

Transmog needs no client change because the client never sees your real
gear: it draws whatever item id the server puts in
`PLAYER_VISIBLE_ITEM_n_ENTRYID`, and the module puts the appearance item
there while the stats keep coming from the real one.

The collection is `Transmogrification.UseCollectionSystem = 1`: an
**account-wide** table, `acore_characters.custom_unlocked_appearances`, that
gains an item's appearance the moment a character loots, equips, crafts, buys
or is rewarded it (the module hooks all five), so - as on retail - once you
have owned it you can use it without keeping it. `RetroActiveAppearances`
walks each character's completed quests once at login and unlocks their
rewards; `TrackUnusableItems` records appearances the current rules would
refuse (poor and common quality, say) so a later rule change does not lose
them.

Applying one is not the retail wardrobe: the client has no Appearances tab.
Either talk to a Warpweaver (`.npc add 190010` places one) or type
`.transmog portable` anywhere - the gossip lists your collection per slot.
Hiding a slot is allowed and free. Outfits can be saved as sets
(`EnableSets`, up to ten). The addon is the browsing half: `/transmog` opens a
dressing-room wardrobe with the whole catalogue (`db/Items.lua`, 5 MB), an
Unlocked filter fed live by the server's `TRANSMOG_SYNC:<id>` lines
(`.transmog sync` replays the collection), per-slot progress, and saved looks.
It reads only; applying still goes through the gossip.

**Collecting from gear you sell or disenchant.** mod-transmog's collection
covers loot, equip, craft, vendor purchase and quest reward - but not the two
things that happen to gear nobody means to keep, selling it and
disenchanting it, both of which destroy the item and took the appearance with
it. `mod-transmog-collect` (`server/modules/mod-transmog-collect`,
`run/etc/modules/mod_transmog_collect.conf`) records those two moments while
the item still exists: `OnPlayerCanSellItem`, which fires in
`HandleSellItemOpcode` with the item still in the bags (the module records
and returns true, so the sale and its buyback slot are unaffected), and
`OnPlayerBeforeSendLoot` filtered to `LOOT_DISENCHANTING`, which is what
`Spell::EffectDisEnchant` raises on the item's own GUID. The recording itself
is mod-transmog's own `AddToDatabase`, so the quality and armour-type rules,
the account-wide dedupe, the chat notice and the
`custom_unlocked_appearances` row are all exactly as for any other source -
and mod-transmog stays an unmodified upstream clone, which is why this is a
separate module rather than a fourth fork.

Rules are the module defaults: same armour type, same weapon type and
handedness, uncommon-to-epic plus heirlooms, no cost. Every one of those is a
key in `transmog.conf` (`AllowMixedArmorTypes`, `AllowPoor`, `CopperCost`...)
and re-read by `.transmog reload` (not by `reload config`).

### Worgen and Goblin

`mod-worgoblin` (community module, `server/modules/mod-worgoblin`,
`run/etc/modules/mod_worgoblin.conf`; the heyitsbench fork of Helias's
module). Two Cataclysm races on a WotLK realm: Goblin keeps its retail id, 9, and
Worgen becomes race 12 rather than retail's 22 (the client's race tables and
masks were sized for twelve), with their
models, animations, voices, racials (Darkflight, Rocket Barrage and Rocket
Jump, Best Deals Anywhere, Two Forms...), starting outfits and a stand-in
starting zone each, since Gilneas and Kezan do not exist in this client.

The choice was deliberate. The only project carrying High Elf, Mag'har, Ogre
and Dark Iron as well ([Medviten/mod-worgoblin-high-elf](https://github.com/Medviten/mod-worgoblin-high-elf);
the six-race fork it was found under has since been deleted) is marked work
in progress and installs by patching 13 core files and 9 mod-playerbots
files, replacing the entire DBC set through its own MySQL pipeline and
resetting the world database - on a tree that is not under git and already
carries its own core and playerbots patches. mod-worgoblin, by contrast, is
57 lines of C++, no core patch, 30 DBCs and a client patch. It is marked "no
longer maintained", which for a finished thing is fine.

**How it fits this fork.** Nothing in the core had to change: this playerbots
fork already discovers playable races from `ChrRaces.dbc` at startup
(`RaceMgr::LoadRaces`, called from `World.cpp:391` - every row without
`CHRRACES_FLAGS_NOT_PLAYABLE` joins the playable mask, and `GetMaxRaces()`
follows the highest id). Drop the module's `ChrRaces.dbc` into
`run/data/dbc` and the server accepts race 12 and 9 at character creation,
the bot factory (`RandomPlayerbotFactory.cpp:71` iterates to `GetMaxRaces()`)
starts rolling Worgen and Goblin bots when it next creates any, and the
module's SQL (`playercreateinfo`, spells, skills, the stand-in start
locations) is applied by the updater on the first start. Because our own
generators run on top of the module's DBCs, Worgen and Goblin also get every
class and every weapon like everybody else.

`tools/install_worgoblin_dbc.sh` is the server-side data step: it copies the
module's 30 DBCs over `run/data/dbc` (backup of the previous set in
`run/data/dbc-before-worgoblin.tgz`), refreshes the `.orig` baselines the
generators start from, re-runs both generators, and packs our client DBCs as
`patch-Z.MPQ`.

**Client side, three things**, and this is where it stops being plug and
play:

1. `client-patch/patch-A.MPQ` (130 MB, packed from the module's `data/patch`
   folder with `tools/mpq_pack`: 6,484 files - models, textures, sounds,
   DBCs and four GlueXML files for the creation screen) into the client's
   `Data/`.
2. `client-patch/patch-Z.MPQ` replaces the old `patch-4.MPQ`. The client
   loads every `patch-?.MPQ` in name order with later ones overriding, digits
   before letters; `patch-4` would have lost to `patch-A`, and both carry
   `CharBaseInfo.dbc` and `CharStartOutfit.dbc`. Delete `patch-4.MPQ` from
   the client.
3. **A patched `Wow.exe`.** The module ships modified `GlueXML` (the
   character creation screen has to know about two more race buttons), and
   the stock executable refuses modified interface files - the same
   signature check that ended the trade-skill UI patch earlier. The check has
   to be removed from the binary with a patcher such as
   [anzz1/WoWPatcher335](https://github.com/anzz1/WoWPatcher335) (keep the
   original). This is a real change to what "a clean client" means for
   anyone else who joins.

Delete `Cache/` in the client afterwards, as with any DBC change.

**Living with the HD patches.** The client here also runs Leeviathan's HD
patches (`Patch-F`/`G` mounts and creatures, `Patch-H` WoD character models
with its own goblin textures, `T` environment, `S` sunlight, `X` Cataclysm
trees). The first attempt crashed the moment the Worgen race button was
clicked: `ERROR #132` reading address 4 with `EAX = 0x72EF` - 29423, the
Worgen female display id from the module's `ChrRaces.dbc` - and `ESI = 0`,
a null `CreatureDisplayInfo` record. `Patch-F` and `Patch-G` each ship their
own `CreatureDisplayInfo.dbc` and `CreatureModelData.dbc`, and being past
`A` in the alphabet they replaced the module's copies wholesale, Worgen rows
included. Goblins survived because their display ids exist in the stock
file, but with scrambled faces: `Patch-H` carries its own `CharSections.dbc`
with 1,028 goblin rows of an older goblin patch, so two sets of goblin skins
sat side by side.

The fix is `tools/merge_dbc.py`, run by the install script: for each of the
eight contested DBCs it takes the HD patch's copy as the base and lays the
module's *changes relative to stock* on top (new ids, or ids whose content
differs from the original), so the HD work and the race work both survive.
It needs no knowledge of each DBC's layout: base rows and the base string
block are copied byte for byte, and only the module's rows are re-encoded,
with string columns detected by the rule that every value in all three
files is 0 or lands just past a NUL in the string block. For the three
character-appearance DBCs `Patch-H`'s non-stock goblin rows are dropped
first (`--base-drop 1=9,12`) so only the module's remain, and the module's
`Character\Goblin` folder rides along so its skins are the ones those rows
name. `CharacterFacialHairStyles.dbc` has no id column and is keyed on
race, sex and variation (`--key 0,1,2`). Everything lands in `patch-Z.MPQ`
(32 MB now), which loads after every HD patch. The HD copies of the eight
DBCs live in `client-patch/hd-dbc/` (probed out of the archives by name -
`Patch-H` has no listfile) and the untouched originals in
`client-patch/stock-dbc/`, so `tools/install_worgoblin_dbc.sh --client-only`
rebuilds `patch-Z` from scratch at any time.

### World-wide level scaling

Two modules, because instances and the open world need different handling:

* **Instances** - `mod-autobalance` (`run/etc/modules/AutoBalance.conf`).
  Scales dungeon and raid creatures to the group that walks in.
* **Open world** - `mod-worldscale`
  (`server/modules/mod-worldscale`, `run/etc/modules/mod_worldscale.conf`),
  written for this server because autobalance is hard-gated to
  `map->IsDungeon()` and does nothing outside instances.

`mod-worldscale` scales *per player* and never touches creature stats in the
world, because a creature in the open world is shared by everybody who can see
it. Instead it scales the damage exchanged between a player and a creature:

* creature -> player: the creature hits like a creature of the player's level
* player -> creature: the creature soaks damage as if it had the health pool of
  a creature of the player's level
* experience from creatures that were scaled *up* is paid out for the player's
  level, so levelling in a low level zone is viable (grey creatures included)

The multipliers come from the core's own `creature_classlevelstats` curve, so
they follow the same numbers the core uses when it spawns a creature. Both
directions can be turned off independently (`WorldScale.ScaleUp`,
`WorldScale.ScaleDown`), and `WorldScale.LevelDelta` shifts the whole world up
or down relative to the player. Open world bosses are excluded by default.

### All classes on all races

Three pieces:

1. **Client** - `CharBaseInfo.dbc` lists the race/class combinations the
   character creation screen offers. `tools/gen_all_classes_dbc.py` rewrites it
   with all 10 x 10 = 100 combinations and packs it into
   `client-patch/patch-Z.MPQ` (already copied into the client's `Data/`).
2. **Server** - `sql/01_all_classes_all_races.sql` adds the missing
   `playercreateinfo` rows (a new combination starts where that race already
   starts) and copies a default action bar for it. Starting *stats* need no
   work: AzerothCore builds them from `player_class_stats` plus the per-race
   modifiers in `player_race_stats`, so a Blood Elf Druid gets correct,
   race-adjusted stats. Starting skills and spells are keyed by race/class
   *masks* and already cover the new combinations.
3. **Starting gear** - `CharStartOutfit.dbc` (read by the server, not just the
   client) has no entry for a combination that never existed, which would mean
   starting with nothing. The same generator copies the outfit of a race that
   already plays that class, so every new combination starts with proper class
   gear and a hearthstone.

### Any race on either faction

`mod-factionchoice` (`server/modules/mod-factionchoice`) decouples faction from
race.

**On a character's first login** a window opens asking which side it will fight
for: Alliance, Horde, or stay with its own people. Pick the side your race does
not belong to and a second window asks *where* to begin, listing that side's
starting zones - Northshire Valley, Coldridge Valley, Shadowglen and Ammen Vale
for the Alliance; the Valley of Trials, Shadow Grave, Camp Narache and
Sunstrider Isle for the Horde - plus the capital. Choosing sends you there and
re-binds your hearthstone.

These are ordinary gossip windows, no client addon involved: the core's
`HandleGossipSelectOptionOpcode` accepts menus sent with the player's own GUID
and routes the answer to the `OnPlayerGossipSelect` hook. The window text lives
in `npc_text` (ids 90010 and 90011, see `sql/04_factionchoice_gossip.sql`), and
it appears `FactionChoice.PromptDelay` milliseconds after login so the client
has finished loading. A character is asked exactly once, and never if it
already picked a side with `.faction`; bots are never asked.

The zone list is built from `playercreateinfo`, one entry per distinct starting
position of the side's races, so dwarves and gnomes (and orcs and trolls) fold
into a single entry. `.faction zones alliance|horde` prints the same list from
the console.

Afterwards, or with `FactionChoice.PromptOnFirstLogin = 0`:

```
.faction alliance     play this character on the Alliance side
.faction horde        play this character on the Horde side
.faction reset        go back to the race's own faction
.faction status       show what is in effect
.faction where        re-open the "where do I start" chooser
.faction zones a|h    (GM) print the zones the chooser would offer
```

The choice is stored per character and re-applied on login. Three things change:

* **team** (`Player::setTeamId`) - what the server uses for battleground sides,
  graveyards, auction houses, chat channels and grouping.
* **faction template** - who is hostile. A Horde Human is attacked by Stormwind
  guards and welcomed in Orgrimmar.
* **reputations** - rebased onto the chosen side's starting values.

The third one is not optional, and it is worth knowing why. When a *creature*
works out how it feels about a *player*, the core does not compare faction
templates: `Unit::GetFactionReactionTo()` takes its CvP branch and uses the
player's reputation with the creature's faction. Reputation starting values
come from the character's race, so an Orc who picks Alliance is still at war
with Stormwind - its NPCs come out "unfriendly", which the client draws as red
name plates, and `Player::GetNPCIfCanInteractWith()` refuses anything at or
below unfriendly, so nobody will talk to you. The NPCs still do not *attack*,
because that check goes the other way round, which makes the symptom look odd.

So the module moves every reputation from the starting values of the
character's own race onto the values a character of the chosen side would have
had, keeping whatever the character earned on top of them, and sets the at-war
flags to match. It records which baseline is currently applied, so the change
is a transition (own race -> Alliance -> own race) instead of something that
drifts every time it runs, and `.faction reset` puts the original baseline
back.

### The core changes

Everything else on this server is modules, data and DBC files, with one
exception noted under "The first patch to mod-playerbots". The AzerothCore
source itself is touched in nine places - five additive hooks, two one-line
corrections, one script relaxation and one parameter added to an existing
method - and **all of them have to be remembered on any upstream merge**,
because the modules that depend on them will not compile without them:

| change | what it is for | documented under |
| --- | --- | --- |
| `ReputationMgr::AdoptFactionState` | faction switching, below | this section |
| `UnitScript::OnUnitGetLevelForTarget` hook | creatures aggroing and landing hits at their presented level | "Low level content that is still worth doing" |
| `PlayerScript::OnPlayerQuestComputeLevel` hook | quest levels sent to the client | the same |
| `UnitScript::OnUnitRewardRage` hook | rage income when damage is scaled | "Rage, when the damage is scaled" |
| `PlayerStorage.cpp` bonus talent read | a width bug, fixed | "Talent points on demand" |
| `Player::isHonorOrXPTarget` | kill procs against scaled creatures | "Kill procs, when the level is scaled" |
| `npc_professions.cpp` specialisation gossip | several profession specialisations per character | "More than one profession specialisation" |
| `Player::DestroyItemCount` + the two `Spell` reagent sites | crafting from bank reagents | "Crafting from the bank" |
| `AllCreatureScript::OnCreatureGetAggroRange` hook | aggro radius of scaled creatures | "Low level content that is still worth doing" |

The five hooks are each one `virtual` with an empty body, a dispatcher and a
call site (four also have an enabled-hook enum entry). The profession change is nine relaxed `if`
conditions behind a config flag that defaults to off. The two one-line
corrections are the only changes that alter existing behaviour unconditionally:
a stored
bonus talent count above 255 used to be silently truncated on login, and the
honor/experience test used to read a level nothing else in a scaled fight was
using. The reputation entry is a new method, and the only one of the six with
real logic in the core:

```
src/server/game/Reputation/ReputationMgr.{h,cpp}
    void ReputationMgr::AdoptFactionState(FactionEntry const*, uint32 flags, uint32 mask)
```

It overwrites the masked bits of a faction's state flags - visible, at war,
hidden, invisible-forced, peace-forced, rival, special - even when the
character's own race has that faction hidden or peace-forced, keeping the
visible-faction counter honest and sending `SMSG_SET_FACTION_VISIBLE` when a
faction is revealed. `FACTION_FLAG_INACTIVE` is left out of the mask the module
passes, because that one belongs to the player, not to a side. Nothing else in
the core calls it, so existing behaviour is unchanged - but **remember it on any
upstream merge of the core** (the module will not compile without it).

Why it is needed: `ReputationMgr::Initialize()` re-derives the at-war and hidden
flags from the character's **race** on every login, and the load path only
honours a saved "not at war" state `if (faction->Flags & FACTION_FLAG_VISIBLE)`.
The adopted side is hidden for the wrong race, so the clear was skipped and a
faction-switched character was put back at war with the side it had joined after
every single relog. Server-side the forced-reaction pins still said "friendly",
but the *client* decides whether to even send a gossip request and it uses its
own at-war state - so every reputation-bearing NPC, which is most of them,
silently refused to talk. `SetVisible()` and `SetAtWar()` both refuse on hidden
factions, the private setter is unreachable, `GetStateList()` is const, and the
rank-transition path needs `FactionEntry::CanBeSetAtWar()`, which requires
`BaseRepRaceMask[0] == 1791` and is false for every city faction. Hence the new
method.

The module calls it from `ReconcileFactionFlags()` on **every** login, not just
when the side changes, because the flags are re-derived each time while the
standings persist. Rather than patching up the war bit alone, it sets the whole
adopted flag set to exactly what a character of the chosen side would have been
given at creation: the new side's cities visible and peace-forced, the abandoned
side's hidden and at war, and everything else merely revealable so it enters the
reputation pane when it is actually met. A faction the character has already met
keeps its place in the pane unless the new side hides it outright. The
forced-reaction pins then become unnecessary in practice - the pin count for a
test character fell from 31 to 0.

#### Getting the flags to the client

Reconciling the server's flags is only half of it. The flags reach the client in
exactly one packet, `SMSG_INITIALIZE_FACTIONS`, sent from
`Player::SendInitialPacketsBeforeAddToMap()` - some 240 lines of
`WorldSession::HandlePlayerLogin` *before* the `OnPlayerLogin` hook this module
reconciles from. `ReputationMgr::SendStates()` is no help, because
`SMSG_SET_FACTION_STANDING` carries standings only, and 3.3.5 has no opcode for
flags on their own.

So the client went on using the at-war state it was handed at load - the
character's *race's*, not the side it joined - and kept refusing to open a
gossip window with NPCs the server was perfectly happy about. This is why the
symptom came back after the reputation-pane cleanup: clearing
`FACTION_FLAG_VISIBLE` from the saved rows (so unmet factions stay out of the
pane) also disabled the core's load-time `if (faction->Flags &
FACTION_FLAG_VISIBLE) SetAtWar(faction, false)`, which had until then been
quietly fixing the flags *before* that packet went out.

The module's `PushFactionFlags()` re-sends the whole table after reconciling,
and after any `.faction` change. It is one packet of about 650 bytes, once per
login, and it corrects the reputation pane's contents at the same time.

#### Why it does not narrate a screenful of reputation changes

`ReputationMgr::SendStates()` looks like the obvious way to push the result,
but it calls `SendState()` once **per faction** - 105 separate
`SMSG_SET_FACTION_STANDING` packets - and the client reports each as a
reputation change in the chat frame. Since `PushFactionFlags()` already sends
the same standings *and* flags in a single `SMSG_INITIALIZE_FACTIONS`, which is
the silent bulk initialiser, the per-faction sends are pure noise. Neither
`ReconcileFactionFlags()` nor `MoveReputationBaseline()` calls `SendStates()`
any more; every caller of both follows up with `PushFactionFlags()`.

Two things caused the login spam, and both are fixed:

* Characters with **no** faction override were being reconciled at all. That
  was a mistake introduced when `.faction reset` was made symmetric: for a
  natural Human it found 2 of 105 rows to "correct" every login (Frenzyheart
  Tribe and The Oracles, saved flags `0` against a race default of `16`
  peace-forced, both at standing 0), and those 2 changes triggered the 105
  packets. Worse than noisy, it also forced at-war flags back to race defaults,
  so a player's own war declarations were reverted on each login. The login
  path now only checks the reputation baseline; `ClearChoice()` reconciles at
  the moment a side is given up, which is the only time it is needed.
* The redundant `SendStates()` calls described above.

Standings were never at risk - `ReconcileFactionFlags` only ever touches flags,
and `AlignReputations` is a no-op unless the applied baseline differs from the
chosen side's.

#### Checking it without a client

`tools/diag_reactions.py` replays the whole chain offline -
`ReputationMgr::Initialize`, `LoadFromDB`, the module's `ReconcileFactionFlags`
and `PinReactions`, then `Unit::GetFactionReactionTo` - against `Faction.dbc`,
`FactionTemplate.dbc` and the character's saved rows, and reports which
creature faction templates would refuse to talk. Run it with no arguments for
every non-bot character, or name them:

```
python3 tools/diag_reactions.py Sarah Sokthun
```

The number that matters is the last line: how many faction templates a
cross-faction character refuses that a native of the chosen side would not.
It should be **0**. Both test characters (an Undead and an Orc on the Alliance)
now report 0, with 40 flag sets reconciled and 0 reactions pinned - the pins
are no longer needed now that the flags themselves are right.

The at-war flag cannot always be changed: `ReputationMgr::SetAtWar()` refuses
for factions that are hidden or peace-forced, and which ones those are comes
from the character's race. An Orc that joins the Alliance therefore stays
flagged at war with Stormwind however good its standing is. For those the
module pins the reaction instead, with the core's forced reactions
(`ApplyForceReaction`): `Unit::GetFactionReactionTo()` consults them before
anything else, and the client is told about them through
`SMSG_SET_FORCED_REACTIONS`, so server and client agree. Pins are held in
memory only and re-applied on every login.

Turn the whole reputation part off with `FactionChoice.AlignReputations = 0` if
you only want the faction template changed.

The core resets both to the race defaults in `Player::SetFactionForRace()`,
which runs on login and whenever a mind control or disguise effect ends. That
function calls the `OnPlayerUpdateFaction` hook, so the module re-applies the
override immediately; a cheap per-update check is the safety net. Effects that
are *supposed* to borrow your faction (mind control, faction auras) are left
alone while they last.

**The switch happens on arrival, not when you pick.** Changing hands
immediately would leave you standing in what had just become enemy territory,
with your own guards attacking you while the second window was still open. So
the order is: pick a side, pick where to start, travel, and the faction changes
once you land - the module waits for `IsBeingTeleported()` and
`PlayerLoading()` to clear, so it works for same-map and cross-map trips alike.
`.faction alliance` / `.faction horde` behave the same way. The prompt's
"answered" flag is likewise only set once the flow completes, so closing the
destination window without choosing re-offers the prompt on your next login
rather than silently losing it.

Switching sides teleports you to your new side and re-binds your hearthstone
there (`FactionChoice.TeleportOnSwitch`, `FactionChoice.SetHomebind`), because
the guards of your race's own home city turn hostile the moment you switch.
Where exactly depends on your level:

| Level | Destination |
| --- | --- |
| 1 to `FactionChoice.StarterZoneMaxLevel` (4 by default) | the new side's **starting zone** - Northshire Valley or the Valley of Trials |
| above that | the new side's **capital** - `FactionChoice.Capital.Alliance` / `.Horde` |

A capital is no use to a character that has not done its class quests yet, so
fresh characters land where a character of that side would have started. Both
positions come from data rather than hardcoded coordinates: the starting zone
from `playercreateinfo` for the side's proxy race, the capital from the world
database's `game_tele` table (the same names `.tele` accepts). Set
`StarterZoneMaxLevel = 0` to always use the capital.

Switching is refused in combat, in a battleground or arena, and inside
instances.

Two supporting changes come with it:

* All `AllowTwoSide.Interaction.*` options are on (chat, channels, group, guild,
  arena, auction, calendar), so the two sides can actually play together.
* `sql/03_quests_any_race.sql` removes the race requirement from quests
  (`AllowableRaces = 0`). Quest access is checked against your *race*, not your
  team, so without this a Horde Human could not take Horde quests (wrong race)
  and could not reach Alliance quest givers either (hostile) - 4919 of 9464
  quests were affected. The original values are saved in
  `quest_template_allowableraces_backup`; `sql/03_quests_any_race_revert.sql`
  puts them back.

### Every class can learn every weapon

`tools/gen_all_weapons_dbc.py` removes the class restriction from weapon
training, so any class can walk up to a weapon master and buy any weapon skill
at the normal price. A rogue can learn two-handed axes, a mage can learn swords.

Two server-side DBCs decide this. `Player::IsSpellFitByClassAndRace()`, which
`Trainer.cpp` consults both when listing a trainer's spells and when selling
one, checks the `ClassMask` on the `SkillLineAbility.dbc` row (0 means no
restriction) and requires a matching row in `SkillRaceClassInfo.dbc`. The
script clears the first and opens up the second for the fifteen weapon skills:

```
Swords, Axes, Maces, Daggers, Staves, Polearms, Fist Weapons, Thrown,
Two-Handed Swords/Axes/Maces, Bows, Guns, Crossbows, Wands
```

Neither file matters to the client here - trainer lists are built server side -
so **no client patch is needed** for this, unlike the class/race unlock.

Kept deliberately untouched: the automatic abilities that share those skill
lines (Shoot, Throw) stay class-restricted, and the racial weapon
specialisations live in other skill lines and are not touched at all, so no
race gains another race's bonuses. Every weapon skill uses the same
flags/tier in `SkillRaceClassInfo`, so opening the masks does not change
anyone's skill caps.

Wands needed one extra step: no trainer ever taught them, because caster
classes are simply given them at creation. `sql/06_weapon_masters_wands.sql`
adds the Wands proficiency and Shoot to every trainer that already teaches a
weapon skill.

Every weapon master keeps their own list - the class gate is gone, but the
*trainer's* list is not changed - so covering all fourteen trainable types
means visiting more than one. Wands (added by the SQL above) are available from
all of them.

| Master | Where | Teaches |
| --- | --- | --- |
| Woo Ping | Stormwind | Polearms, Swords, 2H Swords, Staves, Daggers, Crossbows |
| Buliwyf Stonehand | Ironforge | Axes, 2H Axes, Maces, 2H Maces, Guns, Fist |
| Bixi Wobblebonk | Ironforge | Daggers, Thrown, Crossbows |
| Ilyenia Moonfire | Darnassus | Staves, Bows, Daggers, Thrown, Fist |
| Handiir | the Exodar | Maces, 2H Maces, Swords, 2H Swords, Daggers, Crossbows |
| Sayoc | Orgrimmar | Axes, 2H Axes, Bows, Daggers, Thrown, Fist |
| Hanashi | Orgrimmar | Axes, 2H Axes, Staves, Bows, Thrown |
| Ansekhwa | Thunder Bluff | Maces, 2H Maces, Staves, Guns |
| Archibald | Undercity | Polearms, Swords, 2H Swords, Daggers, Crossbows |
| Ileda | Silvermoon City | Polearms, Swords, 2H Swords, Bows, Daggers, Thrown |
| Duelist Larenis | Eversong Woods | Polearms, Swords, 2H Swords, Bows, Daggers, Thrown |

Shortest routes to all fourteen: **Alliance** Stormwind + Ironforge +
Darnassus (Bows and Thrown only come from Ilyenia; Guns only from Buliwyf).
**Horde** Orgrimmar + Thunder Bluff + Undercity or Silvermoon (Guns only come
from Ansekhwa in Thunder Bluff).

To revert: restore `run/data/dbc/SkillLineAbility.dbc.orig` and
`SkillRaceClassInfo.dbc.orig` over the patched files, run the `DELETE` noted in
the SQL file, and restart.

### Lore chatter from the bots

`mod-botlore` owns everything the bots say. Playerbots' own chatter is off, and
it took **four** switches rather than the one it first appeared to:

| setting | what it was producing |
| --- | --- |
| `AiPlayerbot.EnableBroadcasts = 0` | the channel spam - "Wanna party in Duskwood.", "WTS [item] for 5g." Makes `BroadcastHelper` return early and zeroes `broadcastChanceMaxValue`. |
| `AiPlayerbot.RandomBotTalk = 0` | "suggest what to do / suggest dungeon / suggest trade" on an `often` trigger - the same noise, locally |
| `AiPlayerbot.RandomBotEmote = 0` | see below |
| `AiPlayerbot.EnableGreet = 0` | `new player nearby -> greet` |

`RandomBotEmote` was originally turned **on**, on the understanding that it was
emote-only with no text. That is wrong twice over. `EmoteStrategy` installs a
`talk` action on `often`, and - the real problem - a reaction trigger:

```cpp
triggers.push_back(new TriggerNode("receive text emote", { NextAction("emote", 10.0f) }));
triggers.push_back(new TriggerNode("receive emote",      { NextAction("emote", 10.0f) }));
```

A bot that *receives* an emote emotes back, at priority 10, with text -
`"Hey there!"` (`EmoteAction.cpp:183`). That reply is itself an emote the next
bot receives. `EnableGreet` lights the fuse on "new player nearby", and once
quest hubs began packing hundreds of bots onto shared coordinates it became a
standing ovation that never ended. `EmoteStrategy` is the only route to either
action, so with these off nothing the bots say comes from anywhere but the
corpus.

**The corpus** is 11,868 lines across 10 triggers, emitted to
`sql/13_bot_lore.sql` by two generator files. The prose lives in Python because
it *is* prose - it needs to be readable and editable. Re-run the generator,
apply the SQL, and `.botlore reload` picks it up without a restart.

| trigger | lines |
| --- | --- |
| `idle` | 3,548 |
| `loot_rare` | 2,876 |
| `quest_accept` | 1,353 |
| `quest_complete` | 1,296 |
| `zone_enter` | 933 |
| `combat_start` | 678 |
| `death` | 649 |
| `level_up` | 268 |
| `kill_boss` | 248 |
| `kill` | 19 |

It is written in two halves, because they are two different kinds of writing.

`tools/gen_bot_lore.py` holds the **placed** lines - this zone, that quest, that
named creature. Every id in it was checked against `quest_template`,
`creature_template` or `item_template` first, which caught eight boss entries
that were the wrong creature entirely (9019 is Emperor Dagran Thaurissan, not
Grimlok). That half tops out in the high hundreds, because each line is authored
individually.

`tools/gen_bot_lore_combos.py` is the other half and supplies the volume. It
authors *fragments* along the axes the module can actually filter on, and
multiplies them out. Two complete sentences joined with a space stay
grammatical, so an object observation plus an archetype reaction produces a line
neither fragment was written to be:

```
"A two-handed hammer. Heavy work, and honest work."        item class 2/5
"The Light gave it into my hands. I will not waste it."    devout
```

becomes one row filtered to *devout, plate-wearing, looting a two-handed mace* -
which given the archetype table can only be a paladin. Roughly 900 authored
fragments produce just under 11,000 lines that way, and the result is not
repetitive precisely because each line carries the full filter set of both
halves: a bot only ever draws from the slice that fits who it is.

The layers, and what each one crosses:

Counted by which filters a row actually carries:

| slice | crosses | rows |
| --- | --- | --- |
| class alone | 10 classes x their 4 archetypes, all triggers | 2,450 |
| item category | 26 categories x archetype x wielding class | 2,199 |
| named quests | 38 quest ids x 6 lines x archetype | 2,124 |
| race alone | 10 races x 8 archetypes | 1,638 |
| specialisation | 30 class/tree pairs x archetype | 780 |
| race and class together | 50 race/class pairs x archetype | 784 |
| named items | 36 item ids x archetype | 660 |
| gender | 20 class forms and 20 race forms x archetype | 484 |
| placed by zone or area | 74 zones, all four continents | 252 |
| generic fallbacks | nothing - these only surface when nothing else fits | 467 |
| named creatures | 48 verified boss entries | 48 |

**Identity signals.** Six, all read straight off the character:

| signal | source | filter column |
| --- | --- | --- |
| class | `getClass()` | `ClassMask` |
| archetype | FNV-1a of the name | `PersonalityMask` |
| race | `getRace()` | `RaceMask` |
| gender | `getGender()` | `Gender` |
| specialisation | `GetMostPointsTalentTree()` | `SpecMask` |
| item category | `ItemTemplate::Class`/`SubClass` | `ItemClass`, `ItemSubClass` |

Gender is only used where it changes the words - kinship and the forms of
address the orders use, *brother* and *sister* of the Light, *son* and
*daughter* of Mulgore. Everything else is written to read correctly either way.

Specialisation has a trap in it. `GetMostPointsTalentTree()` weighs three
counters and returns the index of the largest, so with nothing spent it returns
**0** rather than "no spec" - every fresh character would read as Arms, Holy,
Beast Mastery and so on down the list. `MatchesFilters` therefore rejects
spec-filtered lines outright when `GetTalentMap()` is empty, which keeps those
lines silent until the bot has actually chosen.

**Personality.** Eight archetypes - devout, grim, scholar, boastful, wry,
haunted, savage, sinister - and each class may only draw from the four that
suit it. A warlock is never devout; a paladin is never sinister. Which one a bot
gets is FNV-1a over its lowercased name, modulo its class's allowed set, so it
is stable for the life of the character and identical across restarts without
storing anything. Two warriors in the same field have different voices, and the
same warrior always has the same one.

Verified live: six paladins came out devout/boastful/grim/boastful/devout/
boastful and five warriors savage/grim/savage/wry/wry - only ever from their own
class's set.

**Selection** weights by specificity rather than filtering on it. An earlier
version preferred the most specific match and *suppressed* everything else,
which meant a bot standing in a zone with authored lines could only ever say
those. Now each candidate's weight is multiplied by
`1 + specificity * BotLore.SpecificityWeight` (6 by default), so the Duskwood
line is heavily favoured in Duskwood without the generic pool going silent.

`.botlore test <bot> <trigger> [entry]` resolves and speaks a line on demand and
prints the bot's archetype. The optional third argument is whatever entry the
trigger is about - an item for `loot_rare`, a quest for the quest triggers, a
creature for the kill ones. Without it a forced test cannot reach any line
filtered on item class, quest id or creature entry, which is now most of the
corpus:

```
.botlore test Raitu loot_rare 6953      # Verigan's Fist, a paladin libram
.botlore test Raitu quest_accept 55     # Morbent Fel
```

**Gating**, in evaluation order, because these hooks run for 500 bots: trigger
enabled, any real player online at all, bot-ness, a real player within
`BotLore.RangeYards`, per-bot cooldown, then a chance roll. A bot alone in a
field costs one branch - nothing is ever said with nobody to hear it, which is
also why `Idle` and `CombatStart` are safe to have on. `Kill` stays off: it
fires on every corpse.

**Rate.** Deliberately sparse: `Chance = 12`, `CooldownSeconds = 1200`,
`IdleSeconds = 900`. The cooldown is a hard per-bot cap, so a bot's rate is
`min(1 per cooldown, trigger rate x chance)` - at 1200 that is at most three
lines an hour from any one bot, and with a handful in earshot it comes out at a
line every few minutes. Variety comes from the size of the corpus and the
number of bots, not from any one of them talking often; a bot that speaks rarely
reads as a person, one that speaks often reads as a chat log. `KillBoss` (50)
and `LevelUp` (35) are the exceptions, because both are earned moments.

On login each bot's cooldown is seeded to `now + urand(0, CooldownSeconds)`
rather than zero, so 500 of them do not all become eligible in the same second
after a restart. It also means `.botlore test` refuses for most bots for the
first 20 minutes after startup, which is not a fault.

**Two ordering traps**, both learned the hard way:

* **Apply the SQL before installing the binary.** The module's loader selects
  `PersonalityMask` and `QuestId`; running a binary that expects them against a
  table that lacks them fails the query, and the core treats a failed query as
  *"Your database structure is not up to date"* and **aborts startup**. That is
  how this feature took the server down once.
* Load the table in `OnStartup()`, not `OnAfterConfigLoad()` - the DBC and
  object stores do not exist at config-load time, so validating zone and
  creature ids there silently discards every row.

### Buying languages from faction leaders

`mod-languages` (`server/modules/mod-languages`) lets a character pay a faction
leader to teach it their people's language. Talk to the leader and the offer
appears in their own gossip window, with the client's usual "this will cost
money" confirmation box:

> Teach me to speak Orcish (100 gold).

Each teacher wants **100 gold** and **Exalted** reputation with their own
faction. The requirement is shown rather than hidden, so the option reads
either "Teach me to speak Orcish (100 gold)." or "Teach me to speak Orcish
(requires Exalted with Orgrimmar)."

`sql/05_language_teachers.sql` seeds all fourteen languages that 3.3.5 has a
spell for:

| Teacher | Language | Reputation needed |
| --- | --- | --- |
| King Varian Wrynn | Common | Exalted, Stormwind |
| King Magni Bronzebeard | Dwarvish | Exalted, Ironforge |
| High Tinker Mekkatorque | Gnomish | Exalted, Gnomeregan Exiles |
| Tyrande Whisperwind | Darnassian | Exalted, Darnassus |
| Prophet Velen | Draenei | Exalted, the Exodar |
| Thrall | Orcish | Exalted, Orgrimmar |
| Cairne Bloodhoof | Taurahe | Exalted, Thunder Bluff |
| Lady Sylvanas Windrunner | Gutterspeak | Exalted, Undercity |
| Vol'jin | Troll | Exalted, Darkspear Trolls |
| Lor'themar Theron | Thalassian | Exalted, Silvermoon City |
| Alexstrasza, Wyrmrest Temple | **Draconic** | Exalted, the Wyrmrest Accord |
| Duke Hydraxis | **Kalimag** (elemental) | Exalted, Hydraxian Waterlords |
| Lillehoff, Sons of Hodir | **Titan** | Exalted, the Sons of Hodir |
| Demisette Cloyce, the Slaughtered Lamb | **Demonic** | Exalted, Stormwind |
| Nartok, the Cleft of Shadow | **Demonic** | Exalted, Orgrimmar |

Notes on the ones that are not racial:

* **Demonic** has no faction of its own - 3.3.5 has no demonic reputation - so
  the warlocks who actually speak it teach it, gated on the city that tolerates
  them, one per side.
* **Cult of the Damned** was the other candidate for Demonic and does not work:
  every cultist in 3.3.5 is hostile and carries no gossip flag, so no window
  can be opened with one, and the cult has no reputation faction.
* **Furbolg, Goblin, Ethereal** and the rest have no language spell in this
  expansion. Timbermaw Hold and the Kalu'ak do have reputation, but there is
  nothing to teach - the client has no such language.
* **Draconic** could equally hang off Netherwing (Mordenai) or the Scale of the
  Sands; both are noted in the SQL file.

Everything is data in the world database table `language_teacher`:

```sql
UPDATE language_teacher SET Cost = 500000;                     -- 50g for everything
UPDATE language_teacher SET RequiredRank = 5;                  -- honored instead of exalted
UPDATE language_teacher SET RequiredFaction = 0 WHERE Spell = 668;  -- Common, no reputation needed
INSERT INTO language_teacher VALUES (1234, 669, 1000000, 76, 7, 'Orcish', 'another orc');
```

The `Name` column is the label the option uses. It exists because the spell
names are not presentable: they read "Language Common", and Kalimag's is
"Language Old Tongue (NYI)" - Blizzard never finished the player-facing spell,
even though the client's own `Languages.dbc` knows the language as Kalimag and
will happily speak it. The seeded names match that client list. Leave `Name`
empty and the module falls back to the spell name with the `Language ` prefix
and ` (NYI)` suffix trimmed off.

`RequiredRank` is the usual 0-7 scale (4 friendly, 5 honored, 6 revered,
7 exalted), and `Languages.RequireReputation = 0` in the module config ignores
the requirement entirely.

`.language list` prints the loaded table (GM), `.language reload` re-reads it
without a restart (admin). The spell ids are the ones the core uses for
languages itself (`lang_description` in `ObjectMgr.cpp`), and the option only
appears for languages the character does not already know.

This pairs with the faction choice: a Horde character playing Alliance can walk
into Stormwind, buy Common, and actually be understood in /say.

Two implementation notes. The option is added in C++ rather than as a
`gossip_menu_option` row because the core gives every database option the same
sender and action (`0`), which would make the click impossible to identify; the
`CanCreatureGossipHello` hook runs before both the creature's own script and
the core's default handling, so the leader's normal menu is rebuilt with
`PrepareGossipMenu` (quests and existing options intact) and the language
option added on top. And King Magni and Tyrande were flagged quest-giver-only,
so the SQL adds the gossip bit to them - otherwise the core shows their quest
list instead of a gossip window whenever they have a quest to offer. The revert
statement is in the same file.

### Extra large bags for everyone

Four 36-slot containers (item 23162), the largest general purpose bag that
exists in 3.3.5a - 144 bag slots on top of the 16 slot backpack. It is not
unique, so four can be equipped at once, and its sell price is zero, so the
bags cannot be turned into gold:

* **New characters** - `sql/02_big_bags.sql` adds the bags to
  `playercreateinfo_item` for every race/class combination. The core equips
  starting containers one by one, so they land in the four bag slots.
* **Existing characters and bots** - `mod-bigbags`
  (`server/modules/mod-bigbags`) fills empty bag slots on login, once per
  character. The grant is remembered through the core's player settings
  (`EnablePlayerSettings = 1`), so bags cannot be farmed by deleting them.

Change `BigBags.BagEntry` in `run/etc/modules/mod_bigbags.conf` to use a
different bag - 51809 is a 24 slot Portable Hole, 38082 the 22 slot
"Gigantique" Bag.

Random bots are the exception: `mod-playerbots` equips its own bags
(`PlayerbotFactory::InitBags` hardcodes the 24 slot Portable Hole) and destroys
whatever was in the bag slots when it re-gears a bot, so bots end up with
playerbots' bags rather than these. Your own characters keep theirs.

### Bigger item stacks

Trade goods stack to **999**; consumables and reagents to 200, the way retail
eventually did - 2343 items in total, across two scripts.

`sql/08_trade_goods_stacks.sql` raises every stackable trade good (item class
7) - 758 items, of which 593 used to stack to 20, 124 to 10 and 39 to 5. Ore,
cloth, leather, herbs, stone, elemental and enchanting materials are all in
here. The 168 trade goods that are genuinely non-stackable are left alone, and
the bound is `stackable < 999` so the change only ever raises a limit.

It went to 200 first (the retail figure) and to 999 later, once every layer
that could cap it had been checked rather than assumed:

| layer | limit |
| --- | --- |
| item loader | corrects only 0 and below -1; no upper clamp |
| `GetMaxStackSize()` | passes the value straight through |
| `item_instance.count` | `int unsigned` |
| `ITEM_FIELD_STACK_COUNT` | 32-bit |
| client bag count (`SetItemButtonCount`) | draws up to 9999, then `*` |
| client auction stack box | four digits |
| stack-split dialog | unbounded |

999 keeps every count at three digits in every UI that draws one. The auction
bot's lots are held at 200 separately (`TradeGoodsFullStack.Max`), because a
lot the size of the whole stack would be five times the price and more than a
buyer wanting forty needs to carry away. Existing 200-stacks stay as they are
until merged by hand.

Stack size is **server side only**, so this needs no client patch. `Item.dbc`
carries just eight fields (ID, class, subclass, sound override, material,
display info, inventory type, sheath) and the stack limit is not one of them;
the client is told it at runtime in `SMSG_ITEM_QUERY_SINGLE_RESPONSE`, sent
straight from `item_template` by `WorldSession::HandleItemQuerySingleOpcode`
(`ItemHandler.cpp:441`). The client needs no convincing that 200 is legal
either - the stock data already ships 87 items at 200, 144 at 250, 51 at 1000
and 21 at 2147483647 - and the core does not clamp: `ObjectMgr` only rejects 0
and values below -1, and `ItemTemplate::GetMaxStackSize()` passes the rest
through.

Two things to know when changing this again:

* **A worldserver restart is required.** This core has no `.reload
  item_template` command, only `item_template_locale`.
* **Clients cache item data.** The client writes what it was told into
  `Cache/WDB/<locale>/itemcache.wdb` and reuses it on later sessions without
  re-querying, so the `Cache` folder in the WoW directory has to be deleted or
  it will go on showing the old limit.

Gems are item class 3, not 7, so they are untouched at 20. Original values live
in `item_template_stackable_backup`; `sql/08_trade_goods_stacks_revert.sql`
puts them back.

`sql/09_consumable_reagent_stacks.sql` does the same for consumables and
reagents - another 1585 items:

| selector | items | what it is |
| --- | --- | --- |
| `class = 0` | 1547 | Consumable: potions, elixirs, flasks, food and drink, bandages, scrolls, conjured food and water |
| `class = 5` | 1 | Reagent, the top-level class - 3.3.5 barely uses it |
| `class = 15 AND subclass = 1` | 37 | Reagent as a subclass of Miscellaneous: Arcane Powder, Symbol of Kings, Symbol of Divinity, Rune of Teleportation, Rune of Portals, Sacred and Devout Candle, Flash Powder, Frost Vial, the druid seeds |

The third row is the one that matters and the easy one to miss: item class 5 is
*named* Reagent but holds only four items in 3.3.5, one of them stackable.
Every reagent a player actually carries is class 15 subclass 1. The rest of
class 15 - junk, pets, holiday items, mounts - is deliberately excluded, and
that is asserted after applying: 0 rows of any other class 15 subclass appear
in the backup table.

Both scripts share `item_template_stackable_backup` (`INSERT IGNORE`, so they
do not tread on each other) and both revert scripts filter by item class, so
trade goods and consumables can be rolled back independently.

### Low level content that is still worth doing

Three separate mechanisms, because scaling the fight is not the same as
scaling the reward.

**Creatures** - `mod-worldscale` scales a creature's outgoing damage up to the
player's level and scales the player's damage to it *down* by the health
ratio, so a level 5 mob effectively has a level 60 health pool and hits like a
level 60 mob. Nothing about the creature's own level, health field or nameplate
changes, which keeps it invisible to the client.

**Kill experience** - rescaled to the level the creature was scaled to, through
`OnPlayerGiveXP`.

**Grey creatures** were the hole, and the module's original code for them could
never run. `KillRewarder::_RewardXP` computes the experience first and only then
calls the hook, inside a guard:

```cpp
if (xp)
{
    xp *= player->GetTotalAuraMultiplier(SPELL_AURA_MOD_XP_PCT);
    sScriptMgr->OnPlayerGiveXP(player, xp, _victim, XPSOURCE_KILL);
    player->GiveXP(xp, _victim, _groupRate);
}
```

A grey kill is worth 0, so the block is skipped and `OnPlayerGiveXP` is never
reached. The grey branch inside it was dead code. It now lives in
`OnPlayerCreatureKill`, which fires unconditionally from `Unit::Kill`, and is
guarded to act *only* when `Acore::XP::BaseGain` values the kill at zero - so a
creature the core still pays for cannot be paid twice. `Player::GiveXP` does not
itself call `OnPlayerGiveXP`, so there is no re-entry.

This matters more than it sounds: `Acore::XP::GetGrayLevel` returns
`pl_level - 9` above level 60, so at level 80 everything below level 72 is grey
- essentially the whole old world.

**How they present** - a creature scaled up to hit like level 60 still showed
its own low level, so the nameplate was the one part of the illusion telling the
player the wrong thing: a grey name on something that is a real fight.
`WorldScale.PresentLevel` fixes that, and it is **cosmetic only**.

`UNIT_FIELD_LEVEL` is an update field, so only the number written into the
packet changes. The creature's real level, its combat maths (miss, glancing,
crushing, spell hit, defence skill), its experience value, loot and reputation
are all still computed from the true level, with the damage multipliers above
doing the actual balancing.

Crucially it is **per observer**, which is why this uses the script hooks rather
than `Creature::SetLevel()`. `SetLevel()` writes one value for everybody and
drags the combat maths along with it - fine for mod-autobalance inside a dungeon
where one party shares a level range (`ABAllCreatureScript.cpp:150` does exactly
that), wrong in an open world where 500 bots from level 1 to 80 can all see the
same boar. The core builds update blocks per player and patches tracked fields
in afterwards, so each observer can be sent a different number:

```cpp
// record where the field landed in the cached buffer
bool ShouldTrackValuesUpdatePosByIndex(Unit const*, uint8, uint16 index);
// write this observer's value in at that offset
void OnPatchValuesUpdate(Unit const*, ByteBuffer&, BuildValuesCachePosPointers&, Player* target);
```

Those hooks exist for precisely this purpose and no other module was using them.
The offset arrives in the generic `posPointers.other[UNIT_FIELD_LEVEL]` map, so
no core change was needed.

Only the scale-*up* direction is relabelled: a creature above the player keeps
its real, higher level so it still reads as dangerous, which matters now that
`ScaleDown` is 0.

Two things to know:

* The level reaches the client with the **create-object block**, when the
  creature comes into view. A creature already on screen when the player levels
  up keeps the old number until it leaves and re-enters visibility.
* `UnitUtils.h` has **no include guard** and `Unit.h` already includes it.
  Including it explicitly redefines `MMapTargetData`, `SafeUnitPointer`,
  `BuildValuesCachePosPointers` and `BuildValuesCachedBuffer`. Take
  `BuildValuesCachePosPointers` from `Unit.h`.

**Higher level content stays off limits.** `WorldScale.ScaleDown` is 0, against
the module's own default of 1 - with it on, its config comment reads "so any
zone can be entered at any level", which is the opposite of what is wanted here.
Quest access is unaffected either way: `Player::SatisfyQuestLevel` gates on
`MinLevel` and `MaxLevel` and never looks at `QuestLevel`.

**Quests** - `WorldScale.ScaleQuests`, two hooks, and the quest levels left
alone in the database.

The first attempt set `QuestLevel = -1` on all 8071 fixed-level quests, because
that is the core's own sentinel for "this quest is the player's level" and 1324
stock quests already ship that way. It worked for the display, but it had a real
cost that only showed up when the numbers were checked: `Quest::XPValue` reads
the level *twice*, once for `diffFactor` and once as the `QuestXP.dbc` row to
read, so measuring everything at the player's level also **reduced** the reward
for quests *above* the player. Stormpike's Delivery at level 12 went 1050 -> 900.

So the levels were restored (`sql/12_quests_scale_to_player_revert.sql`) and the
work moved into two hooks:

* `OnPlayerQuestComputeXP` - recompute at the player's level when the quest is
  *below* them, and take the better of the two values. Upwards only, so a
  reward can never shrink. At level 60, Report to Gryan Stoutmantle goes from
  65 XP to 7150; Stormpike's Delivery keeps its full 1050 at level 12.
* `OnPlayerQuestComputeLevel` - a new hook, applied at the three places
  `PlayerMenu` writes a quest level to the client (the two quest-list packets
  and the query response that drives the quest log). A quest at or below the
  player is reported as **-1**; one above keeps its real level.

Sending -1 rather than the player's actual number is deliberate. The client
resolves -1 when it *draws* the quest, not when it writes `questcache.wdb`, so
it never goes stale after a level up - a hardcoded number would be frozen at
whatever level the quest was first seen. A quest above the player is sent its
real level, which is correct permanently because that value never changes.

Net effect: low level quests read at the player's level and pay out at it,
quests ahead of the player still read as ahead and keep their larger reward.

Three things this cannot reach:

* **Quest money and item rewards.** `RewardMoney` is a fixed column with no
  scaling path (at max level `GetRewMoneyMaxLevel()` replaces the XP instead),
  and item rewards are specific items.
* **Quest availability**, which is unchanged by design:
  `Player::SatisfyQuestLevel` gates on `MinLevel` and `MaxLevel` and never looks
  at the quest level.
* **Addons with their own quest database.** Questie bundles static quest data in
  Lua and reports its own levels no matter what the server sends - which is
  worth knowing, because it is what made this look broken while it was working:
  the quest *log* showed everything correctly at the player's level while
  Questie still showed the original numbers.

### Rage, when the damage is scaled

A level 12 warrior fighting a level 2 creature generated almost no rage, and it
took a while to see why, because nothing about the rage code is wrong.

`mod-worldscale` lengthens a low level fight by cutting the *player's* damage
rather than raising the creature's health - health is one shared value on the
creature, so it cannot be scaled per player, while damage can. Against a level 2
creature at level 12 the real multipliers, from `creature_classlevelstats`, are:

```
player -> creature   x0.223      base health 55 / 247
creature -> player  x18.91       base damage 5.4601 / 0.2888
```

Rage income is a function of damage (`Unit::RewardRage`), so cutting damage to
22% cut rage to 22% with it. That much was predictable. What made it severe is
the clamp:

```cpp
float rageFromDamageDealt = damage / rageconversion * 7.5f;
addRage = (rageFromDamageDealt + weaponSpeedHitFactor) / 2.0f;
addRage = std::min(addRage, rageFromDamageDealt * 2.0f);
```

The `weaponSpeedHitFactor` term is the part that does *not* depend on damage,
and the clamp is what stops it paying disproportionate rage on low damage hits.
That is correct retail behaviour - the core cites Bornak's 2009 post for it -
and scaled-down damage walks straight into the case it was written for. For a
level 12 warrior with a 2.6s weapon (`rageconversion` = 44.28):

| | damage | rage per swing |
| --- | --- | --- |
| unscaled | 30 | 7.04 |
| scaled x0.223 | 6 | **2.03**, clamp binding |

And once the clamp binds, rage from attacking is purely proportional to damage,
so it no longer grows with the length of the fight. Total rage from hitting the
creature across the whole kill becomes `15 x health / 44.28` - about **14 rage
for a 42 health creature**, whatever the multiplier, in a fight now lasting
twenty seconds. Heroic Strike costs 15. What rage did arrive was mostly coming
from *taking* hits at 18.91x damage, which is why it felt wrong rather than
merely slow.

The fix is symmetric, because both halves of the exchange were scaled. The
`OnUnitRewardRage` hook fires at the top of `Unit::RewardRage`, before the
formula reads the damage, and `mod-worldscale` divides that figure by whichever
multiplier it applied: `playerDamage` for rage from damage dealt,
`creatureDamage` for rage from damage taken. Rage then behaves exactly as it
would in an at-level fight in both directions, while the damage itself stays
scaled - and because `rageFromDamageDealt` is full size again, the clamp stops
binding of its own accord.

Dividing the post-armor figure back up is exact rather than approximate:
armor reduction is a percentage, so it commutes with a constant multiplier.

`RewardRage` gained an optional trailing `Unit* other` parameter to carry the
unit on the other side of the exchange, since the hook needs the creature to
know which multiplier was applied and the method only ever knew the rage
gainer. All five call sites pass it; nothing outside `Unit.cpp` calls it.

It also affects bear-form druids, for the same reason. `Bloodrage`,
`Berserker Rage` and `Charge` were never affected - they grant flat rage.

The scope is narrow, which is why it is only noticeable at the bottom: at
level 12 the multiplier is 0.80 against a level 10 and 0.55 against a level 7.
It is the 1-4 range that collapses.

### Aggro range, when the level is scaled

Presenting a creature at the player's level makes it as alert as an at-level
one. `Creature::GetAggroRange` builds the radius from the creature's
`detection_range` (20 for 23,035 of the templates, 18 for most of the rest)
minus one yard per level the target is above it, floor 5 - and it reads the
level through `getLevelForTarget`, the same hook that gives scaled creatures
an at-level melee skill gap. So the "aggro and avoidance" choice for that hook
had a side effect the table makes obvious:

| creature vs you | stock aggro | presented at your level |
| --- | --- | --- |
| at level | 20 yd | 20 yd |
| 5 below | 15 yd | 20 yd |
| 10 below | 10 yd | 20 yd |
| 15+ below | 5 yd | 20 yd |

Every creature in a zone lunging from twenty yards is a different game from
"fights at your level", and it felt like it. The level hook cannot tell an
aggro query from an avoidance query, so tuning one without the other needed a
point that is only ever about aggro: `AllCreatureScript::OnCreatureGetAggroRange`,
which fires inside `GetAggroRange` after the level and aura terms and before
the clamps. `mod-worldscale` subtracts `WorldScale.Aggro.LevelsBelow` yards
from the radius of scaled-up creatures only - the formula's own unit, one yard
per level - and the core's 5-yard floor still applies after it. It is **5**
here, so scaled creatures notice you as a creature five levels down would, at
15 yards; 10 gives 10 yards and 15 the old grey floor. Live on `reload config`.

`Creature::GetAttackDistance` is a second, near-identical formula that the
stealth-visibility check uses (`Object.cpp`, `checkAlert`) and is left alone;
it decides whether a stealthed player is *noticed at range*, not whether a
creature pulls.

### Kill procs, when the level is scaled

Victory Rush stopped working on scaled-up creatures, and it is a separate
mechanism from the experience fix - so it stayed broken after that one.

Spells that need a worthwhile kill are gated by
`PROC_ATTR_REQ_EXP_OR_HONOR`, which resolves through:

```cpp
bool Player::isHonorOrXPTarget(Unit* victim) const
{
    uint8 v_level = victim->GetLevel();                  // the real level
    uint8 k_grey  = Acore::XP::GetGrayLevel(GetLevel());
    if (v_level <= k_grey)
        return false;
```

`mod-worldscale` relabels the creature and pays experience for the kill, but
this read the *real* level, so a scaled grey silently failed every such proc.

The reach is much wider than it looks. Only 15 rows in `spell_proc` set that
attribute (Drain Soul, Vendetta, Butchery, Improved Blood Presence, Glyph of
Death Grip, Swift Hand of Justice, Spinal Reaper and a handful of quest and
trinket effects) - but `SpellMgr::LoadSpellProcs` hands it to **every** spell
whose DBC proc flags include `PROC_FLAG_KILL`:

```cpp
procEntry.AttributesMask  = 0;
if (spellInfo->ProcFlags & PROC_FLAG_KILL)
    procEntry.AttributesMask |= PROC_ATTR_REQ_EXP_OR_HONOR;
```

which is how Victory Rush is affected while having no `spell_proc` row at all.

The fix reuses the hook that already exists for this question:

```cpp
uint8 v_level = victim->getLevelForTarget(this);
```

`Unit::getLevelForTarget` returns `GetLevel()` for anything unscaled, so stock
behaviour is unchanged, and world bosses (which return player level + 3) were
never grey either way. Scaled creatures now answer consistently with the aggro
range, melee skill gap, experience award and rage income that already follow
the presented level.

One coupling to be aware of: this follows `WorldScale.PresentLevel`. With that
off but `ScaleUp` on, scaled greys would pay experience without satisfying
proc requirements - the two would disagree again.

### Where the bots are

Out of the box the bots clustered at Northshire Abbey and the Lion's Pride Inn
and nowhere else in the zone. Three separate causes, all in `mod-playerbots`:

1. **Destinations were "travel hubs".** With `EnableNewRpgStrategy = 1`,
   `TravelMgr::GetTeleportLocations` returns `allianceHubsPerLevelCache`, built
   from **innkeepers** (plus flight masters in the handful of zones that have
   no inn) and, for levels 1-5 only, the race's **starting position**. For a
   low-level bot that *is* the entire candidate list, so Northshire and the
   Lion's Pride Inn were the only two places it could be sent.
2. **Low levels are leashed to their own starting zone.**
   `PlayerbotAI::StarterLevelDistanceCheck` is hardcoded: within 500 yards of
   the race's start position at level <= 4, 2500 at <= 10, 10000 at 11-16, and
   unrestricted above 16, same map required. A level 5 Dwarf bot therefore can
   never appear in Elwynn - only human-start bots can.
3. **Per-location jitter is dead code.** The offset that would scatter bots
   around a destination is commented out in `RandomTeleport`, so they land
   exactly on the point, on top of one another.

The first fix was to turn the RPG strategy **off**, which swings
`GetTeleportLocations` over to `locsPerLevelCache` - points derived from
creature spawn grids, spread right across every zone. That solved the
clustering, and it is why the bots spent a long time purely grinding. It has
since been turned back **on**, for reasons under "Bots that actually quest"
below; the spread is now handled by quest hubs instead.

Current settings, all in `run/etc/modules/playerbots.conf` and registered in
`tools/apply_config.py`:

| setting | stock | here | effect |
| --- | --- | --- | --- |
| `AiPlayerbot.RandomBotConcentrateInPlayerZone` | 0 | **1** | filters candidate locations to zones holding a real, non-GM player |
| `AiPlayerbot.ProbTeleToQuestHubs` | - | **0.25** | new; a quarter of teleports go to a quest hub |
| `AiPlayerbot.EnableNewRpgStrategy` | 1 | **1** | the real quest loop |
| `AiPlayerbot.RpgStatusProbWeight.TravelFlight` | 15 | **0** | no cross-zone flights |
| `AiPlayerbot.Min/MaxRandomBotTeleportInterval` | 3600/18000 | **600/1800** | relocation every 10-30 minutes rather than every 1-5 hours |
| `AiPlayerbot.LevelBrackets.Enabled` | 0 | **1** | keeps the population spread across level brackets instead of letting it drift to 80 |
| `AiPlayerbot.LevelBrackets.CheckFrequency` | 300 | 300 | seconds between redistributions |
| `AiPlayerbot.LevelBrackets.Dynamic.UseDynamicDistribution` | 0 | **1** | sizes the brackets from who is actually online |
| `AiPlayerbot.LevelBrackets.Dynamic.SyncFactions` | 0 | **1** | keeps Alliance and Horde bracket counts in step |
| `AiPlayerbot.LevelBrackets.Dynamic.RealPlayerWeight` | 1.0 | **10.0** | the option's own docs recommend this "if you want a large congestion of bots in your level bracket for solo play" |

`RandomBotConcentrateInPlayerZone` only does anything **while a real player is
online** - it falls back to world-wide behaviour otherwise - so its effect
cannot be observed from the console with nobody logged in.

`AiPlayerbot.BroadcastChanceSuggestSomething` is also managed, at **3000**
against a stock 30000. It is redundant now - `EnableBroadcasts = 0` zeroes
`broadcastChanceMaxValue` before it is consulted - and is kept only so the
value is sane if broadcasts are ever switched back on.

### Quest hubs as destinations

No town, camp or tower was ever a bot destination, and the reason is one clause
in `TravelMgr::PrepareDestinationCache`:

```cpp
if (creatureTemplate->npcflag == 0 && creatureTemplate->lootid != 0 && ...)
```

Every quest giver, innkeeper, vendor and trainer carries an npcflag, so the
whole quest-hub population of the game is excluded before any other test runs.
That is deliberate - the cache is a list of places worth *grinding* - but it
means bots were only ever found out in the fields, never where a player stands.

**They get their own roll, not extra pool entries.** The mob-cluster pool holds
**17,506** cells; a few hundred hubs mixed into it would be picked about 3% of
the time and the towns would stay empty. So hubs work the way the fork's own
banker teleport does, on a probability:

```
AiPlayerbot.ProbTeleToQuestHubs = 0.25
```

and the hub list runs through the same `GetPlayerZoneTeleportLocations` filter
as the ordinary pool, so with a real player online the hub chosen is in *their*
zone.

**The hubs are derived, not hand-typed.** `tools/gen_bot_hubs.py` reads the
same spawn data the fork does and writes `sql/14_bot_teleport_hubs.sql` -
**962 hubs** across the four random-bot maps. A cell is a hub when it holds at
least one quest giver **and** at least two service NPCs. Both halves matter:
quest givers alone miss Westbrook Garrison, where Deputy Rainer is the only
one, while any two service NPCs lets in every roadside guard post (1519 cells
rather than 962).

Level bands come from the median level of grindable mobs within 250 yards,
spread by the same ±1/+3 the fork uses for its own destinations. Two
corrections were needed to get that right, both worth knowing if the generator
is ever re-tuned:

* **Game event spawns had to go.** 3125 level 1 Wild Turkeys from Pilgrim's
  Bounty sit in the `creature` table year-round, **186 of them within 250 yards
  of Goldshire** - enough to drag its median to level 1 on their own. Holiday
  quest givers (Bountiful Table Hostess, Costumed Orphan Matron) likewise
  invented hubs that exist for one week a year. Anything in
  `game_event_creature` is excluded.
* **Capitals need a median, not a range.** Stormwind hands out level 1 errands
  and Argent Dawn work from the same courtyard, so `min..max` of the quest
  levels gave a band of **1-80** - a hub offered to every bot on the server.

Sanity check, the four hubs of Elwynn:

```
Northshire              1-5     3 quest givers of 5 npcs
Goldshire               4-8     three cells, up to 5 givers of 9 npcs
Westbrook Garrison      4-8     Deputy Rainer and 2 others
Eastvale Logging Camp   8-12    Supervisor Raelen
```

Adding or removing a hub afterwards is a row and a restart, not a rebuild.

### Bots that actually quest

`AutoDoQuests = 1` was set the whole time, which reads as though bots were
questing. They were not. `AiFactory` picks exactly one non-combat strategy:

```cpp
if (enableNewRpgStrategy)  nonCombatEngine->addStrategy("new rpg", false);
else if (autoDoQuests)     nonCombatEngine->addStrategy("rpg", false);
else                       nonCombatEngine->addStrategy("move random", false);
```

With the new strategy off, `AutoDoQuests` selects the **old** `rpg` strategy,
whose entire action set is `choose rpg target / move to rpg target / rpg stay /
rpg work / rpg emote / rpg cancel` - ambient pottering around NPCs. Busy
looking, but no quest is ever picked up.

`EnableNewRpgStrategy = 1` is the real loop. It finds objectives through
**QuestPOI** data (18,771 POIs over 57,162 points in this database), accepts
quests through `HandleQuestgiverAcceptQuestOpcode`, and turns them in.

It does not scatter bots, for two reasons. Quest objectives are capped in the
code:

```cpp
if (bot->GetDistance2d(dx, dy) >= 1500.0f)
    continue;                       // NewRpgBaseAction.cpp
```

and the one behaviour that *did* scatter them is a weighted state, now zero:

```
DoQuest 60, WanderNpc 20, WanderRandom 15, GoGrind 15,
GoCamp 10, OutdoorPvp 10, Rest 5, TravelFlight 0
```

`TravelFlight` is what puts a bot on a gryphon to another zone. Raise it if you
would rather see bots using flight masters and do not mind them leaving.

**It ramps rather than starting hot**, which matters when judging whether it
works. `RPG_DO_QUEST` only succeeds if the bot *already holds* a quest with
resolvable POI data, and returns false otherwise - bots collect quests first
via `WanderNpc`. Measured across one restart:

| status, of 500 bots | 6 min | 16 min |
| --- | --- | --- |
| Idle | 263 | 114 |
| DoQuest | 14 | 50 |
| GoGrind | 72 | 136 |
| MoveNpc | 119 | 119 |
| TravelFlight | 0 | 0 |
| holding active quests | 123 | 154 |

Cost: none measurable. The three map threads sat at 78-86% against the ~81%
they were at before, and 351 of 500 bots were within 100 yards of a quest hub -
higher than the 25% roll alone, because with the new strategy the *base* pool
is travel hubs (154 flight masters, 990 innkeepers) which overlap with them.

### The first patch to mod-playerbots

The fork was a pristine shallow clone until this. The patch is **67 lines
across 5 files, purely additive**, and everything about *which* hubs exist is
data:

| file | change |
| --- | --- |
| `Mgr/Travel/TravelMgr.h` | `questHubsPerLevelCache` + `GetQuestHubLocations` |
| `Mgr/Travel/TravelMgr.cpp` | loads `playerbot_teleport_hub` at the end of `PrepareDestinationCache` |
| `Bot/RandomPlayerbotMgr.cpp` | the hub roll in `RandomTeleportForLevel`, with the player-zone filter |
| `PlayerbotAIConfig.{h,cpp}` | `probTeleToQuestHubs` |
| `conf/playerbots.conf.dist` | documents the option |

Like the core changes, **it has to be remembered on any upstream merge.**

### Buffs that used to cancel each other

`mod-aurastack` (`server/modules/mod-aurastack`) lets two classes of buff
coexist that the stock core refuses to stack:

* **Tracking** - Find Herbs and Find Minerals at the same time, plus Find
  Treasure, Find Fish and the creature trackers.
* **Stat scrolls** - Scroll of Strength, Agility, Stamina, Intellect, Spirit
  and Protection, all eight ranks of each.

Neither needed a client patch, and neither needed a core change. The mechanism
is the same for both: the core sorts some auras into "spell specific" classes,
and two auras sharing one of the classes listed in
`SpellInfo::IsAuraExclusiveBySpecificWith` are never allowed to be up together
- `Aura::CanStackWith` returns false and the older one is dropped. Tracking
spells are tagged `SPELL_SPECIFIC_TRACKER`, scrolls `SPELL_SPECIFIC_SCROLL`.

Nothing in the data model requires it. `PLAYER_TRACK_RESOURCES` and
`PLAYER_TRACK_CREATURES` are *bitmask* fields and the aura handlers already use
`SetFlag`/`RemoveFlag` on individual bits (herbs `0x2`, minerals `0x4`,
treasure `0x20`, fish `0x40000`), so the minimap draws every kind of blip at
once. The core even carries a hand-written exception already - spell 30645 Gas
Cloud Tracking is returned as `SPELL_SPECIFIC_NORMAL` so it can stack, with the
comment *"We need generic solution"*.

So the module is that generic solution: at `OnStartup` it walks the spell store
and re-tags the affected spells `SPELL_SPECIFIC_NORMAL`. That is safe because
each class is read by that one exclusivity switch and nowhere else in the tree
(`grep -rn SPELL_SPECIFIC_SCROLL src/` returns the enum, the assignment and the
switch - nothing more). `SpellInfo::_spellSpecific` is derived exactly once, in
`SpellMgr.cpp`, and no `.reload` command re-derives it, so the override is
stable for the life of the process. The original value of every spell touched
is remembered, so the options below take effect on `reload config` in both
directions without a restart.

Scrolls carry a **second, independent** restriction, in the `spell_group`
table. `sql/10_scroll_stacking.sql` removes it. Both halves are required,
because `Aura::CanStackWith` consults the spell specific first and returns
early - the SQL alone changes nothing. The script only drops the rule for group
**1087 "Scrolls"** (stack rule 1, `EXCLUSIVE`) and deliberately leaves these
alone:

| group | rule | governs |
| --- | --- | --- |
| 1083 Single Intellect Buffs | 4 | Scroll of Intellect vs Arcane Intellect |
| 1084 Single Stamina Buffs | 4 | Scroll of Stamina vs Power Word: Fortitude |
| 1085 Single Spirit Buffs | 4 | Scroll of Spirit vs Divine Spirit |
| 1086 Armor Buffs | 4 | Scroll of Protection vs armor buffs |
| 1088 Strength and Agility Buffs | 4 | Scroll of Strength/Agility vs Blessing of Might, Mark of the Wild |

Rule 4 is `EXCLUSIVE_HIGHEST` - the stronger buff wins rather than the two
adding up - so scrolls still do not pile on top of the equivalent class buff.
`.reload spell_group_stack_rules` applies the SQL live; no restart needed for
that half.

Two things this cannot fix, both client side:

* The minimap tracking menu is **single-select**. All the blips appear, but the
  menu shows only one entry ticked and the button shows one icon.
* Turning tracking off through that menu only cancels the one entry it thinks
  is active. `.track off` clears the lot (removes both tracking aura types and
  zeroes both fields).

The startup line reports how many spells it **changed on that pass**, not how
many are stackable in total: `mod-aurastack: 31 tracking spell(s) and 48 scroll
spell(s) may now stack`. After a `reload config` that turns one option off and
on again, the other option's count therefore reads `0` - nothing needed
changing, because it was already re-tagged. Only the first line after a restart
shows the full picture.

`tools/diag_spell_groups.py` replays `SpellMgr::CheckSpellGroupStackRules`
against the live table - container expansion, the "same container, skip the
parent" rule and the first-rank mapping included - and prints the resolved rule
for every scroll pair plus the scroll-versus-class-buff pairs. All fifteen
scroll pairs should read `DEFAULT (stack)` and all eight class-buff pairs
`EXCLUSIVE_HIGHEST`. It needs no client and no running worldserver.

Options live in `run/etc/modules/mod_aurastack.conf` and are registered in
`tools/apply_config.py`: `AuraStack.Enable`,
`AuraStack.Tracking.Resources` (1), `AuraStack.Tracking.Creatures` (1),
`AuraStack.Tracking.Stealthed` (**0** - Track Hidden is a combat ability, so it
is left exactly as the core has it) and `AuraStack.Scrolls` (1).

### A living auction house

`mod-ah-bot` (`server/modules/mod-ah-bot`, AzerothCore's own module, cloned at
`a680cc1`) keeps the auction houses stocked and, just as importantly, **buys
what players put up**. On a server whose only other inhabitants are playerbots
that never auction anything, listing an item would otherwise just cost you the
deposit: mod-playerbots treats auctioneers purely as travel destinations and
RPG targets, and posts nothing.

Both halves are on: `EnableSeller` and `EnableBuyer`.

It needed no core change, but it carries **four local patches**, all of which
have to be remembered if the module is ever re-cloned:

| file | change |
| --- | --- |
| `AuctionHouseBot.cpp:1042` | "Begin Performing Update Cycle" from `LOG_INFO` to `LOG_DEBUG` - it fires once per seller per minute, ~11.5k lines a day, and flooded both the log and the console |
| `AuctionHouseBotAuctionHouseScript.cpp` | shuffles the seller iteration order each tick, so listings spread evenly across the seller characters (see "Sellers, and why there were eight of one" below) |
| `AuctionHouseBot.cpp` + `AuctionHouseBotConfig.{h,cpp}` | `TradeGoodsFullStack` option - common trade goods post at the item's full stack instead of a random size (see "Full stacks of trade goods" below) |
| `AuctionHouseBotConfig.cpp` + `AuctionHouseBot.cpp` | items with a `BuyPrice` but no `SellPrice` are admitted and priced at `BuyPrice / 4` (see "Enchanting materials" below) |

Compatibility with this playerbot fork was checked
before installing rather than assumed - all eleven `AuctionHouseMgr` calls it
makes exist here (including `GetAuctionHouseSearcher`, which is
AzerothCore-specific), as do all ten script hooks it registers: the four
`AUCTIONHOUSEHOOK_ON_AUCTION_*`, the four
`AUCTIONHOUSEHOOK_ON_BEFORE_AUCTIONHOUSEMGR_SEND_AUCTION_*_MAIL`,
`MAILHOOK_ON_BEFORE_MAIL_DRAFT_SEND_MAIL_TO` and
`WORLDHOOK_ON_BEFORE_CONFIG_LOAD`.

**Who owns the listings.** A dedicated account, `ahbot` (id 103), with eight
characters - Marlen, Dorvin, Ysolde, Brannok, Elwyne, Tharek, Nissa, Ordrin
(guids 1004-1011). `AuctionHouseBot.GUID = 0` means "every character on the
account", so the seller name varies between auctions instead of 750 listings
all coming from one name. They were created without a client, by copying an
idle level 1 random bot:

```
account create ahbot <password>
pdump copy Zaleri ahbot Marlen        # repeated per name
```

Details and the password are in `ADMIN_CREDENTIALS.txt`. **Do not delete those
characters** - it would orphan the bot's auctions.

**Prices.** The buyout is a randomised percentage of each item's own vendor
value, scaled by quality, from the `minprice`/`maxprice` columns of
`mod_auctionhousebot`:

| quality | buyout as % of vendor value |
| --- | --- |
| grey | 100-150% |
| white | 150-250% |
| green | 800-1400% |
| blue | 1250-1750% |
| purple | 2250-4550% |

Opening bids land at 70-100% of the rolled buyout. On top of that
`UseMarketPriceForSeller = 1` with `MarketResetThreshold = 25` lets prices
drift towards what actually sells: below that many auctions of an item the
price moves by a heuristic, above it the observed price is adopted. A lower
threshold reacts faster, a higher one smooths the swings. Be aware this starts
from the same vendor-value guess and needs trading volume to settle, so it is
not an instant fix for an odd-looking price.

**One setting had to be changed because of the bigger item stacks**, and
`sql/11_ahbot_tuning.sql` does it. The `maxstack<colour>` columns cap the stack
size the seller posts, and the seeded rows use `0` for grey and white, meaning
"as large as the item allows" (`AuctionHouseBot.cpp:874`). That was fine at 20;
after `sql/08`/`sql/09` raised trade goods and consumables to 200, the houses
would have filled with 200-stacks of ore and cloth that no levelling character
could afford - and since the per-house limit counts *items*, not volume, those
lots would crowd everything else out. Both are set to 20, which brings back the
classic look of listings in ones, fives and twenties. Green and above keep the
seeded 3/2/1/1/1.

**`VendorTradeGoods` must be 1 for the gathering economy to exist**, which is
not obvious from the name. The item filter checks `npc_vendor` *first* and
excludes unconditionally:

```cpp
if (NpcItems.find(itemId) != NpcItems.end()) {
    isNpc = true;
    if (!Vendor_TGs) exclude = true;   // wins over the loot check below
}
if (!exclude) { /* only now consider LootItems */ }
```

So any trade good a vendor sells *anywhere* is dropped even when it also comes
from mining nodes, herb nodes and creature loot. That removed 165 of the 927
trade goods, 88 of them gatherable - Copper Ore (1 vendor, 14 gameobject loot
entries), Peacebloom (6/6, plus 97 creature loot), Silverleaf (6/7, 96) and
Linen Cloth (1/6, 788) among them, so the whole low-level materials market was
missing. Note that adding such items to `auctionhousebot_professionItems` does
*not* help, because the vendor check runs before the loot check.

**`ConsiderOnlyBotAuctions` must be 0**, and it is the one setting that will
silently ruin the market if it is not. Its name reads as "count only the bot's
own auctions", which is what I assumed and what the module's own conf comment
claims ("Ignore player auctions and consider only bot ones"). The code does the
opposite - it returns early for bot-owned auctions, so the bot's listings never
increment the per-quality counters:

```cpp
if (config->ConsiderOnlyBotAuctions)
    if (gBotsId.find(auction->owner.GetCounter()) != gBotsId.end())
        return;                  // AuctionHouseBotAuctionHouseScript.cpp:115
```

The counters then stay at zero, and because the seller walks the quality bins
in strict rarity order and re-reads the counts once per *cycle* rather than per
item, the first bin with a non-zero maximum takes the whole market. Set to 1 it
produced 3200 listings of nothing but white items - no trade goods, no greens,
no blues at all. Set to 0 the stock lands within 0.3 points of every configured
percentage.

The trade-off of 0 is that player auctions count towards the bins too, so
someone listing a great many white items will pause the bot's own white
listings. That is a fair price, and arguably realistic.

Other choices worth knowing:

* `ProfessionItems = 1` - profession materials are listed, which matters on a
  server where one character can learn all eleven professions.
* Vendor-buyable items stay excluded (`VendorItems`/`VendorTradeGoods = 0`);
  looted and fished items are the stock (`LootItems`/`LootTradeGoods = 1`).
* The module's own SQL also filled `mod_auctionhousebot_disabled_items` with
  ~11.9k test and trash entries, so `[PH]`, `[UNUSED]` and test items never
  appear.

Everything in `mod_auctionhousebot` is reachable live from the console as
`ahbotoptions <setting> <ahMapID> [args]` - `minitems`, `maxitems`, `maxstack`,
`minprice`, `maxprice`, `minbidprice`, `maxbidprice`, `percentages`,
`buyerprice`, `bidinterval`, `bidsperinterval`, `seller`, `buyer`,
`usemarketprice` - so the numbers above are starting points, not settled ones.

**`ahbotoptions maxitems` did not take effect live.** It writes the new value
to `mod_auctionhousebot` and calls `SetMaxItems()` + `CalculatePercents()` on
the in-memory config, and the console reports `Done` - but the sellers went on
stopping at the old target across many update cycles. The per-quality limits
actually used by the seller come from `config->GetMaximum(colour)`, and
something on that path evidently still held the old figure; I did not chase it
further. A worldserver restart reads the table fresh and applies it. By
contrast `ahbotoptions maxstack` *does* apply live - the refill after it showed
zero oversized stacks - so this is not true of every setting. Verify the effect
rather than trusting `Done`.

**Changing a setting does not touch listings that already exist.** Raising the
stack cap after the first restock left 475 of the 2000 listings holding stacks
of up to 200. `ahbotoptions ahexpire 7` expires every bot-owned auction in a
house so the seller reposts under the current settings; the old listings then
clear on the next auction house update. Do that after any change that should be
visible in the stock rather than waiting for natural expiry.

**The item target is per seller character, not per house.** The count comes
from `getNofAuctions(config, auctionHouse, AHBplayer->GetGUID())`, so with
`GUID = 0` putting all eight characters to work, each fills to the target
independently: 250 produced exactly 2000 listings, 500 produces about 4000.
Adding or removing seller characters moves the total with it.

**Selling actually works**, which is the part that matters here. The buyer
skips anything owned by one of its own characters -
`if (gBotsId.find(auction->owner.GetCounter()) != gBotsId.end()) continue;` -
so its bids only ever land on player auctions. With eight bots at one bid per
minute each, that is eight bids a minute aimed exclusively at your listings.

**Scaling cost**, measured at 3960 listings: the `auctionhouse` table is 0.3 MB
(~0.08 MB per 1000 listings) and `item_instance` rows cost ~0.27 KB each
(~0.27 MB per 1000). **Mail churn is zero** - the module hooks the expired,
successful and outbidded mail paths and suppresses them when the owner is one
of its own characters, so cycling stock does not accumulate mail or item rows
the way player auctions would. What actually scales is
`AuctionHouseObject::Update()` walking every auction each tick looking for
expirations, browse/search cost (mitigated by this core's indexed
`AuctionHouseSearcher`), the refill rate, and startup load. The market is
configured for **20000** listings (`minitems`/`maxitems` in
`sql/11_ahbot_tuning.sql`). Note `ahbotoptions maxitems` does not apply live,
so changing it needs a restart.

#### Sellers, and why there were eight of one and one of the others

More sellers do **not** make a bigger market. Every cap is house-wide -
`getNofAuctions` returns `auctionHouse->Getcount()` - so each seller tops the
*house* up towards `maxitems`. Another seller only changes whose name is on
the listing, and costs a throwaway `WorldSession` and `Player` construction
per seller per minute (`AuctionHouseMgr::Update` ticks on a
`MINUTE * IN_MILLISECONDS` timer) plus, on the bidding interval, a
`SELECT id FROM auctionhouse WHERE houseid=? AND itemowner<>? AND buyguid<>?`
that returns essentially the whole house. That last one is the only part that
is O(sellers x listings).

They also did not share the work. `gBots` is a `std::set` of pointers, so the
iteration order is by address and fixed for the life of the process. The first
seller each tick sees the entire deficit and posts its full `ItemsPerCycle`;
by the last there is usually nothing left. In the steady state the deficit is
only what expired in the last minute, which is less than one allowance, so one
character took essentially all of it - **5330 of 9998 listings (53%) against
131 for the last seller.**

Two changes fix that:

* **Shuffle the seller order each tick** - a second local patch to
  `mod-ah-bot`, in `AuctionHouseBotAuctionHouseScript.cpp`. Eight pointers
  copied into a vector and `std::shuffle`d once a minute, so the seller that
  gets the work is random and the listings spread evenly *whatever*
  `ItemsPerCycle` is. This is the actual fix.
* **`ItemsPerCycle = 25`**, down from the stock 200, so each seller takes a
  smaller bite and more of them contribute per tick. Eight sellers x 25 is 200
  listings a minute against the ~27 a minute that expire at 20000 listings and
  a mean auction life of 12.5 hours (`ElapsingTimeClass = 1` is
  `urand(1, 24)` hours), so the market still refills in about an hour from
  half empty.

`AuctionHouseBot.DuplicatesCount` must stay **0**. It caps copies per item, and
turning it on would both stop the house reaching `maxitems` and cost a full
scan of every auction in the house *for each item posted*.

#### Full stacks of trade goods

Every stack the seller posts is a random size up to a cap
(`getStackCount`: `urand(1, max)`, or multiples of 3/4/5 with
`DivisibleStacks`), then clamped by `maxstack<quality>`. With the white cap at
20 that meant a house full of 20-stacks of cloth and ore against a 200 stack
limit - a crafter buying ten lots to fill one stack. There was no "always
full" option, so one was added: the third local patch to `mod-ah-bot`.

```
AuctionHouseBot.TradeGoodsFullStack = 1
AuctionHouseBot.TradeGoodsFullStack.MaxQuality = 1
```

Trade goods of grey and white quality now post at the item's own maximum,
bypassing the quality cap, held to `TradeGoodsFullStack.Max = 200` - the
lot size stays put even though the bag stack went to 999. A stack is one auction
whatever its size, so this changes the *units* on offer, not the item count
or the quality mix: 20,000 listings before and after. Green and blue trade
goods deliberately keep the random sizing and their own `maxstack` (3 and 2),
because the same rule would post 200 Arcane Crystals as a single lot at a
price nobody pays. Non-stackable trade goods - Arcanite Rod, Jeweler's Kit,
the engineering tools - post as one, correctly.

Per-unit prices are unchanged; only the lot grows. At the white band (150-250%
of vendor) a full stack runs from 0.2g for Copper Ore through 12-20g for
Runecloth to 75-125g for Saronite Ore - about half a gold a unit at the top,
which is fine for a level 80 economy.

Rather than wait a day for the old 20-stacks to expire, or use `ahexpire`
(which wipes every bot listing and leaves the house sparse for an hour), the
switch-over expired **only** the bot's grey and white trade-goods listings
with a targeted update to `auctionhouse.time` while the server was down:
2,998 rows. They were replaced within fifteen minutes at the seller's 200 a
minute, the new ones averaging 189 units and peaking at 200, while everything
else in the house stayed exactly where it was.

**The one real cost:** the buyer does not spend gold it owns - there is no
`GetMoney` or `ModifyMoney` check anywhere in `AuctionHouseBot.cpp` - so money
paid for player auctions is created from nothing. That is a slow inflation
source, and the price to pay for being able to sell anything at all here.

### Enchanting materials

There were none - no dust, essence, shard or crystal, only the rods vendors
sell - and the reason was pricing, not selection. The bot bases its asking
price on `item_template.SellPrice` and, at `AuctionHouseBotConfig.cpp:2673`,
excludes any item whose sell price is 0. Enchanting materials cannot be sold
to a vendor, so all 36 of them (plus three other trade goods) have exactly
that. They do carry a `BuyPrice` - Strange Dust 8s, Arcane Dust 2g40, Small
Glimmering Shard 40s - Blizzard's reference value even for things no vendor
stocks.

The patch admits an item when it has *either* price and, when the sell price
is 0, prices from `BuyPrice / 4`. Four because that is what a vendor's
margin is on the trade goods that have both numbers: over cloth, leather,
metal and herbs `BuyPrice / SellPrice` averages 4.01 (7.37 across all trade
goods, skewed by a few oddities). The usual per-quality multipliers then
apply on top, so Arcane Dust lists at 90s-1g50 and a Small Glimmering Shard
(rare quality, 1250-1750%) at 1g25-1g75 - in the range players remember. The
buyer side gets the same stand-in so the bot bids on player-listed dust too.
Switching `AuctionHouseBot.UseBuyPriceForSeller` on would have admitted them
without a patch, but it re-bases *every* item on its four-times-higher buy
price, which is a different auction house.

## Rebuilding and re-applying

```bash
/root/classic/stop.sh          # stop before compiling, not just before installing:
                               # a build killed mid-write once left a truncated
                               # precompiled header and GCC then died with an
                               # internal compiler error on unrelated files
                               # (delete worldserver.dir/cmake_pch.hxx.gch to fix).
                               # Installing while running can also silently skip
                               # the binary with "-- Up-to-date".
cd /root/classic/build
cmake ../server -DCMAKE_INSTALL_PREFIX=/root/classic/run \
      -DCMAKE_C_COMPILER=gcc-14 -DCMAKE_CXX_COMPILER=g++-14 \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo -DSCRIPTS=static -DMODULES=static \
      -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
make -j1 && make install      # -j1 if cmake reported a new module, see below
# Do NOT compare md5sums of the two binaries: `make install` rewrites the
# RUNPATH (from a padded placeholder to /root/classic/run/lib), so the hashes
# differ even on a good install. Check size + mtime instead, or look for a
# symbol you just added:
#   nm -C run/bin/worldserver | grep AuraStack

python3 /root/classic/tools/apply_config.py          # config (make install only refreshes *.conf.dist)
python3 /root/classic/tools/gen_all_classes_dbc.py   # re-patch the dbc files and the MPQ staging dir
/root/classic/tools/mpq_pack /root/classic/client-patch/patch-Z.MPQ \
                             /root/classic/client-patch/staging
```

**A warning about `apply_config.py`, learned the hard way.** Its managed
settings are one dict literal keyed by config file, and
`"modules/playerbots.conf"` once appeared in it **twice**. Python keeps the
last of a duplicate key, so the entire first block - the bot count, the level
brackets, the emote and greet switches, the broadcast chance - was silently
discarded on every run, for an unknown length of time. Nothing warns about
this: the script reports success, and the settings it never saw simply keep
whatever value is in the file.

The script now parses its own source at startup and refuses to run rather than
apply a partial set:

```
apply_config.py: duplicated config block(s): modules/playerbots.conf
Only the last of each is applied. Merge them.
```

If a setting registered there does not appear in the run's output, that is the
first thing to check.

GCC 14 is used on purpose: Ubuntu 26.04's default GCC 15 is newer than this
source tree expects (its `c++` also has no `libstdc++` development files
installed).

Two things about memory, learned the hard way on this 15 GB machine:

* `make -j4` gets the build killed. `-j2` is the practical limit for ordinary
  changes, and the final `worldserver` link (the binary is ~2.3 GB with debug
  info) wants a single job: `make -j1`.
* **Adding a module recompiles the entire `modules` target - unless the compile
  cache has seen the files before.** The modules are not compiled "into" the
  core; with `MODULES=static` they are one static library (`libmodules.a`, 698
  objects, ~600 of them mod-playerbots) linked into `worldserver`, and an edit
  to one module file rebuilds that file and the link. What hurts is the module
  *list*: `server/modules/CMakeLists.txt` puts every module's `src/` on the
  include path of the whole target, so a new module adds one `-I` to the
  command line of all 698 files and `make` recompiles every one of them even
  though 697 preprocess to exactly the same thing.

  `ccache` (4.12, installed with `apt`) is set up for exactly that case. The
  build is configured with `CMAKE_CXX_COMPILER_LAUNCHER=ccache` (that lands in
  the make recipes, not in `flags.make`, so enabling it did not itself force a
  rebuild - verified with `make -n game` reporting nothing to do), and
  `~/.config/ccache/ccache.conf` sets `ignore_options = -I*`: the key is the
  preprocessed source, which already reflects whatever the include path
  resolved, so a changed `-I` list is a hit and a changed header is a miss,
  which is the right answer for both. `max_size = 10G`. The cache fills as
  files compile, so the first pass after enabling it (the mod-extraglyphs
  build) paid full price for the modules and the core is seeded whenever it
  next rebuilds; after that a module add/remove should be minutes of
  preprocessing rather than 45 minutes of compiling. `ccache -s` shows the hit
  rate, `ccache -z` resets the counters.

* **When it does recompile everything, `-j1`.** Registering a new module
  changes the module list, which recompiles the *entire* `modules` target -
  including all of `mod-playerbots`, whose translation units are the heaviest
  in the tree. `-j2` survived every header-only rebuild here but was
  memory-killed at 82% during the mod-playerbots pass when `mod-aurastack` was
  added, even with the swap file active and 13 GB reported available. `make -j1`
  from the start is the safe choice when `cmake` reports a new entry under
  "Modules configuration".
* **The archive step is the memory peak, not the compiling.** The `modules`
  objects total ~3.5 GB, so `ar` writes a 3.5 GB `libmodules.a` and that write
  lands in the page cache. `mod-ah-bot`'s build was killed there even at `-j1`:
  free memory was 4.6 GB with 9.5 GB already in `buff/cache`, and the watchdog
  acts on *free*, not on the reclaimable `available` figure. Clearing the cache
  first fixed it - `sync; echo 3 > /proc/sys/vm/drop_caches` took free from
  4.6 GB to 13 GB, and the archive then completed with free bottoming out at
  5.7 GB as cache climbed to 8.3 GB. Do that before resuming a link or archive
  that has been killed once.
* **`/tmp` is tmpfs, i.e. RAM** (7.7 GB). GCC writes its intermediate assembly
  there, so scratch files left in `/tmp` are taken straight out of the build's
  memory budget. Keep it clean.
* After any killed build, check for a truncated precompiled header before
  resuming: `find build -name '*.gch' -printf '%TY-%Tm-%Td %TH:%TM %10s %p\n'`.
  If one was written around the time of the kill, delete it - a truncated PCH
  makes GCC die with an internal compiler error on unrelated files. Timestamps
  older than the killed build mean they are intact and can be kept.
* An 8 GB swap file was added (`/swapfile`) to get through that link. It is
  active now but not in `/etc/fstab`, so after a reboot re-enable it with
  `swapon /swapfile` before rebuilding.
* The build is configured with `-Wl,--no-keep-memory -Wl,--reduce-memory-overheads`
  and `-Wl,--strip-debug` for the same reason (the binary went from 2.3 GB to
  67 MB).
* **Stop the server before `make install`.** With the old server still running,
  CMake decided the destination was `-- Up-to-date` and skipped copying the new
  `worldserver`, so a restart silently kept running the previous build. If
  something you just changed does not seem to be live, confirm the install by
  looking for one of its symbols in the installed binary
  (`nm -C run/bin/worldserver | grep <something new>`) and by comparing size
  and mtime - *not* by comparing md5sums, which always differ because install
  rewrites the RUNPATH.

Database schema updates that ship with the core are applied automatically on
startup (`Updates.AutoSetup = 1`). Note that `start.sh` starts the auth server
first and waits for it: both servers run the database updater, and starting
them simultaneously against empty databases makes them deadlock against each
other (which is exactly what happened on the first boot here - the auth server
lost the race and exited, the world server completed the import).

The custom SQL in `sql/` is idempotent and can be re-run at any time:

```bash
mysql -uacore -pacore -h127.0.0.1 acore_world < /root/classic/sql/01_all_classes_all_races.sql
mysql -uacore -pacore -h127.0.0.1 acore_world < /root/classic/sql/02_big_bags.sql
```

## Tests

Five of the modules written here carry unit tests: mod-worldscale (24),
mod-botlore (27), mod-talentgrant (15), mod-spellcooldowns (10) and
mod-bankreagents (8). **84 tests, and they run in under a second** - because
none of them needs a server.

That is the whole design. A module's logic normally lives inside hook methods
that take a `Player` and a `Creature`, which cannot be called without a
world, a database and a client. So in each of these modules the *decisions*
were moved into a header of pure functions over numbers and strings -
`WorldScaleMath.h`, `BotLoreSelection.h`, `TalentGrantMath.h`,
`SpellIdList.h`, `BankReagentsMath.h` - leaving the hooks to do the part that
genuinely needs the world and hand the numbers over. Those headers include
nothing but the standard library. (The core's `uint8` and friends are plain
typedefs of `std::uint8_t`, so spelling out the standard types costs the
module nothing and removes the last dependency.)

Two ways to run them:

* **On their own** - what CI does. Each module has `tests/CMakeLists.txt`,
  which fetches googletest and builds nothing else, and a GitHub workflow
  that is checkout, cmake, ctest. No AzerothCore clone, no core build.

      cmake -S tests -B build-tests && cmake --build build-tests
      ctest --test-dir build-tests --output-on-failure

* **Alongside AzerothCore's own suite.** Each module also ships
  `<module>.cmake`, which appends the same test files to the core's
  `unit_tests` target through the `ACORE_MODULE_TEST_SOURCES` property that
  `modules/CMakeLists.txt` already supports - so **no change to AzerothCore
  is needed**, and only `<module>/src` is ever compiled into the server.
  Configure a *separate* build tree for this, because `BUILD_TESTING=ON`
  fetches googletest and builds a `unit_tests` binary that links all of
  `game` and `modules`:

      cmake /root/classic/server -DBUILD_TESTING=ON -DCMAKE_INSTALL_PREFIX=/root/classic/run ...
      make unit_tests && ./src/test/unit_tests

  Keep `CMAKE_INSTALL_PREFIX` the same as the production tree: it lands in
  `-D_CONF_DIR` in every translation unit, and changing it turns ~1,700
  ccache hits into misses - an hour of compiling instead of fifteen minutes.
  The coverage flags `BUILD_TESTING` adds go only to `unit_tests`; `game` and
  `modules` keep byte-identical flags, so the server build is unaffected.

The full in-tree run is 11,502 tests (6,016 assertions executed, the rest
skipped), our 84 among them, in 370 ms.

**Writing the tests was worth it for what they found.** Two live bugs:
mod-botlore's placeholder substitution resumed its search *at* the inserted
value rather than after it, so a replacement containing its own token would
have looped forever; and mod-bankreagents multiplied stack size by
`MinStacks` unguarded, which with 999-stacking trade goods could wrap and
quietly pull too little. Two of the tests were themselves wrong and the code
was right - the quest-XP curve is flat for the first five levels below the
player, and a zero stack size should leave the recipe's own count in charge -
which is its own kind of value: they now record how those things actually
behave.

The modules that are mostly gossip menus and database writes - mod-aurastack,
mod-bigbags, mod-languages, mod-factionchoice, mod-extraglyphs,
mod-transmog-collect - have no tests, deliberately. There is no arithmetic in
them to pin down, and extracting a seam to test would be inventing one.

## Long jobs

A rebuild here takes tens of minutes to hours, and the obvious way to run one
- start it, watch it, wait - loses the job the moment the SSH connection
drops. `tools/bg.sh` runs it in a tmux session instead:

```
tools/bg.sh start rebuild 'cd /root/classic/build && make -j2 game scripts modules'
tools/bg.sh status                  # running, or finished with its exit code
tools/bg.sh log rebuild 40          # the output so far
tmux attach -t acore-rebuild        # watch it happen (ctrl-b d to leave)
tools/bg.sh watch rebuild           # block until it finishes; exits with its code
```

tmux buys three things over `setsid nohup ... &`:

* the job can be watched live, and its scrollback survives;
* **the exit code survives the process.** The pane is kept after the command
  exits (`remain-on-exit`), so `#{pane_dead_status}` still reports it - tested
  at 42 and 9. A plain background job has to remember to write `$?` somewhere,
  and if it is killed rather than failing, nothing is written at all;
* the output is on screen *and* in `logs/<name>.log` (`pipe-pane`), so it can
  be grepped afterwards.

What it does not do is announce that it has finished - nothing polls on its
own. `tools/bg.sh watch <name>` blocks until the job ends and exits with the
job's code, which is the thing to run when something needs to wait for it.

`status` lists the server's own `acore-world` and `acore-auth` sessions too,
since they are tmux sessions with the same prefix; they simply always read
"running".

## Logs

`logs/Server.log`, `Playerbots.log`, `Errors.log` and `Auth.log` are opened in
mode `w`, so each is truncated when its server starts - and, less obviously,
whenever `reload config` runs, because the core rebuilds its appenders then.
Between those moments nothing used to bound them, and with the playerbots
logger at debug that is tens of megabytes a day on a long uptime.

Now each appender carries the core's size cap as its sixth argument
(`Appender.Server = 2,5,0,Server.log,w,52428800`: 50 MB for Server and
Playerbots, 10 MB for Errors and Auth). Past the cap the core renames the
file to `<name>.<timestamp>` and starts a fresh one, so the live file is
always bounded; `tools/prune_logs.sh`, a daily root cron job (04:17), deletes
those rotated copies after seven days, so the directory is bounded too.
Worst case on disk is therefore about 8 × 50 MB plus the small ones. The
caps are in `tools/apply_config.py` and survive `make install`.

## Databases

MySQL 8.4, user `acore` / password `acore`:
`acore_auth`, `acore_characters`, `acore_world`, `acore_playerbots`.

## Known limitations

* **Odd class/race combinations have no class trainer in their starting zone.**
  A Blood Elf Druid has to reach Thunder Bluff, a Human Shaman the Exodar, and
  so on; class *quests* for those combinations do not exist either. The game
  handles this gracefully, it is just a trip.
* **Racial starting outfits are borrowed.** A new combination gets the outfit
  of the race the generator copied from, so the gear is class-correct but not
  necessarily the same items Blizzard would have picked.
* **Open world scaling is per player, not per creature.** A creature's health
  bar and level still show its real values; what changes is how hard it hits
  you and how much of your damage it takes. Loot and quest rewards are not
  scaled - only experience is.
* **Faction choice needs the core method above.** If you ever re-clone or
  update the core, re-apply `ReputationMgr::AdoptFactionState` or
  mod-factionchoice will not build.
* **Faction choice is not perfectly consistent.** A few systems deliberately
  read your *race's* team rather than your chosen one
  (`Player::GetTeamId(true)`): achievement faction requirements,
  faction-flagged loot, and arena team membership. Everything else - hostility,
  battleground side, graveyards, auction house, chat channels, grouping -
  follows your choice.
* **Your race's home city is hostile after switching sides**, which is why the
  module moves you to your new capital and re-binds your hearthstone there. The
  reverse is also true: a Horde Human can walk into Orgrimmar, but Stormwind
  will shoot at them.
* **Quests no longer check race at all** (see
  `sql/03_quests_any_race.sql`). That is what makes questing possible for a
  race playing on the "wrong" side, but it also means anyone can pick up
  quests that were originally race-specific. The revert script is next to it.
* **You end up at war with the side you left.** That is the point - an Orc
  playing Alliance is attacked in Orgrimmar - but it does mean your race's own
  capital is off limits until you `.faction reset`.
* **The client still thinks you are your race's faction** on the character
  selection screen and in some interface colouring. Hostility, grouping and
  battleground sides all come from the server, so this is cosmetic.
* **500 bots is heavy.** They are the reason `MapUpdate.Threads` is raised.
  On a 4 core machine expect the first startup to take a while as bot accounts
  and characters are created.

## What was verified on this machine

Checked after the server came up with all 500 bots online:

| Check | Result |
| --- | --- |
| Build | `worldserver` + `authserver` built with GCC 14, installed to `run/bin` |
| Databases | `acore_auth`, `acore_characters`, `acore_world`, `acore_playerbots` imported (838 base files) |
| Auth database consistency | compared table by table against a fresh scratch import after the first-boot deadlock: every static table matches |
| Race/class combinations | `>> Loaded 100 Player Create Definitions` (10 races x 10 classes), no SQL warnings |
| Action bars | 100 combinations have one |
| Starting bags | 100 combinations have four 36 slot bags in `playercreateinfo_item` |
| Client patch | `patch-Z.MPQ` (formerly `patch-4.MPQ`) reads back correctly with StormLib and is installed in the client's `Data/` |
| `mod-worldscale` | loaded: `mod-worldscale: enabled (delta 0, up true, down true, xp true)` |
| `mod-autobalance` | loaded |
| `mod-bigbags` | login hook ran for all 500 characters (grant recorded in `character_settings`) |
| `mod-aurastack` | startup reported `31 tracking spell(s) and 48 scroll spell(s) may now stack` - matching the DBC exactly: 22 creature trackers + 9 resource trackers, and 6 scroll buffs x 8 ranks. Toggling `AuraStack.Scrolls` to 0 and back through `reload config` put 48 spells back to stock exclusivity and then re-applied them, so the override is reversible without a restart |
| `mod-ah-bot` | item pools loaded (1112 grey / 1121 white / 5216 green / 1553 blue / 760 purple items, plus 321 white and 43 green trade goods). 2000 listings appeared within a minute of the first start, spread across all eight seller names, all in the neutral house as expected with `AllowTwoSide.Interaction.Auction = 1`. Sampled prices match the configured bands: white items 1.3-2.3x vendor value (config 150-250%), greens 9.7-13.0x (config 800-1400%) |
| AH stack cap | the first restock predated the cap and left 475 listings with stacks up to 200; `ahbotoptions ahexpire 7` cleared them and the refill reported 0 oversized |
| Scroll stacking (DB half) | `tools/diag_spell_groups.py` resolves all 15 scroll pairs to `DEFAULT (stack)` - 0 still blocked - while all 8 scroll-versus-class-buff pairs stay `EXCLUSIVE_HIGHEST`. Group 1088 needed splitting, not just 1087: it held both the Strength and Agility scroll containers, so those two would otherwise have gone on cancelling each other |
| Weapon training | all 15 weapon skills verified open in the patched DBCs (no trainer-taught row left class-restricted, 67 race/class rows opened); 11 weapon trainers now also teach wands |
| `mod-botlore` | loaded 109 lore lines across 10 triggers, no rejected rows. Verified live: a bot standing in Darkshire produced the Duskwood line ("They say Morbent Fel still walks these woods"), the same bot after travelling produced the Ashenvale one, a level-10 bot in Eversong produced a level-up line with `%zone` substituted, and an immediate second call was refused by the cooldown. `BotLore.CooldownSeconds` changed live through `reload config`. |
| `mod-languages` | loaded; `.language list` prints all 16 seeded teachers (14 distinct languages) with prices and reputation requirements resolved from the DBCs |
| `mod-factionchoice` | loaded; `.faction` registered with all four subcommands (`alliance`, `horde`, `reset`, `status`); a stored choice was applied at login to two test bots - a Night Elf played Horde and an Orc played Alliance (then reverted) |
| Reputation rebase | an Orc bot switched to Alliance had 38 reputations rebased (Stormwind moved to friendly, Orgrimmar to hated); re-logging rebased 0 more, so the transition does not drift |
| Faction chooser | `.faction zones` from the console lists exactly what the second window offers: Alliance - Northshire Valley (area 9), Coldridge Valley (132), Shadowglen (188), Ammen Vale (3526) + Stormwind; Horde - Valley of Trials (363), Shadow Grave (2117), Camp Narache (221), Sunstrider Isle (3431) + Orgrimmar. Shared zones fold together, so gnomes and trolls do not produce duplicates |
| Starter-zone destination | the positions come from `playercreateinfo` for the proxy race: Human -> map 0 `(-8950, -132.5, 83.5)` = Northshire Valley (area 9), Orc -> map 1 `(-618.5, -4251.7, 38.7)` = Valley of Trials (area 363); both area names resolve through the DBC |
| Faction flags across relogs | a Forsaken and an Orc playing Alliance were put back at war with the Alliance by `Initialize()` on each login, so the client refused every NPC. Fixed twice: first by reconciling the server's flags, then - after the reputation-pane cleanup removed the saved `FACTION_FLAG_VISIBLE` that had been masking it - by re-sending them, because the core only ever tells the client the flags in a packet that goes out before the `OnPlayerLogin` hook |
| Adopted flag set | `tools/diag_reactions.py` replays the core's maths offline: both test characters now reconcile 40 flag sets, pin **0** reactions, and refuse interaction with exactly the same 333 creature faction templates as a native Alliance human - 0 extra (it was 9 extra before, all Forsaken). Alliance cities end visible and peace-forced, Horde cities hidden and at war, and only the 6 factions a natural human starts with are in the reputation pane |
| Cross-faction options | all eight `AllowTwoSide.*` values are 1 in the running config |
| Talent rate | `Rate.Talent = 3`, plus `.talents grant` per character |
| Quest race gate | 0 of 9464 quests still race gated, 4919 original masks saved for revert |
| Public login | `tools/check_login.py` completed a full SRP6 logon against `5.161.99.58:3724` and was told to use realm `5.161.99.58:8085`; the same check over loopback is told `127.0.0.1:8085` |
| Bots | 500/500 logged in |
| Realm | `AzerothCore` at `127.0.0.1:8085`, game build 12340, ports 3724 and 8085 listening |
| Load | `worldserver` ~4.6 GB RSS, ~2.4 of 4 cores, load average ~3 with 500 bots online |

Not verifiable from a shell: anything that needs a real client session - the
character creation screen actually offering all 100 combinations, bags landing
in the bag slots of a freshly created character, open world scaling during
combat, and how a switched faction feels in game. The server side of each of
those is in place and loads without complaint.

Worth trying first when you log in:

1. Create a combination that should not exist, e.g. a Blood Elf Druid or a
   Human Shaman, and check it starts with class gear and four large bags.
2. `.faction horde` on an Alliance race character: you should be moved to
   Orgrimmar, be left alone by its guards, and be attacked in Stormwind.
3. Kill something ten levels below you in a starting zone and watch that it
   still fights back and still pays experience.
