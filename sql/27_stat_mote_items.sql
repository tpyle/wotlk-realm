-- ---------------------------------------------------------------------------
-- A mote that grants a stat outright, with no quest in the way
--
-- The short route alongside sql/26_stat_token_quest.sql: no quest to accept,
-- no Echo to summon, no turn-in. Right-click it and the bonus is yours, and
-- the mote is spent.
--
-- What it grants is the statbonus_item_reward row at the bottom, not anything
-- in item_template, so retuning the amount is an UPDATE and a
-- ".statbonus reload" rather than a rebuild. Adding a second mote - agility,
-- say - is a copy of both halves with a new entry and a new Id.
--
-- Rerunning this file is safe: every statement is a DELETE followed by an
-- INSERT of the same rows.
-- ---------------------------------------------------------------------------

SET @MOTE  := 90003;

-- The spell is a doorbell and is never cast.
--
-- Whether an item is usable at all - the "Use:" line on the tooltip and
-- whether right-clicking sends CMSG_USE_ITEM - is decided by the client out of
-- its own Spell.dbc. A purpose-written spell in the spell_dbc world table does
-- not work, because that table is a server-side overlay the client never sees;
-- an item carrying one shows no Use: line and right-clicks into nothing. That
-- was measured on item 90001 rather than guessed: a probe item differing only
-- in its spell id did show the line.
--
-- 5735 is 'REUSE', one of Blizzard's own placeholders, chosen out of the 368
-- spells in Spell.dbc that are instant, self-targeted, free of cost, reagents
-- and weapon requirements, neither passive nor hidden - and carry no
-- description, which matters because the client renders a spell's description
-- as the Use: line. An empty one leaves the tooltip saying nothing rather than
-- saying something untrue, which is what item 90001 does with its own
-- borrowed spell.
--
-- ScriptName item_statbonus_grant returns true from OnUse, so this spell's own
-- (empty) effect is never reached.
SET @SPELL := 5735;

-- --- the mote -------------------------------------------------------------
DELETE FROM `item_template` WHERE `entry` = @MOTE;
CREATE TEMPORARY TABLE `tmp_mote` AS SELECT * FROM `item_template` WHERE `entry` = 90001;
UPDATE `tmp_mote` SET
    `entry`       = @MOTE,
    `name`        = 'Mote of Vigour',
    `description` = 'It wants to be part of something that moves.',
    `Quality`     = 2,     -- uncommon; it is a small, ordinary gain
    `startquest`  = 0,     -- the point of this one: no quest to collide with
    `spellid_1`      = @SPELL,
    `spelltrigger_1` = 0,
    -- No charges, because the script spends the item itself.
    --
    -- spellcharges_1 = -1 would be the usual way to say "consumed on use", but
    -- charges are taken in CastItemUseSpell, and the script returns true
    -- before that runs. Leaving it at 0 and destroying one in the script keeps
    -- the two from both trying.
    `spellcharges_1` = 0,
    `spellcooldown_1` = -1,
    `spellcategory_1` = 0,
    `spellcategorycooldown_1` = -1,
    `ScriptName`  = 'item_statbonus_grant',
    `bonding`     = 1,     -- bind on pickup, as the token is
    `stackable`   = 20,
    `MaxCount`    = 0,     -- no cap on how many may be carried
    `VerifiedBuild` = 0;
INSERT INTO `item_template` SELECT * FROM `tmp_mote`;
DROP TEMPORARY TABLE `tmp_mote`;

-- --- what it grants -------------------------------------------------------
--
-- One row, so it is a certainty rather than a gamble: Kind 0 is a primary
-- stat and Id 2 is stamina, the same vocabulary as character_stat_bonus and
-- the quest pool. Several rows sharing @MOTE would make it random instead.
DELETE FROM `statbonus_item_reward` WHERE `ItemId` = @MOTE;
INSERT INTO `statbonus_item_reward` (`ItemId`, `Kind`, `Id`, `Amount`, `Weight`, `Comment`) VALUES
    (@MOTE, 0, 2, 1, 1, 'Mote of Vigour: +1 stamina');
