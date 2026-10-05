# Audit: do the custom SQL files delete stock rows they do not put back?

Prompted by 25_armor_proficiencies_all_classes.sql, whose

    DELETE ... WHERE TrainerId IN (...) AND SpellId IN (...)

was a cross product and removed two base rows (hunters and shamans training
Mail) that it then did not reinsert.

Every DELETE in sql/ was checked against the base data in
server/data/sql/base/db_world/ to see whether stock rows fall inside its
scope, and if so whether the file restores or replaces them.

| File | Scope deleted | Stock rows in scope | Verdict |
| --- | --- | --- | --- |
| 02_big_bags | playercreateinfo_item itemid 23162 | 0 | own rows only |
| 04_factionchoice_gossip | npc_text 90010, 90011 | 0 | custom id range |
| 10_scroll_stacking | spell_group_stack_rules 1087 | 1 | **backed up first** into spell_group_stack_rules_backup, and replaced deliberately |
| 10_scroll_stacking | spell_group (1088, -1067) | 0 | nothing there to lose |
| 10_scroll_stacking_revert | group 1200 | 0 | custom id |
| 16_multiple_specializations_revert | quest_exclusive_group_backup (whole table) | n/a | its own backup table |
| 17_tyraels_hilt | gossip_menu_option 9768 option 0 | 1 | replaced on purpose, which is the point of the file, and reinserted working |
| 17_tyraels_hilt | creature_text / smart_scripts / conditions for 29093, 29095 | 0 | the NPCs had no SmartAI before this file gave them one |
| 18_blizzcon_murlocs | creature_text / smart_scripts for 2943, 7951; conditions 6565 | 0 | same shape, nothing stock |
| 24_lfg_random_rewards | lfg_dungeon_rewards 300, 301 | 0 | ids this realm invented |
| 25_armor_proficiencies | 22 exact (TrainerId, SpellId) pairs | 0 | fixed; was the cross product |

Two files delete a stock row on purpose. Both are fine, and they are fine in
different ways worth noticing:

* 10_scroll_stacking copies the row into a backup table first, which is what
  lets its revert file put the original back. That is the pattern to copy when
  a change has to displace base data.
* 17_tyraels_hilt replaces the row outright and says so in its header. It
  loses one thing in the process that is worth recording: the stock option
  carried OptionBroadcastTextID 29420 and the replacement sets 0, so that
  gossip line is English only now. Deliberate - the text was rewritten, so the
  broadcast text no longer matched - but it is a localisation the realm gave
  up rather than a neutral edit.

No file still has the cross-product shape, and nothing else deletes base data
without either backing it up or replacing it.
