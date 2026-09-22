--[[
    Bank Reagents

    The server is configured with Crafting.AllowBankReagents, so a craft draws
    any reagents it cannot find in the bags out of the bank instead, without
    moving anything. The stock trade skill window does not know that: it counts
    bags only, greys out the reagents it thinks are missing, and disables
    Create. The craft would succeed if it were ever sent.

    This addon does not change any of that logic - it runs after Blizzard's own
    and corrects three things:

      * the reagent counts, which now include bank stock
      * the grey-out, removed for reagents the bank can cover
      * the Create buttons, left enabled so the server decides

    It only ever raises counts and enables buttons, never the reverse, so with
    the server option off the worst case is a craft that fails with the usual
    "you do not have the required reagents".

    That is the display half. The other half is why this addon talks to the
    server at all: the client runs its own reagent check against the bags in
    the executable, before sending a craft, and no addon can change that. So
    when a recipe is selected (and again after every craft) the addon asks the
    server to move that recipe's reagents from the bank into the bags - one
    stack per reagent - through the core's addon command channel. An addon
    message with the "AzerothCore" prefix and opcode 'i' is run as a command
    from the player and never shown as chat. The server side is
    mod-bankreagents.

    Why an addon and not a patched Blizzard_TradeSkillUI.lua in an MPQ: the
    client verifies its own addons and refuses a modified one with
    "Couldn't load Blizzard_TradeSkillUI: Corrupt". Hooking from outside has no
    signature to satisfy.
]]

local HIGHLIGHT = HIGHLIGHT_FONT_COLOR

-- Bags plus bank, via GetItemCount's includeBank argument. Returns nil when
-- the reagent has no link yet (the item is not cached client side), in which
-- case Blizzard's own bag-only number is left alone.
local function CountWithBank(skillIndex, reagentIndex)
    local link = GetTradeSkillReagentItemLink(skillIndex, reagentIndex)
    if not link then
        return nil
    end
    return GetItemCount(link, true)
end

-- How many of recipe skillIndex the reagents allow once the bank is counted.
-- Mirrors what the client computes for the [N] in the list, but with bank
-- stock included. Returns nil when a reagent's link is not cached yet.
local function BankAvailable(skillIndex)
    local numReagents = GetTradeSkillNumReagents(skillIndex)
    if not numReagents or numReagents == 0 then
        return nil
    end

    local canMake
    for i = 1, numReagents do
        local reagentName, _, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(skillIndex, i)
        if reagentName and reagentCount and reagentCount > 0 then
            local withBank = CountWithBank(skillIndex, i)
            if withBank and withBank > playerReagentCount then
                playerReagentCount = withBank
            end
            local possible = floor(playerReagentCount / reagentCount)
            if not canMake or possible < canMake then
                canMake = possible
            end
        end
    end
    return canMake
end

-- The [N] beside each recipe in the list. Blizzard draws it from
-- GetTradeSkillInfo's numAvailable, which is bag-only; redraw it for the
-- eight visible rows with the bank counted, using the same width logic.
local function RefreshList()
    if not TradeSkillFrame or not TradeSkillFrame:IsShown() then
        return
    end

    local numTradeSkills = GetNumTradeSkills()
    local offset = FauxScrollFrame_GetOffset(TradeSkillListScrollFrame)

    for i = 1, TRADE_SKILLS_DISPLAYED do
        local skillIndex = i + offset
        if skillIndex > numTradeSkills then
            break
        end

        local skillName, skillType, numAvailable = GetTradeSkillInfo(skillIndex)
        if skillName and skillType ~= "header" then
            local shown = math.abs(numAvailable or 0)
            local withBank = BankAvailable(skillIndex)
            if withBank and withBank > shown then
                local skillButtonText = _G["TradeSkillSkill" .. i .. "Text"]
                local skillButtonCount = _G["TradeSkillSkill" .. i .. "Count"]
                if skillButtonText and skillButtonCount then
                    skillButtonCount:SetText("[" .. withBank .. "]")
                    TradeSkillFrameDummyString:SetText(" " .. skillName)
                    local nameWidth = TradeSkillFrameDummyString:GetWidth()
                    local countWidth = skillButtonCount:GetWidth()
                    if nameWidth + 2 + countWidth > TRADE_SKILL_TEXT_WIDTH then
                        skillButtonText:SetWidth(TRADE_SKILL_TEXT_WIDTH - 2 - countWidth)
                    else
                        skillButtonText:SetWidth(0)
                    end
                end
            end
        end
    end
end

