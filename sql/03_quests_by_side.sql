-- ---------------------------------------------------------------------------
-- Quest race requirements, judged by the side a character plays for
--
-- Quest availability is checked against the character's *race*
-- (Player::SatisfyQuestRace compares quest_template.AllowableRaces with the
-- race mask), while mod-factionchoice changes which *side* a character plays
-- for. This file used to be 03_quests_any_race.sql, which set every
-- AllowableRaces to 0 so a Human playing Horde could quest at all - and so
-- anyone could take the other side's quests by accident.
--
-- mod-factionchoice now answers the core's OnPlayerSatisfyQuestRace hook and
-- tests the mask against the side played instead (see QuestSide.h in the
-- module), so the stock masks are wanted back. This puts them back from
-- quest_template_allowableraces_backup, the copy 03_quests_any_race.sql took.
-- On a database that never had the old file run the table is created empty
-- and nothing is restored, because nothing was removed.
--
-- Then mod-worgoblin's own mask update is applied again: its SQL gives Goblins
-- every quest open to Orcs and Worgen every quest open to Humans, but it ran
-- here after the masks were already 0 and changed nothing. A native Goblin is
-- tested by race, so without these bits it would be offered no Horde quests.
-- Harmless where the two races are not playable: the bits are then ignored.
--
-- Apply ".reload quest_template" afterwards, or restart.
--
-- Idempotent: safe to run more than once.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `quest_template_allowableraces_backup` (
  `ID` int unsigned NOT NULL,
  `AllowableRaces` int unsigned NOT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='original quest_template.AllowableRaces values (03_quests_any_race.sql)';

UPDATE quest_template q
JOIN quest_template_allowableraces_backup b ON b.ID = q.ID
SET q.AllowableRaces = b.AllowableRaces
WHERE q.AllowableRaces = 0;

-- As mod-worgoblin's data/sql/db-world/worgoblin.sql: Goblins with Orcs,
-- Worgen with Humans, except the Human and Orc versions of the death knight
-- quest "A Special Surprise", which the module keeps to their own race.
UPDATE quest_template SET AllowableRaces = AllowableRaces | 256
WHERE AllowableRaces & 2 AND NOT AllowableRaces & 256 AND ID <> 12748;

UPDATE quest_template SET AllowableRaces = AllowableRaces | 2048
WHERE AllowableRaces & 1 AND NOT AllowableRaces & 2048 AND ID <> 12742;
