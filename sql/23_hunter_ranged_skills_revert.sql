-- Undo 23_hunter_ranged_skills.sql: back to the four stock bow-using hunter
-- races. Re-run tools/gen_all_classes_dbc.py and tools/gen_hunter_start_kits.py
-- afterwards so the starting kits follow, and restart the worldserver.
UPDATE `playercreateinfo_skills` SET `raceMask` = 650
WHERE `classMask` = 4 AND `skill` = 45 AND `raceMask` = 731;
