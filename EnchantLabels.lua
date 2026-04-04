-- ============================================================
--  Light Kit  |  Author: Hateless
--  EnchantLabels.lua – shows enchant names beside gear icons
-- ============================================================

LightUI.EnchantLabels = {}
local M = LightUI.EnchantLabels

local FONT      = "Fonts\\ARIALN.TTF"
local FONT_SIZE = 11

-- Maps slot name - which side the label anchors to.
local SIDE = {
    HeadSlot          = "right",
    NeckSlot          = "right",
    ShoulderSlot      = "right",
    BackSlot          = "right",
    ChestSlot         = "right",
    WristSlot         = "right",
    HandsSlot         = "left",
    WaistSlot         = "left",
    LegsSlot          = "left",
    FeetSlot          = "left",
    Finger0Slot       = "left",
    Finger1Slot       = "left",
    Trinket0Slot      = "left",
    Trinket1Slot      = "left",
    MainHandSlot      = "top",
    SecondaryHandSlot = "top",
}

-- Flat list used for iteration.
local SLOT_NAMES = {}
for name in pairs(SIDE) do
    SLOT_NAMES[#SLOT_NAMES + 1] = name
end

-- ----------------------------------------------------------------
--  Enchant detection
-- ----------------------------------------------------------------

local function GetEnchantText(unit, slotID)
    local itemData = C_TooltipInfo.GetInventoryItem(unit, slotID)
    if not itemData or not itemData.lines then return nil end
    for _, line in ipairs(itemData.lines) do
        -- type 15 is the enchant line; leftText is "Enchanted: Enchant Ring - Name"
        if line.type == 15 and line.leftText then
            local name = line.leftText:match("^Enchanted:%s*(.+)$")
            if name then
                name = name:match("^Enchant .-%s*%-%s*(.+)$") or name
                name = name:gsub("%s*|A:.-%|a%s*", "")   -- strip inline texture tags
                name = name:gsub("%s*%b()%s*$", "")       -- strip trailing (Rank N)
                name = name:match("^%s*(.-)%s*$")         -- trim whitespace
                return name ~= "" and name or nil
            end
        end
    end
    return nil
end

-- ----------------------------------------------------------------
--  Label creation
-- ----------------------------------------------------------------

local function GetOrCreateLabel(btn, side)
    if btn._luiEnchantLabel then return btn._luiEnchantLabel end

    local fs = btn:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, FONT_SIZE, "")
    fs:SetWordWrap(false)

    if side == "top" then
        fs:SetPoint("BOTTOM", btn, "TOP", 0, 3)
        fs:SetJustifyH("CENTER")
    elseif side == "right" then
        fs:SetPoint("LEFT", btn, "RIGHT", 4, 0)
        fs:SetJustifyH("LEFT")
    else  -- "left"
        fs:SetPoint("RIGHT", btn, "LEFT", -4, 0)
        fs:SetJustifyH("RIGHT")
    end

    btn._luiEnchantLabel = fs
    return fs
end

-- ----------------------------------------------------------------
--  Panel update
-- ----------------------------------------------------------------

local function UpdatePanel(prefix, unit)
    for _, name in ipairs(SLOT_NAMES) do
        local btn = _G[prefix .. name]
        if btn then
            local fs = GetOrCreateLabel(btn, SIDE[name])
            if LightKitDB.showEnchantLabels then
                fs:SetText(GetEnchantText(unit, btn:GetID()) or "")
            else
                fs:SetText("")
            end
        end
    end
end

-- ----------------------------------------------------------------
--  Public API
-- ----------------------------------------------------------------

function M:SetShown(shown)
    LightKitDB.showEnchantLabels = shown
    UpdatePanel("Character", "player")
    if InspectFrame and InspectFrame:IsShown() then
        UpdatePanel("Inspect", InspectFrame.unit or "target")
    end
end

-- ----------------------------------------------------------------
--  Init
-- ----------------------------------------------------------------

function M:Init()
    -- ---- Event-driven refreshes ---------------------------------
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    ev:RegisterEvent("INSPECT_READY")
    ev:SetScript("OnEvent", function(_, event)
        if not LightKitDB.showEnchantLabels then return end
        if event == "PLAYER_EQUIPMENT_CHANGED" then
            UpdatePanel("Character", "player")
        elseif event == "INSPECT_READY" then
            if InspectFrame and InspectFrame:IsShown() then
                UpdatePanel("Inspect", InspectFrame.unit or "target")
            end
        end
    end)

    -- ---- Character frame ----------------------------------------
    CharacterFrame:HookScript("OnShow", function()
        if LightKitDB.showEnchantLabels then
            UpdatePanel("Character", "player")
        end
    end)

    -- ---- Inspect frame (loaded on demand) -----------------------
    local addonEv = CreateFrame("Frame")
    addonEv:RegisterEvent("ADDON_LOADED")
    addonEv:SetScript("OnEvent", function(self, _, name)
        if name ~= "Blizzard_InspectUI" then return end
        InspectFrame:HookScript("OnShow", function()
            if LightKitDB.showEnchantLabels then
                UpdatePanel("Inspect", InspectFrame.unit or "target")
            end
        end)
        self:UnregisterEvent("ADDON_LOADED")
    end)
end
