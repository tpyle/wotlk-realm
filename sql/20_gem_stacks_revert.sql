-- Undo 20_gem_stacks.sql: put the gems back to the stack sizes recorded in
-- item_template_stackable_backup by 20_gem_stacks.sql. Restart the worldserver
-- afterwards; there is no ".reload item_template".
UPDATE item_template it
JOIN item_template_stackable_backup b ON b.entry = it.entry
SET it.stackable = b.stackable
WHERE it.class = 3;
