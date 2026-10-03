-- ---------------------------------------------------------------------------
-- Daily rewards for the realm's two extra Dungeon Finder random options
--
-- LFGDungeons.dbc gains two rows from tools/gen_lfg_dbc.py - 300 "Random
-- Dungeon", every normal dungeon at once, and 301 "Random Heroic", every
-- heroic - and they point at the two synthetic groups the core fills by kind
-- (LFG_GROUP_ALL_DUNGEONS and LFG_GROUP_ALL_HEROICS in LFGMgr.h).
--
-- Without rows here they would still queue, but grant nothing:
-- LFGMgr::GetRandomDungeonReward looks the reward up by dungeon id and the
-- first row whose maxLevel reaches the player, so an unlisted random dungeon
-- finishes with no daily at all. That would make the new options strictly
-- worse than the stock ones at the same level, which nobody would expect.
--
-- The quest ids are the stock ones, not new quests. Finishing "Random Dungeon"
-- at 80 awards the same daily that "Random Lich King Dungeon" awards, and at
-- 30 the same one "Random Classic Dungeon" awards, which also means the two
-- cannot be farmed against each other - it is one daily either way.
--
-- Idempotent: the rows are deleted and reinserted.
-- ---------------------------------------------------------------------------

DELETE FROM `lfg_dungeon_rewards` WHERE `dungeonId` IN (300, 301);

-- 300 Random Dungeon: the classic bands as dungeon 258 has them, then the
-- Burning Crusade bands from 259, then the Lich King one from 261.
INSERT INTO `lfg_dungeon_rewards` (`dungeonId`, `maxLevel`, `firstQuestId`, `otherQuestId`) VALUES
(300, 15, 24881, 24889),
(300, 25, 24882, 24890),
(300, 34, 24883, 24891),
(300, 45, 24884, 24892),
(300, 55, 24885, 24893),
(300, 60, 24886, 24894),
(300, 64, 24887, 24895),
(300, 70, 24888, 24896),
(300, 80, 24790, 24791);

-- 301 Random Heroic: the Burning Crusade heroic daily from 260 up to 70, then
-- the Lich King heroic daily from 262.
INSERT INTO `lfg_dungeon_rewards` (`dungeonId`, `maxLevel`, `firstQuestId`, `otherQuestId`) VALUES
(301, 70, 24922, 24923),
(301, 80, 24788, 24789);
