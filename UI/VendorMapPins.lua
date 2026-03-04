--[[
    Housing Codex - VendorMapPins.lua
    World map vendor pin provider and pin behavior
]]

local ADDON_NAME, addon = ...

local L = addon.L
local C = addon.CONSTANTS.VENDOR_PIN

local TEMPLATE_NAME = "HousingCodexVendorPinTemplate"
local WORLD_MAP_ADDON_NAME = "Blizzard_WorldMap"
local VENDOR_PIN_TEXTURE = "Interface\\AddOns\\HousingCodex\\HC64"

local function GetPinSetting(key)
    local db = addon.db
    if not db or not db.settings then return 1 end
    local v = db.settings[key]
    return (v ~= nil) and v or 1
end

local TOOLTIP_LIST_INDENT = "    "
local TOOLTIP_LIST_BULLET = "- "
local TOOLTIP_LIST_R, TOOLTIP_LIST_G, TOOLTIP_LIST_B = 0.9, 0.9, 0.9
local VENDOR_AREA_POI_STYLE_INFO = {
    areaPoiID = 0,
    isCurrentEvent = false,
    atlasName = "UI-EventPoi-Horn-big",
}

local function IsSupportedVendorMapType(mapType)
    return mapType == Enum.UIMapType.Continent
        or mapType == Enum.UIMapType.Zone
        or mapType == Enum.UIMapType.Dungeon
        or mapType == Enum.UIMapType.Micro
        or mapType == Enum.UIMapType.Orphan
end

local function GetProjectedCoordinates(vendorData, vendorMapID, targetMapID, cachedRect)
    if not addon.HasValidCoordinates(vendorData) then
        return nil, nil
    end

    if vendorMapID == targetMapID then
        return vendorData.x / 100, vendorData.y / 100
    end

    local left, right, top, bottom
    if cachedRect then
        left, right, top, bottom = cachedRect[1], cachedRect[2], cachedRect[3], cachedRect[4]
    else
        left, right, top, bottom = C_Map.GetMapRectOnMap(vendorMapID, targetMapID)
    end
    if not left or not right or not top or not bottom then
        return nil, nil
    end

    local width = right - left
    local height = bottom - top
    if width <= 0 or height <= 0 then
        return nil, nil
    end

    return left + ((vendorData.x / 100) * width), top + ((vendorData.y / 100) * height)
end

local function IsIncompleteProgress(owned, total)
    return total > 0 and owned < total
end

local function GetOrCreateZoneCluster(clustersByZone, zoneMapID)
    local cluster = clustersByZone[zoneMapID]
    if cluster then
        return cluster
    end

    cluster = {
        xSum = 0,
        ySum = 0,
        count = 0,
        owned = 0,
        total = 0,
        vendors = {},
    }
    clustersByZone[zoneMapID] = cluster
    return cluster
end

local function AddClusterVendor(cluster, vendorData, owned, total, x, y)
    cluster.xSum = cluster.xSum + x
    cluster.ySum = cluster.ySum + y
    cluster.count = cluster.count + 1
    cluster.owned = cluster.owned + owned
    cluster.total = cluster.total + total
    cluster.vendors[#cluster.vendors + 1] = {
        npcId = vendorData.npcId,
        npcName = vendorData.npcName,
        uiMapId = vendorData.uiMapId,
        x = vendorData.x,
        y = vendorData.y,
        faction = vendorData.faction,
        owned = owned,
        total = total,
    }
end

