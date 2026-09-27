-- Undo 22_soul_shard_stacks.sql: Soul Shards unstackable again, 32 held at
-- most. Takes effect at the next worldserver restart; item templates are only
-- read at startup.
UPDATE `item_template` SET `stackable` = 1, `MaxCount` = 32 WHERE `entry` = 6265;
