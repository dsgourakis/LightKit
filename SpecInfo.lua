-- ============================================================
--  Light Kit  |  Author: Hateless
--  SpecInfo.lua – active spec, loot spec & talent loadout indicator
--
--  Shows a small persistent frame with up to three segments:
--    Spec: [icon]    Loot: [icon]    Loadout: name
--  Each segment can be toggled independently.
--  The loot spec icon turns yellow-tinted when pinned to a spec
--  that differs from your active spec.
-- ============================================================

LightUI.SpecInfo = {}
local M = LightUI.SpecInfo

local FONT = "Fonts\\ARIALN.TTF"

-- ----------------------------------------------------------------
--  Public API
-- ----------------------------------------------------------------

function M:Init()
    self:_BuildFrame()
    self.frame:SetShown(LightKitDB.showSpecInfo)
    self:_Update()
end

function M:SetShown(shown)
    LightKitDB.showSpecInfo = shown
    self.frame:SetShown(shown)
end

function M:SetLocked(locked)
    LightKitDB.specInfoFrameLocked = locked
end

function M:SetFontSize(size)
    LightKitDB.specInfoFontSize = size
    self.label:SetFont(FONT, size, "")
    self.frame:SetHeight(size + 8)
    self:_Update()
end

function M:SetShowSpec(shown)
    LightKitDB.specInfoShowSpec = shown
    self:_Update()
end

function M:SetShowLoot(shown)
    LightKitDB.specInfoShowLoot = shown
    self:_Update()
end

function M:SetShowLoadout(shown)
    LightKitDB.specInfoShowLoadout = shown
    self:_Update()
end

-- ----------------------------------------------------------------
--  Data helpers
-- ----------------------------------------------------------------

-- Returns (name, icon) for the currently active spec.
local function GetActiveSpecData()
    local specIndex = GetSpecialization()
    if not specIndex then return nil, nil end
    local _, name, _, icon = GetSpecializationInfo(specIndex)
    return name, icon
end

-- Returns (name, icon, isFollowingActive).
-- isFollowingActive is true when loot spec tracks the active spec
-- (i.e. GetLootSpecialization() == 0).
local function GetLootSpecData()
    local lootSpecID = GetLootSpecialization()
    if lootSpecID == 0 then
        local specIndex = GetSpecialization()
        if not specIndex then return "Unknown", nil, true end
        local _, name, _, icon = GetSpecializationInfo(specIndex)
        return name or "Unknown", icon, true
    else
        local _, name, _, icon = GetSpecializationInfoByID(lootSpecID)
        return name or "Unknown", icon, false
    end
end

local function GetLoadoutName()
    if not C_ClassTalents then return nil end

    -- Starter Build is a special built-in config with no saved config ID.
    if C_ClassTalents.GetHasStarterBuild and C_ClassTalents.GetHasStarterBuild()
    and C_ClassTalents.GetStarterBuildActive and C_ClassTalents.GetStarterBuildActive() then
        return _G.TALENT_FRAME_DROP_DOWN_STARTER_BUILD or "Starter Build"
    end

    -- GetLastSelectedSavedConfigID returns the user's named saved loadout.
    if C_ClassTalents.GetLastSelectedSavedConfigID then
        local specIndex = GetSpecialization()
        local specID    = specIndex and select(1, GetSpecializationInfo(specIndex))
        if specID then
            local configID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
            if configID then
                local info = C_Traits and C_Traits.GetConfigInfo(configID)
                if info and info.name ~= "" then return info.name end
            end
        end
    end

    return nil
end

-- ----------------------------------------------------------------
--  Internal
-- ----------------------------------------------------------------

function M:_BuildLootMenu()
    local f = CreateFrame("Frame", "LightUI_LootSpecMenu", UIParent, "BackdropTemplate")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:Hide()
    f:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    f:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
    f.buttons = {}
    self._lootMenu = f
end

