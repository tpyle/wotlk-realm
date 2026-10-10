-- ---------------------------------------------------------------------------
-- Let a character hold more than one profession specialisation
--
-- Companion to Professions.MultipleSpecializations in worldserver.conf, which
-- covers every specialisation chosen through a GOSSIP MENU: alchemy,
-- tailoring, leatherworking, and blacksmithing's weaponsmith sub-branches
-- (hammer, axe, sword). A config switch is enough for those.
--
-- It is not enough for a specialisation chosen by QUEST, because a quest pair
-- locks itself with an exclusive group that no config reads. Two professions
-- do it that way, and both are handled here:
--
--   engineering    Gnomish or Goblin          nine quests, one group
--   blacksmithing  Armorsmith or Weaponsmith  two quests per faction, one
--                  group each
--
-- Blacksmithing was missed the first time this file was written, which was a
-- wrong conclusion and not an oversight: the config option lists
-- blacksmithing, so blacksmithing looked covered. What it covers is the
-- gossip that offers the weaponsmith sub-branches, one step PAST the
-- armorsmith/weaponsmith choice - and that first choice is a quest.
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
--     5283 Armorsmith (Alliance)  -> group 5283 (unchanged)
--     5284 Weaponsmith (Alliance) -> group 5284
--     5301 Armorsmith (Horde)     -> group 5301 (unchanged)
--     5302 Weaponsmith (Horde)    -> group 5302
--
-- The two blacksmith groups end up with one quest each, which is the point:
-- an exclusive group of one locks nothing. The faction pairs stay separate
-- from each other exactly as they shipped, so this adds no way to take the
-- same branch twice from both capitals.
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
WHERE ID IN (3630, 3632, 3634, 3635, 3637, 5284, 5302);

-- Engineering: the Gnome half moves out of the shared group.
UPDATE quest_template_addon SET ExclusiveGroup = 3630
WHERE ID IN (3630, 3632, 3634, 3635, 3637);

-- Blacksmithing: each Weaponsmith quest moves into a group of its own, so
-- taking The Art of the Armorsmith no longer locks out The Way of the
-- Weaponsmith. Keyed on each quest's own id, the convention the data already
-- follows.
UPDATE quest_template_addon SET ExclusiveGroup = 5284 WHERE ID = 5284;
UPDATE quest_template_addon SET ExclusiveGroup = 5302 WHERE ID = 5302;
