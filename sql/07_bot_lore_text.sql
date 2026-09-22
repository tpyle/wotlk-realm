-- ---------------------------------------------------------------------------
-- Lore chatter lines for mod-botlore
--
-- One row per line a bot can say. Every filter column defaults to "any", so a
-- generic line is a row with only Trigger and Text set, and a line written for
-- one place carries a ZoneId (or AreaId) - the module prefers the most
-- specific match it can find, so zone lines beat generic ones where they apply.
--
-- Triggers: zone_enter, quest_accept, quest_complete, kill_boss, kill, death,
--           level_up, loot_rare, combat_start, idle
-- Channel:  0 say, 1 emote, 2 party, 3 guild
-- TeamId:   -1 any, 0 Alliance, 1 Horde
-- Placeholders: %zone %area %target %quest %item %level %name
--
-- Text must stay under 255 characters and must not contain '|': the module
-- speaks through Player::Say, which bypasses the chat opcode's length trim and
-- hyperlink validation, so the loader rejects such rows rather than sending
-- them.
--
--   To undo: DROP TABLE bot_lore_text;
--
-- Idempotent: the table is rebuilt from scratch, so it is safe to re-run.
-- ---------------------------------------------------------------------------

DROP TABLE IF EXISTS `bot_lore_text`;