local function BuildPinEntriesForMap(mapID, mapType)
    local entries = {}
    local isContinent = mapType == Enum.UIMapType.Continent
    local clustersByZone = isContinent and {} or nil
    local seenNpcIds = isContinent and {} or nil
    local rectCache = {}  -- cache map rect per source map (static geometry, safe within one refresh)

    local vendorsByMapID = addon:GetAllVendorMapVendors()
    for vendorMapID, vendors in pairs(vendorsByMapID or {}) do
        -- Resolve map rect once per unique source map
        if not rectCache[vendorMapID] then
            if vendorMapID == mapID then
                rectCache[vendorMapID] = true  -- identity: no projection needed
            else
                local left, right, top, bottom = C_Map.GetMapRectOnMap(vendorMapID, mapID)
                if left and right and top and bottom then
                    rectCache[vendorMapID] = {left, right, top, bottom}
                else
                    rectCache[vendorMapID] = false  -- invalid: skip projection
                end
            end
        end
        local rect = rectCache[vendorMapID]
        local resolvedRect = type(rect) == "table" and rect or nil

        for _, vendorData in ipairs(vendors) do
            if not (isContinent and seenNpcIds[vendorData.npcId]) then
                local x, y = GetProjectedCoordinates(vendorData, vendorMapID, mapID, resolvedRect)
                if x and y then
                    local owned, total = addon:GetVendorPinProgress(vendorData.npcId)
                    if IsIncompleteProgress(owned, total) then
                        if isContinent then
                            seenNpcIds[vendorData.npcId] = true
                            local zoneMapID = addon:GetZoneRootMapID(vendorMapID) or vendorMapID
                            local cluster = GetOrCreateZoneCluster(clustersByZone, zoneMapID)
                            AddClusterVendor(cluster, vendorData, owned, total, x, y)
                        else
                            entries[#entries + 1] = {
                                vendorData = vendorData,
                                owned = owned,
                                total = total,
                                x = x,
                                y = y,
                                vendorCount = 1,
                                isAggregate = false,
                            }
                        end
                    end
                end
            end
        end
    end

    if mapType == Enum.UIMapType.Continent then
        for _, cluster in pairs(clustersByZone) do
            table.sort(cluster.vendors, function(a, b)
                return (a.npcName or "") < (b.npcName or "")
            end)

            local representative = cluster.vendors[1]
            entries[#entries + 1] = {
                vendorData = representative,
                owned = cluster.owned,
                total = cluster.total,
                x = cluster.xSum / cluster.count,
                y = cluster.ySum / cluster.count,
                vendorCount = cluster.count,
                isAggregate = true,
                aggregateVendors = cluster.vendors,
            }
        end
    end

    return entries
end

local function GetProgressColor(owned, total)
    if total > 0 and owned >= total then
        return 0.2, 1, 0.2
    end

    if total > 0 and owned > 0 then
        return 1, 0.82, 0
    end

    return 0.7, 0.7, 0.7
end

local function IsAggregateVendorPin(pin)
    return pin.isAggregate and pin.aggregateVendors and #pin.aggregateVendors > 1
end

local function AddBulletedTooltipLine(text)
    GameTooltip:AddLine(TOOLTIP_LIST_INDENT .. TOOLTIP_LIST_BULLET .. text, TOOLTIP_LIST_R, TOOLTIP_LIST_G, TOOLTIP_LIST_B)
end

local function ScheduleRefresh(provider)
    local map = provider:GetMap()
    if not map or not map:IsShown() then
        return
    end

    if provider.refreshPending then
        return
    end

    provider.refreshPending = true
    C_Timer.After(C.REFRESH_DEBOUNCE, function()
        provider.refreshPending = false
        local currentMap = provider:GetMap()
        if not currentMap or not currentMap:IsShown() then
            return
        end
        provider:RefreshAllData()
    end)
end

HousingCodexVendorDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin)

local function RegisterProviderListeners(provider)
    if not provider.listeningWoW then
        provider:RegisterEvent("HOUSE_DECOR_ADDED_TO_CHEST")
        provider.listeningWoW = true
    end

    if not provider.listeningInternal and provider.onOwnershipUpdated then
        addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", provider.onOwnershipUpdated)
        provider.listeningInternal = true
    end
end

local function UnregisterProviderListeners(provider)
    if provider.listeningWoW then
        provider:UnregisterEvent("HOUSE_DECOR_ADDED_TO_CHEST")
        provider.listeningWoW = false
    end

    if provider.listeningInternal and provider.onOwnershipUpdated then
        addon:UnregisterInternalEvent("RECORD_OWNERSHIP_UPDATED", provider.onOwnershipUpdated)
        provider.listeningInternal = false
    end
end

