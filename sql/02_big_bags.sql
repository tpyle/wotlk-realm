-- ---------------------------------------------------------------------------
-- Extra large bags for every new character
--
-- Every race/class combination gets four large bags at creation, which
-- Player::StoreNewItemInBestSlots equips into the four bag slots one by one.
-- Characters that already exist (including bots created earlier) are handled
-- by mod-bigbags on login.
--
-- Idempotent: safe to run more than once.
-- ---------------------------------------------------------------------------

SET @BAG_ENTRY := 23162;   -- 36 slot general purpose container (the largest in 3.3.5a)
SET @BAG_COUNT := 4;       -- one per bag slot

DELETE FROM playercreateinfo_item WHERE itemid = @BAG_ENTRY;

INSERT INTO playercreateinfo_item (race, class, itemid, amount, Note)
SELECT pci.race, pci.class, @BAG_ENTRY, @BAG_COUNT, 'large starting bags'
FROM playercreateinfo pci
WHERE EXISTS (SELECT 1 FROM item_template WHERE entry = @BAG_ENTRY AND class = 1);
