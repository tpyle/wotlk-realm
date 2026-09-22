-- ---------------------------------------------------------------------------
-- Ransin Donner and Zas'Tysh hand out the BlizzCon prizes
--
-- The two Elders (2943 in Ironforge, 7951 in Orgrimmar) share gossip menu
-- 6565, which already carries three coded options - "I would like to enter
-- the secret code to receive my Murloc pet / Murloc costume / Big Blizzard
-- Bear" - and, exactly like the Worldwide Invitational Elders in sql/17,
-- nothing behind them. The text box opens, the code goes nowhere.
--
-- This adds the SmartAI that answers each option with its prize:
--
--     option 0  Blue Murloc Egg    20371  teaches Murky, spell 24696
--     option 1  Murloc Costume     33079  a use item, not learned
--     option 2  Big Blizzard Bear  43599  teaches the mount, spell 58983
--
-- The learned prizes are hidden once the spell is known or the item is
-- carried. The pet and mount spells come from item_template.spellid_2;
-- spellid_1 on both is 55884, the generic "Learning" spell that every such
-- item casts, and is not the thing to check. The costume is never learned,
-- so it is hidden only while carried - a character who destroys it can ask
-- again, which is the most that can be enforced without inventing a flag.
--
-- Any code works, for the same reason as sql/17: the real ones were
-- single-use secrets bound to retail accounts.
--
-- Data only. Reloadable tables, but the Elders keep the AI they spawned
-- with, so a restart (or respawn) is what makes them answer.
--
-- Idempotent: safe to run more than once.
-- ---------------------------------------------------------------------------

UPDATE creature_template SET AIName = 'SmartAI' WHERE entry IN (2943, 7951);

DELETE FROM creature_text WHERE CreatureID IN (2943, 7951) AND GroupID = 0;
INSERT INTO creature_text (CreatureID, GroupID, ID, Text, Type, Language, Probability, Emote, Duration, Sound, BroadcastTextId, TextRange, comment) VALUES
    (2943, 0, 0, 'Ah, I thought I recognised you. Here - and do not let it out near the fountain.', 12, 0, 100, 1, 0, 0, 0, 0, 'Ransin Donner - hands over a BlizzCon prize'),
    (7951, 0, 0, 'Ah, I thought I recognised you. Here - and do not let it out near the fountain.', 12, 0, 100, 1, 0, 0, 0, 0, 'Zas''Tysh - hands over a BlizzCon prize');

DELETE FROM smart_scripts WHERE entryorguid IN (2943, 7951) AND source_type = 0;
INSERT INTO smart_scripts
    (entryorguid, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags,
     event_param1, event_param2, event_param3, event_param4,
     action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6,
     target_type, target_param1, target_param2, target_param3, target_x, target_y, target_z, target_o, comment)
