-- ---------------------------------------------------------------------------
-- Put the quest race requirements back the way they were.
-- ---------------------------------------------------------------------------

UPDATE quest_template q
JOIN quest_template_allowableraces_backup b ON b.ID = q.ID
SET q.AllowableRaces = b.AllowableRaces;
