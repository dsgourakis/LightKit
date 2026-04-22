-- ============================================================
--  Light Kit  |  Author: Hateless
--  Core.lua – namespace, saved-variable initialisation
-- ============================================================

LightUI = {}
LightUI.ADDON_NAME = "LightKit"

-- ----------------------------------------------------------------
--  LightUI.SnapFrame(frame, dbKey)
--  Snaps `frame` to an 4px grid after a drag and saves the result
--  into LightKitDB[dbKey] = { x, y } (TOPLEFT relative to UIParent).
-- ----------------------------------------------------------------
function LightUI.SnapFrame(frame, dbKey)
    local x, y
    if LightKitDB.snapToGrid then
        local grid = 4
        x = math.floor(frame:GetLeft() / grid + 0.5) * grid
        y = math.floor((frame:GetTop() - UIParent:GetHeight()) / grid + 0.5) * grid
    else
        x = frame:GetLeft()
        y = frame:GetTop() - UIParent:GetHeight()
    end
    LightKitDB[dbKey] = { x = x, y = y }
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
end

-- ----------------------------------------------------------------
--  LightUI.ApplyFrameStyle(frame, style)
--  Applies a named backdrop style to a BackdropTemplate frame.
--  Styles: "tooltip" (default), "minimal" (flat, no border), "none"
-- ----------------------------------------------------------------
function LightUI.ApplyFrameStyle(frame, style)
    if style == "minimal" then
        frame:SetBackdrop({
            bgFile  = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 0,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        frame:SetBackdropColor(0, 0, 0, 0.5)
        frame:SetBackdropBorderColor(0, 0, 0, 0)
    elseif style == "none" then
        frame:SetBackdrop(nil)
    else -- "tooltip" default
        frame:SetBackdrop({
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 10,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(0, 0, 0, 0.2)
        frame:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.4)
    end
end

-- ----------------------------------------------------------------
--  LightUI.RefreshAnchorChain()
--  Re-evaluates the FPS -> Gold -> SpecInfo anchor chain.
--  Each chained frame anchors to the nearest visible predecessor;
--  if no predecessor is visible it falls back to its saved position.
--  Call whenever a frame is shown/hidden or an anchor setting changes.
-- ----------------------------------------------------------------
function LightUI.RefreshAnchorChain()
    local fpsFrame  = LightUI.FPSPing     and LightUI.FPSPing.frame
    local goldFrame = LightUI.GoldTracker and LightUI.GoldTracker.frame
    local specFrame = LightUI.SpecInfo    and LightUI.SpecInfo.frame

    if not LightKitDB.anchorDataFrames then return end

    -- Gold: anchor to FPS if visible, else its absolute saved position.
    if goldFrame then
        goldFrame:ClearAllPoints()
        if fpsFrame and fpsFrame:IsShown() then
            goldFrame:SetPoint("TOPLEFT", fpsFrame, "TOPRIGHT", 4, 0)
        else
            goldFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
                LightKitDB.goldFrame.x, LightKitDB.goldFrame.y)
        end
    end

    -- SpecInfo: anchor to nearest visible predecessor (Gold -> FPS -> absolute).
    if specFrame then
        specFrame:ClearAllPoints()
        if goldFrame and goldFrame:IsShown() then
            specFrame:SetPoint("TOPLEFT", goldFrame, "TOPRIGHT", 4, 0)
        elseif fpsFrame and fpsFrame:IsShown() then
            specFrame:SetPoint("TOPLEFT", fpsFrame, "TOPRIGHT", 4, 0)
        else
            specFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
                LightKitDB.specInfoFrame.x, LightKitDB.specInfoFrame.y)
        end
    end
end

-- ----------------------------------------------------------------
--  LightUI.SetFrameStyle(style)
--  Persists the chosen style and re-applies it to every data frame.
-- ----------------------------------------------------------------
function LightUI.SetFrameStyle(style)
    LightKitDB.frameStyle = style
    for _, mod in ipairs({ LightUI.FPSPing, LightUI.GoldTracker, LightUI.SpecInfo }) do
        if mod and mod.frame then
            LightUI.ApplyFrameStyle(mod.frame, style)
        end
    end
end

-- ----------------------------------------------------------------
--  LightUI.SetAnchorChained(enabled)
--  Persists the anchor-chain toggle and refreshes the chain.
-- ----------------------------------------------------------------
function LightUI.SetAnchorChained(enabled)
    LightKitDB.anchorDataFrames = enabled
    LightUI.RefreshAnchorChain()
end

-- ----------------------------------------------------------------
--  LightUI.MakeDraggable(frame, posKey, lockKey, anchorGuard)
--  Configures a frame for mouse dragging with grid-snap on release.
--  posKey      – LightKitDB key for { x, y } position storage.
--  lockKey     – LightKitDB key for the lock boolean.
--  anchorGuard – when true, dragging is blocked while anchorDataFrames is set.
-- ----------------------------------------------------------------
function LightUI.MakeDraggable(frame, posKey, lockKey, anchorGuard)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if anchorGuard and LightKitDB.anchorDataFrames then return end
        if IsShiftKeyDown() or not LightKitDB[lockKey] then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        if anchorGuard and LightKitDB.anchorDataFrames then return end
        self:StopMovingOrSizing()
        LightUI.SnapFrame(self, posKey)
    end)
