-- Chat.lua
-- Attaches a small button to the corner of each visible
-- chat frame. Clicking it opens the copy dialog
-- pre-filled with the frame's message history,
-- hyperlink tokens, and texture tags.

LightUI.ChatCopy = {}
local M = LightUI.ChatCopy

-- ----------------------------------------------------------------
--  Strip WoW formatting codes from a chat message string.
-- ----------------------------------------------------------------
local function StripFormatting(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|H[^|]*|h([^|]*)|h", "%1")
    text = text:gsub("|T[^|]*|t", "")
    text = text:gsub("|A[^|]*|a", "")
    return text
end

-- ----------------------------------------------------------------
--  Build and attach the copy button to a given chat frame.
-- ----------------------------------------------------------------
local function BuildCopyButton(chatFrame)
    if chatFrame._luiCopyBtn then return end

    local btn = CreateFrame("Button", nil, chatFrame, "BackdropTemplate")
    btn:SetSize(18, 18)
    btn:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", -4, -4)
    btn:SetFrameLevel(chatFrame:GetFrameLevel() + 5)

    btn:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 6,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    btn:SetBackdropColor(0, 0, 0, 0.45)
    btn:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.7)

    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\ARIALN.TTF", 10, "")
    label:SetPoint("CENTER")
    label:SetTextColor(0.85, 0.85, 0.85, 1)
    label:SetText("C")

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.75, 0.75, 0.75, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Copy chat log")
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.7)
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", function()
        local n = chatFrame:GetNumMessages()
        if n == 0 then
            LightUI.ShowCopyDialog("Chat Log", "(no messages)")
            return
        end

        local lines = {}
        for i = 1, n do
            local text = select(1, chatFrame:GetMessageInfo(i))
            if text then
                local ok, stripped = pcall(StripFormatting, text)
                if ok then
                    lines[#lines + 1] = stripped
                end
            end
        end

        local title = "Chat Log"
        if chatFrame.name and chatFrame.name ~= "" then
            title = "Chat Log – " .. chatFrame.name
        end
        LightUI.ShowCopyDialog(title, table.concat(lines, "\n"))
    end)

    chatFrame._luiCopyBtn = btn
end

-- ----------------------------------------------------------------
--  Chat history: persist across /reload, wipe on real login.
-- ----------------------------------------------------------------
local MAX_HISTORY     = 200
local suppressCapture = false

-- Hook ReloadUI so we can stamp the flag before SavedVariables are written.
local _origReloadUI = ReloadUI
ReloadUI = function(...)
    if LightKitDB then LightKitDB._reloadPending = true end
    return _origReloadUI(...)
end
if C_UI and C_UI.Reload then
    local _origCUIReload = C_UI.Reload
    C_UI.Reload = function(...)
        if LightKitDB then LightKitDB._reloadPending = true end
        return _origCUIReload(...)
    end
end

local function MakeCapturer(frameIndex)
    local key = tostring(frameIndex)
    return function(_, text, r, g, b)
        if suppressCapture then return end
        if not LightKitDB or not LightKitDB.chatKeepHistory then return end
        if not LightKitDB.chatHistory then LightKitDB.chatHistory = {} end
        local h = LightKitDB.chatHistory
        if not h[key] then h[key] = {} end
        local tab = h[key]
        tab[#tab + 1] = { text = text, r = r, g = g, b = b }
        while #tab > MAX_HISTORY do
            table.remove(tab, 1)
        end
    end
end

local function RestoreHistory()
    if not LightKitDB or not LightKitDB.chatKeepHistory then return end
    local h = LightKitDB.chatHistory
    if not h then return end
    suppressCapture = true
    local count = NUM_CHAT_WINDOWS or 10
    for i = 1, count do
        local frame = _G["ChatFrame" .. i]
        local msgs  = h[tostring(i)]
        if frame and msgs then
            for _, msg in ipairs(msgs) do
                frame:AddMessage(msg.text, msg.r, msg.g, msg.b)
            end
        end
    end
    suppressCapture = false
end

function M:SetKeepHistory(enabled)
    LightKitDB.chatKeepHistory = enabled
    if not enabled then
        LightKitDB.chatHistory = {}
    end
end

-- ----------------------------------------------------------------
--  Public API
-- ----------------------------------------------------------------
local function ApplyShown(shown)
    local count = NUM_CHAT_WINDOWS or 10
    for i = 1, count do
        local frame = _G["ChatFrame" .. i]
        if frame and frame._luiCopyBtn then
            frame._luiCopyBtn:SetShown(shown)
        end
    end
end

function M:SetShown(shown)
    LightKitDB.showChatCopy = shown
    ApplyShown(shown)
end

-- ----------------------------------------------------------------
--  Module initialisation
-- ----------------------------------------------------------------
function M:Init(shown)
    -- Attach copy buttons and history hooks to all chat frames at load time.
    local count = NUM_CHAT_WINDOWS or 10
    for i = 1, count do
        local frame = _G["ChatFrame" .. i]
        if frame then
            BuildCopyButton(frame)
            hooksecurefunc(frame, "AddMessage", MakeCapturer(i))
            frame._luiHistoryHooked = true
        end
    end

    -- Hook FCF_SetWindowName: called for every chat frame when named,
    -- including whisper pop-out windows which bypass FCF_OpenNewWindow.
    hooksecurefunc("FCF_SetWindowName", function(frame)
        if not frame then return end
        if not frame._luiCopyBtn then
            BuildCopyButton(frame)
            if LightKitDB and not LightKitDB.showChatCopy then
                frame._luiCopyBtn:Hide()
            end
        end
        -- Hook AddMessage for any numbered frame not already hooked.
        if not frame._luiHistoryHooked then
            for i = 1, NUM_CHAT_WINDOWS or 10 do
                if _G["ChatFrame" .. i] == frame then
                    hooksecurefunc(frame, "AddMessage", MakeCapturer(i))
                    frame._luiHistoryHooked = true
                    break
                end
            end
        end
    end)

    -- Restore on /reload; wipe on real login. The _reloadPending flag is
    -- stamped by the ReloadUI hook above before SavedVariables are written.
    if LightKitDB._reloadPending then
        LightKitDB._reloadPending = nil
        RestoreHistory()
    else
        LightKitDB.chatHistory = {}
    end

    if not shown then
        ApplyShown(false)
    end
end
