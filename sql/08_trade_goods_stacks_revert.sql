-- ---------------------------------------------------------------------------
-- Put the trade goods stack limits back the way they were.
--
-- Filtered by item class so this leaves 09_consumable_reagent_stacks.sql's
-- changes in place. Needs a worldserver restart to take effect, and clients
-- need their Cache folder deleted again.
-- ---------------------------------------------------------------------------

UPDATE item_template i
JOIN item_template_stackable_backup b ON b.entry = i.entry
SET i.stackable = b.stackable
WHERE i.class = 7;
