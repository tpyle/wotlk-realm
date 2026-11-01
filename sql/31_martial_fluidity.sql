-- ---------------------------------------------------------------------------
-- Martial Fluidity: a warrior passive that lifts every stance requirement
--
-- Taught by warrior trainers at level 60. While a warrior knows it, every
-- warrior ability can be used in any stance (Overpower in Defensive Stance,
-- Shield Wall in Berserker Stance, Intercept in Battle Stance), and the buffs
-- those abilities put on the warrior survive a change of stance.
--
-- How
-- ---
-- Aura 275, SPELL_AURA_MOD_IGNORE_SHAPESHIFT, is the stock mechanism:
-- Warbringer uses it for Charge, Intercept and Intervene, and Shadow Dance for
-- the rogue's openers. It matches spells by family and class mask, and the
-- mask here is every bit of the warrior family (SpellClassSet 4), so it
-- covers all 23 stance-locked warrior abilities and anything else of theirs.
-- Spell::CheckCast skips the form check for a spell it covers; the core's
-- stance-change handler (AuraEffect::HandleShapeshiftBoosts) keeps such a
-- spell's buffs instead of stripping them.
--
-- THE CLIENT HAS TO KNOW THIS SPELL. The client checks a spell's stance
-- itself and will not send the cast ("Must be in Battle Stance"), and it
-- reads the ignoring aura from its own Spell.dbc. tools/gen_spell_dbc.py
-- ships this row into patch-W, which every player has to install again.
--
-- The row is modelled on two stock spells:
--
--   Parry (3127), a passive warrior trainers teach: Attributes 0x50
--   (IS_ABILITY | PASSIVE, and not DO_NOT_DISPLAY, so it shows in the
--   spellbook), instant, self, ProcChance 101, SpellPriority 50.
--   Warbringer (57499) for the aura itself: Effect 6 (APPLY_AURA) on the
--   caster, BasePoints -1 with DieSides 1, and its icon.
--
-- Spell ids 90150-90199 are for trainer-taught spells the client must know;
-- 90100-90149 belong to sql/28_custom_spells.sql. Both are inside the block
-- gen_spell_dbc.py ships.
--
-- Rerunning this file is safe: DELETE then INSERT of the same rows.
-- ---------------------------------------------------------------------------

DELETE FROM `spell_dbc` WHERE `ID` = 90150;
INSERT INTO `spell_dbc`
    (`ID`, `Attributes`, `CastingTimeIndex`, `ProcChance`, `BaseLevel`, `SpellLevel`,
     `RangeIndex`, `EquippedItemClass`,
     `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `ImplicitTargetA_1`, `EffectAura_1`,
     `EffectSpellClassMaskA_1`, `EffectSpellClassMaskA_2`, `EffectSpellClassMaskA_3`,
     `EffectChainAmplitude_1`, `EffectChainAmplitude_2`, `EffectChainAmplitude_3`,
     `SpellIconID`, `SpellPriority`, `SpellClassSet`, `SchoolMask`,
     `Name_Lang_enUS`, `Description_Lang_enUS`)
VALUES
    (90150, 0x50, 1, 101, 60, 60,
     1, -1,
     6, 1, -1, 1, 275,
     0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF,
     1, 1, 1,
     3518, 50, 4, 1,
     'Martial Fluidity',
     'Your abilities can be used in any stance, and their effects no longer end when you change stance.');

-- Trainer 1 is the warrior class trainer of every capital and town (31
-- creatures); trainer 2 is the starting-area one, which teaches nothing past
-- level 6. Level 60, so it comes once a warrior has every stance and most of
-- its abilities, at 6 gold 20 silver, what that trainer asks for most new
-- ranks at 60 (Rend, Cleave and Shield Slam).
DELETE FROM `trainer_spell` WHERE `SpellId` = 90150;
INSERT INTO `trainer_spell` (`TrainerId`, `SpellId`, `MoneyCost`, `ReqLevel`) VALUES
    (1, 90150, 62000, 60);

-- The trainer list also needs a skill line. The client checks its own
-- SkillLineAbility.dbc before it lists a trainer spell, and quietly drops one
-- that has no row there: with only the two rows above, Martial Fluidity was
-- sent to a level 60 warrior and never drawn. So it is filed under Arms (26),
-- where Battle Stance is, on the terms of every stock warrior ability:
-- ClassMask 0 (the skill line is warrior-only already), MinSkillLineRank 1,
-- AcquireMethod 0 (learned from a trainer, not granted with the skill). That
-- also gives it a place in the spellbook, on the Arms tab.
--
-- The server reads skilllineability_dbc on top of SkillLineAbility.dbc at
-- startup. tools/gen_openskills_client_dbc.py ships this row into patch-Y,
-- which carries the client's SkillLineAbility.dbc. Id 40100, clear of the
-- stock file (which ends at 31448) and of mod-openskills' 40000-40002.
DELETE FROM `skilllineability_dbc` WHERE `ID` = 40100;
INSERT INTO `skilllineability_dbc`
    (`ID`, `SkillLine`, `Spell`, `RaceMask`, `ClassMask`, `ExcludeRace`, `ExcludeClass`,
     `MinSkillLineRank`, `SupercededBySpell`, `AcquireMethod`, `TrivialSkillLineRankHigh`,
     `TrivialSkillLineRankLow`, `CharacterPoints_1`, `CharacterPoints_2`)
VALUES
    (40100, 26, 90150, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0);
