-- ---------------------------------------------------------------------------
-- Put the fixed quest levels back.
--
-- Apply ".reload quest_template" afterwards.
--
-- Idempotent: safe to run more than once.
-- ---------------------------------------------------------------------------

UPDATE quest_template q
JOIN quest_template_questlevel_backup b ON b.ID = q.ID
SET q.QuestLevel = b.QuestLevel;
