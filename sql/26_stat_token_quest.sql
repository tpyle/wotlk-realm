-- ---------------------------------------------------------------------------
-- Earning a stat point: a Fragment of Power and the Echo who takes it
--
-- A boss hands every member of the killing party a Fragment of Power. Using
-- the fragment starts a repeatable quest and calls the Echo of Azeroth, who
-- takes it and grants one bonus rolled from a pool. The fragment can call the
-- Echo again afterwards, on a cooldown, so missing her the first time costs
-- nothing.
--
-- Deliberately says nothing about where the fragment comes from. Bazil Thredd
-- (1716) is the only source today and that lives in the module's
-- configuration, not in this text, so another boss can be added without the
-- quest starting to lie.
--
-- Three of the four pieces are here as data. The fourth - who gets the token,
-- when the broker appears, and what the roll lands on - is mod-statbonus,
-- reading statbonus_quest_reward and a handful of config options.
--
--   item     90001  Fragment of Power        (starts the quest, and calls the Echo)
--   quest    90001  A Fragment of Power      (repeatable)
--   creature 90001  Echo of Azeroth          (takes it)
--   spell   900000  Call the Echo            (added through spell_dbc, see below)
--
-- WHY THE TOKEN IS NOT LOOT. The ask was "everyone in the party, every time",
-- and creature_loot_template cannot do that. A quest item only drops for
-- somebody already on the quest, and an ordinary item drops once for one
-- looter. So the module hands it out on the kill instead, to every group
-- member in the same map, and mails it to anybody whose bags are full.
--
-- THE SUMMON, AND WHY IT NEEDS NO CLIENT PATCH. Quest 12798 and item 42922 are
-- the pattern being copied: a quest item whose on-use spell summons the NPC
-- who takes it, with no charges consumed and a cooldown, so it can be used
-- again. The Darkmoon version does it with two items - 37164 starts the quest
-- and is consumed, 12798 hands over 42922 on accept, and 42922 is the one with
-- the spell - because an item cannot obviously do both jobs at once.
--
-- Here it is one item that does both: StartQuest for the first click, and the
-- spell for every click after, which works because accepting a quest from an
-- item spares the item when it is also one of the quest's required items and
-- its MaxCount is non-zero. If the client turns out to refuse the spell while
-- the quest is already taken, the module still summons her on accept, so the
-- quest is always completable.
--
-- The spell is new, and new spells do NOT need a Spell.dbc edit here:
-- DBCStores loads "Spell.dbc" and then overlays the world table spell_dbc on
-- top of it, and 4492 of that table's rows are already ids that Spell.dbc has
-- never heard of. So the spell is a row of SQL. It is a copy of 56894, the
-- Darkmoon Fortune Teller summons, with the summoned creature changed - field
-- 110 of the DBC, EffectMiscValue_1 - and its own name. The table's columns
-- are in DBC field order, all 234 of them, which is what makes a copy like
-- this readable rather than a guess.
--
-- Rows are cloned from existing ones and overridden, rather than written out
-- column by column, so this cannot go stale when a column is added: the deck
-- quest 13326 and the deck item 44326 are the templates, both already
-- repeatable item-start quests, and Professor Thaddeus Paleo (14847) is the
-- template questgiver.
--
-- Idempotent. Needs a restart to take, since quest and creature templates are
-- read at startup.
-- ---------------------------------------------------------------------------

SET @ITEM   := 90001;   -- what the kill drops, and what starts the quest
SET @FOCUS  := 90002;   -- what the quest hands back, and what calls the Echo
SET @QUEST  := 90001;
SET @BROKER := 90001;
-- The doorbell, and nothing more than a doorbell.
--
-- 56894 is the spell item 42922 uses to call up its own quest giver. It is
-- here because whether an item is usable at all - the "Use:" line on the
-- tooltip, and whether right-clicking sends CMSG_USE_ITEM - is decided by the
-- client alone, from its own Spell.dbc.
--
-- This originally used a purpose-written spell 900000 in the spell_dbc world
-- table. That table is a server-side overlay the client never sees, so the
-- fragment showed no Use: line and right-clicking did nothing at all. A probe
-- item identical to this one but carrying 56894 did show the line, which is
-- what pinned the cause on the client rather than on the server.
--
-- The ItemScript below intercepts the use and returns true, so the cast never
-- happens and 56894 never summons what it would normally summon. Nothing has
-- to be added to the client's Spell.dbc and no patch has to be shipped.
-- 5735 'REUSE' and not 56894, which was here first.
--
-- Both are doorbells and neither is ever cast, but the client builds the
-- tooltip's "Use:" line from the spell's DESCRIPTION - and 56894 has one, so
-- the fragment was offering to "Communicate through the spirit world to
-- request an audience with a Darkmoon Fortune Teller". 5735 is one of
-- Blizzard's own placeholders and has no description, which removes the line
-- rather than printing something untrue. What the item does is said in its own
-- description field instead, which is ours.
SET @SPELL  := 5735;

