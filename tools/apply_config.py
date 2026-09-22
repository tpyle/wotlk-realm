#!/usr/bin/env python3
"""
Create the server configuration from the installed *.conf.dist templates and
apply this server's settings. Re-running it is safe: existing .conf files are
kept and only the managed keys below are rewritten.

Run after every `make install` (make install only refreshes the .dist files).
"""

import os
import re
import shutil
import sys

ETC = "/root/classic/run/etc"
RUN = "/root/classic/run"
LOGS = "/root/classic/logs"

# file -> { config key: value }
SETTINGS = {
    "worldserver.conf": {
        # Log files: mode "w" truncates each file when the server starts (and
        # on "reload config"), but nothing bounded them in between. The sixth
        # appender argument is a size cap in bytes: past it the core renames
        # the file to <name>.<timestamp> and starts a fresh one. The rotated
        # copies are pruned by the daily cron job (see README, "Logs").
        "Appender.Server": "2,5,0,Server.log,w,52428800",
        "Appender.Playerbots": "2,5,0,Playerbots.log,w,52428800",
        "Appender.Errors": "2,2,0,Errors.log,w,10485760",
        # Anti-cheat off: a two-player realm has nothing to police, and the
        # stock setting (ClientCheckFailAction = 0) only logged failures
        # anyway. Turning it off also drops the Warden module from every
        # client login. Re-enable and set ClientCheckFailAction = 1 if the
        # realm is ever opened to strangers.
        "Warden.Enabled": "0",
        # paths
        "DataDir": f'"{RUN}/data"',
        "LogsDir": f'"{LOGS}"',
        # all four databases, including the playerbots one (1|2|4|8)
        "Updates.EnableDatabases": "15",
        "Updates.AutoSetup": "1",
        # every primary profession on a single character (0-11)
        "MaxPrimaryTradeSkill": "11",
        # required by mod-bigbags to remember that a character got its bags
        "EnablePlayerSettings": "1",
        # a few hundred bots need more than the single default map thread
        "MapUpdate.Threads": "3",
        # faster talent progression
        "Rate.Talent": "3",
        # Let one character hold several profession specialisations - both
        # Armorsmith and Weaponsmith, every alchemy mastery, and so on. Read by
        # npc_professions.cpp, which is the only thing that ever enforced the
        # exclusivity: the gossip offering a specialisation is hidden once the
        # player holds any of that profession's. Engineering is chosen by quest
        # instead and needs sql/16_multiple_specializations.sql.
        "Professions.MultipleSpecializations": "1",
        # Let crafting draw reagents straight out of the bank, without moving
        # them into the bags first - so a craft is never blocked by bag space.
        # Bags are still consumed first; the bank is only reached for the
        # shortfall. Note the stock client greys the Create button out from its
        # own bag-only count, so this also wants the UI patch in
        # client-patch/ to be usable from the trade skill window.
        "Crafting.AllowBankReagents": "1",
        # let both factions play together: mod-factionchoice puts characters of
        # any race on either side, so the two sides have to be able to mix
        "AllowTwoSide.Accounts": "1",
        "AllowTwoSide.Interaction.Calendar": "1",
        "AllowTwoSide.Interaction.Chat": "1",
        "AllowTwoSide.Interaction.Channel": "1",
        "AllowTwoSide.Interaction.Group": "1",
        "AllowTwoSide.Interaction.Guild": "1",
        "AllowTwoSide.Interaction.Arena": "1",
        "AllowTwoSide.Interaction.Auction": "1",
    },
    "authserver.conf": {
        "Appender.Auth": "2,5,0,Auth.log,w,10485760",
        "LogsDir": f'"{LOGS}"',
        # the auth server owns the auth database updates (see start.sh: it is
        # started first, so it can never race the world server over them)
        "Updates.EnableDatabases": "1",
        "Updates.ExceptionShutdownDelay": "10000",
    },
    "modules/AutoBalance.conf": {
        # instance (dungeon/raid) scaling; the open world is mod-worldscale
        "AutoBalance.Enable.Global": "1",
        "AutoBalance.LevelScaling": "1",
    },
    "modules/mod_worldscale.conf": {
        "WorldScale.Enable": "1",
        "WorldScale.ScaleUp": "1",
        # 0 on purpose: scaling creatures *above* the player down would make
        # every zone enterable at any level, and high level content should stay
        # dangerous. Only the scale-up direction is wanted - low level content
        # made a fair fight, not high level content made safe.
        "WorldScale.ScaleDown": "0",
        "WorldScale.ScaleXP": "1",
        # show creatures scaled up to the player at the player's level, so a mob
        # that hits like level 60 stops showing a grey name. Cosmetic: per
        # observer, and the creature's real level is untouched.
        "WorldScale.PresentLevel": "1",
        # Scaled-up creatures aggro as if five levels below you (15 yards)
        # rather than as at-level ones (20). Presenting them at your level
        # had made every creature in a zone as alert as an at-level one. Aggro
        # only - avoidance and experience keep the presented level. Live on
        # reload config; 10 gives 10 yards, 15 the old grey floor of 5.
        "WorldScale.Aggro.LevelsBelow": "5",
        # quest XP measured at the player's level (upwards only, never a cut),
        # and low-level quests reported to the client as -1 so they render at the
        # player's level instead of grey
        "WorldScale.ScaleQuests": "1",
    },
    "modules/mod_factionchoice.conf": {
        "FactionChoice.Enable": "1",
        "FactionChoice.TeleportOnSwitch": "1",
        "FactionChoice.SetHomebind": "1",
        # rebase reputations onto the chosen side, without which its NPCs stay
        # unfriendly (red name plates, no interaction)
        "FactionChoice.AlignReputations": "1",
        # levels 1-4 go to the new side's starting zone, not its capital
        "FactionChoice.StarterZoneMaxLevel": "4",
        # ask for a side (and a starting zone) on a character's first login
        "FactionChoice.PromptOnFirstLogin": "1",
        "FactionChoice.PromptDelay": "3000",
        "FactionChoice.PromptRetries": "4",
        "FactionChoice.PromptRetrySeconds": "20",
    },
    "modules/mod_botlore.conf": {
        "BotLore.Enable": "1",
        # Deliberately sparse. The corpus is nearly 12k lines, so variety does
        # not need a high rate to show itself - with a handful of bots in
        # earshot and a 20 minute per-bot cooldown this comes out at a line
        # every few minutes, which is ambience rather than a chat channel.
        # The cap is per bot: rate = min(1 per cooldown, trigger rate x chance).
        "BotLore.Chance": "12",
        "BotLore.CooldownSeconds": "1200",
        "BotLore.IdleSeconds": "900",
        # The two rare, earned moments are worth hearing when they happen.
        "BotLore.Chance.KillBoss": "50",
        "BotLore.Chance.LevelUp": "35",
        "BotLore.RangeYards": "40",
        "BotLore.LoginGraceSeconds": "60",
        # Ambient chatter is what makes the world feel inhabited rather than
        # merely populated, and it is safe to switch on because nothing is said
        # unless a real player is within BotLore.RangeYards - a bot alone in a
        # field costs one branch. Kill stays off: it fires on every corpse.
        "BotLore.Trigger.Idle": "1",
        "BotLore.Trigger.CombatStart": "1",
        "BotLore.Trigger.Kill": "0",
        # specificity is a weight multiplier, not a hard filter - keeps the
        # whole matching corpus in the draw so a long session does not repeat
        "BotLore.SpecificityWeight": "6",
    },
    "modules/mod_talentgrant.conf": {
        "TalentGrant.Enable": "1",
        # Policy, not a technical ceiling - it catches a mistyped grant. The
        # core's uint8 read of characters.extraBonusTalentCount is fixed, so
        # this can be raised freely.
        "TalentGrant.MaxBonus": "255",
        "TalentGrant.Announce": "1",
    },
    "modules/mod_aoe_loot.conf": {
        # Area loot (retail's MoP feature) on a 3.3.5 client: the module
        # intercepts CMSG_LOOT and merges the loot of every lootable corpse
        # you have rights to within Range into the window you opened. The
        # login banner is off; .aoeloot on/off still works per character.
        "AOELoot.Enable": "1",
        "AOELoot.Message": "0",
        "AOELoot.Range": "55.0",
        "AOELoot.Group": "1",
    },
    "modules/transmog.conf": {
        # mod-transmog with the Legion-style collection: appearances unlock
        # account-wide when an item is looted, equipped, crafted, bought or
        # rewarded (custom_unlocked_appearances). Interface is the
        # Warpweaver NPC (190010) or ".transmog portable" anywhere; the
        # TransmogAzerothCore addon (client-patch/addon) is the wardrobe.
        "Transmogrification.Enable": "1",
        "Transmogrification.UseCollectionSystem": "1",
        "Transmogrification.RetroActiveAppearances": "1",
        "Transmogrification.TrackUnusableItems": "1",
        "Transmogrification.EnablePortable": "1",
        "Transmogrification.AllowHiddenTransmog": "1",
        "Transmogrification.HiddenTransmogIsFree": "1",
        "Transmogrification.EnableSets": "1",
        "Transmogrification.CopperCost": "0",
        "Transmogrification.RequireToken": "0",
        "Transmogrification.AllowHeirloom": "1",
    },
    "modules/mod_worgoblin.conf": {
        # Worgen and Goblin as playable races (mod-worgoblin). The login
        # banner is off; the races are visible on the creation screen once
        # patch-A.MPQ is in the client's Data folder.
        "Announce.enable": "false",
    },
    "modules/mod_extraglyphs.conf": {
        # Glyph effects beyond the six sockets, kept per character and spec
        # and applied as passive auras (the sockets are a client limit, the
        # effect is only an aura). Managed from client-patch/addon/ExtraGlyphs
        # over the addon command channel.
        "ExtraGlyphs.Enable": "1",
        "ExtraGlyphs.Max": "0",
        "ExtraGlyphs.RequireItem": "1",
    },
    "modules/mod_bankreagents.conf": {
        # The server half of crafting from the bank. The client checks
        # reagents against the bags in the executable before sending a craft,
        # so they have to be there; this moves one stack per reagent out of
        # the bank the moment a recipe is selected, on request from the
        # companion addon (client-patch/addon/BankReagents).
        "BankReagents.Enable": "1",
        "BankReagents.MinStacks": "1",
    },
    "modules/mod_spellcooldowns.conf": {
        # Inscription research as often as the ink allows. Both spells are a
        # flat 20h RecoveryTime in Spell.dbc; the module zeroes it after the
        # spell store loads and clears any cooldown a character already
        # carries at login. Other daily profession cooldowns are listed in the
        # .conf.dist if they should join.
        "SpellCooldowns.Enable": "1",
        "SpellCooldowns.Remove": "61288,61177",
    },
    "modules/mod_languages.conf": {
        "Languages.Enable": "1",
        "Languages.RequireReputation": "1",
    },
    "modules/mod_bigbags.conf": {
        "BigBags.Enable": "1",
        # 36 slot container, the largest general purpose bag in 3.3.5a
        "BigBags.BagEntry": "23162",
    },
    "modules/playerbots.conf": {
        "AiPlayerbot.Enabled": "1",
        "AiPlayerbot.MinRandomBots": "500",
        "AiPlayerbot.MaxRandomBots": "500",
        "AiPlayerbot.RandomBotAutologin": "1",
        # keep the bot population spread across level brackets instead of
        # letting it drift to 80, and pull it towards whatever level the real
        # players are at (see the LEVEL BRACKETS block in playerbots.conf)
        "AiPlayerbot.LevelBrackets.Enabled": "1",
        "AiPlayerbot.LevelBrackets.CheckFrequency": "300",
        "AiPlayerbot.LevelBrackets.Dynamic.UseDynamicDistribution": "1",
        "AiPlayerbot.LevelBrackets.Dynamic.RealPlayerWeight": "10.0",
        "AiPlayerbot.LevelBrackets.Dynamic.SyncFactions": "1",
        # bots never emoted or greeted with these off; both are emote-only, no text
        # All three off, because mod-botlore owns what bots express now and
        # these are the playerbots originals it replaced.
        #
        # RandomBotEmote is not the harmless "emote only, no text" switch it
        # looks like. EmoteStrategy installs a "receive text emote" trigger at
        # priority 10, so a bot that is greeted greets back ("Hey there!",
        # EmoteAction.cpp:183) - and that reply is itself an emote the next bot
        # receives. With EnableGreet starting the chain on "new player nearby"
        # and hundreds of bots now standing on the same quest hub coordinates,
        # it becomes a standing ovation that never ends.
        #
        # RandomBotTalk is the "suggest what to do / suggest dungeon / suggest
        # trade" chatter on an "often" trigger, which is the same trade-chat
        # noise EnableBroadcasts was turned off for.
        "AiPlayerbot.RandomBotEmote": "0",
        "AiPlayerbot.EnableGreet": "0",
        "AiPlayerbot.RandomBotTalk": "0",
        # was at the 30000 maximum: the "Wanna party in <zone>" channel spam that
        # would otherwise drown out the authored lore lines
        "AiPlayerbot.BroadcastChanceSuggestSomething": "3000",
        # bias random bot teleports towards zones that hold a real player
        "AiPlayerbot.RandomBotConcentrateInPlayerZone": "1",
        # Send a quarter of random teleports to a quest hub instead of a mob
        # field. Without this no town is ever a destination: the stock
        # destination cache is built from creature clusters with npcflag == 0,
        # which excludes every quest giver, innkeeper and vendor in the game.
        "AiPlayerbot.ProbTeleToQuestHubs": "0.25",
        # Silence playerbots' own chatter entirely. BroadcastHelper is where the
        # out-of-character lines come from ("Wanna party in Duskwood.",
        # "WTS [item] for 5g.") and EnableBroadcasts = 0 makes it return early
        # and zeroes broadcastChanceMaxValue, so mod-botlore owns everything the
        # bots say.
        "AiPlayerbot.EnableBroadcasts": "0",
        # Off so that TravelMgr::GetTeleportLocations returns locsPerLevelCache
        # - points derived from creature spawn grids, spread right across each
        # zone - instead of allianceHubsPerLevelCache, which is built from
        # innkeepers plus (for levels 1-5) the race's starting position. With
        # it on, every low-level bot could only ever land at Northshire or the
        # Lion's Pride Inn, because that *was* the whole candidate list.
        # Turning it off also re-enables AutoDoQuests, RandomBotTeleLowerLevel
        # and RandomBotTeleHigherLevel, which the RPG strategy overrides.
        # The real quest loop. The alternative is not "no questing" but the old
        # "rpg" strategy (AutoDoQuests picks it), whose actions are choose/move
        # to/stay at/work/emote at an rpg target - ambient pottering around
        # NPCs, not questing. This one walks quest POIs and turns them in, and
        # it is the fork's own default.
        "AiPlayerbot.EnableNewRpgStrategy": "1",
        # ...but not across the world. TravelFlight is the state that puts bots
        # on a gryphon to another zone, which empties the zone the player is
        # standing in. Everything else in the new strategy is local: quest
        # objectives are already capped at 1500 yards in NewRpgBaseAction.
        # Raise it if you would rather see bots using flight masters.
        "AiPlayerbot.RpgStatusProbWeight.TravelFlight": "0",
        # 1-5 hours between relocations left the world static and slow to
        # follow the player around; 10-30 minutes re-sorts the population
        # while still being long enough that bots are not visibly blinking
        # (RandomTeleport already refuses to move a bot within 150 yards of a
        # real player)
        "AiPlayerbot.MinRandomBotTeleportInterval": "600",
        "AiPlayerbot.MaxRandomBotTeleportInterval": "1800",
    },
    "modules/mod_ahbot.conf": {
        # account 103 (AHBOT) owns the auctions; GUID 0 means "every character
        # on that account", so listings are spread over eight seller names.
        # Safe because the per-quality bins are counted house-wide and cap the
        # market at maxitems regardless of how many sellers contribute - but
        # only once ConsiderOnlyBotAuctions is 0, see below.
        "AuctionHouseBot.Account": "103",
        "AuctionHouseBot.GUID": "0",
        # populate the houses, and buy player auctions so selling is worthwhile
        "AuctionHouseBot.EnableSeller": "1",
        "AuctionHouseBot.EnableBuyer": "1",
        # let prices drift towards what actually sells rather than staying on
        # the flat percentage-of-vendor-value heuristic
        "AuctionHouseBot.UseMarketPriceForSeller": "1",
        "AuctionHouseBot.MarketResetThreshold": "25",
        # profession materials are worth having up on a server where every
        # character can learn all 11 professions
        "AuctionHouseBot.ProfessionItems": "1",
        # Without this the basic gathering economy is absent: the item filter
        # checks npc_vendor FIRST and excludes unconditionally, so any trade
        # good a vendor sells anywhere is dropped even though it also comes
        # from mining nodes, herb nodes and creature loot. That took out 165 of
        # the 927 trade goods, 88 of them gatherable - Copper Ore, Peacebloom,
        # Silverleaf, Linen Cloth among them. Adding them to
        # auctionhousebot_professionItems would not help, because the vendor
        # check runs before the loot check.
        "AuctionHouseBot.VendorTradeGoods": "1",
        # MUST be 0. The name says the opposite of what the code does: with 1,
        # AHBot_AuctionHouseScript::OnAuctionAdd returns early for bot-owned
        # auctions, so the bot's own listings never increment the per-quality
        # counters. They stay at zero, and since the seller walks the bins in
        # strict rarity order and re-reads the counts only once per cycle, the
        # first bin with a non-zero maximum swallows the whole market - it
        # produced 3200 listings of nothing but white items.
        "AuctionHouseBot.ConsiderOnlyBotAuctions": "0",
        # Lowered from the stock 200. Each seller tops the *house* up towards
        # maxitems, so a large allowance lets whichever seller runs first take
        # the whole deficit; a smaller bite means more of them contribute per
        # tick. Eight sellers x 25 is 200 listings a minute, comfortably above
        # the ~27 a minute that expire at 20000 listings and a mean auction
        # life of 12.5 hours (ElapsingTimeClass 1 = urand(1,24) hours), so the
        # market still refills quickly. The even spread itself comes from
        # shuffling the seller order per tick, patched into
        # AuctionHouseBotAuctionHouseScript.cpp - without that, lowering this
        # barely helps, because the steady-state deficit is smaller than even
        # one seller's allowance.
        "AuctionHouseBot.ItemsPerCycle": "25",
        # Common trade goods post as full stacks (200 after sql/08) instead of
        # random sizes up to 20. Same listing count, ten times the units, and no
        # more buying a dozen small lots of cloth. Rarer trade goods keep the
        # random sizing: a 200-lot of a blue material would price itself out.
        "AuctionHouseBot.TradeGoodsFullStack": "1",
        "AuctionHouseBot.TradeGoodsFullStack.MaxQuality": "1",
        # Lots stay at 200 even though the bag stack is 999 (sql/08): a lot
        # the size of the whole stack would be five times the price and more
        # than a buyer wanting forty needs to carry.
        "AuctionHouseBot.TradeGoodsFullStack.Max": "200",
    },
    "modules/mod_aurastack.conf": {
        "AuraStack.Enable": "1",
        # track herbs and minerals (and treasure, and fish) at the same time
        "AuraStack.Tracking.Resources": "1",
        "AuraStack.Tracking.Creatures": "1",
        # Track Hidden is a combat ability, left exclusive as the core has it
        "AuraStack.Tracking.Stealthed": "0",
        # stat scrolls stop cancelling each other; the other half of this is
        # sql/10_scroll_stacking.sql
        "AuraStack.Scrolls": "1",
    },
}