function HousingCodexVendorDataProviderMixin:OnAdded(owningMap)
    MapCanvasDataProviderMixin.OnAdded(self, owningMap)
    self.refreshPending = false
    self.listeningWoW = false
    self.listeningInternal = false
    self.onOwnershipUpdated = self.onOwnershipUpdated or function()
        ScheduleRefresh(self)
    end
end

function HousingCodexVendorDataProviderMixin:OnShow()
    RegisterProviderListeners(self)
end

function HousingCodexVendorDataProviderMixin:OnHide()
    UnregisterProviderListeners(self)
end

function HousingCodexVendorDataProviderMixin:OnRemoved(owningMap)
    UnregisterProviderListeners(self)
    self.refreshPending = false
    self:RemoveAllData()
    MapCanvasDataProviderMixin.OnRemoved(self, owningMap)
end

function HousingCodexVendorDataProviderMixin:OnEvent(event, ...)
    if event == "HOUSE_DECOR_ADDED_TO_CHEST" then
        addon:InvalidateVendorPinCache()
        ScheduleRefresh(self)
    end
end

function HousingCodexVendorDataProviderMixin:RemoveAllData()
    local map = self:GetMap()
    if map then
        map:RemoveAllPinsByTemplate(TEMPLATE_NAME)
    end
end

function HousingCodexVendorDataProviderMixin:RefreshAllData(fromOnShow)
    local map = self:GetMap()
    if not map then
        return
    end

    map:RemoveAllPinsByTemplate(TEMPLATE_NAME)

    if not addon.db or not addon.db.settings or not addon.db.settings.showVendorMapPins then
        return
    end

    local mapID = map:GetMapID()
    if not mapID then
        return
    end

    local mapInfo = C_Map.GetMapInfo(mapID)
    if not mapInfo or not IsSupportedVendorMapType(mapInfo.mapType) then
        return
    end

    local pinEntries = BuildPinEntriesForMap(mapID, mapInfo.mapType)
    if #pinEntries == 0 then
        return
    end

    for _, entry in ipairs(pinEntries) do
        local pin = map:AcquirePin(TEMPLATE_NAME, entry.vendorData, entry.owned, entry.total, entry.vendorCount, entry.isAggregate, entry.aggregateVendors)
        pin:SetPosition(entry.x, entry.y)
    end
end

function HousingCodexVendorDataProviderMixin:ApplyPinAppearance()
    local map = self:GetMap()
    if not map then return end
    local alpha = GetPinSetting("vendorPinAlpha")
    local scale = GetPinSetting("vendorPinScale")
    for pin in map:EnumeratePinsByTemplate(TEMPLATE_NAME) do
        pin:SetAlpha(alpha)
        pin:SetScalingLimits(C.SCALE_FACTOR, C.SCALE_MIN * scale, C.SCALE_MAX * scale)
        pin:ApplyCurrentScale()
        pin:ApplyPOIStyle()
    end
end

HousingCodexVendorPinMixin = CreateFromMixins(MapCanvasPinMixin, POIButtonMixin)

function HousingCodexVendorPinMixin:DisableInheritedMotionScriptsWarning()
    return true
end

function HousingCodexVendorPinMixin:ShouldMouseButtonBePassthrough(button)
    return button ~= "LeftButton"
end

function HousingCodexVendorPinMixin:OnLoad()
    self:SetSize(C.SIZE, C.SIZE)
    self:SetScalingLimits(C.SCALE_FACTOR, C.SCALE_MIN, C.SCALE_MAX)
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")

    self:SetStyle(POIButtonUtil.Style.AreaPOI)
    self:SetAreaPOIInfo(VENDOR_AREA_POI_STYLE_INFO)
    self:ClearSelected()

    local fontPath = addon:GetFontPath()
    local _, size = self.CountMaskText:GetFont()
    self.CountMaskText:SetFont(fontPath, (size or 10) + 1, "OUTLINE")
    self.CountMaskText:SetTextColor(1, 1, 1, 1)
end

