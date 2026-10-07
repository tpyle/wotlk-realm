-- Fishing Swap
--
-- Fishing needs a pole in the weapon slot and the client, not the server,
-- is what enforces that: with a pole in your bags but none equipped, clicking
-- Fishing produces "Must have a fishing pole equipped" and no cast packet is
-- ever sent. Measured, not assumed - the server's own opcode log stayed empty
-- through a refused click while recording every other thing the client sent.
--
-- So this does not relax the requirement, it satisfies it and then undoes
-- itself: the pole goes on when a cast is refused for want of one, and your
-- own weapons come back once you have stopped fishing.
--
-- Why you press Fishing twice the first time
--
-- An addon cannot cast a spell - casting has been protected since 2.0, so a
-- "/run equip pole" plus "/cast Fishing" macro cannot work either, in both
-- cases because the cast has to come from your own keypress. And even if it
-- could, the client decides whether the requirement is met from its own copy
-- of your inventory, which does not change until the server has confirmed the
-- equip. A single press therefore cannot both equip and fish, whoever asks.
--
-- What is left is to make the refusal useful: the press that fails is the one
-- that puts the pole on, and the next press fishes. Only the first press of a
-- fishing session costs the extra click, because the pole stays on between
-- casts.

local ADDON = "FishingSwap"

-- The poles that shipped with 3.3.5, used to find one in your bags.
--
-- By item id and not by item subtype, because subtype comes back from
-- GetItemInfo as a localised string with no global constant to compare it
-- against. A pole that is not on this list can be named with
-- "/fishswap pole <link>", which remembers it per character.
local KNOWN_POLES = {
    [6256]  = true,   -- Fishing Pole
    [6365]  = true,   -- Strong Fishing Pole
    [6366]  = true,   -- Darkwood Fishing Pole
    [6367]  = true,   -- Big Iron Fishing Pole
    [12225] = true,   -- Blump Family Fishing Pole
    [19022] = true,   -- Nat Pagle's Extreme Angler FC-5000
    [25978] = true,   -- Seth's Graphite Fishing Pole
    [44050] = true,   -- Mastercraft Kalu'ak Fishing Pole
    [45858] = true,   -- Nat's Lucky Fishing Pole
    [45991] = true,   -- Bone Fishing Pole
    [45992] = true,   -- Jeweled Fishing Pole
}

local MAINHAND, OFFHAND = 16, 17

-- How long after the last cast ends before your weapons go back on. Long
-- enough that casting again straight away does not thrash your gear.
local RESTORE_DELAY = 4.0

local state = {
    swapped    = false,   -- we put a pole on and owe the player a restore
    mainhand   = nil,     -- what was in the slots before we touched them
    offhand    = nil,
    idleSince  = nil,     -- when we last saw them not fishing
}

local function Say(fmt, ...)
    DEFAULT_CHAT_FRAME:AddMessage("|cff40c0ff" .. ADDON .. "|r: " .. format(fmt, ...))
end

local function Debug(fmt, ...)
    if FishingSwapDB and FishingSwapDB.debug then
        Say(fmt, ...)
    end
end

-- The messages that mean "you have no pole on".
--
-- Built from the globals rather than hardcoded so this survives a locale, with
-- the string actually observed on this realm kept as a backstop in case the
-- global behind it is named something else again.
local function RefusalMessages()
    local msgs = { ["Must have a fishing pole equipped"] = true }

    -- Only messages that are specifically about a pole.
    --
    -- Deliberately not SPELL_FAILED_EQUIPPED_ITEM_CLASS, which is the generic
    -- wrong-weapon refusal shared by every ability with a weapon requirement:
    -- acting on that would stuff a fishing pole into a rogue's hand the moment
    -- they fumbled Mutilate.
    for _, key in ipairs({
        "SPELL_FAILED_FISHING_POLE_REQUIRED",
        "ERR_FISHINGPOLE_REQUIRED",
        "SPELL_FAILED_FISHING_POLE",
    }) do
        local text = _G[key]
        if type(text) == "string" and text ~= "" then
            msgs[text] = true
        end
    end

    return msgs
end

local REFUSALS = nil   -- filled on load, once GlobalStrings exist

local function IsPole(itemId)
    if not itemId then
        return false
    end
    if KNOWN_POLES[itemId] then
        return true
    end
    return FishingSwapDB and FishingSwapDB.poles and FishingSwapDB.poles[itemId] or false
end

local function EquippedPoleId()
    local id = GetInventoryItemID("player", MAINHAND)
    return IsPole(id) and id or nil
end

-- The first pole found in the bags, as a bag/slot pair.
local function FindPoleInBags()
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local id = tonumber(link:match("item:(%d+)"))
                if IsPole(id) then
                    return bag, slot, id
                end
            end
        end
    end
