-- ---------------------------------------------------------------------------
-- Ian Drake and Edward Cairn hand out Tyrael's Hilt
--
-- Both Elders (29093 in Stormwind, 29095 for the Horde) share gossip menu
-- 9768, whose text is the 2008 Worldwide Invitational pitch: "surely that
-- means you were given a secret code to tell me. In return for your code I
-- will give you a gift, Tyrael's Hilt. Just whisper it in my ear when you are
-- ready." On retail the code was redeemed on the account site and the NPC
-- checked a flag. AzerothCore ships the speech and nothing behind it - no
-- gossip option, no condition, no script - so the promise was never kept.
-- (The BlizzCon murloc Elders, menu 6565, are in exactly the same state.)
--
-- This gives the menu a coded option - the text box the text is asking for -
-- and a SmartAI script that hands over item 39656 and closes the window.
-- Nothing checks the code itself: the real codes were single-use secrets
-- tied to retail accounts and there is nothing to check them against, so any
-- code works. He is not picky.
--
-- The option is hidden once the character has learned the pet or is carrying
-- the hilt, so it is one per character, which is how the promo behaved. The
-- pet spell is 53082, from item_template.spellid_2 - NOT spellid_1, which is
-- 55884, the generic "Learning" spell every pet and mount item casts to teach
-- whatever is in spellid_2. A first draft checked 55884, which no character
-- ever knows, so the option would have come back after the first hilt was
-- used: infinite hilts. Every learn-on-use item on this table follows the
-- same rule.
--
-- Data only. `.reload creature_template 29093 29095`, `.reload
-- gossip_menu_option`, `.reload smart_scripts`, `.reload conditions` apply
-- the rows live, but an Elder already standing in the world keeps the AI he
-- spawned with; a worldserver restart (or a respawn) is what puts SmartAI on
-- him.
--
-- Idempotent: safe to run more than once.
-- ---------------------------------------------------------------------------

UPDATE creature_template SET AIName = 'SmartAI' WHERE entry IN (29093, 29095);

DELETE FROM gossip_menu_option WHERE MenuID = 9768 AND OptionID = 0;
INSERT INTO gossip_menu_option
    (MenuID, OptionID, OptionIcon, OptionText, OptionBroadcastTextID, OptionType, OptionNpcFlag,
     ActionMenuID, ActionPoiID, BoxCoded, BoxMoney, BoxText, BoxBroadcastTextID)
VALUES
    (9768, 0, 0, 'I have the secret code. Let me whisper it to you.', 0, 1, 1, 0, 0, 1, 0, '', 0);

DELETE FROM creature_text WHERE CreatureID IN (29093, 29095) AND GroupID = 0;
INSERT INTO creature_text (CreatureID, GroupID, ID, Text, Type, Language, Probability, Emote, Duration, Sound, BroadcastTextId, TextRange, comment) VALUES
    (29093, 0, 0, 'That is the one. Here - a small guardian for a long road. Look after him.', 12, 0, 100, 1, 0, 0, 0, 0, 'Ian Drake - hands over Tyrael''s Hilt'),
    (29095, 0, 0, 'That is the one. Here - a small guardian for a long road. Look after him.', 12, 0, 100, 1, 0, 0, 0, 0, 'Edward Cairn - hands over Tyrael''s Hilt');

DELETE FROM smart_scripts WHERE entryorguid IN (29093, 29095) AND source_type = 0;
INSERT INTO smart_scripts
    (entryorguid, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags,
     event_param1, event_param2, event_param3, event_param4,
     action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6,
     target_type, target_param1, target_param2, target_param3, target_x, target_y, target_z, target_o, comment)
VALUES
    -- on the coded option: give the hilt (item 39656 x1) to the player who clicked
    (29093, 0, 0, 1, 62, 0, 100, 0, 9768, 0, 0, 0, 56, 39656, 1, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Ian Drake - On Gossip Select - Add Item Tyrael''s Hilt'),
    (29093, 0, 1, 2, 61, 0, 100, 0,    0, 0, 0, 0,  1,     0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Ian Drake - On Gossip Select - Say'),
    (29093, 0, 2, 0, 61, 0, 100, 0,    0, 0, 0, 0, 72,     0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Ian Drake - On Gossip Select - Close Gossip'),
    (29095, 0, 0, 1, 62, 0, 100, 0, 9768, 0, 0, 0, 56, 39656, 1, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Edward Cairn - On Gossip Select - Add Item Tyrael''s Hilt'),
    (29095, 0, 1, 2, 61, 0, 100, 0,    0, 0, 0, 0,  1,     0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Edward Cairn - On Gossip Select - Say'),
    (29095, 0, 2, 0, 61, 0, 100, 0,    0, 0, 0, 0, 72,     0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Edward Cairn - On Gossip Select - Close Gossip');

-- one per character: hide the option once the pet is known or the hilt is in the bags
DELETE FROM conditions WHERE SourceTypeOrReferenceId = 15 AND SourceGroup = 9768 AND SourceEntry = 0;
INSERT INTO conditions
    (SourceTypeOrReferenceId, SourceGroup, SourceEntry, SourceId, ElseGroup, ConditionTypeOrReference, ConditionTarget,
     ConditionValue1, ConditionValue2, ConditionValue3, NegativeCondition, ErrorType, ErrorTextId, ScriptName, Comment)
VALUES
    (15, 9768, 0, 0, 0, 25, 0, 53082, 0, 0, 1, 0, 0, '', 'Tyrael''s Hilt - hide once Mini Tyrael (53082) is known'),
    (15, 9768, 0, 0, 0,  2, 0, 39656, 1, 0, 1, 0, 0, '', 'Tyrael''s Hilt - hide while the hilt is carried');
