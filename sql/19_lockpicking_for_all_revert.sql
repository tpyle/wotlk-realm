-- Undo 19_lockpicking_for_all.sql: take Pick Lock back off the blacksmithing
-- trainers. The DBC half is reverted by restoring
-- run/data/dbc/SkillLineAbility.dbc.orig and SkillRaceClassInfo.dbc.orig and
-- re-running tools/gen_all_weapons_dbc.py (without gen_lockpicking_dbc.py).
DELETE FROM `trainer_spell` WHERE `SpellId` = 1804 AND `TrainerId` IN (58, 59, 60);
