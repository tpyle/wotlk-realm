-- ---------------------------------------------------------------------------
-- Spells the client has to know about, so an item can say what it does
--
-- Why this file exists
-- --------------------
--
-- An item's "Use:" line is not sent by the server. The client builds it from
-- the DESCRIPTION of the item's spell, read out of its OWN Spell.dbc, and the
-- same lookup decides whether right-clicking the item sends CMSG_USE_ITEM at
-- all. An item whose spell the client cannot find has no Use: line and does
-- nothing when clicked.
--
-- `spell_dbc` alone is not enough for that, because it is a server-side
-- overlay the client never sees. A spell meant to be visible has to exist in
-- BOTH places: here, so the server resolves it, and in the client's Spell.dbc,
-- which tools/gen_spell_dbc.py puts there.
--
-- The alternative was to borrow a stock spell whose description happened to
-- fit. Nothing fits: of the 149 spells whose description mentions Stamina,
-- every one resolves $s1 from its own effect values and would print somebody
-- else's number. Repurposing a dead row was the fallback, and the only stock
-- spell that is instant, self-cast, free and silent AND has no description is
-- 5735 'REUSE' - five others share its shape but carry names like 'Trigger
-- Sandworm Mortar NOW', which scripts may well still reach for.
--
-- THE 90100-90199 BLOCK IS RESERVED for spells that must reach the client.
-- gen_spell_dbc.py ships exactly this range and nothing else, which matters:
-- 4492 of the 4517 rows in spell_dbc are serverside-only, and six stock items
-- point spellid_1 at spells literally named '... serverside spell'. Shipping
-- the whole table would hand the client spells deliberately kept from it.
--
-- The convention is spell = item entry + 100, so 90003's spell is 90103.
--
-- Rerunning this file is safe: DELETE then INSERT of the same rows.
-- ---------------------------------------------------------------------------

-- Every column not named here defaults to 0, and these nine are exactly the
-- non-zero fields of spell 5735, which is already known to work as an item use
-- spell on this realm. So each row below is that same spell with a new number
-- and our own words, rather than a guess at what a usable spell needs:
--
--   CastingTimeIndex 1      instant
--   RangeIndex       1      self
--   ImplicitTargetA_1 1     TARGET_UNIT_CASTER
--   Effect_1         3      SPELL_EFFECT_DUMMY - does nothing if ever cast
--   EquippedItemClass -1    no weapon requirement
--   ProcChance       101    as the stock row has it
--   SpellIconID      1      unused; the Use: line carries no icon
--   SchoolMask       1      physical
--   EffectChainAmplitude_1  1.0
--
-- SPELL_EFFECT_DUMMY is the safety net: ScriptName item_statbonus_grant returns
-- true from OnUse and the cast never happens, but if that ever stopped being
-- true the effect would still be a no-op rather than something unintended.
--
-- Description_Lang_enUS IS THE TOOLTIP. It is plain text on purpose - a $s1
-- would resolve against this spell's own (empty) effect values and print 0.
-- That means the number here is written by hand and the amount actually
-- granted lives in statbonus_item_reward, so the two can drift;
-- gen_spell_dbc.py compares them and refuses to ship a tooltip that disagrees
-- with the table.

DELETE FROM `spell_dbc` WHERE `ID` BETWEEN 90100 AND 90199;
INSERT INTO `spell_dbc`
    (`ID`, `CastingTimeIndex`, `ProcChance`, `RangeIndex`, `EquippedItemClass`,
     `Effect_1`, `ImplicitTargetA_1`, `SpellIconID`, `EffectChainAmplitude_1`,
     `SchoolMask`, `Name_Lang_enUS`, `Description_Lang_enUS`)
VALUES
    (90102, 1, 101, 1, -1, 3, 1, 1, 1, 1, 'Call Echo of Azeroth',
        'Calls the Echo of Azeroth to you.'),
    (90103, 1, 101, 1, -1, 3, 1, 1, 1, 1, 'Absorb Mote of Vigour',
        'Permanently increases your Stamina by 1.'),
    (90104, 1, 101, 1, -1, 3, 1, 1, 1, 1, 'Absorb Mote of Might',
        'Permanently increases your Strength by 1.'),
    (90105, 1, 101, 1, -1, 3, 1, 1, 1, 1, 'Absorb Mote of Grace',
        'Permanently increases your Agility by 1.'),
    (90106, 1, 101, 1, -1, 3, 1, 1, 1, 1, 'Absorb Mote of Insight',
        'Permanently increases your Intellect by 1.'),
    (90107, 1, 101, 1, -1, 3, 1, 1, 1, 1, 'Absorb Mote of Serenity',
        'Permanently increases your Spirit by 1.');
