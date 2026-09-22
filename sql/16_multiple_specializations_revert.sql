-- Restores the engineering quests to the single exclusive group they shipped
-- with, so Gnomish and Goblin are once again one or the other.

UPDATE quest_template_addon a
JOIN quest_exclusive_group_backup b ON b.ID = a.ID
SET a.ExclusiveGroup = b.ExclusiveGroup;

DELETE FROM quest_exclusive_group_backup;
