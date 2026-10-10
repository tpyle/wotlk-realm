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
--
-- Demonic and Kalimag need sql/29_language_spells.sql applied, and the client
-- running the patch it ships with. See the note below.
(26917,   814, 1000000, 1091, 7, 'Draconic', 'Alexstrasza, Wyrmrest Temple - Draconic (exalted with the Wyrmrest Accord)'),
(31333,   814, 1000000, 1091, 7, 'Draconic', 'Alexstrasza, second spawn - Draconic (exalted with the Wyrmrest Accord)'),
(13278,   817, 1000000,  749, 7, 'Kalimag', 'Duke Hydraxis - Kalimag, the elemental tongue (exalted with the Hydraxian Waterlords)'),
(32540,   816, 1000000, 1119, 7, 'Titan', 'Lillehoff, Sons of Hodir quartermaster - Titan (exalted with the Sons of Hodir)'),
-- Demonic has no faction of its own that players can gain reputation with, so
-- it is taught by the warlocks who actually speak it, gated on the city that
-- tolerates them. One per side.
(  461,   815, 1000000,   72, 7, 'Demonic', 'Demisette Cloyce, the Slaughtered Lamb in Stormwind - Demonic (exalted with Stormwind)'),
( 3156,   815, 1000000,   76, 7, 'Demonic', 'Nartok, the Cleft of Shadow in Orgrimmar - Demonic (exalted with Orgrimmar)');

-- DEMONIC AND KALIMAG ONCE COULD NOT BE TAUGHT. Selling one cost a player 100g
-- and EMPTIED their chat language menu, and the reason is worth keeping: a
-- language spell teaches whatever its EffectMiscValue says, and stock data has
-- two that lie.
--
--     spell 815  'Language Demon Tongue'      -> misc  7  = COMMON
--     spell 817  'Language Old Tongue (NYI)'  -> misc  7  = COMMON
--
-- 817 says so in its own name. Of the 14 spells in Spell.dbc carrying
-- SPELL_EFFECT_LANGUAGE (39), those were the only two whose effect disagreed
-- with their name - and the client builds a character's language menu from the
-- languages its known spells grant, so a Human who bought 'Demonic' ended up
-- knowing Common from two different spells, which the stock game cannot
-- produce. The menu went blank rather than wrong.
--
-- Both are back on sale because that one field is now corrected in both places
-- it is read: sql/29_language_spells.sql overrides the server's copy through
-- `spell_dbc`, and tools/gen_spell_dbc.py ships the same correction to the
-- client in patch-W. Everything else about those languages was already
-- complete and untouched - Languages.dbc names them, LanguageWords.dbc holds
-- 126 Demonic and 122 Kalimag words, SkillLineAbility.dbc grants skills 139
-- and 141, and the core's lang_description agreed all along.
--
-- A CLIENT WITHOUT PATCH-W STILL HAS THE OLD BUG. Garbling is done client
-- side, so an unpatched client listening to Demonic is fine; one that LEARNS
-- it gets the empty menu again.
--
-- SO: VERIFY A TEACHER'S SPELL BY ITS EFFECT, NOT BY ITS NAME. The check, on
-- the client's own copy of the data the client reads:
--
--     Effect_1 == 39 (SPELL_EFFECT_LANGUAGE), and EffectMiscValue_1 is the
--     Languages.dbc id it actually grants.
--
-- mod-languages now enforces exactly that at startup, dropping any row whose
-- spell cannot do what its gossip option claims, and logging the language each
-- surviving teacher genuinely teaches.
--
-- Not included, and why:
--   Cult of the Damned   - every cultist in 3.3.5 is hostile and carries no
--                          gossip flag, so no window can be opened with one,
--                          and the cult has no reputation faction. Demonic is
--                          taught by warlock trainers instead (above).
--   Furbolg, Goblin,     - these have no language spell in 3.3.5. Timbermaw
--   Ethereal, tuskarr      Hold and the Kalu'ak have reputation but there is
--                          nothing to teach.
--   Zombie, Gnomish      - named in Languages.dbc and given words in
--   Binary, Goblin Binary  LanguageWords.dbc, but no spell anywhere grants
--                          them, so unlike Demonic there is nothing to
--                          correct - one would have to be invented.
--   Draconic alternatives- Mordenai (22113) for Netherwing, or Soridormi for
--                          the Scale of the Sands, if you would rather use
--                          those factions.

-- King Magni and Tyrande are flagged as quest givers only (npcflag 2). Without
-- the gossip flag the core shows their quest list instead of a gossip window
-- whenever they have a quest to offer, and the language option would be
-- unreachable. Add the gossip bit to them.
--   To undo: UPDATE creature_template SET npcflag = npcflag & ~1 WHERE entry IN (2784, 7999);
UPDATE creature_template SET npcflag = npcflag | 1 WHERE entry IN (2784, 7999);
