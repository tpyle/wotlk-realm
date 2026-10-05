-- ---------------------------------------------------------------------------
-- Every class can train every armour proficiency, at level 40
--
-- Plate on a warlock, mail on a mage. The proficiencies are ordinary trainer
-- spells, so this is trainer rows rather than anything cleverer:
--
--   750  Plate Mail   stock ClassMask 0x23  - warrior, paladin, death knight
--   8737 Mail         stock ClassMask 0x67  - those three, hunter, shaman
--   9077 Leather      stock ClassMask 0x46f - all but priest, mage, warlock
--   9078 Cloth        stock ClassMask 0x5ff - every class already has it
--
-- Cloth is therefore absent from this file: there is nobody to give it to.
-- Shields (9116) are absent too, being an off-hand rather than a set piece;
-- adding them would be the same shape of row against trainers 7, 9, 11, 13,
-- 16, 31 and 33.
--
-- Level 40 is what the stock rows use for plate and mail, so this keeps the
-- rhythm: a warlock buys plate at exactly the level a warrior buys it.
--
-- The costs follow the stock rows too - plate 2g, mail 1g80s - with leather at
-- 1g, which has no precedent to copy because leather has never been trained by
-- anybody. The stock rows themselves disagree slightly (the hunter pays 1g80s
-- for mail and the shaman 1g20s); the higher figure is used throughout rather
-- than reproducing that.
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
-- memory: OpenSkills.Extra must list 293, 413 and 414 (Plate Mail, Mail,
-- Leather) or every row below is invisible and any skill somehow acquired is
-- stripped. tools/gen_openskills_client_dbc.py then has to run so the client
-- agrees, or the skills will not show on the character sheet.
--
-- Idempotent: the rows are deleted and reinserted. Applying it needs no
-- restart, only ".reload trainer".
-- ---------------------------------------------------------------------------

DELETE FROM `trainer_spell` WHERE `TrainerId` IN (7, 9, 11, 14, 16, 31, 33) AND `SpellId` IN (750, 8737, 9077);

INSERT INTO `trainer_spell` (`TrainerId`, `SpellId`, `MoneyCost`, `ReqSkillLine`, `ReqSkillRank`, `ReqAbility1`, `ReqAbility2`, `ReqAbility3`, `ReqLevel`) VALUES
(7, 750, 20000, 0, 0, 0, 0, 0, 40),   -- Plate Mail for the hunter trainer
(9, 750, 20000, 0, 0, 0, 0, 0, 40),   -- Plate Mail for the rogue trainer
(9, 8737, 18000, 0, 0, 0, 0, 0, 40),   -- Mail for the rogue trainer
(11, 750, 20000, 0, 0, 0, 0, 0, 40),   -- Plate Mail for the priest trainer
(11, 8737, 18000, 0, 0, 0, 0, 0, 40),   -- Mail for the priest trainer
(11, 9077, 10000, 0, 0, 0, 0, 0, 40),   -- Leather for the priest trainer
(14, 750, 20000, 0, 0, 0, 0, 0, 40),   -- Plate Mail for the shaman trainer
(16, 750, 20000, 0, 0, 0, 0, 0, 40),   -- Plate Mail for the mage trainer
(16, 8737, 18000, 0, 0, 0, 0, 0, 40),   -- Mail for the mage trainer
(16, 9077, 10000, 0, 0, 0, 0, 0, 40),   -- Leather for the mage trainer
(31, 750, 20000, 0, 0, 0, 0, 0, 40),   -- Plate Mail for the warlock trainer
(31, 8737, 18000, 0, 0, 0, 0, 0, 40),   -- Mail for the warlock trainer
(31, 9077, 10000, 0, 0, 0, 0, 0, 40),   -- Leather for the warlock trainer
(33, 750, 20000, 0, 0, 0, 0, 0, 40),   -- Plate Mail for the druid trainer
(33, 8737, 18000, 0, 0, 0, 0, 0, 40);   -- Mail for the druid trainer
