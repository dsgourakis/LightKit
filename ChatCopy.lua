-- ChatCopy.lua
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
    -- Attach to all chat frames that exist at load time
    local count = NUM_CHAT_WINDOWS or 10
    for i = 1, count do
        local frame = _G["ChatFrame" .. i]
        if frame then
            BuildCopyButton(frame)
        end
    end
    if not shown then
        ApplyShown(false)
    end
end
