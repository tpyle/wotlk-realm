--[[
    ExtraGlyphs - a panel for glyph effects beyond the six sockets.

    The client's glyph UI is drawn from six fixed update fields and cannot be
    given a seventh socket without patching Wow.exe, so extra glyphs do not
    appear there at all. This panel is the only view of them. It holds no
    state of its own: everything is asked of the server module
    (mod-extraglyphs) over the addon command channel the core provides, and
    the answers are drawn as they come back.

    Request:  SendAddonMessage("AzerothCore", "i0002extraglyphs <cmd>", "WHISPER", me)
    Replies:  CHAT_MSG_ADDON, prefix "AzerothCore", message = <op><echo><body>
                 a0002        acknowledged
                 m0002<line>  one line of output; ours all start with "EG "
                 o0002 / f0002  done, ok or failed

    Lines the server sends:
        EG head <spec> <max> <count>
        EG glyph <glyphId> <spellId> <itemEntry> <major|minor> <extra|socketed|none>
        EG added ... / EG removed ...   (same fields as glyph)
        EG err <text>

    Names and icons come from GetSpellInfo(spellId) on this side; glyph
    passives are named "Glyph of X" like the items, so nothing localised has
    to travel.

    Open it with /extraglyphs, /eg, or the "Extra" button on the glyph tab.
]]

local ECHO = "0002"
local PREFIX = "AzerothCore"

local ROWS = 12
local ROW_HEIGHT = 26

local state = {
    spec = 0, max = 0, count = 0,
    glyphs = {},        -- glyphId -> { spell, item, kind, state }
    order = {},         -- glyphIds sorted for display
    filter = "all",     -- all | major | minor | active
    message = nil,
    pending = nil,      -- what we are waiting on: "catalog" | "add" | "remove"
}

local function Send(cmd)
    SendAddonMessage(PREFIX, "i" .. ECHO .. "extraglyphs " .. cmd, "WHISPER", UnitName("player"))
end

------------------------------------------------------------------------------
-- Frame
------------------------------------------------------------------------------

local panel = CreateFrame("Frame", "ExtraGlyphsFrame", UIParent)
panel:SetWidth(420)
panel:SetHeight(ROWS * ROW_HEIGHT + 96)
panel:SetPoint("CENTER")
panel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:SetFrameStrata("DIALOG")
panel:Hide()
tinsert(UISpecialFrames, "ExtraGlyphsFrame")   -- Escape closes it

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -20)
title:SetText("Extra Glyphs")

local header = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
header:SetPoint("TOP", 0, -42)

local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)

local msgLine = panel:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
msgLine:SetPoint("BOTTOM", 0, 20)
msgLine:SetWidth(380)

-- filter buttons
local filters = {}
local function SetFilter(f)
    state.filter = f
    for name, b in pairs(filters) do
        if name == f then b:LockHighlight() else b:UnlockHighlight() end
    end
    ExtraGlyphs_Refresh()
end
local x = 24
for _, f in ipairs({ "all", "major", "minor", "active" }) do
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetWidth(64); b:SetHeight(20)
    b:SetPoint("TOPLEFT", x, -58)
    b:SetText(f:sub(1, 1):upper() .. f:sub(2))
    b:SetScript("OnClick", function() SetFilter(f) end)
    filters[f] = b
    x = x + 68
end

local refresh = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
refresh:SetWidth(70); refresh:SetHeight(20)
refresh:SetPoint("TOPRIGHT", -24, -58)
refresh:SetText("Refresh")
refresh:SetScript("OnClick", function() ExtraGlyphs_Request() end)

-- list
local scroll = CreateFrame("ScrollFrame", "ExtraGlyphsScroll", panel, "FauxScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 20, -84)
scroll:SetPoint("BOTTOMRIGHT", -40, 40)
scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, ExtraGlyphs_Refresh)
end)

