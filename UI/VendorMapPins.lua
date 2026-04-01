--[[
    Housing Codex - VendorMapPins.lua
    World map vendor pin provider and pin behavior
]]

local _, addon = ...

local L = addon.L
local C = addon.CONSTANTS.VENDOR_PIN

local TEMPLATE_NAME = "HousingCodexVendorPinTemplate"
local WORLD_MAP_ADDON_NAME = "Blizzard_WorldMap"
local VENDOR_PIN_TEXTURE = "Interface\\AddOns\\HousingCodex\\HC64"

local function GetMapTooltip()
    return HousingCodexMapTooltip
end

-- Module-level rect cache: map coordinate projections are static geometry,
-- so cache persists across refreshes of the same target map.
local pinRectCache = {}
local pinRectCacheMapID = nil

function addon:StyleMapTooltip(tooltip)
    local nine = tooltip.NineSlice
    if not nine then return end
    nine:SetCenterColor(0.08, 0.08, 0.1, 1)
    nine:SetBorderColor(0.45, 0.45, 0.45, 1)
end

local function GetPinSetting(key)
    local db = addon.db
    if not db or not db.settings then return 1 end
    local v = db.settings[key]
    return (v ~= nil) and v or 1
end

local TOOLTIP_LIST_INDENT = "    "
local TOOLTIP_LIST_BULLET = "- "

-- Tooltip color objects (modern GameTooltip helpers)
local COLOR_GOLD = CreateColor(1, 0.82, 0, 1)
local COLOR_LIGHT_GRAY = CreateColor(0.85, 0.85, 0.85, 1)
local COLOR_MEDIUM_GRAY = CreateColor(0.7, 0.7, 0.7, 1)
local COLOR_ITEM_LIST = CreateColor(0.9, 0.9, 0.9, 1)
local COLOR_ALLIANCE = CreateColor(0.35, 0.6, 1, 1)
local COLOR_HORDE = CreateColor(1, 0.3, 0.3, 1)
local COLOR_PROGRESS_COMPLETE = CreateColor(0.2, 1, 0.2, 1)
local VENDOR_AREA_POI_STYLE_INFO = {
    areaPoiID = 0,
    isCurrentEvent = false,
    atlasName = "UI-EventPoi-Horn-big",
}

