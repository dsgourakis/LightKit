-- ============================================================
--  Light Kit  |  Author: Hateless
--  VendorUtils.lua – auto-repair and auto-sell grey items at vendors
-- ============================================================

LightUI.VendorUtils = {}
local M = LightUI.VendorUtils

-- ----------------------------------------------------------------
--  Public API
-- ----------------------------------------------------------------

function M:SetAutoRepair(enabled)
    LightKitDB.autoRepair = enabled
end

function M:SetAutoSellGrey(enabled)
    LightKitDB.autoSellGrey = enabled
end

-- ----------------------------------------------------------------
--  Internal helpers
-- ----------------------------------------------------------------

local function FormatMoney(copper)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = string.format("|cffffd700%dg|r", g) end
    if s > 0 then parts[#parts + 1] = string.format("|cffc0c0c0%ds|r", s) end
    if c > 0 or #parts == 0 then parts[#parts + 1] = string.format("|cffeda55f%dc|r", c) end
    return table.concat(parts, " ")
end

local function DoRepair()
    if not CanMerchantRepair() then return end
    local cost, canRepair = GetRepairAllCost()
    if not canRepair or cost == 0 then return end
    if GetMoney() < cost then
        print("|cff00ccff[LightUI]|r Not enough gold to auto-repair (need " .. FormatMoney(cost) .. ").")
        return
    end
    RepairAllItems()
    print("|cff00ccff[LightUI]|r Auto-repaired all items for " .. FormatMoney(cost) .. ".")
end

local function DoSellGrey()
    local totalCopper, count = 0, 0
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == Enum.ItemQuality.Poor and not info.hasNoValue then
                local sellPrice = select(11, GetItemInfo(info.itemID))
                if sellPrice and sellPrice > 0 then
                    totalCopper = totalCopper + sellPrice * (info.stackCount or 1)
                end
                C_Container.UseContainerItem(bag, slot)
                count = count + 1
            end
        end
    end
    if count > 0 then
        if totalCopper > 0 then
            print(string.format("|cff00ccff[LightUI]|r Sold %d grey item(s) for %s.", count, FormatMoney(totalCopper)))
        else
            print(string.format("|cff00ccff[LightUI]|r Sold %d grey item(s).", count))
        end
    end
end

-- ----------------------------------------------------------------
--  Init
-- ----------------------------------------------------------------

function M:Init()
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("MERCHANT_SHOW")
    ev:SetScript("OnEvent", function()
        if LightKitDB.autoSellGrey then DoSellGrey() end
        if LightKitDB.autoRepair   then DoRepair()   end
    end)
end
