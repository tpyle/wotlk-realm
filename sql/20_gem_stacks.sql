-- ---------------------------------------------------------------------------
-- Gems stack to 999, like trade goods
--
-- 08_trade_goods_stacks.sql raised item class 7 to 999 and left gems (class 3)
-- on their retail 20, which is an odd seam once prospecting and jewelcrafting
-- are producing raw gems in quantity: the mats that go *into* a gem stack a
-- thousand deep while the gem itself stops at twenty.
--
-- Only 67 of the 677 gems are stackable at all; the other 610 ship at 1 and
-- are left alone by the `stackable > 1` bound - those are the cut and unique
-- ones, where a stack would be wrong. The `stackable < 999` bound means this
-- only ever raises a limit.
--
-- Everything that made this safe for trade goods holds here too: stack size is
-- server side only (the client is told it at runtime in
-- SMSG_ITEM_QUERY_SINGLE_RESPONSE), the loader rejects only 0 and below -1,
-- item_instance.count is int unsigned and ITEM_FIELD_STACK_COUNT is 32-bit.
--
-- The original values go into the same item_template_stackable_backup table
-- 08 uses, so 20_gem_stacks_revert.sql restores them from there.
--
-- There is no ".reload item_template", so the worldserver has to be restarted
-- for this to take effect. Clients normally also need Cache/WDB cleared,
-- because item data is cached client side and reused without re-querying -
-- though a client patched with "Disable Cache" (as this realm's is) re-queries
-- anyway and needs nothing.
--
-- Idempotent: safe to run more than once.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `item_template_stackable_backup` (
  `entry` int unsigned NOT NULL,
  `stackable` int NOT NULL,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='original item_template.stackable values (08_trade_goods_stacks.sql, 20_gem_stacks.sql)';

INSERT IGNORE INTO item_template_stackable_backup (entry, stackable)
SELECT entry, stackable FROM item_template
WHERE class = 3 AND stackable > 1 AND stackable < 999;

UPDATE item_template SET stackable = 999
WHERE class = 3 AND stackable > 1 AND stackable < 999;