VALUES
    -- Ransin Donner: pet
    (2943, 0, 0, 1, 62, 0, 100, 0, 6565, 0, 0, 0, 56, 20371, 1, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Ransin Donner - On Gossip Select (pet) - Add Item Blue Murloc Egg'),
    (2943, 0, 1, 2, 61, 0, 100, 0,    0, 0, 0, 0,  1,     0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Ransin Donner - On Gossip Select (pet) - Say'),
    (2943, 0, 2, 0, 61, 0, 100, 0,    0, 0, 0, 0, 72,     0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Ransin Donner - On Gossip Select (pet) - Close Gossip'),
    -- Ransin Donner: costume
    (2943, 0, 3, 4, 62, 0, 100, 0, 6565, 1, 0, 0, 56, 33079, 1, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Ransin Donner - On Gossip Select (costume) - Add Item Murloc Costume'),
    (2943, 0, 4, 5, 61, 0, 100, 0,    0, 0, 0, 0,  1,     0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Ransin Donner - On Gossip Select (costume) - Say'),
    (2943, 0, 5, 0, 61, 0, 100, 0,    0, 0, 0, 0, 72,     0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Ransin Donner - On Gossip Select (costume) - Close Gossip'),
    -- Ransin Donner: bear
    (2943, 0, 6, 7, 62, 0, 100, 0, 6565, 2, 0, 0, 56, 43599, 1, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Ransin Donner - On Gossip Select (bear) - Add Item Big Blizzard Bear'),
    (2943, 0, 7, 8, 61, 0, 100, 0,    0, 0, 0, 0,  1,     0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Ransin Donner - On Gossip Select (bear) - Say'),
    (2943, 0, 8, 0, 61, 0, 100, 0,    0, 0, 0, 0, 72,     0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Ransin Donner - On Gossip Select (bear) - Close Gossip'),
    -- Zas'Tysh: pet
    (7951, 0, 0, 1, 62, 0, 100, 0, 6565, 0, 0, 0, 56, 20371, 1, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Zas''Tysh - On Gossip Select (pet) - Add Item Blue Murloc Egg'),
    (7951, 0, 1, 2, 61, 0, 100, 0,    0, 0, 0, 0,  1,     0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Zas''Tysh - On Gossip Select (pet) - Say'),
    (7951, 0, 2, 0, 61, 0, 100, 0,    0, 0, 0, 0, 72,     0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Zas''Tysh - On Gossip Select (pet) - Close Gossip'),
    -- Zas'Tysh: costume
    (7951, 0, 3, 4, 62, 0, 100, 0, 6565, 1, 0, 0, 56, 33079, 1, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Zas''Tysh - On Gossip Select (costume) - Add Item Murloc Costume'),
    (7951, 0, 4, 5, 61, 0, 100, 0,    0, 0, 0, 0,  1,     0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Zas''Tysh - On Gossip Select (costume) - Say'),
    (7951, 0, 5, 0, 61, 0, 100, 0,    0, 0, 0, 0, 72,     0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Zas''Tysh - On Gossip Select (costume) - Close Gossip'),
    -- Zas'Tysh: bear
    (7951, 0, 6, 7, 62, 0, 100, 0, 6565, 2, 0, 0, 56, 43599, 1, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Zas''Tysh - On Gossip Select (bear) - Add Item Big Blizzard Bear'),
    (7951, 0, 7, 8, 61, 0, 100, 0,    0, 0, 0, 0,  1,     0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Zas''Tysh - On Gossip Select (bear) - Say'),
    (7951, 0, 8, 0, 61, 0, 100, 0,    0, 0, 0, 0, 72,     0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Zas''Tysh - On Gossip Select (bear) - Close Gossip');

DELETE FROM conditions WHERE SourceTypeOrReferenceId = 15 AND SourceGroup = 6565;
INSERT INTO conditions
    (SourceTypeOrReferenceId, SourceGroup, SourceEntry, SourceId, ElseGroup, ConditionTypeOrReference, ConditionTarget,
     ConditionValue1, ConditionValue2, ConditionValue3, NegativeCondition, ErrorType, ErrorTextId, ScriptName, Comment)
VALUES
    (15, 6565, 0, 0, 0, 25, 0, 24696, 0, 0, 1, 0, 0, '', 'BlizzCon murloc pet - hide once Murky (24696) is known'),
    (15, 6565, 0, 0, 0,  2, 0, 20371, 1, 0, 1, 0, 0, '', 'BlizzCon murloc pet - hide while the egg is carried'),
    (15, 6565, 1, 0, 0,  2, 0, 33079, 1, 0, 1, 0, 0, '', 'BlizzCon murloc costume - hide while carried'),
    (15, 6565, 2, 0, 0, 25, 0, 58983, 0, 0, 1, 0, 0, '', 'BlizzCon bear - hide once the mount (58983) is known'),
    (15, 6565, 2, 0, 0,  2, 0, 43599, 1, 0, 1, 0, 0, '', 'BlizzCon bear - hide while the item is carried');
