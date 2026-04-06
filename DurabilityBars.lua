-- ============================================================
--  Light Kit  |  Author: Hateless
--  DurabilityBars.lua – renders a color-coded durability bar
--  on each gear slot icon in the Character panel.
--    100 % → green    50 % → yellow    0 % → red
-- ============================================================

LightUI.DurabilityBars = {}
local M = LightUI.DurabilityBars

-- Only slots that can carry durability in WoW.
local DUR_SLOT_NAMES = {
    "HeadSlot", "ShoulderSlot", "BackSlot",  "ChestSlot",
    "WristSlot", "HandsSlot",   "WaistSlot", "LegsSlot",
    "FeetSlot",  "MainHandSlot", "SecondaryHandSlot",
}

local BAR_WIDTH = 4   -- pixels wide

-- ----------------------------------------------------------------
--  Color helper  green (100 %) → yellow (50 %) → red (0 %)
-- ----------------------------------------------------------------
local function DurabilityColor(pct)
    if pct >= 0.5 then
        local t = (pct - 0.5) * 2   -- 1 at 100 %, 0 at 50 %
        return 1 - t, 1, 0           -- r fades in, g stays 1
    else
        local t = pct * 2            -- 1 at 50 %, 0 at 0 %
        return 1, t, 0               -- r stays 1, g fades out
    end
end

-- ----------------------------------------------------------------
--  Per-button bar widget
-- ----------------------------------------------------------------
local function GetOrCreateBar(button)
    if button._luiDurBar then return button._luiDurBar end

    -- Dark background – spans the full (padded) height of the slot icon.
    local bg = button:CreateTexture(nil, "OVERLAY", nil, 1)
    bg:SetColorTexture(0, 0, 0, 0.65)
    bg:SetWidth(BAR_WIDTH)
    bg:SetPoint("TOPRIGHT",    button, "TOPRIGHT",    -1, -1)
    bg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1,  1)

    -- Coloured fill – anchored at the bottom, height driven by durability %.
    local fill = button:CreateTexture(nil, "OVERLAY", nil, 2)
    fill:SetColorTexture(0, 1, 0, 1)
    fill:SetWidth(BAR_WIDTH)
    fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    fill:SetHeight(1)   -- real height set in UpdateBar

    button._luiDurBar = { bg = bg, fill = fill }
    return button._luiDurBar
end

-- ----------------------------------------------------------------
--  Update a single gear-slot button
-- ----------------------------------------------------------------
local function UpdateBar(button)
    local bar = GetOrCreateBar(button)

    if not LightKitDB.showDurabilityBars then
        bar.bg:Hide()
        bar.fill:Hide()
        return
    end

    local slotID          = button:GetID()
    local link            = GetInventoryItemLink("player", slotID)
    local cur, max        = GetInventoryItemDurability(slotID)

    if not link or not cur or not max or max == 0 then
        bar.bg:Hide()
        bar.fill:Hide()
        return
    end

    local pct    = cur / max
    local btnH   = button:GetHeight()
    if not btnH or btnH < 4 then btnH = 36 end
    local availH = btnH - 2                            -- 1 px top + 1 px bottom padding
    local fillH  = math.max(1, math.floor(availH * pct))

    local r, g, b = DurabilityColor(pct)
    bar.fill:SetColorTexture(r, g, b, 1)
    bar.fill:SetHeight(fillH)
    bar.bg:Show()
    bar.fill:Show()
end

-- ----------------------------------------------------------------
--  Refresh all tracked slots
-- ----------------------------------------------------------------
local function UpdateAllSlots()
    for _, name in ipairs(DUR_SLOT_NAMES) do
        local btn = _G["Character" .. name]
        if btn then UpdateBar(btn) end
    end
end

-- ----------------------------------------------------------------
--  Public API
-- ----------------------------------------------------------------
function M:SetShown(shown)
    LightKitDB.showDurabilityBars = shown
    UpdateAllSlots()
end

-- ----------------------------------------------------------------
--  Init
-- ----------------------------------------------------------------
function M:Init()
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    ev:SetScript("OnEvent", function()
        if LightKitDB.showDurabilityBars and CharacterFrame:IsShown() then
            UpdateAllSlots()
        end
    end)

    CharacterFrame:HookScript("OnShow", function()
        if LightKitDB.showDurabilityBars then
            UpdateAllSlots()
        end
    end)
end