end

-- Default values for every saved variable.
LightUI.defaults = {
    showFPSPing            = true,
    showFPS                = true,
    showPing               = true,
    fpsFrameLocked         = true,
    fpsFrame               = { x = 8, y = -8 },
    fpsFontSize            = 12,
    showItemLevel          = true,
    showItemLevelIcons     = true,
    itemLevelIconFontSize  = 11,
    itemLevelIconFont      = "Fonts\\FRIZQT__.TTF",
    showEnchantLabels      = true,
    showGoldTracker        = true,
    goldFrameLocked        = true,
    goldFrame              = { x = 80, y = -8 },
    goldFontSize           = 12,
    goldDisplayMode        = "account",
    goldHideEmpty          = true,
    anchorDataFrames       = false,
    snapToGrid             = true,
    autoRepair             = true,
    autoSellGrey           = true,
    showChatCopy           = true,
    chatKeepHistory        = false,
    showDurabilityBars     = true,
    frameStyle             = "tooltip",
    showSpecInfo           = false,
    specInfoFrameLocked    = true,
    specInfoFrame          = { x = 8, y = -30 },
    specInfoFontSize       = 12,
    specInfoShowSpec       = true,
    specInfoShowLoot       = true,
    specInfoShowLoadout    = true,
}

-- Recursively fill in any keys that are missing from `db`.
local function ApplyDefaults(db, defaults)
    for k, v in pairs(defaults) do
        if db[k] == nil then
            if type(v) == "table" then
                db[k] = {}
                ApplyDefaults(db[k], v)
            else
                db[k] = v
            end
        elseif type(v) == "table" and type(db[k]) == "table" then
            ApplyDefaults(db[k], v)
        end
    end
end

-- Bootstrap on ADDON_LOADED so SavedVariables are already populated.
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName ~= LightUI.ADDON_NAME then return end

    if not LightKitDB then
        LightKitDB = {}
        -- One-time migration: copy settings saved under the old addon name.
        if LightUIDB then
            for k, v in pairs(LightUIDB) do
                LightKitDB[k] = v
            end
            -- Drop old frame positions; anchor points changed to TOPLEFT.
            LightKitDB.fpsFrame  = nil
            LightKitDB.goldFrame = nil
            LightUIDB = nil
        end
    end
    ApplyDefaults(LightKitDB, LightUI.defaults)

    LightUI.FPSPing:Init()
    LightUI.ItemLevelTooltip:Init()
    LightUI.ItemLevelIcons:Init()
    LightUI.DurabilityBars:Init()
    LightUI.EnchantLabels:Init()
    LightUI.GoldTracker:Init()
    LightUI.ChatCopy:Init(LightKitDB.showChatCopy)
    LightUI.VendorUtils:Init()
    LightUI.SpecInfo:Init()
    LightUI.RefreshAnchorChain()
    LightUI.Options:Init()

    self:UnregisterEvent("ADDON_LOADED")
end)

-- Re-apply the anchor chain after the loading screen
local pewFrame = CreateFrame("Frame")
pewFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
pewFrame:SetScript("OnEvent", function(self)
    LightUI.RefreshAnchorChain()
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)

-- ----------------------------------------------------------------
--  LightUI.ShowCopyDialog(title, text)
--  Opens a resizable, draggable popup with an EditBox pre-filled
--  with the text. The text is auto-selected so Ctrl+C copies it.
-- ----------------------------------------------------------------
function LightUI.ShowCopyDialog(title, text)
    -- Build the frame once and reuse it.
    if not LightUI._copyFrame then
        local f = CreateFrame("Frame", "LightUI_CopyDialog", UIParent, "BackdropTemplate")
        f:SetSize(520, 320)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true)
        f:SetResizable(true)
        f:SetResizeBounds(300, 160)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop",  f.StopMovingOrSizing)

        f:SetBackdrop({
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        f:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

        -- Title bar
        local titleFS = f:CreateFontString(nil, "OVERLAY")
        titleFS:SetFont("Fonts\\ARIALN.TTF", 12, "")
        titleFS:SetPoint("TOP", 0, -10)
        f._titleFS = titleFS

        -- Close button
        local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -2, -2)
        closeBtn:SetScript("OnClick", function() f:Hide() end)

        -- Resize grip
        local grip = CreateFrame("Button", nil, f)
        grip:SetSize(16, 16)
        grip:SetPoint("BOTTOMRIGHT", -2, 2)
        grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
        grip:SetScript("OnMouseUp",   function() f:StopMovingOrSizing() end)

        -- Scroll frame
        local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT",     f, "TOPLEFT",  8, -30)
        sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 10)
        f._sf = sf

        -- EditBox inside scroll frame
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(sf:GetWidth())
        eb:SetAutoFocus(false)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        -- Keep editbox width in sync when the dialog is resized.
        sf:SetScript("OnSizeChanged", function()
            eb:SetWidth(sf:GetWidth())
        end)
        sf:SetScrollChild(eb)
        f._eb = eb

        LightUI._copyFrame = f
    end

    local f = LightUI._copyFrame
    f._titleFS:SetText(title or "Copy")
    f._eb:SetText(text or "")
    f._eb:SetCursorPosition(0)
    f._eb:HighlightText()
    f:Show()
    f._eb:SetFocus()
end
