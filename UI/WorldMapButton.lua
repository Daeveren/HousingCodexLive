--[[
    Housing Codex - WorldMapButton.lua
    HC icon button on the world map (via Krowi_WorldMapButtons library)
    Left-click opens a dropdown with overlay settings
]]

local ADDON_NAME, addon = ...

--------------------------------------------------------------------------------
-- Button Mixin (mixed in via WorldMapButton.xml template)
--------------------------------------------------------------------------------
HousingCodexWorldMapButtonMixin = {}

function HousingCodexWorldMapButtonMixin:OnLoad()
    -- Initial setup happens in Refresh (called by Krowi lib after positioning)
end

function HousingCodexWorldMapButtonMixin:Refresh()
    if not addon.db then return end

    local L = addon.L
    local db = addon.db

    self:SetupMenu(function(dropdown, rootDescription)
        rootDescription:SetTag("MENU_WORLD_MAP_HOUSINGCODEX")

        -- Checkbox: Show Zone Overlay
        rootDescription:CreateCheckbox(
            L["ZONE_OVERLAY_SHOW"],
            function() return db.settings.showZoneOverlay end,
            function()
                db.settings.showZoneOverlay = not db.settings.showZoneOverlay
                if addon.ZoneOverlay then
                    addon.ZoneOverlay:UpdateVisibility()
                end
            end
        )

        -- Checkbox: Show Vendor Map Pins
        rootDescription:CreateCheckbox(
            L["ZONE_OVERLAY_PINS"],
            function() return db.settings.showVendorMapPins end,
            function()
                db.settings.showVendorMapPins = not db.settings.showVendorMapPins
                local provider = addon.vendorMapProvider
                if provider then
                    local map = provider:GetMap()
                    if map and map:IsShown() then
                        provider:RefreshAllData()
                    end
                end
            end
        )

        -- Checkbox: Include already unlocked decor vendors
        rootDescription:CreateCheckbox(
            L["ZONE_OVERLAY_INCLUDE_COLLECTED_VENDORS"],
            function() return db.settings.includeCollectedVendorDecor end,
            function()
                db.settings.includeCollectedVendorDecor = not db.settings.includeCollectedVendorDecor
                addon:InvalidateZoneDecorCache()
                if addon.ZoneOverlay then addon.ZoneOverlay:RefreshLayout() end
            end
        )

        -- Submenu: Panel Position
        local posSubmenu = rootDescription:CreateButton(L["ZONE_OVERLAY_POSITION"])
        posSubmenu:CreateRadio(
            L["ZONE_OVERLAY_POS_TOPLEFT"],
            function() return db.settings.zoneOverlayPosition == "topLeft" end,
            function()
                db.settings.zoneOverlayPosition = "topLeft"
                if addon.ZoneOverlay then addon.ZoneOverlay:RefreshLayout() end
            end
        )
        posSubmenu:CreateRadio(
            L["ZONE_OVERLAY_POS_BOTTOMRIGHT"],
            function() return db.settings.zoneOverlayPosition == "bottomRight" end,
            function()
                db.settings.zoneOverlayPosition = "bottomRight"
                if addon.ZoneOverlay then addon.ZoneOverlay:RefreshLayout() end
            end
        )

        -- Submenu: Transparency
        local alphaSubmenu = rootDescription:CreateButton(L["ZONE_OVERLAY_TRANSPARENCY"])
        for _, pct in ipairs({ 100, 80, 60, 40 }) do
            alphaSubmenu:CreateRadio(
                pct .. "%",
                function() return math.floor(db.settings.zoneOverlayAlpha * 100 + 0.5) == pct end,
                function()
                    db.settings.zoneOverlayAlpha = pct / 100
                    if addon.ZoneOverlay then addon.ZoneOverlay:UpdateAlpha() end
                end
            )
        end

        -- Submenu: Preview Size
        local previewSubmenu = rootDescription:CreateButton(L["ZONE_OVERLAY_PREVIEW_SIZE"])
        for _, info in ipairs({ { label = "50%", scale = 0.5 }, { label = "100%", scale = 1.0 }, { label = "150%", scale = 1.5 } }) do
            previewSubmenu:CreateRadio(
                info.label,
                function() return db.settings.zoneOverlayPreviewScale == info.scale end,
                function()
                    db.settings.zoneOverlayPreviewScale = info.scale
                    if addon.ZoneOverlay then addon.ZoneOverlay:UpdatePreviewSize() end
                end
            )
        end
    end)
end

function HousingCodexWorldMapButtonMixin:OnMouseDown()
    self.Icon:SetPoint("TOPLEFT", 8, -8)
end

function HousingCodexWorldMapButtonMixin:OnMouseUp()
    self.Icon:SetPoint("TOPLEFT", 6, -6)
end

function HousingCodexWorldMapButtonMixin:OnEnter()
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(addon.L["ZONE_OVERLAY_BUTTON_TOOLTIP"])
    GameTooltip:Show()
end

--------------------------------------------------------------------------------
-- Deferred initialization (WorldMapFrame may not be loaded yet)
--------------------------------------------------------------------------------
local buttonCreated = false

local function CreateWorldMapButton()
    if buttonCreated then return end
    buttonCreated = true

    local rwm = LibStub("Krowi_WorldMapButtons-1.4")
    addon.worldMapButton = rwm:Add("HousingCodexWorldMapButtonTemplate", "DropdownButton")
    addon:Debug("World map button created")
end

addon:RegisterInternalEvent("DATA_LOADED", function()
    if buttonCreated then return end

    if WorldMapFrame and WorldMapFrame.AddDataProvider then
        CreateWorldMapButton()
    else
        local function onAddonLoaded(loadedAddon)
            if loadedAddon == "Blizzard_WorldMap" then
                CreateWorldMapButton()
                addon:UnregisterWoWEvent("ADDON_LOADED", onAddonLoaded)
            end
        end
        addon:RegisterWoWEvent("ADDON_LOADED", onAddonLoaded)
    end
end)
