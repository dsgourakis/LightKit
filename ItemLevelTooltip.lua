-- ============================================================
--  Light Kit  |  Author: Hateless
--  ItemLevelTooltip.lua – adds inspected item level to unit tooltips
-- ============================================================

LightUI.ItemLevelTooltip = {}
local M = LightUI.ItemLevelTooltip

local CACHE_TTL       = 600  -- seconds until a cached ilvl is considered stale
local INSPECT_TIMEOUT = 4    -- seconds before giving up on a pending INSPECT_READY
local cache           = {}   -- [guid] = { ilvl = N, time = T }
local pendingGUID     = nil  -- GUID we are waiting on for INSPECT_READY

-- ----------------------------------------------------------------
--  Public API
-- ----------------------------------------------------------------

function M:SetShown(shown)
    LightKitDB.showItemLevel = shown
end

-- ----------------------------------------------------------------
--  Internal helpers
-- ----------------------------------------------------------------

local function FormatIlvl(ilvl)
    return string.format("Item Level: |cffffd700%d|r", ilvl)
end

-- ----------------------------------------------------------------
--  Init
-- ----------------------------------------------------------------

function M:Init()
    -- ---- OnHide cleanup -----------------------------------------
    GameTooltip:HookScript("OnHide", function()
        pendingGUID = nil
    end)

    -- ---- INSPECT_READY handler ----------------------------------
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("INSPECT_READY")
    eventFrame:SetScript("OnEvent", function(_, _, guid)
        if guid ~= pendingGUID then return end
        pendingGUID = nil

        pcall(function()
            -- Resolve to a unit token from any frame (target, party, focus, mouseover, etc.)
            local unit = UnitTokenFromGUID(guid)
            if not unit then
                GameTooltip_SetTooltipWaitingForData(GameTooltip, false)
                return
            end

            -- C_PaperDollInfo.GetInspectItemLevel is the Blizzard value 
            local ilvl = C_PaperDollInfo.GetInspectItemLevel(unit)
            if not ilvl or ilvl == 0 then
                GameTooltip_SetTooltipWaitingForData(GameTooltip, false)
                return
            end

            cache[guid] = { ilvl = math.floor(ilvl), time = GetTime() }

            if GameTooltip:IsShown() then
                local _, ttUnit = GameTooltip:GetUnit()
                -- Guard against tainted unitIDs in combat/dungeons before calling UnitGUID
                if ttUnit and not issecretvalue(ttUnit) and UnitGUID(ttUnit) == guid then
                    GameTooltip_SetTooltipWaitingForData(GameTooltip, false)
                    GameTooltip:AddLine(FormatIlvl(math.floor(ilvl)))
                    GameTooltip:Show()
                else
                    GameTooltip_SetTooltipWaitingForData(GameTooltip, false)
                end
            end
        end)
    end)

    -- ---- Tooltip hook -------------------------------------------
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(self)
        if not LightKitDB.showItemLevel then return end

        pcall(function()
            local _, unit = self:GetUnit()
            -- issecretvalue() guards against tainted restricted unitIDs in combat/dungeons
            if not unit or issecretvalue(unit) then return end

            if not UnitIsPlayer(unit) then return end

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
                self:AddLine(FormatIlvl(entry.ilvl))
                self:Show()
                return
            end

            -- Already waiting on an inspect for this GUID — show Blizzard's built-in spinner.
            if pendingGUID == guid then
                GameTooltip_SetTooltipWaitingForData(self, true)
                return
            end

            -- Don't compete with the InspectFrame.
            if InspectFrame and InspectFrame:IsShown() then return end

            -- CanInspect(unit, true) checks both capability and inspect range in one call.
            if CanInspect(unit, true) then
                pendingGUID = guid
                NotifyInspect(unit)
                GameTooltip_SetTooltipWaitingForData(self, true)

                -- Safety timeout: clear spinner if INSPECT_READY never fires.
                local capturedGUID = guid
                C_Timer.After(INSPECT_TIMEOUT, function()
                    if pendingGUID ~= capturedGUID then return end
                    pendingGUID = nil
                    GameTooltip_SetTooltipWaitingForData(GameTooltip, false)
                end)
            end
        end)
    end)
end
