-- ---------------------------------------------------------------------------
-- Earning a stat point: Bazil Thredd, a token, and the broker who takes it
--
-- Bazil Thredd (1716, the last boss of the Stormwind Stockade) hands every
-- member of the killing party a token. Using the token starts a repeatable
-- quest and calls a broker to the player, who takes it and grants one bonus
-- rolled from a pool.
--
-- Three of the four pieces are here as data. The fourth - who gets the token,
-- when the broker appears, and what the roll lands on - is mod-statbonus,
-- reading statbonus_quest_reward and a handful of config options.
--
--   item     90001  Spoils of the Stockade
--   quest    90001  A Share of the Spoils       (repeatable)
--   creature 90001  Quartermaster of Spoils     (the broker)
--
-- WHY THE TOKEN IS NOT LOOT. The ask was "everyone in the party, every time",
-- and creature_loot_template cannot do that. A quest item only drops for
-- somebody already on the quest, and an ordinary item drops once for one
-- looter. So the module hands it out on the kill instead, to every group
-- member in the same map, and mails it to anybody whose bags are full.
--
-- WHY THE BROKER IS SUMMONED ON ACCEPT, NOT ON USE. Archmage Vargoth's Staff
-- (28455) is the shipped precedent for this - a quest item whose use-spell
-- summons the NPC who takes it - but that needs a spell, and a new spell needs
-- a row in Spell.dbc and therefore a client patch. item_template.StartQuest
-- makes the token start the quest by itself, the way the Darkmoon decks do,
-- and the module summons the broker when the quest is accepted. One click,
-- same result, nothing for the client to learn.
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

SET @ITEM   := 90001;
SET @QUEST  := 90001;
SET @BROKER := 90001;
SET @BAZIL  := 1716;

-- --- the token ------------------------------------------------------------
DELETE FROM `item_template` WHERE `entry` = @ITEM;
CREATE TEMPORARY TABLE `tmp_item` AS SELECT * FROM `item_template` WHERE `entry` = 44326;
UPDATE `tmp_item` SET
    `entry`       = @ITEM,
    `name`        = 'Spoils of the Stockade',
    `description` = 'The Stockade''s quartermaster will know what to make of this.',
    `startquest`  = @QUEST,
    `stackable`   = 20,
    `MaxCount`    = 0,
    `Quality`     = 3,
    `BuyPrice`    = 0,
    `SellPrice`   = 0,
    `Flags`       = 0,
    `bonding`     = 1,
    `VerifiedBuild` = 0;
INSERT INTO `item_template` SELECT * FROM `tmp_item`;
DROP TEMPORARY TABLE `tmp_item`;

-- --- the broker -----------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` = @BROKER;
CREATE TEMPORARY TABLE `tmp_creature` AS SELECT * FROM `creature_template` WHERE `entry` = 14847;
UPDATE `tmp_creature` SET
    `entry`    = @BROKER,
    `name`     = 'Quartermaster of Spoils',
    `subname`  = 'Keeper of Small Advantages',
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
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
VALUES (@BROKER, 0, 14883, 1, 1, 0);

-- --- the quest ------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` = @QUEST;
CREATE TEMPORARY TABLE `tmp_quest` AS SELECT * FROM `quest_template` WHERE `ID` = 13326;
UPDATE `tmp_quest` SET
    `ID`                 = @QUEST,
    `LogTitle`           = 'A Share of the Spoils',
    `LogDescription`     = 'Hand the spoils to the Quartermaster of Spoils.',
    `QuestDescription`   = 'You pried this from what was left of Bazil Thredd. It is worth something to the right person, and the right person can be called.$B$BWhat you get back is not yours to choose.',
    `QuestCompletionLog` = 'Hand it over.',
    `RequiredItemId1`    = @ITEM,
    `RequiredItemCount1` = 1,
    -- Cleared, not pointed at our own token.
    --
    -- The clone inherited StartItem = 44326, the Nobles Deck, which would have
    -- had this quest claim somebody else's item as its source. Pointing it at
    -- @ITEM instead looked right and is not: StartItem is the item a quest
    -- HANDS OVER on accept (Quest::GetSrcItemId), and the token already
    -- arrives from the kill. The item starts the quest through
    -- item_template.startquest; the quest needs no source item of its own.
    `StartItem`          = 0,
    `QuestLevel`         = -1,     -- scales to the player, as this realm's quests do
    `MinLevel`           = 1,
    `RewardXPDifficulty` = 0,      -- the bonus is the reward
    `RewardMoney`        = 0,
    `VerifiedBuild`      = 0;
INSERT INTO `quest_template` SELECT * FROM `tmp_quest`;
DROP TEMPORARY TABLE `tmp_quest`;

DELETE FROM `quest_template_addon` WHERE `ID` = @QUEST;
INSERT INTO `quest_template_addon` (`ID`, `SpecialFlags`) VALUES (@QUEST, 1);   -- 1 = repeatable

DELETE FROM `creature_questender` WHERE `quest` = @QUEST;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES (@BROKER, @QUEST);

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
