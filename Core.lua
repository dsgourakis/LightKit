-- ============================================================
--  Light Kit  |  Author: Hateless
--  Core.lua – namespace, saved-variable initialisation
-- ============================================================

LightUI = {}
LightUI.ADDON_NAME = "LightKit"

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
    goldDisplayMode        = "account",
    goldHideEmpty          = true,
    autoRepair             = true,
    autoSellGrey           = true,
    showChatCopy           = true,
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
    LightUI.EnchantLabels:Init()
    LightUI.GoldTracker:Init()
    LightUI.ChatCopy:Init(LightKitDB.showChatCopy)
    LightUI.VendorUtils:Init()
    LightUI.Options:Init()

    self:UnregisterEvent("ADDON_LOADED")
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
