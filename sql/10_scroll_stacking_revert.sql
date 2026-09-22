-- ---------------------------------------------------------------------------
-- Put the scroll exclusivity rules back.
--
-- Apply ".reload spell_group" then ".reload spell_group_stack_rules"
-- afterwards, and set AuraStack.Scrolls = 0 in
-- run/etc/modules/mod_aurastack.conf followed by "reload config" to restore
-- the core-side half.
--
-- Idempotent: safe to run more than once.
-- ---------------------------------------------------------------------------

-- 1. the blanket scroll-versus-scroll rule
INSERT IGNORE INTO spell_group_stack_rules (group_id, stack_rule, description)
SELECT group_id, stack_rule, description FROM spell_group_stack_rules_backup WHERE group_id = 1087;

-- 2. undo the "Strength and Agility Buffs" split
INSERT IGNORE INTO spell_group (id, spell_id) VALUES (1088, -1067);

DELETE FROM spell_group_stack_rules WHERE group_id = 1200;
DELETE FROM spell_group WHERE id = 1200;
