-- ============================================================
--  Light Kit  |  Author: Hateless
--  GoldTracker.lua – small gold display frame with an account-wide character gold summary on hover.
--  Storage: LightKitDB.characters[realm][name].gold
-- ============================================================

LightUI.GoldTracker = {}
local M = LightUI.GoldTracker

local FONT = "Fonts\\ARIALN.TTF"

-- ----------------------------------------------------------------
--  Gold formatting
-- ----------------------------------------------------------------

local GOLD_ICON   = "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:0|t"
local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:0|t"

local function FormatNumber(n)
    -- Insert comma separators
    local s = tostring(math.floor(n))
    local k = #s % 3
    if k == 0 then k = 3 end
    local result = s:sub(1, k)
    for i = k + 1, #s, 3 do
        result = result .. "," .. s:sub(i, i + 2)
    end
    return result
end

-- Full g/s/c display with standard money colours.
local function FormatMoney(copper)
    copper = math.max(copper or 0, 0)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    return "|cffd4a017" .. FormatNumber(g) .. "|r " .. GOLD_ICON
        .. " |cffc7c7cf" .. s .. "|r " .. SILVER_ICON
        .. " |cffffaa55" .. c .. "|r " .. COPPER_ICON
end

-- Signed g/s/c
local function FormatMoneyNet(copper)
    local sign  = copper >= 0 and "+" or "-"
    local color = copper >= 0 and "|cff00cc44" or "|cffff4444"
    local abs   = math.abs(copper)
    local g = math.floor(abs / 10000)
    local s = math.floor((abs % 10000) / 100)
    local c = abs % 100
    return color .. sign .. FormatNumber(g) .. "|r " .. GOLD_ICON
        .. " " .. color .. s .. "|r " .. SILVER_ICON
        .. " " .. color .. c .. "|r " .. COPPER_ICON
end

-- ----------------------------------------------------------------
--  Per-character storage
-- ----------------------------------------------------------------

local function SaveCurrentGold()
    local name  = UnitName("player")
    local realm = GetRealmName()
    LightKitDB.characters          = LightKitDB.characters          or {}
    LightKitDB.characters[realm]   = LightKitDB.characters[realm]   or {}
    LightKitDB.characters[realm][name] = {
        gold  = GetMoney(),
        class = select(2, UnitClass("player")),
    }
end

-- Sum all saved character gold plus warband bank gold (if known).
local function GetAccountTotal()
    local total = 0
    for _, realmChars in pairs(LightKitDB.characters or {}) do
        for _, data in pairs(realmChars) do
            total = total + (data.gold or 0)
        end
    end
    if LightKitDB.warbandGold then
        total = total + LightKitDB.warbandGold
    end
    return total
end

-- ----------------------------------------------------------------
--  Session gain / spend tracking  (reset on re-login)
-- ----------------------------------------------------------------
local sessionGained = 0
local sessionSpent  = 0
local lastMoney     = nil   -- copper snapshot used to detect changes

-- Warband bank gold via C_Bank.FetchDepositedMoney
local function TrySaveWarbandGold()
    if not C_Bank or not C_Bank.FetchDepositedMoney then return end
    if not Enum.BankType or not Enum.BankType.Account then return end
    local copper = C_Bank.FetchDepositedMoney(Enum.BankType.Account)
    if type(copper) == "number" and copper > 0 then
        LightKitDB.warbandGold = copper
        M:UpdateLabel()
    end
end

-- Read warband gold after a short delay so the server has time to send the value.
local function ScheduleWarbandRead()
    C_Timer.After(0.5, TrySaveWarbandGold)
    C_Timer.After(2.0, TrySaveWarbandGold)
end

-- Hook AccountBankPanel once it exists.
local function HookWarbandBankPanel()
    local panel = AccountBankPanel
    if not panel or panel._luiWarbandHooked then return end
    panel._luiWarbandHooked = true
    panel:HookScript("OnShow", ScheduleWarbandRead)
end

-- ----------------------------------------------------------------
--  Account summary tooltip
-- ----------------------------------------------------------------

