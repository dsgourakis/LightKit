-- ============================================================
--  Light Kit  |  Author: Hateless
--  Options.lua – in-game Settings panel
-- ============================================================

LightUI.Options = {}
local M = LightUI.Options

function M:Init()
    -- Top-level category in Game Menu → Interface → AddOns.
    -- Settings are split into subcategories; each appears as a child
    local category, layout = Settings.RegisterVerticalLayoutCategory("Light Kit")

    -- ================================================================
    --  Parent category page: About, Features, Commands, Reset
    -- ================================================================
    do
        local ver = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(
            "LightKit", "Version") or "?"

        -- About
        layout:AddInitializer(Settings.CreateElementInitializer(
            "SettingsListSectionHeaderTemplate",
            { name = "Light Kit  |cff888888v" .. ver .. "  ·  by Hateless|r" }))

        -- Features
        layout:AddInitializer(Settings.CreateElementInitializer(
            "SettingsListSectionHeaderTemplate",
            { name = "Features" }))
        local FEATURES = {
            "FPS & Ping display overlay",
            "Item level on unit tooltips",
            "Item level numbers on gear icons",
            "Enchant labels on gear slots",
            "Account-wide gold tracker with session summary",
            "Auto-repair at vendors",
            "Auto-sell grey items at vendors",
            "Disable auto-add spells to action bars",
            "Chat message copy dialog",
        }
        for _, feat in ipairs(FEATURES) do
            layout:AddInitializer(Settings.CreateElementInitializer(
                "SettingsListSectionHeaderTemplate",
                { name = "|cffcccccc  •  " .. feat .. "|r" }))
        end

        -- Commands
        layout:AddInitializer(Settings.CreateElementInitializer(
            "SettingsListSectionHeaderTemplate",
            { name = "Commands" }))
        layout:AddInitializer(Settings.CreateElementInitializer(
            "SettingsListSectionHeaderTemplate",
            { name = "|cff88ff88  /lightkit|r  |cffaaaaaa– open this settings panel|r" }))

        -- Reset
        layout:AddInitializer(Settings.CreateElementInitializer(
            "SettingsListSectionHeaderTemplate",
            { name = "Settings" }))

        local function ResetAllSettings()
            LightUI.FPSPing:SetShown(LightUI.defaults.showFPSPing)
            LightUI.FPSPing:SetShowFPS(LightUI.defaults.showFPS)
            LightUI.FPSPing:SetShowPing(LightUI.defaults.showPing)
            LightUI.FPSPing:SetLocked(LightUI.defaults.fpsFrameLocked)
            LightUI.FPSPing:SetFontSize(LightUI.defaults.fpsFontSize)
            LightUI.ItemLevelTooltip:SetShown(LightUI.defaults.showItemLevel)
            LightUI.ItemLevelIcons:SetShown(LightUI.defaults.showItemLevelIcons)
            LightKitDB.itemLevelIconFontSize = LightUI.defaults.itemLevelIconFontSize
            LightKitDB.itemLevelIconFont     = LightUI.defaults.itemLevelIconFont
            LightUI.ItemLevelIcons:RefreshFont()
            LightUI.EnchantLabels:SetShown(LightUI.defaults.showEnchantLabels)
            LightUI.GoldTracker:SetShown(LightUI.defaults.showGoldTracker)
            LightUI.GoldTracker:SetLocked(LightUI.defaults.goldFrameLocked)
            LightUI.GoldTracker:SetDisplayMode(LightUI.defaults.goldDisplayMode)
            LightKitDB.goldHideEmpty = LightUI.defaults.goldHideEmpty
            LightUI.VendorUtils:SetAutoRepair(LightUI.defaults.autoRepair)
            LightUI.VendorUtils:SetAutoSellGrey(LightUI.defaults.autoSellGrey)
            LightUI.ChatCopy:SetShown(LightUI.defaults.showChatCopy)
            SetCVar("AutoPushSpellToActionBar", "0") -- default: auto-add disabled
            print("|cffffd700Light Kit:|r All settings reset to defaults.")
            Settings.OpenToCategory(M.category:GetID())
        end

        local resetInit = CreateSettingsButtonInitializer(
            "Reset All Settings",
            "Reset to Defaults",
            ResetAllSettings,
            "Restore every Light Kit setting to its default value.",
            false)
        layout:AddInitializer(resetInit)
    end

    -- ================================================================
    --  Subcategory: FPS & Ping
    -- ================================================================
    local fpsCat = Settings.RegisterVerticalLayoutSubcategory(category, "FPS & Ping")

    -- Show / hide the overlay frame
    local fpsPingSetting = Settings.RegisterProxySetting(
        fpsCat,
        "LUI_ShowFPSPing",
        Settings.VarType.Boolean,
        "Show FPS & Ping Frame",
        LightUI.defaults.showFPSPing,
        function() return LightKitDB.showFPSPing end,
        function(value) LightUI.FPSPing:SetShown(value) end
    )
    Settings.CreateCheckbox(fpsCat, fpsPingSetting,
        "Display a small overlay showing current FPS and latency (ms).")

    -- Show FPS counter
    local showFPSSetting = Settings.RegisterProxySetting(
        fpsCat, "LUI_ShowFPS", Settings.VarType.Boolean, "Show FPS",
        LightUI.defaults.showFPS,
        function() return LightKitDB.showFPS end,
        function(value) LightUI.FPSPing:SetShowFPS(value) end
    )
    Settings.CreateCheckbox(fpsCat, showFPSSetting, "Show the frames-per-second counter.")

    -- Show Ping counter
    local showPingSetting = Settings.RegisterProxySetting(
        fpsCat, "LUI_ShowPing", Settings.VarType.Boolean, "Show Ping",
        LightUI.defaults.showPing,
        function() return LightKitDB.showPing end,
        function(value) LightUI.FPSPing:SetShowPing(value) end
    )
    Settings.CreateCheckbox(fpsCat, showPingSetting, "Show the network latency (ping) counter.")

    -- Lock frame position
    local fpsLockSetting = Settings.RegisterProxySetting(
        fpsCat,
        "LUI_LockFPSPingFrame",
        Settings.VarType.Boolean,
        "Lock FPS & Ping frame position",
        LightUI.defaults.fpsFrameLocked,
        function() return LightKitDB.fpsFrameLocked end,
        function(value) LightUI.FPSPing:SetLocked(value) end
    )
    Settings.CreateCheckbox(fpsCat, fpsLockSetting,
        "Prevent accidental movement. When locked, hold Shift and drag to reposition the frame.")

    -- Font size slider
    local fpsFontSizeSetting = Settings.RegisterProxySetting(
        fpsCat,
        "LUI_FpsFontSize",
        Settings.VarType.Number,
        "FPS & Ping font size",
        LightUI.defaults.fpsFontSize,
        function() return LightKitDB.fpsFontSize end,
        function(value) LightUI.FPSPing:SetFontSize(value) end
    )
    local fpsSizeSliderOptions = Settings.CreateSliderOptions(8, 32, 1)
    fpsSizeSliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    Settings.CreateSlider(fpsCat, fpsFontSizeSetting, fpsSizeSliderOptions,
        "Font size for the FPS and Ping labels (8–32).")

    -- ================================================================
    --  Subcategory: Item Level & Gear
    -- ================================================================
    local ilvlCat = Settings.RegisterVerticalLayoutSubcategory(category, "Item Level & Gear")

    -- Tooltip item level
    local ilvlSetting = Settings.RegisterProxySetting(
        ilvlCat,
        "LUI_ShowItemLevel",
        Settings.VarType.Boolean,
        "Show Item Level on unit tooltip",
        LightUI.defaults.showItemLevel,
        function() return LightKitDB.showItemLevel end,
        function(value) LightUI.ItemLevelTooltip:SetShown(value) end
    )
    Settings.CreateCheckbox(ilvlCat, ilvlSetting,
        "Appends the inspected item level to the tooltip when hovering a player character.")

    -- Gear icon item level overlay
    local ilvlIconsSetting = Settings.RegisterProxySetting(
        ilvlCat,
        "LUI_ShowItemLevelIcons",
        Settings.VarType.Boolean,
        "Show Item Level on gear icons",
        LightUI.defaults.showItemLevelIcons,
        function() return LightKitDB.showItemLevelIcons end,
        function(value) LightUI.ItemLevelIcons:SetShown(value) end
    )
    Settings.CreateCheckbox(ilvlCat, ilvlIconsSetting,
        "Displays the item level as a number over each gear icon in the Character, Inspect, and Bags panels.")

    -- Item level icon font size
    local fontSizeSetting = Settings.RegisterProxySetting(
        ilvlCat,
        "LUI_ItemLevelIconFontSize",
        Settings.VarType.Number,
        "Item level icon font size",
        LightUI.defaults.itemLevelIconFontSize,
        function() return LightKitDB.itemLevelIconFontSize end,
        function(value)
            LightKitDB.itemLevelIconFontSize = value
            LightUI.ItemLevelIcons:RefreshFont()
        end
    )
    local sliderOptions = Settings.CreateSliderOptions(8, 32, 1)
    sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    Settings.CreateSlider(ilvlCat, fontSizeSetting, sliderOptions,
        "Font size for the item level numbers drawn over gear icons (8–32).")

    -- Item level icon font face
    local fontSetting = Settings.RegisterProxySetting(
        ilvlCat,
        "LUI_ItemLevelIconFont",
        Settings.VarType.String,
        "Item level icon font",
        LightUI.defaults.itemLevelIconFont,
        function() return LightKitDB.itemLevelIconFont end,
        function(value)
            LightKitDB.itemLevelIconFont = value
            LightUI.ItemLevelIcons:RefreshFont()
        end
    )
    local function GetFontOptions()
        local container = Settings.CreateControlTextContainer()
        for _, entry in ipairs(LightUI.ItemLevelIcons.FONTS) do
            container:Add(entry.path, entry.label)
        end
        -- LibSharedMedia-3.0 soft dependency
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        if LSM then
            local seen = {}
            for _, entry in ipairs(LightUI.ItemLevelIcons.FONTS) do seen[entry.path] = true end
            for _, name in ipairs(LSM:List("font")) do
                local path = LSM:Fetch("font", name)
                if path and not seen[path] then
                    seen[path] = true
                    container:Add(path, name)
                end
            end
        end
        return container:GetData()
    end
    Settings.CreateDropdown(ilvlCat, fontSetting, GetFontOptions,
        "Font used for the item level numbers drawn over gear icons.")

    -- Enchant labels on gear slots
    local enchantSetting = Settings.RegisterProxySetting(
        ilvlCat,
        "LUI_ShowEnchantLabels",
        Settings.VarType.Boolean,
        "Show enchant names on gear slots",
        LightUI.defaults.showEnchantLabels,
        function() return LightKitDB.showEnchantLabels end,
        function(value) LightUI.EnchantLabels:SetShown(value) end
    )
    Settings.CreateCheckbox(ilvlCat, enchantSetting,
        "Shows the enchant name beside each gear icon in the Character and Inspect panels.")

    -- ================================================================
    --  Subcategory: Gold Tracker
    -- ================================================================
    local goldCat = Settings.RegisterVerticalLayoutSubcategory(category, "Gold Tracker")

    -- Show / hide the gold frame
    local goldSetting = Settings.RegisterProxySetting(
        goldCat,
        "LUI_ShowGoldTracker",
        Settings.VarType.Boolean,
        "Show gold tracker",
        LightUI.defaults.showGoldTracker,
        function() return LightKitDB.showGoldTracker end,
        function(value) LightUI.GoldTracker:SetShown(value) end
    )
    Settings.CreateCheckbox(goldCat, goldSetting,
        "Displays your current gold with a backdrop. Hover for a per-character account summary.")

    -- Lock frame position
    local goldLockSetting = Settings.RegisterProxySetting(
        goldCat,
        "LUI_LockGoldFrame",
        Settings.VarType.Boolean,
        "Lock gold tracker frame position",
        LightUI.defaults.goldFrameLocked,
        function() return LightKitDB.goldFrameLocked end,
        function(value) LightUI.GoldTracker:SetLocked(value) end
    )
    Settings.CreateCheckbox(goldCat, goldLockSetting,
        "Prevent accidental movement. When locked, hold Shift and drag to reposition the frame.")

    -- Display mode dropdown
    local goldModeSetting = Settings.RegisterProxySetting(
        goldCat,
        "LUI_GoldDisplayMode",
        Settings.VarType.String,
        "Gold indicator display",
        LightUI.defaults.goldDisplayMode,
        function() return LightKitDB.goldDisplayMode end,
        function(value) LightUI.GoldTracker:SetDisplayMode(value) end
    )
    local function GetGoldModeOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("account",   "Account Total")
        container:Add("character", "Current Character")
        return container:GetData()
    end
    Settings.CreateDropdown(goldCat, goldModeSetting, GetGoldModeOptions,
        "Choose whether the gold indicator shows your current character's gold or the account-wide total.")

    -- Hide characters with 0 gold
    local goldHideEmptySetting = Settings.RegisterProxySetting(
        goldCat,
        "LUI_GoldHideEmpty",
        Settings.VarType.Boolean,
        "Hide characters with no gold",
        LightUI.defaults.goldHideEmpty,
        function() return LightKitDB.goldHideEmpty end,
        function(value) LightKitDB.goldHideEmpty = value end
    )
    Settings.CreateCheckbox(goldCat, goldHideEmptySetting,
        "When enabled, characters with 0 gold are omitted from the account tooltip.")

    -- Remove tracked character dropdown
    local goldRemoveSetting = Settings.RegisterProxySetting(
        goldCat,
        "LUI_GoldRemoveChar",
        Settings.VarType.String,
        "Remove tracked character",
        "",
        function() return LightKitDB.goldRemoveChar or "" end,
        function(value)
            if value and value ~= "" then
                local realm, name = value:match("^(.+)\t(.+)$")
                if realm and name then
                    LightUI.GoldTracker:RemoveCharacter(name, realm)
                end
            end
            LightKitDB.goldRemoveChar = ""
        end
    )
    local function GetRemoveCharOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("", "-- Select to remove --")
        local chars = LightKitDB and LightKitDB.characters or {}
        local entries = {}
        for realm, realmChars in pairs(chars) do
            for name in pairs(realmChars) do
                entries[#entries + 1] = { key = realm .. "\t" .. name, label = name .. " (" .. realm .. ")" }
            end
        end
        table.sort(entries, function(a, b) return a.label < b.label end)
        for _, entry in ipairs(entries) do
            container:Add(entry.key, entry.label)
        end
        return container:GetData()
    end
    Settings.CreateDropdown(goldCat, goldRemoveSetting, GetRemoveCharOptions,
        "Select a character to immediately remove them from gold tracking.")

    -- ================================================================
    --  Subcategory: Vendor
    -- ================================================================
    local vendorCat = Settings.RegisterVerticalLayoutSubcategory(category, "Vendor")

    -- Auto-repair
    local autoRepairSetting = Settings.RegisterProxySetting(
        vendorCat,
        "LUI_AutoRepair",
        Settings.VarType.Boolean,
        "Auto-repair at vendors",
        LightUI.defaults.autoRepair,
        function() return LightKitDB.autoRepair end,
        function(value) LightUI.VendorUtils:SetAutoRepair(value) end
    )
    Settings.CreateCheckbox(vendorCat, autoRepairSetting,
        "Automatically repairs all items when opening a vendor that can repair. Prints the cost to chat.")

    -- Auto-sell grey items
    local autoSellGreySetting = Settings.RegisterProxySetting(
        vendorCat,
        "LUI_AutoSellGrey",
        Settings.VarType.Boolean,
        "Auto-sell grey items at vendors",
        LightUI.defaults.autoSellGrey,
        function() return LightKitDB.autoSellGrey end,
        function(value) LightUI.VendorUtils:SetAutoSellGrey(value) end
    )
    Settings.CreateCheckbox(vendorCat, autoSellGreySetting,
        "Automatically sells all Poor-quality (grey) items when opening any vendor. Prints the total sale value to chat.")

    -- ================================================================
    --  Subcategory: Miscellaneous
    -- ================================================================
    local miscCat = Settings.RegisterVerticalLayoutSubcategory(category, "Miscellaneous")

    -- Disable auto-push spells to action bar
    local autoPushSetting = Settings.RegisterProxySetting(
        miscCat,
        "LUI_AutoPushSpellToActionBar",
        Settings.VarType.Boolean,
        "Disable auto add spells",
        true,
        function() return not GetCVarBool("AutoPushSpellToActionBar") end,
        function(value) SetCVar("AutoPushSpellToActionBar", value and "0" or "1") end
    )
    Settings.CreateCheckbox(miscCat, autoPushSetting,
        "When checked, newly learned spells and abilities are NOT automatically placed on your action bars.")

    -- Chat copy button
    local chatCopySetting = Settings.RegisterProxySetting(
        miscCat,
        "LUI_ShowChatCopy",
        Settings.VarType.Boolean,
        "Chat copy button",
        LightUI.defaults.showChatCopy,
        function() return LightKitDB.showChatCopy end,
        function(value) LightUI.ChatCopy:SetShown(value) end
    )
    Settings.CreateCheckbox(miscCat, chatCopySetting,
        "Shows a small \"C\" button in the corner of each chat frame. Click it to open a dialog with the full chat log that you can copy.")

    Settings.RegisterAddOnCategory(category)
    self.category = category

    -- /lightkit  -  open the Light Kit settings panel
    SLASH_LIGHTKIT1 = "/lightkit"
    SlashCmdList["LIGHTKIT"] = function()
        Settings.OpenToCategory(self.category:GetID())
    end
end
