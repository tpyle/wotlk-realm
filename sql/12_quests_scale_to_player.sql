-- ---------------------------------------------------------------------------
-- Quests scale to the player's level
--
-- mod-worldscale already makes low level *creatures* a fair fight and pays out
-- kill experience for the level they were scaled to. Quests were the hole: a
-- level 60 handing in a level 10 quest got a rounding error for it, and the
-- quest log still showed it as a level 10 quest.
--
-- QuestLevel = -1 is the core's own sentinel for "this quest is the player's
-- level", not a custom hack. 1324 of the 9464 quests already ship that way,
-- and the core comments the field as
-- "may be -1, static data, in other cases must be used dynamic level"
-- where it is written to the client (QuestDef.cpp:334, GossipDef.cpp:536).
--
-- Quest::XPValue reads it twice over, which is why this fixes both halves at
-- once:
--
--     int32 quest_level = (Level == -1 ? playerLevel : Level);
--     QuestXPEntry const* xpentry = sQuestXPStore.LookupEntry(quest_level);
--     int32 diffFactor = clamp(2 * (quest_level - playerLevel) + 20, 1, 10);
--     uint32 xp = diffFactor * xpentry->Exp[RewardXPDifficulty] / 10;
--
-- For a level 60 player on a level 10 quest, the current data gives
-- diffFactor 1 and looks Exp[] up at level 10 - the smallest multiplier
-- against the smallest table row. With -1 both become the player's level:
-- diffFactor 10, and Exp[] read at level 60. Quests at or above the player's
-- level are unaffected, because diffFactor already clamps to 10 for anything
-- within five levels above or below.
--
-- RewardXPDifficulty is untouched, so a long quest still pays more than a
-- short one - only the level the reward is measured against changes.
--
-- Because the client is sent -1 rather than a fixed number, it renders the
-- quest at the player's own level: low level quests stop presenting as grey
-- in the log and on the map.
--
-- Scope: the 8071 quests with QuestLevel > 0. The 1324 already at -1 need
-- nothing, and the 69 sitting at 0 are left alone - 0 is not a level and the
-- core treats it separately from the -1 sentinel.
--
-- NOT covered, for honesty:
--   * Quest *money* rewards are a fixed RewardMoney column with no scaling
--     path, so a low level quest still hands over its original few copper.
--     (At max level GetRewMoneyMaxLevel() replaces the XP instead.)
--   * Quest *item* rewards are specific items and cannot scale.
--   * MinLevel is untouched, so which quests a character may accept is
--     exactly as before.
--
-- No restart needed: ".reload quest_template" on the console picks this up.
--
-- Original values are kept in quest_template_questlevel_backup, so
-- 12_quests_scale_to_player_revert.sql can put them back.
--
-- Idempotent: safe to run more than once.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `quest_template_questlevel_backup` (
  `ID` int unsigned NOT NULL,
  `QuestLevel` smallint NOT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='original quest_template.QuestLevel values (12_quests_scale_to_player.sql)';

INSERT IGNORE INTO quest_template_questlevel_backup (ID, QuestLevel)
SELECT ID, QuestLevel FROM quest_template WHERE QuestLevel > 0;

UPDATE quest_template SET QuestLevel = -1 WHERE QuestLevel > 0;
