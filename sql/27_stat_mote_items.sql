-- ---------------------------------------------------------------------------
-- Motes: a stat granted outright, with no quest in the way
--
-- The short route alongside sql/26_stat_token_quest.sql: no quest to accept,
-- no Echo to summon, no turn-in. Right-click a mote and the bonus is yours,
-- and the mote is spent. One per primary stat.
--
--   90003  Mote of Vigour    stamina     Greater Nether Essence  icon
--   90004  Mote of Might     strength    Greater Eternal Essence
--   90005  Mote of Grace     agility     Greater Astral Essence
--   90006  Mote of Insight   intellect   Greater Magic Essence
--   90007  Mote of Serenity  spirit      Greater Mystic Essence
--
-- The icons are the enchanting essences' own DisplayInfoIDs, which is all an
-- icon is: item_template.displayid resolves through the CLIENT's Item.dbc and
-- ItemDisplayInfo.dbc, so borrowing a stock display id borrows its art with
-- nothing to ship but the Item.dbc row. tools/gen_item_dbc.py writes that row;
-- without it the client draws a question mark however complete the server's
-- answer is.
--
-- 90003 keeps stamina rather than being renumbered into stat order, because
-- motes are already sitting in players' bags and an entry means a particular
-- item to them.
--
-- WHAT A MOTE GRANTS is its statbonus_item_reward row, not anything in
-- item_template, so retuning an amount is an UPDATE and a ".statbonus reload"
-- rather than a rebuild. The tooltip is the one thing that does not follow:
-- it comes from the spell description in sql/28_custom_spells.sql and so from
-- a client patch. gen_spell_dbc.py cross-checks the two and refuses to ship a
-- tooltip that disagrees with the table.
--
-- Rerunning this file is safe: every statement is a DELETE or an INSERT of the
-- same rows.
-- ---------------------------------------------------------------------------

-- Cloned from the quest fragment (90001) so the shared shape - quest class,
-- bind on pickup, no vendor price - stays in one place.
SET @SOURCE := 90001;

DELETE FROM `item_template` WHERE `entry` BETWEEN 90003 AND 90007;

CREATE TEMPORARY TABLE `tmp_mote` AS SELECT * FROM `item_template` WHERE 0;

-- The columns every mote shares. The spell is a doorbell and is never cast:
-- ScriptName item_statbonus_grant returns true from OnUse, so the (dummy)
-- effect is not reached. It still has to exist and the client still has to
-- know it, or there is no Use: line and no right-click at all.
INSERT INTO `tmp_mote` SELECT * FROM `item_template` WHERE `entry` = @SOURCE;
UPDATE `tmp_mote` SET
    `Quality`     = 2,     -- uncommon; each is a small, ordinary gain
    `startquest`  = 0,     -- the point of these: no quest to collide with
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

-- Then one row per stat: set the temp row's own columns and insert it, which
-- keeps the shared shape above in one place instead of repeating forty columns
-- five times.
--
-- description is flavour only now. It used to carry a hand-written "Use:"
-- line, because a borrowed spell with an empty description removes the real
-- one altogether rather than leaving it blank. With our own spells in
-- 28_custom_spells.sql the client writes that line itself, and this field goes
-- back to being the quoted text underneath it.

UPDATE `tmp_mote` SET
    `entry`       = 90003,
    `name`        = 'Mote of Vigour',
    `displayid`   = 20896,
    `spellid_1`   = 90103,
    `description` = 'It wants to be part of something that moves.';
INSERT INTO `item_template` SELECT * FROM `tmp_mote`;

UPDATE `tmp_mote` SET
    `entry`       = 90004,
    `name`        = 'Mote of Might',
    `displayid`   = 26772,
    `spellid_1`   = 90104,
    `description` = 'It leans, very slightly, against your hand.';
INSERT INTO `item_template` SELECT * FROM `tmp_mote`;

UPDATE `tmp_mote` SET
    `entry`       = 90005,
    `name`        = 'Mote of Grace',
    `displayid`   = 20613,
    `spellid_1`   = 90105,
    `description` = 'It will not sit still long enough to be looked at properly.';
INSERT INTO `item_template` SELECT * FROM `tmp_mote`;

UPDATE `tmp_mote` SET
    `entry`       = 90006,
    `name`        = 'Mote of Insight',
    `displayid`   = 20609,
    `spellid_1`   = 90106,
    `description` = 'It hums with half-finished questions.';
INSERT INTO `item_template` SELECT * FROM `tmp_mote`;

UPDATE `tmp_mote` SET
    `entry`       = 90007,
    `name`        = 'Mote of Serenity',
    `displayid`   = 20795,
    `spellid_1`   = 90107,
    `description` = 'It is very quiet, and very awake.';
INSERT INTO `item_template` SELECT * FROM `tmp_mote`;

DROP TEMPORARY TABLE `tmp_mote`;

-- --- what each one grants --------------------------------------------------
--
-- One row per item, so each is a certainty rather than a gamble: Kind 0 is a
-- primary stat and the Id is its index, the same vocabulary as
-- character_stat_bonus and the quest pool. Several rows sharing an ItemId
-- would make that item random instead.
DELETE FROM `statbonus_item_reward` WHERE `ItemId` BETWEEN 90003 AND 90007;
INSERT INTO `statbonus_item_reward` (`ItemId`, `Kind`, `Id`, `Amount`, `Weight`, `Comment`) VALUES
    (90003, 0, 2, 1, 1, 'Mote of Vigour: +1 stamina'),
    (90004, 0, 0, 1, 1, 'Mote of Might: +1 strength'),
    (90005, 0, 1, 1, 1, 'Mote of Grace: +1 agility'),
    (90006, 0, 3, 1, 1, 'Mote of Insight: +1 intellect'),
    (90007, 0, 4, 1, 1, 'Mote of Serenity: +1 spirit');