-- Vendors inside sub-areas with no separate uiMapId: override display coords to entrance
local PIN_COORD_OVERRIDES = {
    [255114] = { x = 58, y = 51 },  -- Maku (The Den, Harandar)
    [258540] = { x = 53, y = 51 },  -- Hawli (The Den, Harandar)
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
    local isZone = mapType == Enum.UIMapType.Zone
    local clustersByZone = isContinent and {} or nil
    local clustersBySubzone = isZone and {} or nil
    local seenNpcIds = (isContinent or isZone) and {} or nil

    -- Invalidate rect cache on map change (static geometry, safe to persist within same map)
    if pinRectCacheMapID ~= mapID then
        wipe(pinRectCache)
        pinRectCacheMapID = mapID
    end

    local vendorsByMapID = addon:GetAllVendorMapVendors()
    for _, vendors in pairs(vendorsByMapID or {}) do
        for _, vendorData in ipairs(vendors) do
            local sourceMapID = vendorData.uiMapId
            local dedupKey = seenNpcIds and (vendorData.npcId .. ":" .. (sourceMapID or 0))
            if not seenNpcIds or not seenNpcIds[dedupKey] then
                -- Resolve map rect once per unique source map
                if sourceMapID and not pinRectCache[sourceMapID] then
                    if sourceMapID == mapID then
                        pinRectCache[sourceMapID] = true  -- identity: no projection needed
                    else
                        local left, right, top, bottom = C_Map.GetMapRectOnMap(sourceMapID, mapID)
                        if left and right and top and bottom then
                            pinRectCache[sourceMapID] = {left, right, top, bottom}
                        else
                            pinRectCache[sourceMapID] = false  -- invalid: skip projection
                        end
                    end
                end
                local rect = sourceMapID and pinRectCache[sourceMapID]
                local resolvedRect = type(rect) == "table" and rect or nil

                local x, y = GetProjectedCoordinates(vendorData, sourceMapID, mapID, resolvedRect)
                local pinOverride = PIN_COORD_OVERRIDES[vendorData.npcId]
                if pinOverride and sourceMapID == mapID then
                    x, y = pinOverride.x / 100, pinOverride.y / 100
                end
                if x and y then
                    local owned, total = addon:GetVendorPinProgress(vendorData.npcId)
                    if IsIncompleteProgress(owned, total) then
                        if seenNpcIds then
                            seenNpcIds[dedupKey] = true
                        end
                        if isContinent then
                            local zoneMapID = addon:GetZoneRootMapID(sourceMapID) or sourceMapID
                            local cluster = GetOrCreateZoneCluster(clustersByZone, zoneMapID)
                            AddClusterVendor(cluster, vendorData, owned, total, x, y)
                        elseif isZone and vendorData.uiMapId and vendorData.uiMapId ~= mapID then
                            local cluster = GetOrCreateZoneCluster(clustersBySubzone, vendorData.uiMapId)
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

    if isContinent then
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

    if isZone then
        for _, cluster in pairs(clustersBySubzone) do
            if cluster.count >= 2 then
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
            else
                entries[#entries + 1] = {
                    vendorData = cluster.vendors[1],
                    owned = cluster.owned,
                    total = cluster.total,
                    x = cluster.xSum / cluster.count,
                    y = cluster.ySum / cluster.count,
                    vendorCount = 1,
                    isAggregate = false,
                }
            end
        end
    end

    return entries
end

local function GetProgressColor(owned, total)
    if total > 0 and owned >= total then
        return COLOR_PROGRESS_COMPLETE
    end

    if total > 0 and owned > 0 then
        return COLOR_GOLD
    end

    return COLOR_MEDIUM_GRAY
end

local function IsAggregateVendorPin(pin)
    return pin.isAggregate and pin.aggregateVendors and #pin.aggregateVendors > 1
end

local function AddBulletedTooltipLine(tooltip, text)
    GameTooltip_AddColoredLine(tooltip, TOOLTIP_LIST_INDENT .. TOOLTIP_LIST_BULLET .. text, COLOR_ITEM_LIST, false)
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
    self.onOwnershipUpdated = self.onOwnershipUpdated or function(recordID, collectionStateChanged)
        if not collectionStateChanged then return end
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
        pin:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
        pin:ApplyFrameLevel()
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
    addon:RegisterFontStringWithSize(self.CountMaskText, "GameFontNormalSmall", (size or 10) + 1, "OUTLINE")
    self.CountMaskText:SetTextColor(1, 1, 1, 1)
end

function HousingCodexVendorPinMixin:ApplyPOIStyle()
    self:UpdateButtonStyle()
    self.Display:SetIconShown(false)
    self.Glow:SetShown(false)

    self.HCIcon:SetTexture(VENDOR_PIN_TEXTURE)
    self.HCIcon:SetTexCoord(0, 1, 0, 1)
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
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:ApplyFrameLevel()
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
    self.HighlightTexture:Show()
    self:OnMouseEnter()
end

function HousingCodexVendorPinMixin:OnLeave()
    self.HighlightTexture:Hide()
    self:OnMouseLeave()
end

function HousingCodexVendorPinMixin:OnClick(button)
    self:OnMouseClickAction(button)
end

function HousingCodexVendorPinMixin:OnMouseEnter()
    if not self.vendorData then
        return
    end

    local tooltip = GetMapTooltip()
    tooltip:SetOwner(self, "ANCHOR_RIGHT")

    if IsAggregateVendorPin(self) then
        local vendors = self.aggregateVendors
        local count = #vendors
        GameTooltip_SetTitle(tooltip, string.format(L["VENDOR_PIN_VENDOR_COUNT"], count), COLOR_GOLD)
        GameTooltip_AddColoredLine(tooltip, L["VENDOR_PIN_VENDOR_LIST_HEADER"], COLOR_LIGHT_GRAY)

        local shown = math.min(count, C.TOOLTIP_ITEM_LIMIT)
        for i = 1, shown do
            local vendor = vendors[i]
            local vendorEntry = string.format(L["VENDOR_PIN_VENDOR_ENTRY"], addon:GetLocalizedNPCName(vendor.npcId, vendor.npcName) or L["VENDOR_UNKNOWN"], vendor.owned, vendor.total)
            AddBulletedTooltipLine(tooltip, vendorEntry)
        end

        local overflow = count - shown
        if overflow > 0 then
            GameTooltip_AddColoredLine(tooltip, string.format(L["VENDOR_PIN_VENDORS_MORE"], overflow), COLOR_MEDIUM_GRAY)
        end

        tooltip:Show()
        addon:StyleMapTooltip(tooltip)
        return
    end

    local vendorName = addon:GetLocalizedNPCName(self.vendorData.npcId, self.vendorData.npcName) or L["VENDOR_UNKNOWN"]
    local owned, total, missingNames = addon:GetVendorPinProgress(self.vendorData.npcId)

    GameTooltip_SetTitle(tooltip, vendorName, COLOR_GOLD)

    local zoneCache = addon.vendorZoneCache and addon.vendorZoneCache[self.vendorData.npcId]
    local classHall = zoneCache and addon:GetClassHallAnnotation(zoneCache.zoneName)
    if classHall then
        local cr, cg, cb = addon:GetClassColorRGB(classHall)
        local localizedClass = addon:GetLocalizedClassName(classHall)
        GameTooltip_AddColoredLine(tooltip, string.format(L["VENDOR_CLASS_ONLY_SUFFIX"], localizedClass), CreateColor(cr, cg, cb, 1))
    end

    local progressColor = GetProgressColor(owned, total)
    GameTooltip_AddColoredLine(tooltip, string.format(L["VENDOR_PIN_COLLECTED"], owned, total), progressColor)
    GameTooltip_AddBlankLineToTooltip(tooltip)

    if owned < total and #missingNames > 0 then
        GameTooltip_AddColoredLine(tooltip, L["VENDOR_PIN_UNCOLLECTED_HEADER"], COLOR_LIGHT_GRAY)
        for _, entry in ipairs(missingNames) do
            local suffix = entry.locked and " (|cffcc5a40" .. L["VENDOR_PIN_ITEM_LOCKED"] .. "|r)" or ""
            GameTooltip_AddColoredLine(tooltip, TOOLTIP_LIST_INDENT .. TOOLTIP_LIST_BULLET .. entry.name .. suffix, COLOR_ITEM_LIST, false)
        end

        local overflow = (total - owned) - #missingNames
        if overflow > 0 then
            GameTooltip_AddColoredLine(tooltip, string.format(L["VENDOR_PIN_MORE"], overflow), COLOR_MEDIUM_GRAY)
        end
    end

    if self.vendorData.faction == "Alliance" then
        GameTooltip_AddColoredLine(tooltip, L["VENDOR_PIN_FACTION_ALLIANCE"], COLOR_ALLIANCE)
    elseif self.vendorData.faction == "Horde" then
        GameTooltip_AddColoredLine(tooltip, L["VENDOR_PIN_FACTION_HORDE"], COLOR_HORDE)
    end

    GameTooltip_AddBlankLineToTooltip(tooltip)
    GameTooltip_AddInstructionLine(tooltip, L["VENDOR_PIN_CLICK_WAYPOINT"])
    tooltip:Show()
    addon:StyleMapTooltip(tooltip)
end

function HousingCodexVendorPinMixin:OnMouseLeave()
    local tooltip = GetMapTooltip()
    if tooltip:GetOwner() == self then
        tooltip:Hide()
    end
end

function HousingCodexVendorPinMixin:OnMouseClickAction(button)
    if button ~= "LeftButton" or not self.vendorData then
        return
    end

    if IsAggregateVendorPin(self) then
        if InCombatLockdown() then return end
        local currentMapID = self:GetMap() and self:GetMap():GetMapID()
        local currentInfo = currentMapID and C_Map.GetMapInfo(currentMapID)
        local targetMapID
        if currentInfo and currentInfo.mapType == Enum.UIMapType.Continent then
            targetMapID = addon:GetZoneRootMapID(self.vendorData.uiMapId) or self.vendorData.uiMapId
        else
            targetMapID = self.vendorData.uiMapId
        end
        if targetMapID then
            OpenWorldMap(targetMapID)
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
    if normX < 0 or normX > 1 or normY < 0 or normY > 1 then return end
    if not addon.Waypoints:Set(mapID, normX, normY, addon:GetLocalizedNPCName(self.vendorData.npcId, self.vendorData.npcName) or L["VENDOR_FALLBACK_NAME"]) then
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

    -- Custom frame levels removed: InsertFrameLevelBelow/Above modifies
    -- WorldMapFrame's internal PinFrameLevelsManager from addon context, which
    -- taints WorldMapFrame and causes secret value crashes in Blizzard's AreaPOI
    -- tooltip widget code (WoWUIBugs #811). Pins use PIN_FRAME_LEVEL_AREA_POI
    -- via the fallback in "PIN_FRAME_LEVEL_AREA_POI".
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