-- Ask the server to top the bags up for the selected recipe. The command
-- counter is four characters by protocol; the value is irrelevant here.
local lastPullSpell, lastPullTime = nil, 0

local function RequestPull(force)
    local id = TradeSkillFrame and TradeSkillFrame.selectedSkill
    if not id or id == 0 then
        return
    end

    local link = GetTradeSkillRecipeLink(id)
    if not link then
        return
    end
    local spellId = tonumber(string.match(link, "enchant:(%d+)"))
    if not spellId then
        return
    end

    -- Once per selection, and at most a couple of times a second while a run
    -- of crafts keeps consuming what was pulled.
    local now = GetTime()
    if not force and spellId == lastPullSpell and (now - lastPullTime) < 0.5 then
        return
    end
    lastPullSpell, lastPullTime = spellId, now

    SendAddonMessage("AzerothCore", "i0001bankreagents pull " .. spellId, "WHISPER", UnitName("player"))
end

local function RefreshSelection()
    local id = TradeSkillFrame and TradeSkillFrame.selectedSkill
    if not id or id == 0 then
        return
    end

    local numReagents = GetTradeSkillNumReagents(id)
    if not numReagents or numReagents == 0 then
        return
    end

    local canMake

    for i = 1, numReagents do
        local reagentName, reagentTexture, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(id, i)
        if reagentName and reagentTexture then
            local withBank = CountWithBank(id, i)
            if withBank and withBank > playerReagentCount then
                playerReagentCount = withBank

                -- Blizzard greyed this one out on the bag count; it is covered.
                if playerReagentCount >= reagentCount then
                    local reagent = _G["TradeSkillReagent" .. i]
                    local name = _G["TradeSkillReagent" .. i .. "Name"]
                    if reagent then
                        SetItemButtonTextureVertexColor(reagent, 1.0, 1.0, 1.0)
                    end
                    if name then
                        name:SetTextColor(HIGHLIGHT.r, HIGHLIGHT.g, HIGHLIGHT.b)
                    end
                end

                local count = _G["TradeSkillReagent" .. i .. "Count"]
                if count then
                    local shown = playerReagentCount
                    if shown >= 100 then
                        shown = "*"
                    end
                    count:SetText(shown .. " /" .. reagentCount)
                end
            end

            -- How many the reagents actually allow, so Create All asks for a
            -- sensible number instead of the bag-only zero.
            if reagentCount and reagentCount > 0 then
                local possible = floor(playerReagentCount / reagentCount)
                if not canMake or possible < canMake then
                    canMake = possible
                end
            end
        end
    end

    if canMake and canMake > (TradeSkillFrame.numAvailable or 0) then
        TradeSkillFrame.numAvailable = canMake
    end

    -- Never disabled here, only enabled: the server has the whole picture and
    -- is the only side that can refuse correctly.
    if TradeSkillCreateButton then
        TradeSkillCreateButton:Enable()
    end
    if TradeSkillCreateAllButton then
        TradeSkillCreateAllButton:Enable()
    end
end

local hooked = false

local function Install()
    if hooked then
        return
    end
    hooked = true

    -- Blizzard_TradeSkillUI is load on demand, so the functions below do not
    -- exist until it has loaded. Post-hooks run after the original.
    hooksecurefunc("TradeSkillFrame_SetSelection", function()
        RequestPull(true)
        RefreshSelection()
    end)
    hooksecurefunc("TradeSkillFrame_Update", function()
        RefreshList()
        RefreshSelection()
    end)

    -- Stock moving in or out of the bank has to redraw the counts.
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("BAG_UPDATE")
    watcher:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    watcher:RegisterEvent("TRADE_SKILL_UPDATE")
    watcher:SetScript("OnEvent", function()
        if TradeSkillFrame and TradeSkillFrame:IsShown() then
            -- a craft just consumed some of what was pulled: top up again
            RequestPull(false)
            RefreshList()
            RefreshSelection()
        end
    end)

end

-- The server answers each request on the same channel (ack / ok / failed).
-- Nothing displays LANG_ADDON whispers unless an addon does, so this is only
-- here to make that explicit.
local replies = CreateFrame("Frame")
replies:RegisterEvent("CHAT_MSG_ADDON")
replies:SetScript("OnEvent", function(self, event, prefix)
    -- "AzerothCore" replies are intentionally ignored
end)

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" and addon == "Blizzard_TradeSkillUI" then
        Install()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- If something else pulled the trade skill window in before this addon ran,
-- ADDON_LOADED has already fired for it and will not fire again.
if IsAddOnLoaded("Blizzard_TradeSkillUI") then
    Install()
end