function HousingCodexVendorPinMixin:ApplyPOIStyle()
    self:UpdateButtonStyle()
    self.Display:SetIconShown(false)
    self.Glow:SetShown(false)

    self.HCIcon:SetTexture(VENDOR_PIN_TEXTURE)
    self.HCIcon:SetTexCoord(0, 1, 0, 1)

    local minimal = addon.db and addon.db.settings and addon.db.settings.vendorPinMinimal
    local buttonAlpha = minimal and 0 or 1
    self.NormalTexture:SetAlpha(buttonAlpha)
    self.PushedTexture:SetAlpha(buttonAlpha)
    self.HighlightTexture:SetAlpha(buttonAlpha)

    self.HCShadow:SetTexture(VENDOR_PIN_TEXTURE)
    self.HCShadow:SetTexCoord(0, 1, 0, 1)
    self.HCShadow:SetShown(minimal)
end

function HousingCodexVendorPinMixin:UpdateCountText()
    if self.isAggregate and self.vendorCount > 1 then
        self.CountMaskText:SetText("x" .. self.vendorCount)
        self.CountMaskText:Show()
        return
    end

    self.CountMaskText:Hide()
end

function HousingCodexVendorPinMixin:OnAcquired(vendorData, owned, total, vendorCount, isAggregate, aggregateVendors)
    self.vendorData = vendorData
    self.owned = owned or 0
    self.total = total or 0
    self.vendorCount = vendorCount or 1
    self.isAggregate = isAggregate or false
    self.aggregateVendors = aggregateVendors

    self:ApplyPOIStyle()
    self:SetAlpha(GetPinSetting("vendorPinAlpha"))
    local scale = GetPinSetting("vendorPinScale")
    self:SetScalingLimits(C.SCALE_FACTOR, C.SCALE_MIN * scale, C.SCALE_MAX * scale)
    self:UpdateCountText()
end

function HousingCodexVendorPinMixin:OnReleased()
    self.vendorData = nil
    self.owned = nil
    self.total = nil
    self.vendorCount = nil
    self.isAggregate = nil
    self.aggregateVendors = nil
    self.HCIcon:SetTexture(nil)
    self:UpdateCountText()
    self:SetAlpha(1)
    self:SetScalingLimits(C.SCALE_FACTOR, C.SCALE_MIN, C.SCALE_MAX)
    MapCanvasPinMixin.OnReleased(self)
end

function HousingCodexVendorPinMixin:OnEnter()
    POIButtonMixin.OnEnter(self)
    self:OnMouseEnter()
end

function HousingCodexVendorPinMixin:OnLeave()
    POIButtonMixin.OnLeave(self)
    self:OnMouseLeave()
end

function HousingCodexVendorPinMixin:OnClick(button)
    self:OnMouseClickAction(button)
end

