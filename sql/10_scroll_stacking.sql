-- ---------------------------------------------------------------------------
-- Stat scrolls stop cancelling each other
--
-- Scroll buffs refuse to coexist for two independent reasons, and both have to
-- go, because Aura::CanStackWith checks them in that order and returns early:
--
--   1. The core tags the six scroll buffs SPELL_SPECIFIC_SCROLL
--      (SpellInfo::LoadSpellSpecific, matched on the first rank: 8118
--      Strength, 8115 Agility, 8099 Stamina, 8096 Intellect, 8112 Spirit,
--      8091 Armor), and SpellInfo::IsAuraExclusiveBySpecificWith makes any two
--      spells sharing that tag mutually exclusive. That half is handled by
--      mod-aurastack (AuraStack.Scrolls).
--
--   2. This table, in two places.
--
-- Each scroll buff sits in its own single-member container group (1066
-- Strength, 1067 Agility, 1068 Intellect, 1069 Stamina, 1070 Spirit, 1071
-- Armor), and those containers are referenced by several parent groups.
-- SpellMgr::CheckSpellGroupStackRules applies a parent's rule to two spells
-- when they share that parent but sit in *different* containers under it - so
-- what matters is which parents hold more than one scroll.
--
--   group  rule  scroll containers  effect
--   1083   4     1 (Intellect)      scroll vs Arcane Intellect
--   1084   4     1 (Stamina)        scroll vs Power Word: Fortitude
--   1085   4     1 (Spirit)         scroll vs Divine Spirit
--   1086   4     1 (Armor)          scroll vs armor buffs
--   1087   1     6 (all of them)    every scroll against every other  <-- fixed
--   1088   4     2 (Str + Agi)      also scroll against scroll        <-- fixed
--
-- Rule 1 is SPELL_GROUP_STACK_RULE_EXCLUSIVE, rule 4 is
-- SPELL_GROUP_STACK_RULE_EXCLUSIVE_HIGHEST (the stronger buff wins instead of
-- the two adding up).
--
-- 1083-1086 hold a single scroll each, so they can only ever govern scroll
-- versus class buff. They are deliberately left alone: a Scroll of Intellect
-- should not pile on top of Arcane Intellect.
--
-- 1087 "Scrolls" is the blanket scroll-versus-scroll rule. Its stack rule is
-- removed, which leaves the group with no rule at all - the same state its
-- container groups 1066-1071 are already in - so it falls back to
-- SPELL_GROUP_STACK_RULE_DEFAULT and stops blocking.
--
-- 1088 "Strength and Agility Buffs" is the subtle one. It holds four
-- containers: 1064 (8076 Strength of Earth), 1065 (57330 Horn of Winter),
-- 1066 (Scroll of Strength) and 1067 (Scroll of Agility). Because the two
-- scrolls are in different containers under the same parent, rule 4 applies
-- between them and Strength and Agility scrolls would go on cancelling each
-- other even after 1087 is gone.
--
-- Dropping 1088's rule would be wrong - it is what stops a scroll stacking
-- with Horn of Winter or Strength of Earth, which genuinely should not stack.
-- So the group is split instead: Scroll of Agility moves to a new group 1200
-- that still holds Strength of Earth and Horn of Winter. Afterwards:
--
--   Scroll of Strength vs Scroll of Agility   only share 1087 (no rule) -> stack
--   Scroll of Strength vs Horn of Winter      share 1088 -> highest wins (unchanged)
--   Scroll of Agility  vs Horn of Winter      share 1200 -> highest wins (unchanged)
--   Horn of Winter     vs Strength of Earth   share 1088 and 1200 -> unchanged
--
-- Group membership is matched on the first rank
-- (CheckSpellGroupStackRules uses GetFirstRankSpell), so all eight ranks of
-- every scroll are covered automatically.
--
-- No restart needed: ".reload spell_group" then
-- ".reload spell_group_stack_rules" on the console picks this up live. The
-- core-side half needs the worldserver running the mod-aurastack build.
--
-- Reverted by 10_scroll_stacking_revert.sql.
--
-- Idempotent: safe to run more than once.
-- ---------------------------------------------------------------------------

-- 1. the blanket scroll-versus-scroll rule
CREATE TABLE IF NOT EXISTS `spell_group_stack_rules_backup` (
  `group_id` int unsigned NOT NULL,
  `stack_rule` tinyint NOT NULL,
  `description` varchar(150) NOT NULL DEFAULT '',
  PRIMARY KEY (`group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='original spell_group_stack_rules rows (10_scroll_stacking.sql)';

INSERT IGNORE INTO spell_group_stack_rules_backup (group_id, stack_rule, description)
SELECT group_id, stack_rule, description FROM spell_group_stack_rules WHERE group_id = 1087;

DELETE FROM spell_group_stack_rules WHERE group_id = 1087;

-- 2. split "Strength and Agility Buffs" so the two scrolls no longer share a
--    parent group, while each still shares one with the class buffs
INSERT IGNORE INTO spell_group (id, spell_id) VALUES
  (1200, -1064),   -- 8076  Strength of Earth
  (1200, -1065),   -- 57330 Horn of Winter
  (1200, -1067);   -- 8115  Agility (Scroll of Agility)

INSERT IGNORE INTO spell_group_stack_rules (group_id, stack_rule, description) VALUES
  (1200, 4, 'Agility Buffs (split from 1088 so stat scrolls do not block each other)');

DELETE FROM spell_group WHERE id = 1088 AND spell_id = -1067;
