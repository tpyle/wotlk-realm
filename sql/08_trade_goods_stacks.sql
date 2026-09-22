-- ---------------------------------------------------------------------------
-- Trade goods stack to 999 (first 200, the retail figure; raised later)
--
-- Stack size is server side only. Item.dbc on the client carries just eight
-- fields (ID, class, subclass, sound override, material, display info,
-- inventory type, sheath) and none of them is the stack limit; the client is
-- told it at runtime in SMSG_ITEM_QUERY_SINGLE_RESPONSE, straight out of
-- item_template (WorldSession::HandleItemQuerySingleOpcode sends
-- int32(pProto->Stackable)). So this needs no client patch.
--
-- The 3.3.5 client already handles values this large: the stock data ships 87
-- items at 200, 144 at 250, 51 at 1000 and 21 at 2147483647. The core does not
-- clamp either - ObjectMgr only rejects 0 and anything below -1, and
-- ItemTemplate::GetMaxStackSize() passes the value through.
--
-- Trade goods are item class 7. The bound is deliberate:
--   stackable > 1    leaves the 168 genuinely non-stackable trade goods alone
--   stackable < 999  only ever raises a limit, never lowers anything that
--                    already ships higher (51 items at 1000, 21 unlimited)
-- That covers 758 items: 593 that stacked to 20, 124 to 10, 39 to 5, and two
-- odd ones at 100 and 50.
--
-- The original values are kept in item_template_stackable_backup, so
-- 08_trade_goods_stacks_revert.sql can put them back.
--
-- There is no ".reload item_template" command in this core (only
-- item_template_locale), so the worldserver has to be restarted for this to
-- take effect. Players also cache item data in Cache/WDB/<locale>/itemcache.wdb
-- and reuse it without re-querying, so each client needs its Cache folder
-- deleted or it will go on showing the old limit.
--
-- Idempotent: safe to run more than once.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `item_template_stackable_backup` (
  `entry` int unsigned NOT NULL,
  `stackable` int NOT NULL,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='original item_template.stackable values (08_trade_goods_stacks.sql)';

INSERT IGNORE INTO item_template_stackable_backup (entry, stackable)
SELECT entry, stackable FROM item_template
WHERE class = 7 AND stackable > 1 AND stackable < 999;

-- 200 was the first target; 999 came later, once every layer that could cap
-- it had been checked: the loader corrects only 0 and below -1,
-- item_instance.count is int unsigned, ITEM_FIELD_STACK_COUNT is 32-bit, and
-- the client draws counts up to 9999 in bags and takes four digits in the
-- auction stack box. 999 keeps every count at three digits. The backup table
-- still holds the original values, so the revert is unchanged. The auction
-- bot's lots are capped at 200 separately (TradeGoodsFullStack.Max).
UPDATE item_template SET stackable = 999
WHERE class = 7 AND stackable > 1 AND stackable < 999;
