-- Undo 21_brewfest_reveler_faction.sql: put the Brewfest Reveler back on the
-- Horde-flagged faction template it ships with. Follow with
-- ".reload creature_template".
UPDATE `creature_template` SET `faction` = 775 WHERE `entry` = 24484 AND `faction` = 35;
