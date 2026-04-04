-- ============================================================
--  Light Kit  |  Author: Hateless
--  ItemLevelTooltip.lua – adds inspected item level to unit tooltips
-- ============================================================

LightUI.ItemLevelTooltip = {}
local M = LightUI.ItemLevelTooltip

local CACHE_TTL        = 600  -- seconds until a cached ilvl is considered stale
local INSPECT_TIMEOUT  = 4    -- seconds before giving up on a pending INSPECT_READY
local cache            = {}   -- [guid] = { ilvl = N, time = T }
local pendingGUID      = nil  -- GUID we are waiting on for INSPECT_READY
local pendingLine      = nil  -- GameTooltipTextLeft index of the "(inspecting...)" line
local tooltipShownGUID = nil  -- GUID whose ilvl line we added in the current hover session

-- ----------------------------------------------------------------
--  Public API
-- ----------------------------------------------------------------

function M:SetShown(shown)
    LightKitDB.showItemLevel = shown
end

-- ----------------------------------------------------------------
--  Internal helpers
-- ----------------------------------------------------------------

-- Average the item level of all 16 gear slots
local GEAR_SLOTS = { 1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17 }

local function CalcEquippedItemLevel(unit)
    local total, count = 0, 0
    for _, slot in ipairs(GEAR_SLOTS) do
        local link = GetInventoryItemLink(unit, slot)
        if link then
            local ilvl = GetDetailedItemLevelInfo(link)
            if ilvl and ilvl > 0 then
                total = total + ilvl
                count = count + 1
            end
        end
    end
    return count > 0 and math.floor(total / count) or nil
end

local function FormatIlvl(ilvl)
    return string.format("Item Level: |cffffd700%d|r", ilvl)
end

-- ----------------------------------------------------------------
--  Init
-- ----------------------------------------------------------------

function M:Init()
    -- ---- OnHide cleanup -----------------------------------------
    -- Clear pending state whenever the unit tooltip is dismissed
    GameTooltip:HookScript("OnHide", function()
        pendingGUID      = nil
        pendingLine      = nil
        tooltipShownGUID = nil
    end)

    -- ---- INSPECT_READY handler ----------------------------------
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("INSPECT_READY")
    eventFrame:SetScript("OnEvent", function(_, _, guid)
        if guid ~= pendingGUID then return end
        pendingGUID = nil

        pcall(function()
            -- Confirm the mouse is still over the inspected unit.
            local mouseGUID = UnitGUID("mouseover")
            local unit = (mouseGUID == guid) and "mouseover" or nil
            if not unit then
                pendingLine = nil
                return
            end

            local ilvl = CalcEquippedItemLevel(unit)
            if not ilvl then
                pendingLine = nil
                return
            end

            cache[guid] = { ilvl = ilvl, time = GetTime() }

            -- Patch the placeholder line we left in the tooltip.
            if pendingLine and GameTooltip:IsShown() then
                -- Verify the tooltip is still showing our unit and has not
                -- been replaced by an item tooltip (e.g. inside InspectFrame).
                local _, ttUnit = GameTooltip:GetUnit()
                local ttGUID    = ttUnit and UnitGUID(ttUnit)
                if ttGUID ~= guid then
                    pendingLine = nil
                    return
                end

                local line = _G["GameTooltipTextLeft" .. pendingLine]
                if line then
                    line:SetText(FormatIlvl(ilvl))
                    GameTooltip:Show()
                end
            end
            pendingLine = nil
        end)
    end)

    -- ---- Tooltip hook -------------------------------------------
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(self)
        if not LightKitDB.showItemLevel then return end

        pcall(function()
            local _, unit = self:GetUnit()
            if not unit then return end

            local isPlayer = UnitIsPlayer(unit)
            if not isPlayer then return end

            local guid = UnitGUID(unit)
            if not guid then return end

            -- Own character: no inspect needed.
            if UnitIsUnit(unit, "player") then
                local _, equipped = GetAverageItemLevel()
                self:AddLine(FormatIlvl(math.floor(equipped)))
                self:Show()
                return
            end

            -- Serve from cache if fresh enough.
            local entry = cache[guid]
            if entry and (GetTime() - entry.time) < CACHE_TTL then
                local isFirst = (tooltipShownGUID ~= guid)
                self:AddLine(FormatIlvl(entry.ilvl))
                if isFirst then
                    tooltipShownGUID = guid
                    self:Show()
                end
                return
            end

            -- Tooltip refresh
            if pendingGUID == guid then
                pendingLine = self:NumLines() + 1
                self:AddLine("|cffaaaaaa(inspecting...)|r")
                return
            end

            -- If we are already showing an ilvl for this GUID in the tooltip, don't attempt to inspect again on a tooltip refresh
            if tooltipShownGUID == guid then return end

            -- If InspectFrame is already open, don't compete with NotifyInspect
            if InspectFrame and InspectFrame:IsShown() then
                return
            end

            -- If the unit is out of inspect range, don't attempt to inspect
            if not CheckInteractDistance(unit, 1) then
                return
            end

            -- Request a fresh inspect and leave a placeholder.
            if CanInspect(unit) then
                tooltipShownGUID = guid
                pendingGUID = guid
                pendingLine = self:NumLines() + 1
                NotifyInspect(unit)
                self:AddLine("|cffaaaaaa(inspecting...)|r")
                self:Show()

                -- Safety timeout
                local capturedGUID = guid
                C_Timer.After(INSPECT_TIMEOUT, function()
                    if pendingGUID ~= capturedGUID then return end
                    pendingGUID = nil
                    if pendingLine and GameTooltip:IsShown() then
                        local line = _G["GameTooltipTextLeft" .. pendingLine]
                        if line then
                            line:SetText("")
                            GameTooltip:Show()
                        end
                    end
                    pendingLine = nil
                end)
            end
        end)
    end)
end
