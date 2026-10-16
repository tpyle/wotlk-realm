-- ---------------------------------------------------------------------------
-- Respawn times for individual creature spawns
--
-- Spawns whose stock respawn timer is too long for this realm. Each entry
-- names one spawn by guid and creature entry, and notes the stock value so it
-- can be reverted. Times are in seconds.
-- ---------------------------------------------------------------------------

-- Mai'Zoth (818), the ogre mage in the Mosh'Ogg Ogre Mound in Stranglethorn.
-- One spawn, which playerbots kill in passing, so a player could arrive to
-- find him freshly dead and wait out the full timer. Stock: 1800.
UPDATE creature SET spawntimesecs = 600 WHERE guid = 523 AND id = 818;
