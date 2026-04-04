-- ============================================================
--  Light Kit  |  Author: Hateless
--  ItemLevelIcons.lua – renders item level over gear icons in
--  the Character panel, Bags, and Inspect panel.
-- ============================================================

LightUI.ItemLevelIcons = {}
local M = LightUI.ItemLevelIcons

local allOverlays = {}

-- Available fonts exposed to the options dropdown.
-- To add a custom font: { path = "Interface\\AddOns\\YourAddon\\fonts\\myfont.ttf", label = "My Font" }
M.FONTS = {
    { path = "Fonts\\FRIZQT__.TTF",                                      label = "Friz Quadrata (default)" },
    { path = "Fonts\\ARIALN.TTF",                                        label = "Arial Narrow" },
    { path = "Fonts\\SKURRI.TTF",                                        label = "Skurri" },
    { path = "Fonts\\MORPHEUS.TTF",                                      label = "Morpheus" },
    { path = "Fonts\\BLAMG___.TTF",                                      label = "Blambotgames" },
    { path = "Interface\\AddOns\\LightUIImprovements\\Fonts\\Impact.ttf", label = "Impact" },
}

-- ----------------------------------------------------------------
--  Overlay helpers
-- ----------------------------------------------------------------

local function GetOrCreateOverlay(button)
    if button._luiIlvl then return button._luiIlvl end
    local fs = button:CreateFontString(nil, "OVERLAY")
    fs:SetFont(LightKitDB.itemLevelIconFont, LightKitDB.itemLevelIconFontSize, "OUTLINE")
    fs:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
    button._luiIlvl = fs
    allOverlays[#allOverlays + 1] = fs
    return fs
end

-- Reapply the current font + size selected e.g. after changing them in the options.
function M:RefreshFont()
    local font = LightKitDB.itemLevelIconFont
    local size = LightKitDB.itemLevelIconFontSize

    for _, fs in ipairs(allOverlays) do
        fs:SetFont(font, size, "OUTLINE")
    end
    C_Timer.After(0, function()
        for _, fs in ipairs(allOverlays) do
            fs:SetText(fs:GetText() or "")
        end
    end)
end

-- Returns true if the item link is equippable (weapon, armor, jewelry, etc.).
local function IsEquippable(link)
    return link ~= nil and IsEquippableItem(link)
end

-- Write the ilvl from `link` onto `button`, or clear if disabled/empty.
local function ApplyIlvl(button, link)
    local fs = GetOrCreateOverlay(button)
    if LightKitDB.showItemLevelIcons and link then
        local ilvl = GetDetailedItemLevelInfo(link)
        fs:SetText((ilvl and ilvl > 0) and ilvl or "")
    else
        fs:SetText("")
    end
end

-- ----------------------------------------------------------------
--  Character & Inspect gear panels
-- ----------------------------------------------------------------

local SLOT_NAMES = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot",
    "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
    "MainHandSlot", "SecondaryHandSlot",
}

local function UpdateGearPanel(prefix, unit)
    for _, name in ipairs(SLOT_NAMES) do
        local btn = _G[prefix .. name]
        if btn then
            ApplyIlvl(btn, GetInventoryItemLink(unit, btn:GetID()))
        end
    end
end

-- ----------------------------------------------------------------
--  Bag panel
-- ----------------------------------------------------------------

local function UpdateBagButton(btn)
    local bag, slot = btn.bagID, btn:GetID()
    if not bag or not slot then return end
    local link = C_Container.GetContainerItemLink(bag, slot)
    -- Only label equippable items of Uncommon quality or higher;
    if IsEquippable(link) then
        local _, _, quality = GetItemInfo(link)
        ApplyIlvl(btn, (quality and quality >= 2) and link or nil)
    else
        ApplyIlvl(btn, nil)
    end
end

local function UpdateAllBags()
    -- Standard per-bag frames
    for bagIndex = 0, NUM_BAG_SLOTS do
        local frame = _G["ContainerFrame" .. (bagIndex + 1)]
        if frame and frame.Items then
            for _, btn in ipairs(frame.Items) do
                UpdateBagButton(btn)
            end
        end
    end
    -- Combined-bags frame
    local cbf = ContainerFrameCombinedBags
    if cbf and cbf.Items then
        for _, btn in ipairs(cbf.Items) do
            UpdateBagButton(btn)
        end
    end
end

-- ----------------------------------------------------------------
--  Public API
-- ----------------------------------------------------------------

function M:SetShown(shown)
    LightKitDB.showItemLevelIcons = shown
    UpdateGearPanel("Character", "player")
    if InspectFrame and InspectFrame:IsShown() then
        UpdateGearPanel("Inspect", InspectFrame.unit or "target")
    end
    UpdateAllBags()
end

-- ----------------------------------------------------------------
--  Init
-- ----------------------------------------------------------------

function M:Init()
    -- ---- Event-driven refreshes ---------------------------------
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    ev:RegisterEvent("BAG_UPDATE_DELAYED")
    ev:RegisterEvent("INSPECT_READY")
    ev:SetScript("OnEvent", function(_, event)
        if not LightKitDB.showItemLevelIcons then return end
        if event == "PLAYER_EQUIPMENT_CHANGED" then
            UpdateGearPanel("Character", "player")
        elseif event == "BAG_UPDATE_DELAYED" then
            UpdateAllBags()
        elseif event == "INSPECT_READY" then
            if InspectFrame and InspectFrame:IsShown() then
                UpdateGearPanel("Inspect", InspectFrame.unit or "target")
            end
        end
    end)

    -- ---- Character frame ----------------------------------------
    CharacterFrame:HookScript("OnShow", function()
        if LightKitDB.showItemLevelIcons then
            UpdateGearPanel("Character", "player")
        end
    end)

    -- ---- Inspect frame (loaded on demand via Blizzard_InspectUI) -
    local addonEv = CreateFrame("Frame")
    addonEv:RegisterEvent("ADDON_LOADED")
    addonEv:SetScript("OnEvent", function(self, _, name)
        if name ~= "Blizzard_InspectUI" then return end
        InspectFrame:HookScript("OnShow", function()
            -- INSPECT_READY fires the actual update once data is ready;
            -- OnShow just clears stale overlays from the previous target.
            UpdateGearPanel("Inspect", InspectFrame.unit or "target")
        end)
        self:UnregisterEvent("ADDON_LOADED")
    end)

    -- ---- Bag frames ---------------------------------------------
    for i = 1, NUM_BAG_SLOTS + 1 do
        local frame = _G["ContainerFrame" .. i]
        if frame then
            frame:HookScript("OnShow", function()
                if LightKitDB.showItemLevelIcons then
                    -- Defer one frame so item data is populated first.
                    C_Timer.After(0, UpdateAllBags)
                end
            end)
        end
    end
    if ContainerFrameCombinedBags then
        ContainerFrameCombinedBags:HookScript("OnShow", function()
            if LightKitDB.showItemLevelIcons then
                C_Timer.After(0, UpdateAllBags)
            end
        end)
    end
end