function HousingCodexVendorPinMixin:OnMouseEnter()
    if not self.vendorData then
        return
    end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

    if IsAggregateVendorPin(self) then
        local aggregateVendors = self.aggregateVendors
        local aggregateCount = #aggregateVendors
        GameTooltip:AddLine(string.format(L["VENDOR_PIN_VENDOR_COUNT"], aggregateCount), 1, 0.82, 0)
        GameTooltip:AddLine(L["VENDOR_PIN_VENDOR_LIST_HEADER"], 0.85, 0.85, 0.85)

        local vendorLimit = C.TOOLTIP_ITEM_LIMIT
        local shown = math.min(aggregateCount, vendorLimit)
        for i = 1, shown do
            local vendor = aggregateVendors[i]
            local vendorEntry = string.format(L["VENDOR_PIN_VENDOR_ENTRY"], vendor.npcName or L["VENDOR_UNKNOWN"], vendor.owned, vendor.total)
            AddBulletedTooltipLine(vendorEntry)
        end

        local overflow = aggregateCount - shown
        if overflow > 0 then
            GameTooltip:AddLine(string.format(L["VENDOR_PIN_VENDORS_MORE"], overflow), 0.7, 0.7, 0.7)
        end

        GameTooltip:Show()
        return
    end

    local vendorName = self.vendorData.npcName or L["VENDOR_UNKNOWN"]
    local owned, total, missingNames = addon:GetVendorPinProgress(self.vendorData.npcId)

    GameTooltip:AddLine(vendorName, 1, 0.82, 0)

    local zoneCache = addon.vendorZoneCache and addon.vendorZoneCache[self.vendorData.npcId]
    local classHall = zoneCache and addon:GetClassHallAnnotation(zoneCache.zoneName)
    if classHall then
        local cr, cg, cb = addon:GetClassColorRGB(classHall)
        GameTooltip:AddLine(string.format(L["VENDOR_CLASS_ONLY_SUFFIX"], classHall), cr, cg, cb)
    end

    local r, g, b = GetProgressColor(owned, total)
    GameTooltip:AddLine(string.format(L["VENDOR_PIN_COLLECTED"], owned, total), r, g, b)
    GameTooltip:AddLine(" ")

    if owned < total and #missingNames > 0 then
        GameTooltip:AddLine(L["VENDOR_PIN_UNCOLLECTED_HEADER"], 0.85, 0.85, 0.85)
        for _, name in ipairs(missingNames) do
            AddBulletedTooltipLine(name)
        end

        local overflow = (total - owned) - #missingNames
        if overflow > 0 then
            GameTooltip:AddLine(string.format(L["VENDOR_PIN_MORE"], overflow), 0.7, 0.7, 0.7)
        end
    end

    if self.vendorData.faction == "Alliance" then
        GameTooltip:AddLine(L["VENDOR_PIN_FACTION_ALLIANCE"], 0.35, 0.6, 1)
    elseif self.vendorData.faction == "Horde" then
        GameTooltip:AddLine(L["VENDOR_PIN_FACTION_HORDE"], 1, 0.3, 0.3)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["VENDOR_PIN_CLICK_WAYPOINT"], 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

function HousingCodexVendorPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

function HousingCodexVendorPinMixin:OnMouseClickAction(button)
    if button ~= "LeftButton" or not self.vendorData then
        return
    end

    if IsAggregateVendorPin(self) then
        local zoneMapID = addon:GetZoneRootMapID(self.vendorData.uiMapId) or self.vendorData.uiMapId
        if zoneMapID and not InCombatLockdown() then
            C_Map.OpenWorldMap(zoneMapID)
        end
        return
    end

    local mapID = self.vendorData.uiMapId
    if not addon.IsValidMapId(mapID) then
        return
    end

    local tomtomActive = addon.Waypoints and addon.Waypoints:IsTomTomActive()
    if not tomtomActive and not C_Map.CanSetUserWaypointOnMap(mapID) then
        return
    end

    if not addon.HasValidCoordinates(self.vendorData) then
        return
    end

    local normX, normY = self.vendorData.x / 100, self.vendorData.y / 100
    local npcName = self.vendorData.npcName
    if not addon.Waypoints:Set(mapID, normX, normY, npcName or "Vendor") then
        return
    end

    PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_BUTTON_CLICK_ON)
end

local providerRegistered = false
local waitingForWorldMap = false

local function RegisterProvider()
    if providerRegistered then
        return
    end

    if not WorldMapFrame or not WorldMapFrame.AddDataProvider then
        return
    end

    local provider = CreateFromMixins(HousingCodexVendorDataProviderMixin)
    WorldMapFrame:AddDataProvider(provider)
    addon.vendorMapProvider = provider
    providerRegistered = true
end

local function OnWorldMapAddonLoaded(loadedAddon)
    if loadedAddon ~= WORLD_MAP_ADDON_NAME then
        return
    end

    RegisterProvider()
    addon:UnregisterWoWEvent("ADDON_LOADED", OnWorldMapAddonLoaded)
    waitingForWorldMap = false
end

addon:RegisterInternalEvent("DATA_LOADED", function()
    if providerRegistered then
        return
    end

    if WorldMapFrame and WorldMapFrame.AddDataProvider then
        RegisterProvider()
    elseif not waitingForWorldMap then
        addon:RegisterWoWEvent("ADDON_LOADED", OnWorldMapAddonLoaded)
        waitingForWorldMap = true
    end
end)
