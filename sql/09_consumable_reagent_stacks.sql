-- ---------------------------------------------------------------------------
-- Consumables and reagents stack to 200
--
-- The companion to 08_trade_goods_stacks.sql, same mechanism and same
-- reasoning: stack size is server side only, the client is told it at runtime
-- in SMSG_ITEM_QUERY_SINGLE_RESPONSE, and no client patch is involved. See the
-- header of 08_trade_goods_stacks.sql for the details.
--
-- What "reagent" means here is worth spelling out, because the obvious answer
-- is the wrong one. Item class 5 is named Reagent but 3.3.5 barely uses it -
-- four items, only one of them stackable. The reagents players actually carry
-- are class 15 (Miscellaneous) subclass 1: Arcane Powder, Symbol of Kings,
-- Symbol of Divinity, Rune of Teleportation, Rune of Portals, Sacred and
-- Devout Candle, Flash Powder, Frost Vial, the druid seeds. So both are
-- covered, and the rest of class 15 - junk, pets, holiday items, mounts - is
-- deliberately left alone.
--
--   class 0                Consumable - potions, elixirs, flasks, food and
--                          drink, bandages, scrolls, conjured food and water.
--                          1547 items: 1038 stacked to 20, 359 to 5, 109 to
--                          10, and a scattering at 2, 3, 4, 6, 24, 30, 40, 50
--                          and 100.
--   class 5                Reagent - 1 item, the only stackable one of the
--                          four.
--   class 15 subclass 1    Reagent (Miscellaneous) - 37 items: 23 at 20, 9 at
--                          10, 3 at 5 and 2 at 100.
--
-- The bounds are the same as for trade goods:
--   stackable > 1    leaves the genuinely non-stackable items alone (843
--                    consumables, 3 reagents, 10 miscellaneous reagents)
--   stackable < 200  only raises, never lowers what already ships at 200 or
--                    250
--
-- Original values go into the same item_template_stackable_backup table that
-- 08 uses; INSERT IGNORE keeps 08's rows intact. The revert scripts filter by
-- item class, so 08 and 09 can be reverted independently.
--
-- Needs a worldserver restart (this core has no ".reload item_template"), and
-- every client needs its Cache folder deleted, or the cached
-- Cache/WDB/<locale>/itemcache.wdb will go on reporting the old limit.
--
-- Idempotent: safe to run more than once.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `item_template_stackable_backup` (
  `entry` int unsigned NOT NULL,
  `stackable` int NOT NULL,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='original item_template.stackable values (08/09 stack size scripts)';

INSERT IGNORE INTO item_template_stackable_backup (entry, stackable)
SELECT entry, stackable FROM item_template
WHERE (class IN (0, 5) OR (class = 15 AND subclass = 1))
  AND stackable > 1 AND stackable < 200;

UPDATE item_template SET stackable = 200
WHERE (class IN (0, 5) OR (class = 15 AND subclass = 1))
  AND stackable > 1 AND stackable < 200;