local rows = {}
for i = 1, ROWS do
    local row = CreateFrame("Frame", nil, panel)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 22, -84 - (i - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", -40, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(22); row.icon:SetHeight(22)
    row.icon:SetPoint("LEFT", 2, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetWidth(170)
    row.name:SetJustifyH("LEFT")

    row.kind = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.kind:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
    row.kind:SetWidth(44)
    row.kind:SetJustifyH("LEFT")

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.status:SetPoint("LEFT", row.kind, "RIGHT", 2, 0)
    row.status:SetWidth(58)
    row.status:SetJustifyH("LEFT")

    row.button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.button:SetWidth(60); row.button:SetHeight(20)
    row.button:SetPoint("RIGHT", -2, 0)
    row.button:SetScript("OnClick", function(self)
        local g = self.glyphId
        if not g then return end
        state.message = nil
        if state.glyphs[g].state == "extra" then
            state.pending = "remove"
            Send("remove " .. g)
        else
            state.pending = "add"
            Send("add " .. g)
        end
    end)

    -- tooltip from the passive's spell, which describes the effect
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if not self.spellId then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("spell:" .. self.spellId)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    rows[i] = row
end

------------------------------------------------------------------------------
-- Drawing
------------------------------------------------------------------------------

local function Visible()
    local out = {}
    for _, g in ipairs(state.order) do
        local e = state.glyphs[g]
        local f = state.filter
        if f == "all"
            or (f == "major" and e.kind == "major")
            or (f == "minor" and e.kind == "minor")
            or (f == "active" and e.state ~= "none") then
            tinsert(out, g)
        end
    end
    return out
end

function ExtraGlyphs_Refresh()
    if not panel:IsShown() then return end

    local limit = state.max > 0 and tostring(state.max) or "no limit"
    header:SetText(("Spec %d - %d extra glyph(s), limit %s"):format(state.spec + 1, state.count, limit))
    msgLine:SetText(state.message or "")

    local list = Visible()
    FauxScrollFrame_Update(scroll, #list, ROWS, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(scroll)

    for i = 1, ROWS do
        local row = rows[i]
        local g = list[i + offset]
        if g then
            local e = state.glyphs[g]
            local name, _, icon = GetSpellInfo(e.spell)
            row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.name:SetText(name or ("Glyph " .. g))
            row.kind:SetText(e.kind == "minor" and "Minor" or "Major")
            row.spellId = e.spell
            row.button.glyphId = g

            local have = GetItemCount(e.item) or 0
            if e.state == "extra" then
                row.status:SetText("|cff40ff40Extra|r")
                row.button:SetText("Remove")
                row.button:Enable()
            elseif e.state == "socketed" then
                row.status:SetText("|cffa0a0ffSocketed|r")
                row.button:SetText("Apply")
                row.button:Disable()
            else
                row.status:SetText(have > 0 and ("x" .. have) or "")
                row.button:SetText("Apply")
                if have > 0 and (state.max == 0 or state.count < state.max) then
                    row.button:Enable()
                else
                    row.button:Disable()
                end
            end
            row:Show()
        else
            row.spellId = nil
            row.button.glyphId = nil
            row:Hide()
        end
    end
end

function ExtraGlyphs_Request()
    state.pending = "catalog"
    state.message = nil
    Send("catalog")
end

------------------------------------------------------------------------------
-- Replies
------------------------------------------------------------------------------

local function SortOrder()
    state.order = {}
    for g in pairs(state.glyphs) do tinsert(state.order, g) end
    table.sort(state.order, function(a, b)
        local ea, eb = state.glyphs[a], state.glyphs[b]
        if ea.kind ~= eb.kind then return ea.kind == "major" end
        local na = GetSpellInfo(ea.spell) or ""
        local nb = GetSpellInfo(eb.spell) or ""
        return na < nb
    end)
end

local function OnLine(line)
    local words = {}
    for w in line:gmatch("%S+") do tinsert(words, w) end
    if words[1] ~= "EG" then return end
    local what = words[2]

    if what == "head" then
        state.spec  = tonumber(words[3]) or 0
        state.max   = tonumber(words[4]) or 0
        state.count = tonumber(words[5]) or 0
        if state.pending == "catalog" then state.glyphs = {} end
    elseif what == "glyph" or what == "added" or what == "removed" then
        local g = tonumber(words[3])
        if g then
            state.glyphs[g] = {
                spell = tonumber(words[4]) or 0,
                item  = tonumber(words[5]) or 0,
                kind  = words[6] or "major",
                state = words[7] or "none",
            }
            if what == "added"   then state.count = state.count + 1 end
            if what == "removed" then state.count = math.max(0, state.count - 1) end
        end
    elseif what == "err" then
        state.message = line:sub(8)
    end
end

local replies = CreateFrame("Frame")
replies:RegisterEvent("CHAT_MSG_ADDON")
replies:RegisterEvent("BAG_UPDATE")
replies:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
replies:SetScript("OnEvent", function(self, event, prefix, message)
    if event == "BAG_UPDATE" then
        ExtraGlyphs_Refresh()          -- a glyph item arrived or was consumed
        return
    end
    if event == "ACTIVE_TALENT_GROUP_CHANGED" then
        if panel:IsShown() then ExtraGlyphs_Request() end
        return
    end
    if prefix ~= PREFIX or type(message) ~= "string" then return end
    local op, echo, body = message:sub(1, 1), message:sub(2, 5), message:sub(6)
    if echo ~= ECHO then return end

    if op == "m" then
        OnLine(body)
    elseif op == "o" or op == "f" then
        if state.pending == "catalog" or op == "o" then
            SortOrder()
        end
        state.pending = nil
        ExtraGlyphs_Refresh()
    end
end)

------------------------------------------------------------------------------
-- Entry points
------------------------------------------------------------------------------

local function Toggle()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
        SetFilter(state.filter)
        ExtraGlyphs_Request()
    end
end

SLASH_EXTRAGLYPHS1 = "/extraglyphs"
SLASH_EXTRAGLYPHS2 = "/eg"
SlashCmdList["EXTRAGLYPHS"] = Toggle

-- An "Extra" button on the glyph tab of the talent window, which is a
-- load-on-demand Blizzard addon, so wait for it.
local function InstallButton()
    if not GlyphFrame or GlyphFrame.ExtraGlyphsButton then return end
    local b = CreateFrame("Button", nil, GlyphFrame, "UIPanelButtonTemplate")
    b:SetWidth(60); b:SetHeight(22)
    b:SetPoint("BOTTOMRIGHT", GlyphFrame, "BOTTOMRIGHT", -40, 14)
    b:SetText("Extra")
    b:SetScript("OnClick", Toggle)
    GlyphFrame.ExtraGlyphsButton = b
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, addon)
    if addon == "Blizzard_TalentUI" or addon == "Blizzard_GlyphUI" then
        InstallButton()
    end
end)
if IsAddOnLoaded("Blizzard_TalentUI") then InstallButton() end