DELETE FROM `spell_dbc` WHERE `ID` = 900000;

-- --- the fragment ---------------------------------------------------------
DELETE FROM `item_template` WHERE `entry` = @ITEM;
CREATE TEMPORARY TABLE `tmp_item` AS SELECT * FROM `item_template` WHERE `entry` = 44326;
UPDATE `tmp_item` SET
    `entry`       = @ITEM,
    `name`        = 'Fragment of Power',
    `description` = 'Something is listening on the other side of it.',   -- see @FOCUS for the usable half
    `startquest`  = @QUEST,
    -- No use effect on this one, because the client will not give it one.
    --
    -- An item with startquest set has its right-click taken by the quest
    -- path: with the quest already active the client answers "You are already
    -- on that quest" and never sends CMSG_USE_ITEM, so the Use: line and the
    -- ItemScript behind it were unreachable no matter what spell was on it.
    --
    -- Which is exactly why the stock Darkmoon pair is two items with the same
    -- name. 37164 Swords Deck carries startquest and nothing else; quest 12798
    -- hands back 42922 Swords Deck, which carries the summon spell and is what
    -- you turn in. The player never sees the swap. Same split here, with the
    -- summoning half as @FOCUS below.
    `spellid_1`      = 0,
    `spelltrigger_1` = 0,
    `spellcharges_1` = 0,
    `spellcooldown_1` = 0,
    `spellcategory_1` = 0,
    `spellcategorycooldown_1` = 0,
    `stackable`   = 20,
    -- Consumed on accept, which is now the intent rather than a bug.
    --
    -- This used to need MaxCount above zero to survive being accepted from:
    -- accepting a quest from an item destroys that item unless it is one of
    -- the quest's required items AND its MaxCount is non-zero (PlayerQuest.cpp,
    -- the TYPEID_ITEM branch of AddQuestAndCheckCompletion). With the split,
    -- @FOCUS is the required item and this one is supposed to be spent, so 0
    -- is right - and 0 also means no cap on how many a player may hoard,
    -- which a farmable token wants.
    `MaxCount`    = 0,
    `Quality`     = 3,
    `BuyPrice`    = 0,
    `SellPrice`   = 0,
    `Flags`       = 0,
    `bonding`     = 1,
    `VerifiedBuild` = 0;
INSERT INTO `item_template` SELECT * FROM `tmp_item`;
DROP TEMPORARY TABLE `tmp_item`;

-- --- the focus ------------------------------------------------------------
--
-- Handed over by the quest on accept (quest_template.StartItem) and taken
-- back at turn-in, so it only exists while the quest is open. Same name as
-- the token, as the stock pair does it, so the swap is invisible.
--
-- This is the half that carries the summon, because it has no startquest to
-- lose its right-click to.
DELETE FROM `item_template` WHERE `entry` = @FOCUS;
CREATE TEMPORARY TABLE `tmp_focus` AS SELECT * FROM `item_template` WHERE `entry` = @ITEM;
UPDATE `tmp_focus` SET
    `entry`       = @FOCUS,
    `startquest`  = 0,
    -- Says what the tooltip's "Use:" line cannot: that line comes from the
    -- spell's description in the client's own Spell.dbc, and the doorbell spell
    -- deliberately has none.
    `description` = 'Use: Calls the Echo of Azeroth to you. Something is listening on the other side of it.',
    -- A doorbell, nothing more. 56894 is the spell stock item 42922 uses; it
    -- is here so the client draws a Use: line and sends CMSG_USE_ITEM at all,
    -- which it decides by itself out of its own Spell.dbc. The ItemScript
    -- returns true and the cast never happens, so 56894 never summons what it
    -- would normally summon.
    --
    -- mod-statbonus reads spellcooldown_1 back off this row when it applies
    -- the cooldown by hand, since blocking the cast also skips the cooldown
    -- the cast would have set. This stays the one place the minute is written.
    `spellid_1`      = @SPELL,
    `spelltrigger_1` = 0,
    `spellcharges_1` = 0,
    `spellcooldown_1` = 60000,
    `spellcategory_1` = 0,
    `spellcategorycooldown_1` = -1,
    `ScriptName`  = 'item_statbonus_token',
    `bonding`     = 4,     -- quest item, as 42922 is
    `stackable`   = 1,     -- one open quest, one focus
    `MaxCount`    = 0,
    `VerifiedBuild` = 0;
INSERT INTO `item_template` SELECT * FROM `tmp_focus`;
DROP TEMPORARY TABLE `tmp_focus`;