end

-- Puts a pole on, remembering what it displaced.
--
-- Both weapon slots are saved, not just the main hand: the client treats a
-- fishing pole as a two-hander, so equipping one clears the off hand too.
local function EquipPole()
    if InCombatLockdown() or UnitAffectingCombat("player") then
        Debug("in combat, not touching your weapons")
        return false
    end

    if EquippedPoleId() then
        return false              -- already holding one, nothing to do
    end

    local bag, slot = FindPoleInBags()
    if not bag then
        Say("no fishing pole in your bags. If you are carrying one this does not know about, run: /fishswap pole <shift-click the pole>")
        return false
    end

    -- Only remember the originals on the first swap. A second refusal while
    -- still swapped must not overwrite them with the pole itself.
    if not state.swapped then
        state.mainhand = GetInventoryItemLink("player", MAINHAND)
        state.offhand  = GetInventoryItemLink("player", OFFHAND)
    end

    state.swapped   = true
    state.idleSince = nil

    ClearCursor()
    PickupContainerItem(bag, slot)
    EquipCursorItem(MAINHAND)

    Say("pole on - press Fishing again. Your weapons come back when you stop.")
    return true
end

local function RestoreGear()
    if not state.swapped then
        return
    end

    if InCombatLockdown() or UnitAffectingCombat("player") then
        return                    -- cannot equip in combat; try again later
    end

    -- If the pole is no longer the thing in hand, the player has moved on by
    -- themselves and putting the old weapons back would undo their choice.
    if not EquippedPoleId() then
        Debug("pole already off, leaving your gear alone")
        state.swapped = false
        return
    end

    if state.mainhand then
        EquipItemByName(state.mainhand, MAINHAND)
    end
    if state.offhand then
        EquipItemByName(state.offhand, OFFHAND)
    end

    state.swapped  = false
    state.mainhand = nil
    state.offhand  = nil

    Say("weapons back on.")
end

local FISHING = "Fishing"   -- replaced with the localised name on load

local function IsFishing()
    local channel = UnitChannelInfo("player")
    if channel and channel == FISHING then
        return true
    end
    local cast = UnitCastingInfo("player")
    return cast ~= nil and cast == FISHING
end

-- Restore on a timer rather than on an event.
--
-- There is no single "done fishing" event: a cast can end by catching
-- something, by being interrupted, or by the pool running out, and the loot
-- window outlives the channel. Waiting for a quiet stretch covers all of them
-- and costs one check a second.
local ticker = CreateFrame("Frame")
local elapsed = 0
ticker:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 1.0 then
        return
    end
    elapsed = 0

    if not state.swapped then
        return
    end

    local busy = IsFishing()
        or (LootFrame and LootFrame:IsShown())
        or UnitAffectingCombat("player")

    if busy then
        state.idleSince = nil
        return
    end

    state.idleSince = state.idleSince or GetTime()
    if GetTime() - state.idleSince >= RESTORE_DELAY then
        RestoreGear()
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("UI_ERROR_MESSAGE")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then
            return
        end
        FishingSwapDB = FishingSwapDB or {}
        FishingSwapDB.poles = FishingSwapDB.poles or {}
        REFUSALS = RefusalMessages()
        FISHING  = GetSpellInfo(7620) or FISHING
        return
    end

    -- UI_ERROR_MESSAGE, which is where a refused cast lands. The client
    -- refuses locally, so this is the only notice there is - nothing reaches
    -- the server to react to.
    if not REFUSALS or not REFUSALS[arg1] then
        Debug("ignored error: %s", tostring(arg1))
        return
    end

    EquipPole()
end)

SLASH_FISHINGSWAP1 = "/fishswap"
SlashCmdList["FISHINGSWAP"] = function(input)
    local cmd, rest = input:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()

    if cmd == "restore" then
        if state.swapped then
            RestoreGear()
        else
            Say("nothing to put back.")
        end
    elseif cmd == "pole" then
        local id = tonumber(rest:match("item:(%d+)") or rest:match("^(%d+)$"))
        if not id then
            Say("shift-click a pole into the command, or give its item id: /fishswap pole 6256")
            return
        end
        FishingSwapDB.poles[id] = true
        Say("item %d counts as a fishing pole now.", id)
    elseif cmd == "debug" then
        FishingSwapDB.debug = not FishingSwapDB.debug
        Say("debug %s. With this on, every UI error message is printed, so the exact wording of a refusal this does not recognise can be read off and added.",
            FishingSwapDB.debug and "on" or "off")
    else
        Say("press Fishing with a pole in your bags and this does the rest.")
        Say("/fishswap restore - put your weapons back now")
        Say("/fishswap pole <link> - teach it a pole it does not know")
        Say("/fishswap debug - print UI errors, to find a refusal it misses")
    end
end
