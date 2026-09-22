-- ---------------------------------------------------------------------------
-- Engineering: let a character hold both Gnomish and Goblin specialisations
--
-- Companion to Professions.MultipleSpecializations in worldserver.conf, which
-- covers alchemy, blacksmithing, tailoring and leatherworking. Those four are
-- gated purely by the gossip in npc_professions.cpp, so a config switch is
-- enough. Engineering is not: it is chosen by *quest*, and the nine quests
-- share one exclusive group.
--
--     ExclusiveGroup > 0 means taking one quest in the group locks out every
--     other quest in it (Player::SatisfyQuestExclusiveGroup: "alternative
--     quest already started or completed").
--
-- Rather than clearing the group - which would also let a character take the
-- several race and faction variants of the *same* branch, all granting the
-- same spell - the group is split in two. Gnome quests move to their own
-- group, keyed on their lowest quest id, which is the convention the data
-- already follows (the Goblin group is keyed 3526, its own lowest id).
--
-- The result: still one Gnome quest and one Goblin quest per character, but no
-- longer one *or* the other.
--
--     3526, 3629, 3633, 4181   Goblin Engineering   -> group 3526 (unchanged)
--     3630, 3632, 3634, 3635, 3637  Gnome Engineering -> group 3630
--
-- Nothing else needs changing: the specialisation is an ordinary spell and the
-- recipes behind it are gated by trainer_spell.ReqAbility1 naming that spell
-- (16 Gnomish, 17 Goblin), so both sets become available once both are held.
--
-- Original values are kept in quest_exclusive_group_backup, so
-- 16_multiple_specializations_revert.sql can put them back.
--
-- Idempotent: safe to run more than once.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `quest_exclusive_group_backup` (
  `ID`             int unsigned NOT NULL,
  `ExclusiveGroup` int NOT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='original quest_template_addon.ExclusiveGroup (16_multiple_specializations.sql)';

INSERT IGNORE INTO quest_exclusive_group_backup (ID, ExclusiveGroup)
SELECT ID, ExclusiveGroup FROM quest_template_addon
WHERE ID IN (3630, 3632, 3634, 3635, 3637);

UPDATE quest_template_addon SET ExclusiveGroup = 3630
WHERE ID IN (3630, 3632, 3634, 3635, 3637);
