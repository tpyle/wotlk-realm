-- ---------------------------------------------------------------------------
-- Every class can train every armour proficiency and shields, at level 40
--
-- Plate on a warlock, mail on a mage. The proficiencies are ordinary trainer
-- spells, so this is trainer rows rather than anything cleverer:
--
--   750  Plate Mail   stock ClassMask 0x23  - warrior, paladin, death knight
--   8737 Mail         stock ClassMask 0x67  - those three, hunter, shaman
--   9077 Leather      stock ClassMask 0x46f - all but priest, mage, warlock
--   9078 Cloth        stock ClassMask 0x5ff - every class already has it
--   9116 Shield       stock ClassMask 0x43  - warrior, paladin, shaman
--
-- Cloth is therefore absent from this file: there is nobody to give it to.
--
-- Level 40 is what the stock rows use for plate and mail, so this keeps the
-- rhythm: a warlock buys plate at exactly the level a warrior buys it.
--
-- The costs follow the stock rows too - plate 2g, mail 1g80s - with leather and
-- shields at 1g, neither having a precedent to copy because neither has ever
-- been trained by anybody. The stock rows themselves disagree slightly (the
-- hunter pays 1g80s for mail and the shaman 1g20s); the higher figure is used
-- throughout rather than reproducing that.
--
-- WHICH TRAINERS. Only the primary one per class. Each class has one trainer
-- with a full list - 84 to 297 spells - plus small specialist and portal
-- trainers carrying two to six. The stock plate and mail rows sit on exactly
-- the primary ones, so these join them there; a mage learning plate from a
-- portal trainer would be odd.
--
-- THIS IS HALF THE CHANGE. A trainer will not offer a spell that
-- Player::IsSpellFitByClassAndRace refuses (Trainer.cpp), and
-- Player::_LoadSkills deletes a skill with no matching SkillRaceClassInfo row
-- at the next login. Both read DBC class masks, which mod-openskills opens in
-- memory: OpenSkills.Extra must list 293, 413, 414 and 433 (Plate Mail, Mail,
-- Leather, Shield) or every row below is invisible and any skill somehow
-- acquired is stripped. tools/gen_openskills_client_dbc.py then has to run so the client
-- agrees, or the skills will not show on the character sheet.
--
-- Idempotent: the rows are deleted and reinserted. Applying it needs no
-- restart, only ".reload trainer".
--
-- THE DELETE NAMES EXACT PAIRS, and that is a correction rather than a style
-- choice. It used to read
--
--   WHERE TrainerId IN (...) AND SpellId IN (...)
--
-- which is the cross product, and the cross product contained two rows this
-- file does not own: the stock (7, 8737) and (14, 8737), hunters and shamans
-- training Mail. They were deleted and not reinserted, because those classes
-- already have mail in their class mask and so are skipped by the computation
-- below. The symptom was a level 80 hunter unable to train Mail at all, which
-- is a thing the realm used to be able to do.
--
-- The two rows are restored at the foot of the file, with the money costs the
-- base data gives them (data/sql/base/db_world/trainer_spell.sql), rather than
-- from anybody's memory of a SELECT.
-- ---------------------------------------------------------------------------

DELETE FROM `trainer_spell` WHERE (`TrainerId`, `SpellId`) IN (
    (7, 750), (7, 9116), (9, 750), (9, 8737), (9, 9116), (11, 750),
    (11, 8737), (11, 9077), (11, 9116), (13, 9116), (14, 750), (16, 750),
    (16, 8737), (16, 9077), (16, 9116), (31, 750), (31, 8737), (31, 9077),
    (31, 9116), (33, 750), (33, 8737), (33, 9116)
);

INSERT INTO `trainer_spell` (`TrainerId`, `SpellId`, `MoneyCost`, `ReqSkillLine`, `ReqSkillRank`, `ReqAbility1`, `ReqAbility2`, `ReqAbility3`, `ReqLevel`) VALUES
(7, 750, 20000, 0, 0, 0, 0, 0, 40),   -- Plate Mail for the hunter trainer
(7, 9116, 10000, 0, 0, 0, 0, 0, 40),   -- Shield for the hunter trainer
(9, 750, 20000, 0, 0, 0, 0, 0, 40),   -- Plate Mail for the rogue trainer
(9, 8737, 18000, 0, 0, 0, 0, 0, 40),   -- Mail for the rogue trainer
(9, 9116, 10000, 0, 0, 0, 0, 0, 40),   -- Shield for the rogue trainer
(11, 750, 20000, 0, 0, 0, 0, 0, 40),   -- Plate Mail for the priest trainer
(11, 8737, 18000, 0, 0, 0, 0, 0, 40),   -- Mail for the priest trainer
(11, 9077, 10000, 0, 0, 0, 0, 0, 40),   -- Leather for the priest trainer
(11, 9116, 10000, 0, 0, 0, 0, 0, 40),   -- Shield for the priest trainer
(13, 9116, 10000, 0, 0, 0, 0, 0, 40),   -- Shield for the death knight trainer
(14, 750, 20000, 0, 0, 0, 0, 0, 40),   -- Plate Mail for the shaman trainer
(16, 750, 20000, 0, 0, 0, 0, 0, 40),   -- Plate Mail for the mage trainer
(16, 8737, 18000, 0, 0, 0, 0, 0, 40),   -- Mail for the mage trainer
(16, 9077, 10000, 0, 0, 0, 0, 0, 40),   -- Leather for the mage trainer
(16, 9116, 10000, 0, 0, 0, 0, 0, 40),   -- Shield for the mage trainer
(31, 750, 20000, 0, 0, 0, 0, 0, 40),   -- Plate Mail for the warlock trainer
(31, 8737, 18000, 0, 0, 0, 0, 0, 40),   -- Mail for the warlock trainer
(31, 9077, 10000, 0, 0, 0, 0, 0, 40),   -- Leather for the warlock trainer
(31, 9116, 10000, 0, 0, 0, 0, 0, 40),   -- Shield for the warlock trainer
(33, 750, 20000, 0, 0, 0, 0, 0, 40),   -- Plate Mail for the druid trainer
(33, 8737, 18000, 0, 0, 0, 0, 0, 40),   -- Mail for the druid trainer
(33, 9116, 10000, 0, 0, 0, 0, 0, 40);   -- Shield for the druid trainer

-- Restoring what an earlier version of this file destroyed, exactly as
-- data/sql/base/db_world/trainer_spell.sql has them. IGNORE so that running
-- this on a database where they are still intact does nothing.
INSERT IGNORE INTO `trainer_spell` (`TrainerId`, `SpellId`, `MoneyCost`, `ReqSkillLine`, `ReqSkillRank`, `ReqAbility1`, `ReqAbility2`, `ReqAbility3`, `ReqLevel`, `VerifiedBuild`) VALUES
(7, 8737, 18000, 0, 0, 0, 0, 0, 40, 0),    -- stock: the hunter trains Mail
(14, 8737, 12000, 0, 0, 0, 0, 0, 40, 0);   -- stock: the shaman trains Mail