-- --- the broker -----------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` = @BROKER;
CREATE TEMPORARY TABLE `tmp_creature` AS SELECT * FROM `creature_template` WHERE `entry` = 14847;
UPDATE `tmp_creature` SET
    `entry`    = @BROKER,
    `name`     = 'Echo of Azeroth',
    `subname`  = 'A Shape That Remembers',
    `npcflag`  = 2,        -- questgiver only; nothing to buy or train
    -- Also inherited: Paleo's gossip menu 6202, which the server complains
    -- about on a creature with no gossip flag - and which would have offered
    -- the Darkmoon Faire's card trade if the flag were ever added.
    `gossip_menu_id` = 0,
    `faction`  = 35,       -- friendly to everybody, so either side can turn in
    `minlevel` = 80,
    `maxlevel` = 80,
    `VerifiedBuild` = 0;
INSERT INTO `creature_template` SELECT * FROM `tmp_creature`;
DROP TEMPORARY TABLE `tmp_creature`;

DELETE FROM `creature_template_model` WHERE `CreatureID` = @BROKER;
-- 19661 is the Image of Commander Ameer: an ethereal, and already an *image* of
-- one rather than the thing itself, which is exactly what is being summoned here.
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
VALUES (@BROKER, 0, 19661, 1, 1, 0);

DELETE FROM `creature_template_addon` WHERE `entry` = @BROKER;
-- 28126 'Spirit Particles (purple)' is a cosmetic-only aura (23 stock creatures
-- carry it the same way); it hangs a drift of motes around the model so the Echo
-- reads as something half-here instead of just another Consortium broker.
INSERT INTO `creature_template_addon`
    (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)
VALUES (@BROKER, 0, 0, 0, 1, 0, 0, '28126');

-- --- the quest ------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` = @QUEST;
CREATE TEMPORARY TABLE `tmp_quest` AS SELECT * FROM `quest_template` WHERE `ID` = 13326;
UPDATE `tmp_quest` SET
    `ID`                 = @QUEST,
    `LogTitle`           = 'A Fragment of Power',
    `LogDescription`     = 'Hand the fragment to the Echo of Azeroth before it fades.',
    `QuestDescription`   = 'The fragment is warm, and something on the other side of it is paying attention.$B$BHold it up and that something will take shape long enough to trade. What it gives back is not yours to choose.',
    `QuestCompletionLog` = 'Hand it over.',
    `RequiredItemId1`    = @FOCUS,
    `RequiredItemCount1` = 1,
    -- The focus, handed over on accept.
    --
    -- StartItem is the item a quest GIVES OUT when accepted
    -- (Quest::GetSrcItemId), not the item it comes from - which is why it was
    -- wrong to point this at the token and wrong again to clear it. The token
    -- brings the player here through item_template.startquest; this hands back
    -- the half that can actually be used, and takes it away at turn-in.
    `StartItem`          = @FOCUS,
    `QuestLevel`         = -1,     -- scales to the player, as this realm's quests do
    `MinLevel`           = 1,
    `RewardXPDifficulty` = 0,      -- the bonus is the reward
    `RewardMoney`        = 0,
    -- Cleared for the same reason as the trinkets below: the clone inherited
    -- RewardFactionID1 = 909 (Darkmoon Faire) at value index 6, so every
    -- turn-in was quietly paying faire reputation. Nothing about this quest
    -- belongs to the faire.
    `RewardFactionID1` = 0, `RewardFactionValue1` = 0,
    `RewardFactionID2` = 0, `RewardFactionValue2` = 0,
    `RewardFactionID3` = 0, `RewardFactionValue3` = 0,
    `RewardFactionID4` = 0, `RewardFactionValue4` = 0,
    `RewardFactionID5` = 0, `RewardFactionValue5` = 0,
    -- Cleared, because the clone inherited the Nobles Deck quest's own
    -- rewards: a choice of three Darkmoon trinkets (42987, 44254, 44253),
    -- offered on the turn-in page of a quest that has nothing to do with the
    -- faire. Easy to miss in a diff against the template, since every one of
    -- these column names starts with "Reward" and reads as something the
    -- clone was supposed to bring along.
    `RewardChoiceItemID1` = 0, `RewardChoiceItemQuantity1` = 0,
    `RewardChoiceItemID2` = 0, `RewardChoiceItemQuantity2` = 0,
    `RewardChoiceItemID3` = 0, `RewardChoiceItemQuantity3` = 0,
    `RewardChoiceItemID4` = 0, `RewardChoiceItemQuantity4` = 0,
    `RewardChoiceItemID5` = 0, `RewardChoiceItemQuantity5` = 0,
    `RewardChoiceItemID6` = 0, `RewardChoiceItemQuantity6` = 0,
    `RewardItem1` = 0, `RewardAmount1` = 0,
    `RewardItem2` = 0, `RewardAmount2` = 0,
    `RewardItem3` = 0, `RewardAmount3` = 0,
    `RewardItem4` = 0, `RewardAmount4` = 0,
    `VerifiedBuild`      = 0;
