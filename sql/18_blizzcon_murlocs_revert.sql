-- Puts the two BlizzCon Elders back to speech only. The three coded options
-- are stock and stay.
DELETE FROM conditions WHERE SourceTypeOrReferenceId = 15 AND SourceGroup = 6565;
DELETE FROM smart_scripts WHERE entryorguid IN (2943, 7951) AND source_type = 0;
DELETE FROM creature_text WHERE CreatureID IN (2943, 7951) AND GroupID = 0;
UPDATE creature_template SET AIName = '' WHERE entry IN (2943, 7951);
