-- ---------------------------------------------------------------------------
-- Remove the race gate from quests
--
-- Quest availability is checked against the character's *race*
-- (Player::SatisfyQuestRace compares quest_template.AllowableRaces with the
-- race mask), while mod-factionchoice changes which *faction* a character
-- fights for. Without this, a Human who chose Horde could not pick up Horde
-- quests (wrong race) and could not reach Alliance quest givers either (they
-- are hostile now), which leaves almost no quest content.
--
-- AllowableRaces = 0 means "no race requirement". The original values are kept
-- in quest_template_allowableraces_backup, so 03_quests_any_race_revert.sql can
-- put them back.
--
-- Idempotent: safe to run more than once.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `quest_template_allowableraces_backup` (
  `ID` int unsigned NOT NULL,
  `AllowableRaces` int unsigned NOT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='original quest_template.AllowableRaces values (03_quests_any_race.sql)';

INSERT IGNORE INTO quest_template_allowableraces_backup (ID, AllowableRaces)
SELECT ID, AllowableRaces FROM quest_template WHERE AllowableRaces <> 0;

UPDATE quest_template SET AllowableRaces = 0 WHERE AllowableRaces <> 0;