INSERT INTO `quest_template` SELECT * FROM `tmp_quest`;
DROP TEMPORARY TABLE `tmp_quest`;

DELETE FROM `quest_template_addon` WHERE `ID` = @QUEST;
-- The count for StartItem belongs here, in the addon table, and not next to
-- the StartItem it counts. Leaving it 0 is not silently broken - the server
-- corrects it to 1 and logs "need fix in DB" - but stock 12798 sets it, so
-- this does too.
--
-- The column is ProvidedItemCount. The server's complaint calls it
-- StartItemCount, which is the name of the Quest member it loads into and not
-- of any column in the schema, so the error message cannot be grepped for.
INSERT INTO `quest_template_addon` (`ID`, `SpecialFlags`, `ProvidedItemCount`)
VALUES (@QUEST, 1, 1);   -- SpecialFlags 1 = repeatable

DELETE FROM `creature_questender` WHERE `quest` = @QUEST;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES (@BROKER, @QUEST);

-- --- what the Echo says ---------------------------------------------------
--
-- Both of these were missing entirely, which is not an error the server
-- reports: a quest with no quest_request_items / quest_offer_reward row just
-- shows an empty dialogue box at turn-in.
--
-- RewardText names the stat through a %stat token, which mod-statbonus
-- substitutes in OnPlayerQuestOfferRewardText while the packet is being built
-- - which is also where it rolls the pool, because this packet is the last
-- thing sent before the reward is handed over. Closing the box and reopening
-- it shows the same answer; the roll is only spent at turn-in.
--
-- RequestItemsText comes one box earlier, before anything has been rolled, so
-- that one can only gesture at the trade.
DELETE FROM `quest_request_items` WHERE `ID` = @QUEST;
INSERT INTO `quest_request_items` (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`)
VALUES (@QUEST, 1, 0,
    'You carried it all this way without opening it. Good.$B$BGive it here. I will take the shape out of it and leave what it was holding in you - but understand that I only pour. What lands is whatever the fragment was already carrying, and it was not carrying it for you.',
    0);

DELETE FROM `quest_offer_reward` WHERE `ID` = @QUEST;
INSERT INTO `quest_offer_reward`
    (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`,
     `EmoteDelay1`, `EmoteDelay2`, `EmoteDelay3`, `EmoteDelay4`, `RewardText`, `VerifiedBuild`)
VALUES (@QUEST, 4, 1, 0, 0, 0, 2000, 0, 0,
    'Hold still.$B$BThere. It was carrying %stat, and that has gone into you now. It will not wash out.$B$BBring me another when you find one. There is a great deal of world, and it is all still happening.',
    0);

-- --- what it can grant ----------------------------------------------------
--
-- Kind 0 stats, 1 combat ratings, 2 resistances. Weights are relative within
-- the quest, so the five stats are five times as likely as any one rating and
-- the resistances are the long tail. Retune with an UPDATE and
-- ".statbonus reload"; nothing needs rebuilding.
DELETE FROM `statbonus_quest_reward` WHERE `QuestId` = @QUEST;
INSERT INTO `statbonus_quest_reward` (`QuestId`, `Kind`, `Id`, `Amount`, `Weight`, `Comment`) VALUES
(@QUEST, 0, 0, 1, 50, '+1 strength'),
(@QUEST, 0, 1, 1, 50, '+1 agility'),
(@QUEST, 0, 2, 1, 50, '+1 stamina'),
(@QUEST, 0, 3, 1, 50, '+1 intellect'),
(@QUEST, 0, 4, 1, 50, '+1 spirit'),
(@QUEST, 1, 5, 3, 10, '+3 hit rating'),
(@QUEST, 1, 8, 3, 10, '+3 crit rating'),
(@QUEST, 1, 17, 3, 10, '+3 haste rating'),
(@QUEST, 1, 2, 3, 10, '+3 dodge rating'),
(@QUEST, 1, 3, 3, 10, '+3 parry rating'),
(@QUEST, 1, 23, 3, 10, '+3 expertise rating'),
(@QUEST, 2, 1, 5, 4, '+5 holy resistance'),
(@QUEST, 2, 2, 5, 4, '+5 fire resistance'),
(@QUEST, 2, 3, 5, 4, '+5 nature resistance'),
(@QUEST, 2, 4, 5, 4, '+5 frost resistance'),
(@QUEST, 2, 5, 5, 4, '+5 shadow resistance'),
(@QUEST, 2, 6, 5, 4, '+5 arcane resistance');
