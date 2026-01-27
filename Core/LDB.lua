--[[
    Housing Codex - LDB.lua
    LibDataBroker support for broker display addons (Titan Panel, ChocolateBar, etc.)
]]

local ADDON_NAME, addon = ...

-- Create LDB module
addon.LDB = {}
local LDB = addon.LDB

local dataObject = nil
local libDBIcon = nil

-- Shared click handler for LDB and AddonCompartment
local function HandleClick(button)
    if InCombatLockdown() then
        addon:Print(addon.L["COMBAT_LOCKDOWN_MESSAGE"])
        return
    end
    if button == "LeftButton" then
        if addon.MainFrame then
            addon.MainFrame:Toggle()
        end
    elseif button == "RightButton" then
        if addon.Settings and addon.Settings.Open then
            addon.Settings:Open()
        else
            addon:Print(addon.L["LDB_OPTIONS_PLACEHOLDER"])
        end
    end
end

-- Shared tooltip builder for LDB and AddonCompartment
local function ShowTooltip(tooltip)
    if not tooltip or not tooltip.AddLine then return end
    tooltip:AddLine(addon.L["ADDON_NAME"])
    tooltip:AddLine(" ")
    tooltip:AddLine(addon.L["LDB_TOOLTIP_LEFT"], 0.8, 0.8, 0.8)
    tooltip:AddLine(addon.L["LDB_TOOLTIP_RIGHT"], 0.8, 0.8, 0.8)
end

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
        OnClick = function(_, button) HandleClick(button) end,
        OnTooltipShow = ShowTooltip,
    })

    addon:Debug("LDB data object created")

    -- Register with LibDBIcon for standalone minimap button
    libDBIcon = LibStub("LibDBIcon-1.0", true)
    if libDBIcon then
        addon.db.minimap = addon.db.minimap or {}
        libDBIcon:Register(ADDON_NAME, dataObject, addon.db.minimap)
        -- Apply saved visibility setting
        self:SetMinimapShown(addon.db.settings.showMinimapButton)
        addon:Debug("LibDBIcon registered")
    end
end

function LDB:SetMinimapShown(show)
    if not libDBIcon then return end

    if show then
        libDBIcon:Show(ADDON_NAME)
    else
        libDBIcon:Hide(ADDON_NAME)
    end
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

-- Debounced refresh: rebuild indexes and update broker text
local function DebouncedRefresh(delay)
    if LDB.updatePending then return end
    LDB.updatePending = true
    C_Timer.After(delay, function()
        LDB.updatePending = false
        if addon.indexesBuilt then
            addon:BuildIndexes()
        end
        LDB:UpdateText()
    end)
end

-- Event handlers
addon:RegisterInternalEvent("DATA_LOADED", function()
    LDB:Initialize()
    LDB:UpdateText()
end)

addon:RegisterInternalEvent("RECORD_UPDATED", function()
    DebouncedRefresh(0.1)
end)

-- ============================================================================
-- Addon Compartment (built-in minimap dropdown, no libs required)
-- ============================================================================

function HousingCodex_OnAddonCompartmentClick(_, button)
    HandleClick(button)
end

function HousingCodex_OnAddonCompartmentEnter(_, menuButtonFrame)
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    ShowTooltip(GameTooltip)
    GameTooltip:Show()
end

function HousingCodex_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

-- Also listen for bulk storage updates
addon:RegisterWoWEvent("HOUSING_STORAGE_UPDATED", function()
    if not addon.dataLoaded then return end
    DebouncedRefresh(0.5)
end)
