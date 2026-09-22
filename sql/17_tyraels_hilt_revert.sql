-- Puts the two Elders back to speech only.
DELETE FROM conditions WHERE SourceTypeOrReferenceId = 15 AND SourceGroup = 9768 AND SourceEntry = 0;
DELETE FROM smart_scripts WHERE entryorguid IN (29093, 29095) AND source_type = 0;
DELETE FROM creature_text WHERE CreatureID IN (29093, 29095) AND GroupID = 0;
DELETE FROM gossip_menu_option WHERE MenuID = 9768 AND OptionID = 0;
UPDATE creature_template SET AIName = '' WHERE entry IN (29093, 29095);
