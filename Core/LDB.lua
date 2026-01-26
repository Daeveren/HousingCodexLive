--[[
    Housing Codex - LDB.lua
    LibDataBroker support for broker display addons (Titan Panel, ChocolateBar, etc.)
]]

local ADDON_NAME, addon = ...

-- Create LDB module
addon.LDB = {}
local LDB = addon.LDB

local dataObject = nil

function LDB:Initialize()
    -- Check for LibDataBroker availability (provided by broker display addons)
    local LibStub = _G.LibStub
    if not LibStub then return end

    local LDBLib = LibStub:GetLibrary("LibDataBroker-1.1", true)
    if not LDBLib then return end

    -- Create data object
    dataObject = LDBLib:NewDataObject(ADDON_NAME, {
        type = "launcher",
        icon = "Interface\\AddOns\\HousingCodex\\HC",
        text = "",
        OnClick = function(clickedframe, button)
            if button == "LeftButton" then
                if InCombatLockdown() then
                    addon:Print(addon.L["COMBAT_LOCKDOWN_MESSAGE"])
                    return
                end
                if addon.MainFrame then
                    addon.MainFrame:Toggle()
                end
            elseif button == "RightButton" then
                if InCombatLockdown() then
                    addon:Print(addon.L["COMBAT_LOCKDOWN_MESSAGE"])
                    return
                end
                -- Open WoW Settings to Housing Codex panel
                if addon.Settings and addon.Settings.Open then
                    addon.Settings:Open()
                else
                    addon:Print(addon.L["LDB_OPTIONS_PLACEHOLDER"])
                end
            end
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip or not tooltip.AddLine then return end
            tooltip:AddLine(addon.L["ADDON_NAME"])
            tooltip:AddLine(" ")
            tooltip:AddLine(addon.L["LDB_TOOLTIP_LEFT"], 0.8, 0.8, 0.8)
            tooltip:AddLine(addon.L["LDB_TOOLTIP_RIGHT"], 0.8, 0.8, 0.8)
        end,
    })

    addon:Debug("LDB data object created")
end

function LDB:UpdateText()
    if not dataObject then return end

    -- Check if text display is enabled (icon-only mode if disabled)
    if addon.db and addon.db.settings and addon.db.settings.ldbShowText == false then
        dataObject.text = ""
        return
    end

    -- Count collected/total from indexes
    local collected = 0
    local total = 0

    if addon.indexesBuilt then
        -- Use prebuilt indexes for efficiency
        for _ in pairs(addon.indexes.collected) do
            collected = collected + 1
        end
        for _ in pairs(addon.decorRecords) do
            total = total + 1
        end
    end

    -- Format: "256/1020"
    dataObject.text = string.format("%d/%d", collected, total)
end

-- Event handlers
addon:RegisterInternalEvent("DATA_LOADED", function()
    -- Initialize LDB after data is loaded (ensures indexes exist)
    LDB:Initialize()
    LDB:UpdateText()
end)

addon:RegisterInternalEvent("RECORD_UPDATED", function()
    -- Debounce rapid updates
    if LDB.updatePending then return end
    LDB.updatePending = true
    C_Timer.After(0.1, function()
        LDB.updatePending = false
        -- Rebuild indexes to get accurate counts
        if addon.indexesBuilt then
            addon:BuildIndexes()
        end
        LDB:UpdateText()
    end)
end)

-- Also listen for bulk storage updates
addon:RegisterWoWEvent("HOUSING_STORAGE_UPDATED", function()
    if not addon.dataLoaded then return end

    if LDB.updatePending then return end
    LDB.updatePending = true
    C_Timer.After(0.5, function()
        LDB.updatePending = false
        if addon.indexesBuilt then
            addon:BuildIndexes()
        end
        LDB:UpdateText()
    end)
end)
