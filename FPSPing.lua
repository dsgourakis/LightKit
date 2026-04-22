-- ============================================================
--  Light Kit  |  Author: Hateless
--  FPSPing.lua – movable FPS / Ping overlay frame
-- ============================================================

LightUI.FPSPing = {}
local M = LightUI.FPSPing

-- ----------------------------------------------------------------
--  Public API
-- ----------------------------------------------------------------

function M:Init()
    self:_BuildFrame()
    self.frame:SetShown(LightKitDB.showFPSPing)
end

--- Show or hide the frame and persist the preference.
function M:SetShown(shown)
    LightKitDB.showFPSPing = shown
    self.frame:SetShown(shown)
    LightUI.RefreshAnchorChain()
end

--- Lock or unlock free dragging. When locked only Shift-drag works.
function M:SetLocked(locked)
    LightKitDB.fpsFrameLocked = locked
end

--- Update the font size of both labels and resize the frame to fit.
function M:SetFontSize(size)
    LightKitDB.fpsFontSize = size
    self.fpsLabel:SetFont("Fonts\\ARIALN.TTF", size, "")
    self.pingLabel:SetFont("Fonts\\ARIALN.TTF", size, "")
    self.frame:SetHeight(size + 8)
    if self._update then self._update() end
end

--- Show or hide just the FPS label.
function M:SetShowFPS(shown)
    LightKitDB.showFPS = shown
    if self._update then self._update() end
end

--- Show or hide just the Ping label.
function M:SetShowPing(shown)
    LightKitDB.showPing = shown
    if self._update then self._update() end
end

-- ----------------------------------------------------------------
--  Internal
-- ----------------------------------------------------------------

-- Return an appropriate hex colour code based on value/thresholds.
local function FPSColour(fps)
    if fps >= 60 then return "|cff00ff00"
    elseif fps >= 30 then return "|cffffff00"
    else return "|cffff4444" end
end

local function PingColour(ms)
    if ms < 80  then return "|cff00ff00"
    elseif ms < 200 then return "|cffffff00"
    else return "|cffff4444" end
end

function M:_BuildFrame()
    local f = CreateFrame("Frame", "LightUI_FPSPingFrame", UIParent, "BackdropTemplate")
    f:SetSize(60, 14)   -- width is overwritten dynamically after text update

    LightUI.ApplyFrameStyle(f, LightKitDB.frameStyle)
    LightUI.MakeDraggable(f, "fpsFrame", "fpsFrameLocked", false)

    -- Restore saved position (anchored to UIParent TOPLEFT)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
               LightKitDB.fpsFrame.x, LightKitDB.fpsFrame.y)

    -- ---- Text labels -----------------
    local fpsLabel = f:CreateFontString(nil, "OVERLAY")
    fpsLabel:SetFont("Fonts\\ARIALN.TTF", LightKitDB.fpsFontSize, "")
    fpsLabel:SetShadowColor(0, 0, 0, 0.9)
    fpsLabel:SetShadowOffset(1, -1)
    fpsLabel:SetPoint("LEFT", f, "LEFT", 6, 0)

    local pingLabel = f:CreateFontString(nil, "OVERLAY")
    pingLabel:SetFont("Fonts\\ARIALN.TTF", LightKitDB.fpsFontSize, "")
    pingLabel:SetShadowColor(0, 0, 0, 0.9)
    pingLabel:SetShadowOffset(1, -1)
    pingLabel:SetPoint("LEFT", fpsLabel, "RIGHT", 10, 0)

    self.fpsLabel  = fpsLabel
    self.pingLabel = pingLabel

    -- Resize the frame to tightly wrap whichever labels are visible.
    local PAD_L, PAD_R, GAP = 8, 8, 10
    local function Resize()
        local showFPS  = LightKitDB.showFPS
        local showPing = LightKitDB.showPing
        local w = PAD_L + PAD_R
        if showFPS  then w = w + fpsLabel:GetStringWidth()  end
        if showFPS and showPing then w = w + GAP end
        if showPing then w = w + pingLabel:GetStringWidth() end
        f:SetWidth(math.max(w, 40))
    end
    self._resize = Resize

    -- Central update: refresh text and re-anchor labels based on settings.
    local function Update()
        local showFPS  = LightKitDB.showFPS
        local showPing = LightKitDB.showPing

        if showFPS then
            local fps = math.floor(GetFramerate())
            fpsLabel:SetText("FPS: " .. FPSColour(fps) .. fps .. "|r")
            fpsLabel:Show()
        else
            fpsLabel:SetText("")
            fpsLabel:Hide()
        end

        if showPing then
            local _, _, latHome, latWorld = GetNetStats()
            local ping = (latWorld > 0) and latWorld or latHome
            pingLabel:SetText("Ping: " .. PingColour(ping) .. ping .. "|r")
            -- Re-anchor so ping sits right of fps (or at left edge if fps hidden).
            pingLabel:ClearAllPoints()
            if showFPS then
                pingLabel:SetPoint("LEFT", fpsLabel, "RIGHT", GAP, 0)
            else
                pingLabel:SetPoint("LEFT", f, "LEFT", PAD_L, 0)
            end
            pingLabel:Show()
        else
            pingLabel:SetText("")
            pingLabel:Hide()
        end

        Resize()
    end
    self._update = Update

    -- ---- Periodic stat update (every 1 s) -----------------------
    C_Timer.NewTicker(1, function()
        if not f:IsShown() then return end
        Update()
    end)

    self.frame = f
    self.frame:SetHeight(LightKitDB.fpsFontSize + 8)
end
