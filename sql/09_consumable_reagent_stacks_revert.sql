-- ---------------------------------------------------------------------------
-- Put the consumable and reagent stack limits back the way they were.
--
-- Filtered the same way the forward script selects, so this leaves
-- 08_trade_goods_stacks.sql's changes in place. Needs a worldserver restart to
-- take effect, and clients need their Cache folder deleted again.
-- ---------------------------------------------------------------------------

UPDATE item_template i
JOIN item_template_stackable_backup b ON b.entry = i.entry
SET i.stackable = b.stackable
WHERE i.class IN (0, 5) OR (i.class = 15 AND i.subclass = 1);
