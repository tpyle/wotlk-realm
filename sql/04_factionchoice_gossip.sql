-- ---------------------------------------------------------------------------
-- Text for the faction chooser windows (mod-factionchoice)
--
-- The module sends its menus with the player's own GUID, which the core
-- supports, but the body text of a gossip window still comes from npc_text.
-- Ids 90010 and 90011 were free in this database.
--
-- Idempotent: safe to run more than once.
-- ---------------------------------------------------------------------------

DELETE FROM npc_text WHERE ID IN (90010, 90011);

INSERT INTO npc_text (ID, text0_0, text0_1, Probability0) VALUES
(90010,
 'Azeroth is at war, and you have yet to take a side. Your people expect you to stand with them - but the choice is yours alone.$B$BWhich banner will you fight under?',
 'Azeroth is at war, and you have yet to take a side. Your people expect you to stand with them - but the choice is yours alone.$B$BWhich banner will you fight under?',
 1),
(90011,
 'Then your old home is no longer safe for you.$B$BWhere would you like to begin?',
 'Then your old home is no longer safe for you.$B$BWhere would you like to begin?',
 1);