CREATE TABLE `bot_lore_text` (
  `Id`            int unsigned NOT NULL AUTO_INCREMENT,
  `Trigger`       varchar(32)  NOT NULL COMMENT 'zone_enter, quest_accept, quest_complete, kill, kill_boss, death, level_up, loot_rare, combat_start, idle',
  `ZoneId`        int unsigned NOT NULL DEFAULT '0' COMMENT '0 = any zone',
  `AreaId`        int unsigned NOT NULL DEFAULT '0' COMMENT '0 = any area; more specific than ZoneId',
  `CreatureEntry` int unsigned NOT NULL DEFAULT '0' COMMENT 'kill triggers only; 0 = any',
  `RaceMask`      int unsigned NOT NULL DEFAULT '0' COMMENT '0 = any race',
  `ClassMask`     int unsigned NOT NULL DEFAULT '0' COMMENT '0 = any class',
  `TeamId`        tinyint      NOT NULL DEFAULT '-1' COMMENT '-1 any, 0 Alliance, 1 Horde',
  `MinLevel`      tinyint unsigned NOT NULL DEFAULT '0',
  `MaxLevel`      tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0 = no upper bound',
  `Channel`       tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0 say, 1 emote, 2 party, 3 guild',
  `Weight`        tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'relative pick weight',
  `Text`          varchar(255) NOT NULL,
  `Comment`       varchar(255) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `idx_trigger` (`Trigger`,`ZoneId`,`AreaId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='mod-botlore: what bots say, and where';

-- ---------------------------------------------------------------------------
-- Generic lines. These apply anywhere, and are the fallback when no
-- zone-specific line matches.
-- ---------------------------------------------------------------------------
INSERT INTO `bot_lore_text` (`Trigger`, ZoneId, AreaId, CreatureEntry, TeamId, MinLevel, MaxLevel, Channel, Weight, Text) VALUES
('zone_enter', 0, 0, 0, -1, 0, 0, 0, 1, 'So this is %zone. The maps never do it justice.'),
('zone_enter', 0, 0, 0, -1, 0, 0, 0, 1, 'Keep your wits about you. %zone has swallowed better than us.'),
('zone_enter', 0, 0, 0, -1, 0, 0, 0, 1, 'I have heard stories about %zone. Most of them ended badly.'),
('zone_enter', 0, 0, 0, -1, 0, 0, 1, 1, 'studies the horizon of %zone.'),
('zone_enter', 0, 0, 0, -1, 0, 0, 0, 1, 'Every stone here remembers a war.'),
('zone_enter', 0, 0, 0, -1, 20, 0, 0, 1, 'The road to %zone is older than any kingdom on it.'),
('zone_enter', 0, 0, 0, 0, 0, 0, 0, 1, 'For the Alliance. Even out here, that still means something.'),
('zone_enter', 0, 0, 0, 1, 0, 0, 0, 1, 'Lok-tar. The Horde walks where it pleases.'),

('quest_accept', 0, 0, 0, -1, 0, 0, 0, 1, 'They have asked me to see to %quest. It would be poor manners to refuse.'),
('quest_accept', 0, 0, 0, -1, 0, 0, 0, 1, '%quest, then. No one else seems willing.'),
('quest_accept', 0, 0, 0, -1, 0, 0, 0, 1, 'Another errand in %zone. This is how legends start, or so I am told.'),
('quest_accept', 0, 0, 0, -1, 0, 0, 2, 1, 'I have taken on %quest if anyone wants the coin.'),

('quest_complete', 0, 0, 0, -1, 0, 0, 0, 1, '%quest is finished. %zone owes me a debt it will never pay.'),
('quest_complete', 0, 0, 0, -1, 0, 0, 0, 1, 'That settles %quest. Small deeds, in the end, are what hold the world together.'),
('quest_complete', 0, 0, 0, -1, 0, 0, 0, 1, 'Done. Someone in %zone will sleep easier tonight, even if they never learn my name.'),
('quest_complete', 0, 0, 0, -1, 0, 0, 1, 1, 'dusts off their hands, finished with %quest.'),

('kill_boss', 0, 0, 0, -1, 0, 0, 0, 1, '%target will trouble %zone no longer.'),
('kill_boss', 0, 0, 0, -1, 0, 0, 0, 1, 'They said %target could not be killed. They were wrong, as usual.'),
('kill_boss', 0, 0, 0, -1, 0, 0, 0, 1, 'Let the word go out: %target has fallen.'),
('kill_boss', 0, 0, 0, -1, 0, 0, 1, 1, 'stands over the body of %target, breathing hard.'),
('kill_boss', 0, 0, 0, -1, 0, 0, 2, 1, '%target is down. Take what you need.'),

('kill', 0, 0, 0, -1, 0, 0, 0, 1, 'One less of them in %zone.'),
('kill', 0, 0, 0, -1, 0, 0, 0, 1, 'That was hardly a fight.'),

('death', 0, 0, 0, -1, 0, 0, 0, 1, 'Not like this... %target will answer for it.'),
('death', 0, 0, 0, -1, 0, 0, 0, 1, 'The Light fades... tell them I held the line.'),
('death', 0, 0, 0, -1, 0, 0, 0, 1, 'So %zone claims another. I should have listened.'),
('death', 0, 0, 0, 1, 0, 0, 0, 1, 'Victory... or death. Today it is the other one.'),

('level_up', 0, 0, 0, -1, 0, 0, 0, 1, 'Level %level. The road teaches faster than any master.'),
('level_up', 0, 0, 0, -1, 0, 0, 0, 1, 'I am stronger than I was in the morning. %zone saw to that.'),
('level_up', 0, 0, 0, -1, 0, 0, 1, 1, 'rolls their shoulders, feeling stronger.'),
('level_up', 0, 0, 0, -1, 60, 0, 0, 1, 'Level %level. There are heroes in the songs who never came this far.'),

('loot_rare', 0, 0, 0, -1, 0, 0, 0, 1, '%item. Someone carried this a long way before I found it.'),
('loot_rare', 0, 0, 0, -1, 0, 0, 0, 1, 'A fine piece, this %item. It has seen its share of blood.'),
('loot_rare', 0, 0, 0, -1, 0, 0, 1, 1, 'turns %item over in their hands, admiring it.'),
('loot_rare', 0, 0, 0, -1, 0, 0, 2, 1, 'Found %item. Speak now if anyone has better use for it.'),

('combat_start', 0, 0, 0, -1, 0, 0, 0, 1, '%target picked the wrong day.'),
('combat_start', 0, 0, 0, -1, 0, 0, 0, 1, 'Stand ready. This one bites.'),

('idle', 0, 0, 0, -1, 0, 0, 0, 1, 'Strange, how quiet %zone gets between the killing.'),
('idle', 0, 0, 0, -1, 0, 0, 1, 1, 'checks their gear, one buckle at a time.');

-- ---------------------------------------------------------------------------
-- Zone lines. Zone ids are AreaTable.dbc entries; starting zones use AreaId
-- because they are sub-areas of their parent zone.
-- ---------------------------------------------------------------------------
INSERT INTO `bot_lore_text` (`Trigger`, ZoneId, AreaId, CreatureEntry, TeamId, MinLevel, MaxLevel, Channel, Weight, Text) VALUES
-- Eastern Kingdoms, Alliance side
('zone_enter', 12, 0, 0, -1, 0, 0, 0, 1, 'Elwynn is quiet, and that is exactly how Stormwind likes it.'),
('zone_enter', 12, 0, 0, -1, 0, 0, 0, 1, 'Even the gnolls here have grown bold since the war.'),
('zone_enter', 40, 0, 0, -1, 0, 0, 0, 1, 'Westfall was the kingdom''s breadbasket once. Now it grows scarecrows and Defias.'),
('zone_enter', 40, 0, 0, -1, 0, 0, 0, 1, 'Every farm here is empty. Ask where the people went and nobody answers.'),
('zone_enter', 10, 0, 0, -1, 0, 0, 0, 2, 'They say Morbent Fel still walks these woods. Keep to the road.'),
('zone_enter', 10, 0, 0, -1, 0, 0, 0, 1, 'Duskwood. The Night Watch cannot save everyone, and they know it.'),
('zone_enter', 10, 0, 0, -1, 0, 0, 0, 1, 'The trees here have not seen sunlight in years. Neither have the things beneath them.'),
('zone_enter', 44, 0, 0, -1, 0, 0, 0, 1, 'Lake Everstill used to be a fishing town. Now it is a garrison that pretends otherwise.'),
('zone_enter', 1, 0, 0, -1, 0, 0, 0, 1, 'Dun Morogh. Cold enough to keep a dwarf honest.'),
('zone_enter', 38, 0, 0, -1, 0, 0, 0, 1, 'The dam holds, and the Stonewrought holds Loch Modan. Long may both stand.'),
('zone_enter', 141, 0, 0, -1, 0, 0, 0, 1, 'Teldrassil was grown, not built. Do not lean on anything.'),
('zone_enter', 33, 0, 0, -1, 0, 0, 0, 1, 'Stranglethorn. Half the jungle wants you dead and the other half wants paying.'),
('zone_enter', 47, 0, 0, -1, 0, 0, 0, 1, 'The Wildhammer hold the Hinterlands, and the trolls have never forgiven them for it.'),
-- Eastern Kingdoms, Horde side
('zone_enter', 85, 0, 0, -1, 0, 0, 0, 1, 'Tirisfal. The Scourge made us, and we buried them for it.'),
('zone_enter', 85, 0, 0, -1, 0, 0, 0, 1, 'Do not pity the dead of Lordaeron. Some of us are still walking.'),
('zone_enter', 130, 0, 0, -1, 0, 0, 0, 1, 'Silverpine is worgen country after dark. Keep the fires lit.'),
('zone_enter', 267, 0, 0, -1, 0, 0, 0, 1, 'Southshore and Tarren Mill have been killing each other since before I could hold a blade.'),
('zone_enter', 28, 0, 0, -1, 0, 0, 0, 1, 'Andorhal is ash and plague. The Scourge left nothing worth taking.'),
('zone_enter', 139, 0, 0, -1, 0, 0, 0, 1, 'The Eastern Plaguelands still bleed. No crop will grow in ground like this.'),
('zone_enter', 3430, 0, 0, -1, 0, 0, 0, 1, 'Eversong is beautiful, and that beauty is a lie stitched over the Dead Scar.'),
-- Kalimdor
('zone_enter', 14, 0, 0, -1, 0, 0, 0, 1, 'Durotar is hard land. Thrall chose it so the Horde would stay hard too.'),
('zone_enter', 17, 0, 0, -1, 0, 0, 0, 2, 'Out here water is worth more than gold. Ration it.'),
('zone_enter', 17, 0, 0, -1, 0, 0, 0, 1, 'The Barrens go on forever. That is not a figure of speech.'),
('zone_enter', 215, 0, 0, -1, 0, 0, 0, 1, 'Mulgore feeds the tribes. Walk softly here, the earth is listening.'),
('zone_enter', 331, 0, 0, -1, 0, 0, 0, 1, 'Ashenvale has been logged, burned and fought over. The night elves have not forgotten who did it.'),
('zone_enter', 361, 0, 0, -1, 0, 0, 0, 1, 'Felwood. The taint here predates the Legion''s last defeat, and it is still spreading.'),
('zone_enter', 400, 0, 0, -1, 0, 0, 0, 1, 'The Needles were carved by water that has not fallen in an age.'),
('zone_enter', 440, 0, 0, -1, 0, 0, 0, 1, 'Tanaris hides the Caverns of Time. The bronze flight watches every hour of it.'),
('zone_enter', 490, 0, 0, -1, 0, 0, 0, 1, 'Un''Goro should not exist. Something down here kept the old world alive.'),
('zone_enter', 618, 0, 0, -1, 0, 0, 0, 1, 'Winterspring is silent because everything loud in it has already been eaten.'),
-- Outland
('zone_enter', 3483, 0, 0, -1, 0, 0, 0, 1, 'Hellfire Peninsula. This is what a world looks like after the Legion is done with it.'),
('zone_enter', 3521, 0, 0, -1, 0, 0, 0, 1, 'Zangarmarsh is drying out, one broken pump at a time.'),
('zone_enter', 3518, 0, 0, -1, 0, 0, 0, 1, 'Nagrand was the orcs'' homeland. What is left of it still remembers them.'),
('zone_enter', 3520, 0, 0, -1, 0, 0, 0, 1, 'Shadowmoon burns under the Black Temple. Illidan made certain of that.'),
-- Northrend
('zone_enter', 3537, 0, 0, -1, 0, 0, 0, 1, 'Borean Tundra. Both armies landed here, and neither has moved far since.'),
('zone_enter', 495, 0, 0, -1, 0, 0, 0, 1, 'Howling Fjord. The vrykul built to last, and they built to kill.'),
('zone_enter', 65, 0, 0, -1, 0, 0, 0, 1, 'Wyrmrest Temple stands over the Dragonblight. Every flight sent someone, which tells you how bad it is.'),
('zone_enter', 65, 0, 0, -1, 0, 0, 0, 1, 'Dragons come here to die. Try not to join them.'),
('zone_enter', 394, 0, 0, -1, 0, 0, 0, 1, 'Grizzly Hills. Furbolg, vrykul and worse, all sharing one forest.'),
('zone_enter', 66, 0, 0, -1, 0, 0, 0, 1, 'Zul''Drak. The Drakkari are killing their own gods for the power to fight the Scourge.'),
('zone_enter', 67, 0, 0, -1, 0, 0, 0, 1, 'The Storm Peaks are titan work. Everything here is too large and too precise.'),
('zone_enter', 210, 0, 0, -1, 0, 0, 0, 2, 'Icecrown. The Citadel is up there, and the Lich King knows we have come.'),
('zone_enter', 210, 0, 0, -1, 0, 0, 0, 1, 'Every step here is watched. Say nothing you would not want him to hear.'),
('zone_enter', 2817, 0, 0, -1, 0, 0, 0, 1, 'Crystalsong. The trees are glass and the ground hums. Malygos'' doing.'),
-- Capitals
('zone_enter', 1519, 0, 0, -1, 0, 0, 0, 1, 'Stormwind rebuilt itself once already. Do not tell the stonemasons that story.'),
('zone_enter', 1537, 0, 0, -1, 0, 0, 0, 1, 'Ironforge. The Great Forge has not gone cold in a thousand years.'),
('zone_enter', 1657, 0, 0, -1, 0, 0, 0, 1, 'Darnassus. Ten thousand years of it, and we are the loud newcomers.'),
('zone_enter', 1637, 0, 0, -1, 0, 0, 0, 1, 'Orgrimmar. Thrall built this city out of nothing but will.'),
('zone_enter', 1638, 0, 0, -1, 0, 0, 0, 1, 'Thunder Bluff sits above the world and judges none of it.'),
('zone_enter', 1497, 0, 0, -1, 0, 0, 0, 1, 'The Undercity was Lordaeron''s capital once. We kept the crypts and let the rest rot.'),
('zone_enter', 3487, 0, 0, -1, 0, 0, 0, 1, 'Silvermoon shines as if nothing happened here. That takes effort.'),
('zone_enter', 3557, 0, 0, -1, 0, 0, 0, 1, 'The Exodar is a wreck of a ship we call a city. It will serve.'),
('zone_enter', 3703, 0, 0, -1, 0, 0, 0, 1, 'Shattrath. Aldor and Scryer under one roof, barely.'),
('zone_enter', 4395, 0, 0, -1, 0, 0, 0, 1, 'Dalaran flies now. The Kirin Tor would rather not discuss how.'),
-- Starting areas (sub-areas, so AreaId)
('zone_enter', 0, 9, 0, -1, 0, 10, 0, 1, 'Northshire Abbey. Everyone in Stormwind started somewhere like this.'),
('zone_enter', 0, 363, 0, -1, 0, 10, 0, 1, 'The Valley of Trials. They name it honestly, at least.'),
('zone_enter', 0, 154, 0, -1, 0, 10, 0, 1, 'Deathknell. I woke up in a grave near here. I try not to visit it.'),
('zone_enter', 0, 221, 0, -1, 0, 10, 0, 1, 'Camp Narache. The Grimtotem watch us from the hills and wait.'),
('zone_enter', 0, 188, 0, -1, 0, 10, 0, 1, 'Shadowglen. The Moonwell keeps the shadows honest.'),
('zone_enter', 0, 132, 0, -1, 0, 10, 0, 1, 'Coldridge Valley. Cold, rocky, and full of troggs. Home.'),
('zone_enter', 0, 3431, 0, -1, 0, 10, 0, 1, 'Sunstrider Isle. We were high elves once. Try to keep up.'),
('zone_enter', 0, 3526, 0, -1, 0, 10, 0, 1, 'Ammen Vale. The Exodar came down hard, and we are still counting the dead.');

-- ---------------------------------------------------------------------------
-- Named kills. CreatureEntry makes these beat the generic kill_boss lines.
-- ---------------------------------------------------------------------------
INSERT INTO `bot_lore_text` (`Trigger`, ZoneId, AreaId, CreatureEntry, TeamId, MinLevel, MaxLevel, Channel, Weight, Text) VALUES
('kill_boss', 0, 0,   448, -1, 0, 0, 0, 1, 'Hogger falls! Elwynn will sleep easier, and Stormwind will never hear of it.'),
('kill_boss', 0, 0,   522, -1, 0, 0, 0, 1, 'Mor''Ladim is still. Whatever he was looking for in those graves, he can stop now.'),
('kill_boss', 0, 0,  3864, -1, 0, 0, 0, 1, 'The Fel Steed will carry no more riders out of Duskwood.'),
('kill_boss', 0, 0,  6109, -1, 0, 0, 0, 1, 'Azuregos is down. The blue flight will want words about this.'),
('kill_boss', 0, 0, 12397, -1, 0, 0, 0, 1, 'Kazzak is banished. The Legion will send another, they always do.'),
('kill_boss', 0, 0, 10184, -1, 0, 0, 0, 1, 'Onyxia is dead. Her whispers in Stormwind die with her.'),
('kill_boss', 0, 0, 10430, -1, 0, 0, 0, 1, 'The Beast of Blackrock will not rise again. Check the cages before you rest.'),
('kill_boss', 0, 0, 12201, -1, 0, 0, 0, 1, 'Theradras is broken. Maraudon may yet heal, given an age or two.');