function M:_ShowLootSpecMenu(anchor)
    if not self._lootMenu then self:_BuildLootMenu() end
    local f = self._lootMenu

    -- Toggle closed if already open.
    if f:IsShown() then f:Hide(); return end

    -- Entries: "follow active" + one per spec.
    local entries = {{ label = "Follow Active Spec", id = 0 }}
    for i = 1, GetNumSpecializations() do
        local specID, name = GetSpecializationInfo(i)
        if specID then
            entries[#entries + 1] = { label = name, id = specID }
        end
    end

    local currentLoot = GetLootSpecialization()
    local BTN_H    = 20
    local PAD      = 6
    local fontSize = LightKitDB.specInfoFontSize

    -- Grow button pool as needed.
    for i = #f.buttons + 1, #entries do
        local btn = CreateFrame("Button", nil, f)
        btn:SetHeight(BTN_H)

        local mark = btn:CreateFontString(nil, "OVERLAY")
        mark:SetFont(FONT, fontSize, "")
        mark:SetPoint("LEFT", btn, "LEFT", 4, 0)
        btn.mark = mark

        local lbl = btn:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(FONT, fontSize, "")
        lbl:SetPoint("LEFT", btn, "LEFT", 20, 0)
        lbl:SetTextColor(1, 1, 1)
        btn.lbl = lbl

        btn:SetScript("OnEnter", function(b) b.lbl:SetTextColor(1, 1, 0) end)
        btn:SetScript("OnLeave", function(b) b.lbl:SetTextColor(1, 1, 1) end)
        btn:SetScript("OnClick", function(b)
            SetLootSpecialization(b._id)
            f:Hide()
        end)
        f.buttons[i] = btn
    end

    -- Populate and measure max width.
    local maxW = 80
    for i, entry in ipairs(entries) do
        local btn = f.buttons[i]
        btn._id = entry.id
        btn.lbl:SetText(entry.label)
        btn.mark:SetText(entry.id == currentLoot and "|cff44ff44>|r" or " ")
        btn:Show()
        local w = btn.lbl:GetStringWidth() + 28
        if w > maxW then maxW = w end
    end
    for i = #entries + 1, #f.buttons do
        f.buttons[i]:Hide()
    end

    -- Size the frame and position all buttons.
    local W = maxW + PAD * 2
    local H = PAD * 2 + #entries * BTN_H
    f:SetSize(W, H)
    for i = 1, #entries do
        local btn = f.buttons[i]
        btn:SetWidth(W - PAD * 2)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -PAD - (i - 1) * BTN_H)
    end

    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
    f:Show()
end

-- Build an inline texture escape sized to match the current font.
local function Icon(texture, size)
    if not texture then return "?" end
    return "|T" .. texture .. ":" .. size .. ":" .. size .. "|t"
end

function M:_Update()
    if not self.frame then return end

    local size        = LightKitDB.specInfoFontSize
    local showSpec    = LightKitDB.specInfoShowSpec
    local showLoot    = LightKitDB.specInfoShowLoot
    local showLoadout = LightKitDB.specInfoShowLoadout

    local activeSpecName, activeIcon          = GetActiveSpecData()
    local lootSpecName, lootIcon, isFollowing = GetLootSpecData()
    local loadoutName                         = GetLoadoutName()

    local parts = {}

    if showSpec then
        parts[#parts + 1] = "|cffffffff" .. "Spec:|r " .. Icon(activeIcon, size)
    end

    if showLoot then
        local lootLabel = isFollowing
            and "|cffffffff" .. "Loot:|r "
            or  "|cffffd700" .. "Loot:|r "
        parts[#parts + 1] = lootLabel .. Icon(lootIcon, size)
    end

    if showLoadout then
        local name = loadoutName or "–"
        parts[#parts + 1] = "|cffffffff" .. "Loadout:|r |cffffffff" .. name .. "|r"
    end

    local text = #parts > 0 and table.concat(parts, " ") or "|cff666666–|r"
    self.label:SetText(text)

    -- Resize the frame to tightly wrap the label.
    self.frame:SetWidth(math.max(self.label:GetStringWidth() + 16, 40))
end

function M:_BuildFrame()
    local f = CreateFrame("Frame", "LightUI_SpecInfoFrame", UIParent, "BackdropTemplate")
    f:SetSize(120, LightKitDB.specInfoFontSize + 8)

    LightUI.ApplyFrameStyle(f, LightKitDB.frameStyle)
    LightUI.MakeDraggable(f, "specInfoFrame", "specInfoFrameLocked", true)

    -- Restore saved position; anchor chain is applied by LightUI.RefreshAnchorChain.
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
               LightKitDB.specInfoFrame.x, LightKitDB.specInfoFrame.y)

    local label = f:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT, LightKitDB.specInfoFontSize, "")
    label:SetShadowColor(0, 0, 0, 0.9)
    label:SetShadowOffset(1, -1)
    label:SetPoint("LEFT", f, "LEFT", 6, 0)
    self.label = label

    -- Right-click opens the loot spec picker.
    f:SetScript("OnMouseUp", function(frame, button)
        if button == "RightButton" then
            M:_ShowLootSpecMenu(frame)
        end
    end)

    -- Event-driven refresh.
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    eventFrame:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED")
    eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    eventFrame:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then return end
        C_Timer.After(0, function() M:_Update() end)
    end)

    self.frame = f
end
