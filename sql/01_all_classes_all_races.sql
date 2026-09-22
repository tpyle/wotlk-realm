-- ---------------------------------------------------------------------------
-- All classes available to all races (server side)
--
-- The client decides which combinations to *offer* from CharBaseInfo.dbc (see
-- tools/gen_all_classes_dbc.py and the generated client patch); the server
-- decides which combinations it will *accept* from playercreateinfo.
--
-- Starting stats do not need any work: AzerothCore builds them from
-- player_class_stats (per class/level) plus player_race_stats (per race
-- modifiers), so a brand new combination gets correct, race-adjusted stats.
-- Starting skills and spells come from playercreateinfo_skills /
-- playercreateinfo_spell_custom, which are keyed by race+class *masks* and
-- therefore already cover the new combinations.
--
-- Idempotent: safe to run more than once.
-- ---------------------------------------------------------------------------

-- 1) Starting location for every missing race/class combination.
--    The new combination starts where that race already starts. Death Knights
--    (class 6) are never used as the donor row, otherwise every new character
--    of that race would start in Ebon Hold.
INSERT IGNORE INTO playercreateinfo (race, class, map, zone, position_x, position_y, position_z, orientation)
SELECT donor.race, target.class,
       donor.map, donor.zone, donor.position_x, donor.position_y, donor.position_z, donor.orientation
FROM playercreateinfo donor
JOIN (
    SELECT race, MIN(class) AS class
    FROM playercreateinfo
    WHERE class <> 6
    GROUP BY race
) AS pick ON pick.race = donor.race AND pick.class = donor.class
CROSS JOIN (SELECT DISTINCT class FROM playercreateinfo) AS target;

-- 2) Default action bar for the combinations that just gained one, copied from
--    the lowest numbered race that already plays that class.
INSERT IGNORE INTO playercreateinfo_action (race, class, button, action, type)
SELECT missing.race, missing.class, donor.button, donor.action, donor.type
FROM (
    SELECT pci.race, pci.class
    FROM playercreateinfo pci
    LEFT JOIN (SELECT DISTINCT race, class FROM playercreateinfo_action) have
           ON have.race = pci.race AND have.class = pci.class
    WHERE have.race IS NULL
) AS missing
JOIN (SELECT class, MIN(race) AS race FROM playercreateinfo_action GROUP BY class) AS pick
     ON pick.class = missing.class
JOIN playercreateinfo_action donor
     ON donor.class = pick.class AND donor.race = pick.race;
