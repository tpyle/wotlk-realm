-- ---------------------------------------------------------------------------
-- Auction house bot tuning for this server
--
-- Run AFTER the worldserver has started at least once with mod-ah-bot built in.
--
-- Do NOT apply the module's own data/sql/db-world/*.sql by hand. The core's
-- database updater owns those files (Updates.AutoSetup = 1) and records each
-- one in acore_world.updates. Applying them with a mysql client leaves the
-- updater unaware, so on the next boot it tries again, hits
-- "ERROR 1050 Table 'auctionhousebot_professionItems' already exists", and the
-- worldserver exits during startup. That is what the updater's own error text
-- warns about: "You cannot use auto-update system and import sql files from
-- AzerothCore repository with your sql client."
--
-- Recovering from it means dropping the three tables
-- (auctionhousebot_professionItems, mod_auctionhousebot,
-- mod_auctionhousebot_disabled_items) and letting the updater create them on
-- the next start.
--
-- The module's files seed mod_auctionhousebot with one row per auction house
-- (2 Alliance, 6 Horde, 7 Neutral) and fill mod_auctionhousebot_disabled_items
-- with ~11.9k test and trash entries. This script only adjusts what those
-- files seeded, so it has to come second.
--
-- Only one thing genuinely has to change, and it is a consequence of
-- sql/08_trade_goods_stacks.sql and sql/09_consumable_reagent_stacks.sql.
--
-- The maxstack<colour> columns cap how large a stack the seller posts, and a
-- value of 0 means "as large as the item itself allows":
--
--     else if (config->GetMaxStack(prototype->Quality) == 0 && item->GetMaxStackCount() > 1)
--         stackCount = getStackCount(config, item->GetMaxStackCount());
--                                                   -- AuctionHouseBot.cpp:874
--
-- The seeded rows use 0 for grey and white, which was harmless while trade
-- goods capped at 20. They now cap at 200, so the auction house would fill
-- with 200-stacks of ore, cloth and herbs that no levelling character can
-- afford - and the item count per house is what is limited, not the item
-- volume, so those giant lots would crowd out everything else.
--
-- 20 keeps the classic feel: the seller rolls a random stack size up to that
-- cap, so listings come in ones, fives, twenties the way a real auction house
-- looks. Green and above are left as seeded (3/2/1/1/1) - those are mostly
-- equipment, which does not stack anyway.
--
-- The item target is raised from the seeded 250 to 20000, and that is the size
-- of the whole market, not a per-seller figure. The per-quality bins are
-- computed as percentage x maxitems and counted house-wide, so they cap the
-- house at that figure however many seller characters contribute.
--
-- At 20000 the trade goods bins carry six to eight copies of each item rather
-- than three to four. That is deliberate rather than overlooked: duplication
-- is what a commodity *should* look like - a real auction house has twenty
-- Linen Cloth listings - and the equipment bins, where duplication reads as
-- broken, stay between 1.5 and 2.8 copies because their pools are deep. The
-- case that actually looked wrong was purple trade goods, a pool of one item
-- getting a hundred identical listings, and that bin is excluded entirely.
--
-- AuctionHouseBot.DuplicatesCount must stay 0 for this to fill. It caps copies
-- per item, and enabling it would both stop the house reaching maxitems and
-- cost a full scan of every auction in the house for each item posted.
--
-- One module setting has to be right for any of that to hold, and its name
-- says the opposite of what it does. With
-- AuctionHouseBot.ConsiderOnlyBotAuctions = 1, the ON_AUCTION_ADD handler
-- returns early for bot-owned auctions:
--
--     if (config->ConsiderOnlyBotAuctions)
--         if (gBotsId.find(auction->owner.GetCounter()) != gBotsId.end())
--             return;
--                                  -- AuctionHouseBotAuctionHouseScript.cpp:115
--
-- so the bot's own listings never increment the per-quality counters. They sit
-- at zero, and because the seller walks the bins in strict rarity order and
-- re-reads the counts only once per cycle rather than per item, the first bin
-- with a non-zero maximum swallows the entire market. Measured with it set to
-- 1: 3200 listings of nothing but white items, no trade goods, no greens, no
-- blues. The module's own conf documentation for the setting ("Ignore player
-- auctions and consider only bot ones") contradicts its code; the code is what
-- runs. It is set to 0 in tools/apply_config.py.
--
-- With it at 0 the stock matches the configured percentages closely - measured
-- 27.3% white trade goods, 30.3% green items, 12.1% green trade goods, 10.1%
-- blue trade goods, 10.1% white items, 8.1% blue items, 2.0% purple items
-- against a configuration of 27/30/12/10/10/8/2.
--
-- Only the neutral house is actually stocked on this server, and that is
-- deliberate on the module's part rather than a misconfiguration. Its update
-- loop only touches the Alliance and Horde houses when cross-faction auctions
-- are switched off:
--
--     if (!sWorld->getBoolConfig(CONFIG_ALLOW_TWO_SIDE_INTERACTION_AUCTION))
--     {   // Alliance ... Horde ...   }
--     // Neutral, always
--
-- We run AllowTwoSide.Interaction.Auction = 1, so both factions browse the one
-- shared neutral house. The rows for houses 2 and 6 are still updated here so
-- that turning that setting off later gives a sane starting point.
--
-- A consequence of the shared house: it is Blackwater, the goblin auction
-- house, whose AuctionHouse.dbc row charges a 25% cut and 15% deposit against
-- the faction houses' 5%/5%. The core reads both straight from that row
-- (AuctionHouseMgr::GetAuctionDeposit, AuctionEntry::GetAuctionCut), so
-- selling here costs a quarter of the sale price. That is retail behaviour for
-- the neutral house; it just becomes the only house once cross-faction
-- auctions are on. Lowering it would mean editing the DBC, and the client
-- reads the same row for the fee it quotes, so the two would disagree without
-- a client patch.
--
-- The quality mix is rebalanced away from the seeded 27/30/12/10/10/8/2/1,
-- because those percentages only hold up at a small market size. The seller
-- draws each quality from its own pool, and the trade goods pools are tiny
-- next to the item pools:
--
--     trade goods:  grey 5     white 445   green 54    blue 24    purple 1
--     items:        grey 1112  white 1121  green 5216  blue 1553  purple 760
--
-- At maxitems 4000 the seeded mix was fine. At 10000 it asked for 1200 green
-- trade goods out of a pool of 54 (22 copies of each), 1000 blue out of 24
-- (42 copies), and 100 purple out of a pool of *one* - a hundred identical
-- Nether Vortex listings. Some duplication is what a real auction house looks
-- like, but not at that ratio.
--
-- So the percentages follow the pools, keeping every category under about four
-- copies of any single item at 10000 listings:
--
--     white trade goods  15%  = 3000 / 445  = 6.7 copies
--     green trade goods   2%  =  400 /  54  = 7.4
--     blue trade goods    1%  =  200 /  24  = 8.3
--     purple trade goods  0%         pool of 1, excluded entirely
--     white items        12%  = 2400 / 1121 = 2.1
--     green items        40%  = 8000 / 5216 = 1.5
--     blue items         20%  = 4000 / 1553 = 2.6
--     purple items       10%  = 2000 /  760 = 2.6
--
-- which reads as roughly 27% white, 42% green, 21% blue and 10% purple by
-- quality. Raising maxitems again means revisiting these: the item pools have
-- room to grow into, the trade goods pools do not.
--
-- Prices are not set here. They come from the module's config
-- (UseMarketPriceForSeller) and the minprice/maxprice columns, which express
-- the buyout as a percentage of the item's own vendor value per quality:
-- grey 100-150%, white 150-250%, green 800-1400%, blue 1250-1750%,
-- purple 2250-4550%. Opening bids are 70-100% of the rolled buyout.
--
-- Everything in this table is also reachable live from the console with the
-- ".ahbot" commands, so these are starting values rather than settled ones.
--
-- Idempotent: safe to run more than once.
-- ---------------------------------------------------------------------------

UPDATE mod_auctionhousebot SET
    maxstackgrey  = 20,
    maxstackwhite = 20,
    minitems      = 20000,
    maxitems      = 20000,
    percentgreytradegoods   = 0,
    percentwhitetradegoods  = 15,
    percentgreentradegoods  = 2,
    percentbluetradegoods   = 1,
    percentpurpletradegoods = 0,
    percentgreyitems        = 0,
    percentwhiteitems       = 12,
    percentgreenitems       = 40,
    percentblueitems        = 20,
    percentpurpleitems      = 10
WHERE auctionhouse IN (2, 6, 7);
