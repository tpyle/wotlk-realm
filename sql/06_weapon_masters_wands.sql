-- ---------------------------------------------------------------------------
-- Let the weapon masters teach wands as well
--
-- tools/gen_all_weapons_dbc.py removes the class restriction from the weapon
-- proficiencies, but wands were never on anyone's trainer list: caster classes
-- are simply given them at character creation. Without this, "every class can
-- learn every weapon" would have one hole in it.
--
-- 5009 is the Wands proficiency (lets you equip one), 5019 is Shoot (lets you
-- actually attack with it). Both are added to every trainer that already
-- teaches a weapon proficiency, at the same 10 silver the others cost.
--
--   To undo: DELETE FROM trainer_spell WHERE SpellId IN (5009, 5019);
--
-- Idempotent: safe to run more than once.
-- ---------------------------------------------------------------------------

INSERT IGNORE INTO trainer_spell (TrainerId, SpellId, MoneyCost, ReqSkillLine, ReqSkillRank, ReqAbility1, ReqAbility2, ReqAbility3, ReqLevel)
SELECT DISTINCT existing.TrainerId, wand.SpellId, 1000, 0, 0, 0, 0, 0, 0
FROM trainer_spell existing
CROSS JOIN (SELECT 5009 AS SpellId UNION ALL SELECT 5019) wand
WHERE existing.SpellId IN (196,197,198,199,200,201,202,227,264,266,1180,2567,5011,15590);