local function ShowTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Account Gold", 1, 0.84, 0)

    local colors = RAID_CLASS_COLORS or {}
    local chars  = LightKitDB.characters or {}

    local realmList = {}
    for realm in pairs(chars) do realmList[#realmList + 1] = realm end
    table.sort(realmList)

    for _, realm in ipairs(realmList) do
        local realmChars = chars[realm]
        local charList = {}
        for name, data in pairs(realmChars) do
            if data.gold and not (LightKitDB.goldHideEmpty and data.gold == 0) then
                charList[#charList + 1] = { name = name, data = data }
            end
        end
        table.sort(charList, function(a, b) return a.data.gold > b.data.gold end)

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(realm, 0.6, 0.6, 0.6)
        for _, entry in ipairs(charList) do
            local r, g, b = 1, 1, 1
            if entry.data.class and colors[entry.data.class] then
                r = colors[entry.data.class].r
                g = colors[entry.data.class].g
                b = colors[entry.data.class].b
            end
            GameTooltip:AddDoubleLine(
                "  " .. entry.name, FormatMoney(entry.data.gold),
                r, g, b, 1, 1, 1)
        end
    end

    if LightKitDB.warbandGold and LightKitDB.warbandGold > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(
            "Warband Bank", FormatMoney(LightKitDB.warbandGold),
            0.8, 0.6, 1, 1, 1, 1)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("This Session", 0.9, 0.9, 0.9)
    GameTooltip:AddDoubleLine("  Gained", FormatMoney(sessionGained),              0, 0.8, 0.3, 1, 1, 1)
    GameTooltip:AddDoubleLine("  Spent",  FormatMoney(sessionSpent),               0.9, 0.3, 0.3, 1, 1, 1)
    GameTooltip:AddDoubleLine("  Net",    FormatMoneyNet(sessionGained - sessionSpent), 1, 1, 1, 1, 1, 1)

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Total", FormatMoney(GetAccountTotal()), 1, 0.84, 0, 1, 0.84, 0)
    GameTooltip:Show()
end

-- ----------------------------------------------------------------
--  Public API
-- ----------------------------------------------------------------

function M:UpdateLabel()
    if not self.goldLabel then return end
    local mode = LightKitDB.goldDisplayMode or "account"
    local amount = (mode == "character") and GetMoney() or GetAccountTotal()
    self.goldLabel:SetText(FormatMoney(amount))
    if self._resize then self._resize() end
end

function M:SetDisplayMode(mode)
    LightKitDB.goldDisplayMode = mode
    self:UpdateLabel()
end

function M:RemoveCharacter(name, realm)
    if LightKitDB.characters and LightKitDB.characters[realm] then
        LightKitDB.characters[realm][name] = nil
        if not next(LightKitDB.characters[realm]) then
            LightKitDB.characters[realm] = nil
        end
    end
    self:UpdateLabel()
end

function M:SetShown(shown)
    LightKitDB.showGoldTracker = shown
    self.frame:SetShown(shown)
end

function M:SetLocked(locked)
    LightKitDB.goldFrameLocked = locked
end

function M:SetFontSize(size)
    LightKitDB.goldFontSize = size
    if self.goldLabel then
        self.goldLabel:SetFont(FONT, size, "")
        self.frame:SetHeight(size + 8)
        if self._resize then self._resize() end
    end
end

-- ----------------------------------------------------------------
--  Init
-- ----------------------------------------------------------------

function M:Init()
    -- ---- Draggable frame ----------------------------------------
    local f = CreateFrame("Frame", "LightUI_GoldFrame", UIParent, "BackdropTemplate")
    f:SetSize(120, LightKitDB.goldFontSize + 8)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    f:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0, 0, 0, 0.2)
    f:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.4)

    -- Restore saved position (TOPLEFT anchor; default set in LightUI.defaults).
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
               LightKitDB.goldFrame.x, LightKitDB.goldFrame.y)

    -- ---- Gold label ---------------------------------------------
    local label = f:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT, LightKitDB.goldFontSize, "")
    label:SetShadowColor(0, 0, 0, 0.9)
    label:SetShadowOffset(1, -1)
    label:SetPoint("LEFT",  f, "LEFT",  6, 0)
    label:SetPoint("RIGHT", f, "RIGHT", -6, 0)
    label:SetJustifyH("CENTER")
    self.goldLabel = label

    -- Shrink/grow the frame to tightly wrap the text.
    local function Resize()
        f:SetWidth(math.max(label:GetStringWidth() + 16, 40))
    end
    self._resize = Resize

    -- ---- Drag & position save -----------------------------------
    f:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() or not LightKitDB.goldFrameLocked then
            self:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Snap to 8px grid, matching WoW's layout grid.
        local grid = 8
        local x = math.floor(self:GetLeft() / grid + 0.5) * grid
        local y = math.floor((self:GetTop() - UIParent:GetHeight()) / grid + 0.5) * grid
        LightKitDB.goldFrame = { x = x, y = y }
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
    end)

    -- ---- Tooltip ------------------------------------------------
    f:SetScript("OnEnter", function(self)
        ShowTooltip(self)
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.frame = f
    f:SetShown(LightKitDB.showGoldTracker)

    -- ---- Events -------------------------------------------------
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_MONEY")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            local isInitialLogin = ...
            if isInitialLogin then
                -- Real login: wipe session counters.
                LightKitDB.sessionGained = 0
                LightKitDB.sessionSpent  = 0
            end
            -- Always restore locals from DB (resumes correctly after /reload).
            sessionGained = LightKitDB.sessionGained or 0
            sessionSpent  = LightKitDB.sessionSpent  or 0
            lastMoney     = GetMoney()
        elseif event == "PLAYER_MONEY" then
            local current = GetMoney()
            if lastMoney then
                local diff = current - lastMoney
                if diff > 0 then
                    sessionGained = sessionGained + diff
                    LightKitDB.sessionGained = sessionGained
                elseif diff < 0 then
                    sessionSpent = sessionSpent + (-diff)
                    LightKitDB.sessionSpent = sessionSpent
                end
            end
            lastMoney = current
        end
        SaveCurrentGold()
        TrySaveWarbandGold()
        M:UpdateLabel()
    end)

    -- Warband bank money events
    local wbEv = CreateFrame("Frame")
    for _, evtName in ipairs({ "ACCOUNT_BANK_MONEY_CHANGED", "ACCOUNT_BANK_MONEY_UPDATE" }) do
        pcall(function() wbEv:RegisterEvent(evtName) end)
    end
    wbEv:SetScript("OnEvent", function()
        TrySaveWarbandGold()
    end)

    -- PLAYER_INTERACTION_MANAGER_FRAME_SHOW fires when any banker/vendor window opens.
    local intEv = CreateFrame("Frame")
    pcall(function() intEv:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW") end)
    intEv:SetScript("OnEvent", function(_, _, interactionType)
        if interactionType == 8 or interactionType == Enum.PlayerInteractionType.AccountBanker then
            ScheduleWarbandRead()
        end
    end)

    -- ---- Hook bags money frame ----------------------------------
    local function HookBagsMoneyFrame()
        local mf = ContainerFrameCombinedBags and ContainerFrameCombinedBags.MoneyFrame
        if not mf or mf._luiHooked then return end
        mf._luiHooked = true
        mf:HookScript("OnEnter", function(self)
            if LightKitDB.showGoldTracker then ShowTooltip(self) end
        end)
        mf:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end

    HookBagsMoneyFrame()
    local bagEv = CreateFrame("Frame")
    bagEv:RegisterEvent("ADDON_LOADED")
    bagEv:SetScript("OnEvent", function(self, _, name)
        if name == "Blizzard_BagUI" or name == "Blizzard_InventoryUI" then
            HookBagsMoneyFrame()
        end
        -- Try hooking the warband bank panel whenever any addon loads.
        HookWarbandBankPanel()
    end)
    -- Also try immediately in case it's already loaded.
    HookWarbandBankPanel()

    -- Initial population.
    SaveCurrentGold()
    TrySaveWarbandGold()
    M:UpdateLabel()
end