# A duplicate file key in the dict literal above is silent - Python keeps the
# last one and the earlier block simply never runs. That happened once, and it
# cost a debugging session: "modules/playerbots.conf" appeared twice, so every
# setting in the first block (the bot count, the level brackets, the emote and
# greet switches) had not been applied for some time. Dicts cannot check this
# for themselves, so the source is checked instead.
def _assert_no_duplicate_blocks():
    import re
    from collections import Counter

    with open(__file__, encoding="utf-8") as handle:
        source = handle.read()

    # only the top level file keys, which are indented by exactly four spaces
    keys = re.findall(r'^    "((?:modules/)?[\w./]+\.conf)": \{', source, re.M)
    repeated = sorted(name for name, count in Counter(keys).items() if count > 1)
    if repeated:
        raise SystemExit(
            "apply_config.py: duplicated config block(s): " + ", ".join(repeated) +
            "\nOnly the last of each is applied. Merge them.")


_assert_no_duplicate_blocks()


def set_option(text, key, value):
    """Rewrite `key = value`, uncommenting it if needed, or append it."""
    pattern = re.compile(rf"^([ \t]*)#?\s*{re.escape(key)}\s*=.*$", re.MULTILINE)
    replacement = f"{key} = {value}"

    if pattern.search(text):
        return pattern.sub(lambda m: m.group(1) + replacement, text, count=1), "set"

    separator = "" if text.endswith("\n") else "\n"
    return f"{text}{separator}\n{replacement}\n", "appended"


def main():
    if not os.path.isdir(ETC):
        sys.exit(f"{ETC} does not exist - run `make install` first")

    os.makedirs(LOGS, exist_ok=True)
    failures = 0

    for name, options in SETTINGS.items():
        conf = os.path.join(ETC, name)
        dist = conf + ".dist"

        if not os.path.exists(conf):
            if not os.path.exists(dist):
                print(f"!! {name}: neither the config nor the .dist template exists")
                failures += 1
                continue
            shutil.copy2(dist, conf)
            print(f"{name}: created from {os.path.basename(dist)}")

        with open(conf, encoding="utf-8") as handle:
            text = handle.read()

        for key, value in options.items():
            text, how = set_option(text, key, value)
            print(f"  {key} = {value} ({how})")

        with open(conf, "w", encoding="utf-8") as handle:
            handle.write(text)

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
