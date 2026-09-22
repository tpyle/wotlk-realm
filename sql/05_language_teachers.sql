-- ---------------------------------------------------------------------------
-- Language teachers (mod-languages)
--
-- Maps a creature to a language spell, a price in copper, and the reputation
-- it wants to see first. Spell ids are the ones the core uses for languages
-- itself (`lang_description` in ObjectMgr.cpp); faction ids are Faction.dbc.
--
-- RequiredRank: 0 hated, 1 hostile, 2 unfriendly, 3 neutral, 4 friendly,
--               5 honored, 6 revered, 7 exalted. 0 with RequiredFaction 0
--               means no requirement at all.
--
-- The table is rebuilt from scratch here, so it is safe to re-run; edit the
-- rows below (or UPDATE the live table and run ".language reload") to change
-- prices, requirements or teachers.
-- ---------------------------------------------------------------------------

DROP TABLE IF EXISTS `language_teacher`;

CREATE TABLE `language_teacher` (
  `CreatureEntry` int unsigned NOT NULL,
  `Spell` int unsigned NOT NULL COMMENT 'language spell, e.g. 669 for Orcish',
  `Cost` int unsigned NOT NULL DEFAULT '1000000' COMMENT 'in copper; 1000000 = 100g',
  `RequiredFaction` int unsigned NOT NULL DEFAULT '0' COMMENT 'Faction.dbc id, 0 = no requirement',
  `RequiredRank` tinyint unsigned NOT NULL DEFAULT '7' COMMENT '7 = exalted',
  `Name` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT 'label shown in the gossip option; empty = derive from the spell name',
  `Comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`CreatureEntry`,`Spell`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='mod-languages: who teaches which language, for how much, and at what reputation';

INSERT INTO `language_teacher` (CreatureEntry, Spell, Cost, RequiredFaction, RequiredRank, Name, Comment) VALUES
-- Alliance city leaders, each gated on their own city's reputation
(29611,   668, 1000000,   72, 7, 'Common', 'King Varian Wrynn - Common (exalted with Stormwind)'),
( 2784,   672, 1000000,   47, 7, 'Dwarvish', 'King Magni Bronzebeard - Dwarvish (exalted with Ironforge)'),
( 7937,  7340, 1000000,   54, 7, 'Gnomish', 'High Tinker Mekkatorque - Gnomish (exalted with Gnomeregan Exiles)'),
( 7999,   671, 1000000,   69, 7, 'Darnassian', 'Tyrande Whisperwind - Darnassian (exalted with Darnassus)'),
(17468, 29932, 1000000,  930, 7, 'Draenei', 'Prophet Velen - Draenei (exalted with the Exodar)'),
-- Horde city leaders
( 4949,   669, 1000000,   76, 7, 'Orcish', 'Thrall - Orcish (exalted with Orgrimmar)'),
( 3057,   670, 1000000,   81, 7, 'Taurahe', 'Cairne Bloodhoof - Taurahe (exalted with Thunder Bluff)'),
(10181, 17737, 1000000,   68, 7, 'Gutterspeak', 'Lady Sylvanas Windrunner - Gutterspeak (exalted with Undercity)'),
(10540,  7341, 1000000,  530, 7, 'Troll', 'Vol''jin - Troll (exalted with the Darkspear Trolls)'),
(16802,   813, 1000000,  911, 7, 'Thalassian', 'Lor''themar Theron - Thalassian (exalted with Silvermoon City)'),
-- The languages that are not tied to a playable race. Each one here has both a
-- reputation faction and someone who can reasonably be called its leader.
(26917,   814, 1000000, 1091, 7, 'Draconic', 'Alexstrasza, Wyrmrest Temple - Draconic (exalted with the Wyrmrest Accord)'),
(31333,   814, 1000000, 1091, 7, 'Draconic', 'Alexstrasza, second spawn - Draconic (exalted with the Wyrmrest Accord)'),
(13278,   817, 1000000,  749, 7, 'Kalimag', 'Duke Hydraxis - Kalimag, the elemental tongue (exalted with the Hydraxian Waterlords)'),
(32540,   816, 1000000, 1119, 7, 'Titan', 'Lillehoff, Sons of Hodir quartermaster - Titan (exalted with the Sons of Hodir)'),
-- Demonic has no faction of its own that players can gain reputation with, so
-- it is taught by the warlocks who actually speak it, gated on the city that
-- tolerates them. One per side.
(  461,   815, 1000000,   72, 7, 'Demonic', 'Demisette Cloyce, the Slaughtered Lamb in Stormwind - Demonic (exalted with Stormwind)'),
( 3156,   815, 1000000,   76, 7, 'Demonic', 'Nartok, the Cleft of Shadow in Orgrimmar - Demonic (exalted with Orgrimmar)');

-- Not included, and why:
--   Cult of the Damned   - every cultist in 3.3.5 is hostile and carries no
--                          gossip flag, so no window can be opened with one,
--                          and the cult has no reputation faction. Demonic is
--                          taught by warlock trainers instead (above).
--   Furbolg, Goblin,     - these have no language spell in 3.3.5. Timbermaw
--   Ethereal, tuskarr      Hold and the Kalu'ak have reputation but there is
--                          nothing to teach.
--   Draconic alternatives- Mordenai (22113) for Netherwing, or Soridormi for
--                          the Scale of the Sands, if you would rather use
--                          those factions.

-- King Magni and Tyrande are flagged as quest givers only (npcflag 2). Without
-- the gossip flag the core shows their quest list instead of a gossip window
-- whenever they have a quest to offer, and the language option would be
-- unreachable. Add the gossip bit to them.
--   To undo: UPDATE creature_template SET npcflag = npcflag & ~1 WHERE entry IN (2784, 7999);
UPDATE creature_template SET npcflag = npcflag | 1 WHERE entry IN (2784, 7999);
