--[[
    Housing Codex - WorldMapButton.lua
    HC icon button on the world map (via Krowi_WorldMapButtons library)
    Left-click opens a dropdown with overlay settings
]]

local _, addon = ...

--------------------------------------------------------------------------------
-- Button Mixin (mixed in via WorldMapButton.xml template)
--------------------------------------------------------------------------------
HousingCodexWorldMapButtonMixin = {}

local function GetMapTooltip()
    return HousingCodexMapTooltip
end

function HousingCodexWorldMapButtonMixin:OnLoad()
end

function HousingCodexWorldMapButtonMixin:Refresh()
    if not addon.db then return end

    local L = addon.L
    local db = addon.db

    self:SetupMenu(function(dropdown, rootDescription)
        rootDescription:SetTag("MENU_WORLD_MAP_HOUSINGCODEX")

        ----------------------------------------------------------------
        -- Zone Overlay section
        ----------------------------------------------------------------
        rootDescription:CreateTitle(L["ZONE_OVERLAY_SECTION_HEADER"])

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

        rootDescription:CreateCheckbox(
            L["ZONE_OVERLAY_INCLUDE_COLLECTED_VENDORS"],
            function() return db.settings.includeCollectedVendorDecor end,
            function()
                db.settings.includeCollectedVendorDecor = not db.settings.includeCollectedVendorDecor
                addon:InvalidateZoneDecorCache()
                if addon.ZoneOverlay then addon.ZoneOverlay:RefreshLayout() end
            end
        )

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

        ----------------------------------------------------------------
        -- Vendor Map Pins section
        ----------------------------------------------------------------
        rootDescription:CreateDivider()
        rootDescription:CreateTitle(L["VENDOR_PINS_SECTION_HEADER"])

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

        local pinAlphaSubmenu = rootDescription:CreateButton(L["VENDOR_PINS_TRANSPARENCY"])
        for _, pct in ipairs({ 100, 80, 60, 40 }) do
            pinAlphaSubmenu:CreateRadio(
                pct .. "%",
                function() return math.floor((db.settings.vendorPinAlpha or 1) * 100 + 0.5) == pct end,
                function()
                    db.settings.vendorPinAlpha = pct / 100
                    local provider = addon.vendorMapProvider
                    if provider then provider:ApplyPinAppearance() end
                end
            )
        end

        local pinScaleSubmenu = rootDescription:CreateButton(L["VENDOR_PINS_SCALE"])
        for _, info in ipairs({ { label = "60%", scale = 0.6 }, { label = "80%", scale = 0.8 }, { label = "100%", scale = 1.0 }, { label = "120%", scale = 1.2 }, { label = "140%", scale = 1.4 } }) do
            pinScaleSubmenu:CreateRadio(
                info.label,
                function() return math.floor((db.settings.vendorPinScale or 1) * 100 + 0.5) == math.floor(info.scale * 100 + 0.5) end,
                function()
                    db.settings.vendorPinScale = info.scale
                    local provider = addon.vendorMapProvider
                    if provider then provider:ApplyPinAppearance() end
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
    local tooltip = GetMapTooltip()
    tooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip_SetTitle(tooltip, addon.L["ZONE_OVERLAY_BUTTON_TOOLTIP"])
    tooltip:Show()
    addon:StyleMapTooltip(tooltip)
end

function HousingCodexWorldMapButtonMixin:OnLeave()
    local tooltip = GetMapTooltip()
    if tooltip:GetOwner() == self then
        tooltip:Hide()
    end
end

--------------------------------------------------------------------------------
-- Deferred initialization (WorldMapFrame may not be loaded yet)
--------------------------------------------------------------------------------
local buttonCreated = false
local waitingForWorldMap = false

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
    elseif not waitingForWorldMap then
        waitingForWorldMap = true
        local function onAddonLoaded(loadedAddon)
            if loadedAddon == "Blizzard_WorldMap" then
                waitingForWorldMap = false
                CreateWorldMapButton()
                addon:UnregisterWoWEvent("ADDON_LOADED", onAddonLoaded)
            end
        end
        addon:RegisterWoWEvent("ADDON_LOADED", onAddonLoaded)
    end
end)
