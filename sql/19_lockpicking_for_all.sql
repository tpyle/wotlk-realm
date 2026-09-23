-- ---------------------------------------------------------------------------
-- Lockpicking for every class
--
-- Pick Lock (spell 1804) is taught by rogue trainers, trainer 9, which is a
-- class trainer with Requirement = CLASS_ROGUE - so a non-rogue cannot so
-- much as open its window (Trainer::IsTrainerValidForPlayer). Rather than
-- weaken that trainer, the spell is added to the blacksmithing trainers:
-- trainers 58, 59 and 60, which are Type 2 (tradeskill) with Requirement 0,
-- meaning anyone may talk to them, and which cover 32 NPCs in every capital
-- and most towns. A locksmith is a reasonable thing for a blacksmith to be.
--
-- Terms match what a rogue pays at their own trainer: 18 silver, level 16.
-- Rogues are unaffected - they still learn it from their class trainer, and
-- this row simply never applies to them because they know it already.
--
-- The other half of this is in the DBC files, applied by
-- tools/gen_lockpicking_dbc.py: SkillLineAbility 8439 and SkillRaceClassInfo
-- 601 both carry ClassMask 8 (rogue), and without opening those the trainer
-- would refuse to teach the spell and the skill would never be granted.
--
-- Learning the spell is the whole of it: Player.cpp grants the lockpicking
-- skill automatically when Pick Lock is learned, and the skill's maximum is
-- five times the character's level thereafter.
--
-- Idempotent. 19_lockpicking_for_all_revert.sql puts it back.
-- ---------------------------------------------------------------------------

DELETE FROM `trainer_spell` WHERE `SpellId` = 1804 AND `TrainerId` IN (58, 59, 60);

INSERT INTO `trainer_spell`
    (`TrainerId`, `SpellId`, `MoneyCost`, `ReqSkillLine`, `ReqSkillRank`, `ReqAbility1`, `ReqAbility2`, `ReqAbility3`, `ReqLevel`)
VALUES
    (58, 1804, 1800, 0, 0, 0, 0, 0, 16),
    (59, 1804, 1800, 0, 0, 0, 0, 0, 16),
    (60, 1804, 1800, 0, 0, 0, 0, 0, 16);
