--[[
    Housing Codex - Visibility.lua
    Shared item visibility state for user-hidden decor and shop filtering.
]]

local _, addon = ...

local ROOM_ENTRY_TYPE = Enum.HousingCatalogEntryType and Enum.HousingCatalogEntryType.Room or 2

local SHOP_CURRENCY_TOKENS = {
    ["hearthsteel"] = true,
}

addon.ShopDecorIds = addon.ShopDecorIds or {}
addon.shopDecorLookupBuilt = false

local function NormalizeDecorID(recordID)
    local id = tonumber(recordID)
    return id and id > 0 and id or nil
end

local function IsRoomRecord(record)
    return record and record.entryID and record.entryID.entryType == ROOM_ENTRY_TYPE
end

local function IsShopCurrency(currencyName)
    if type(currencyName) ~= "string" then return false end
    local normalized = strlower(strtrim(currencyName))
    return SHOP_CURRENCY_TOKENS[normalized] == true
end

local function MarkDecorSet(target, decorIds)
    for _, decorId in ipairs(decorIds or {}) do
        local id = NormalizeDecorID(decorId)
        if id then target[id] = true end
    end
end

local function MarkDropShopSources(target)
    local dropData = addon.DropSourceData
    if not dropData then return end

    for category, sources in pairs(dropData) do
        local isShopCategory = strlower(tostring(category or "")) == "shop"
        for _, sourceData in ipairs(sources or {}) do
            if isShopCategory or IsShopCurrency(sourceData.currencyName) then
                MarkDecorSet(target, sourceData.decorIds)
            end
        end
    end
end

local function MarkVendorShopSources(target)
    if not addon.vendorIndexBuilt and addon.BuildVendorIndex then
        addon:BuildVendorIndex()
    end
    if not addon.vendorIndexBuilt then return end

    for _, expansionData in pairs(addon.vendorHierarchy or {}) do
        for _, vendors in pairs(expansionData.zones or {}) do
            for _, vendor in ipairs(vendors or {}) do
                for _, decorId in ipairs(vendor.decorIds or {}) do
                    for currencyName in pairs(addon:GetVendorDecorCurrencyKeys(vendor, decorId)) do
                        if IsShopCurrency(currencyName) then
                            target[decorId] = true
                            break
                        end
                    end
                end
            end
        end
    end
end

function addon:BuildShopDecorLookup()
    wipe(self.ShopDecorIds)
    MarkDropShopSources(self.ShopDecorIds)
    MarkVendorShopSources(self.ShopDecorIds)
    self.shopDecorLookupBuilt = true
end

function addon:EnsureShopDecorLookup()
    if self.shopDecorLookupBuilt then return end
    if not self.DropSourceData and not self.VendorSourceData then return end
    self:BuildShopDecorLookup()
end

function addon:IsShopDecor(recordID)
    local id = NormalizeDecorID(recordID)
    if not id then return false end
    self:EnsureShopDecorLookup()
    return self.ShopDecorIds and self.ShopDecorIds[id] == true
end

function addon:IsDecorHidden(recordID)
    local id = NormalizeDecorID(recordID)
    local hidden = self.db and self.db.hiddenDecor
    return id ~= nil and type(hidden) == "table" and hidden[id] == true
end

function addon:GetHiddenDecorIDs()
    local hidden = self.db and self.db.hiddenDecor
    local items = {}
    if type(hidden) == "table" then
        for recordID, isHidden in pairs(hidden) do
            local id = NormalizeDecorID(recordID)
            if id and isHidden == true then
                local record = self:GetRecord(id)
                local name = self:ResolveDecorName(id, record)
                items[#items + 1] = {
                    id = id,
                    sortName = strlower(name or ""),
                }
            end
        end
    end
    table.sort(items, function(a, b)
        if a.sortName == b.sortName then return a.id < b.id end
        return a.sortName < b.sortName
    end)

    local ids = {}
    for _, item in ipairs(items) do
        ids[#ids + 1] = item.id
    end
    return ids
end

function addon:InvalidateDecorVisibilityCaches()
    if self.countCache then wipe(self.countCache) end
    if self.InvalidateProgressCache then self:InvalidateProgressCache() end
    if self.InvalidateVendorPinCache then self:InvalidateVendorPinCache() end
    if self.InvalidateZoneDecorCache then
        self:InvalidateZoneDecorCache()
        self:FireEvent(self.Events.ZONE_DECOR_CACHE_INVALIDATED)
    end
    if self.dropCategoryProgressCache then wipe(self.dropCategoryProgressCache) end
    if self.craftingProgressCache then wipe(self.craftingProgressCache) end
    if self.pvpCategoryProgressCache then wipe(self.pvpCategoryProgressCache) end
    if self.pvpSourceProgressCache then wipe(self.pvpSourceProgressCache) end
    if self.renownProgressCache then wipe(self.renownProgressCache) end
    if self.renownExpansionProgressCache then wipe(self.renownExpansionProgressCache) end
    if self.vendorExpansionProgressCache then wipe(self.vendorExpansionProgressCache) end
    if self.vendorZoneProgressCache then wipe(self.vendorZoneProgressCache) end
    self.vendorUniqueProgressCache = nil
end

function addon:NotifyDecorVisibilityChanged(recordID, reason)
    self:InvalidateDecorVisibilityCaches()
    self:FireEvent(self.Events.DECOR_VISIBILITY_CHANGED, recordID, reason)
end

function addon:SetDecorHidden(recordID, hidden)
    local id = NormalizeDecorID(recordID)
    if not id or not self.db then return false end

    self.db.hiddenDecor = self.db.hiddenDecor or {}
    local wasHidden = self.db.hiddenDecor[id] == true
    local shouldHide = hidden == true
    if wasHidden == shouldHide then return false end

    self.db.hiddenDecor[id] = shouldHide or nil
    self:NotifyDecorVisibilityChanged(id, shouldHide and "hidden" or "unhidden")
    return true
end

function addon:GetHiddenDecorCount()
    local hidden = self.db and self.db.hiddenDecor
    if type(hidden) ~= "table" then return 0 end
    local count = 0
    for _, isHidden in pairs(hidden) do
        if isHidden == true then count = count + 1 end
    end
    return count
end

function addon:ClearHiddenDecor()
    if not self.db or type(self.db.hiddenDecor) ~= "table" or not next(self.db.hiddenDecor) then
        return false
    end
    wipe(self.db.hiddenDecor)
    self:NotifyDecorVisibilityChanged(nil, "hidden-cleared")
    return true
end

function addon:ShouldDisplayDecor(recordID, record)
    local id = NormalizeDecorID(recordID or (record and record.recordID))
    if not id then return false end
    if self:IsDecorHidden(id) then return false end
    if self.Filters and self.Filters.hideShopItems and self:IsShopDecor(id) then return false end
    return true
end

function addon:GetDecorVisibilityReason(recordID)
    local id = NormalizeDecorID(recordID)
    if not id then return nil end
    if self:IsDecorHidden(id) then return "hidden" end
    if self.Filters and self.Filters.hideShopItems and self:IsShopDecor(id) then return "shop" end
    return nil
end

function addon:FilterVisibleDecorIds(decorIds)
    local visible = {}
    for _, decorId in ipairs(decorIds or {}) do
        if self:ShouldDisplayDecor(decorId) then
            visible[#visible + 1] = decorId
        end
    end
    return visible
end

local function CountVisibleRecords(owner, collectedOnly, decorOnly, includeQuantity)
    if not owner.indexesBuilt then return 0 end
    local count = 0
    for recordID, record in pairs(owner.decorRecords or {}) do
        if owner:ShouldDisplayDecor(recordID, record)
            and (not decorOnly or not IsRoomRecord(record))
            and (not collectedOnly or record.isCollected) then
            if includeQuantity then
                count = count + (record.totalOwned or 0)
            else
                count = count + 1
            end
        end
    end
    return count
end

local function GetCountCache(owner)
    owner.countCache = owner.countCache or {}
    return owner.countCache
end

function addon:GetVisibleRecordCount()
    if not self.indexesBuilt then return 0 end
    local cache = GetCountCache(self)
    if cache.visibleRecordCount ~= nil then return cache.visibleRecordCount end
    cache.visibleRecordCount = CountVisibleRecords(self, false, false, false)
    return cache.visibleRecordCount
end

function addon:GetVisibleUniqueCollectedCount()
    if not self.indexesBuilt then return 0 end
    local cache = GetCountCache(self)
    if cache.visibleUniqueCollected ~= nil then return cache.visibleUniqueCollected end
    cache.visibleUniqueCollected = CountVisibleRecords(self, true, false, false)
    return cache.visibleUniqueCollected
end

function addon:GetVisibleDecorCollectedCount()
    if not self.indexesBuilt then return 0 end
    local cache = GetCountCache(self)
    if cache.visibleDecorCollected ~= nil then return cache.visibleDecorCollected end
    cache.visibleDecorCollected = CountVisibleRecords(self, true, true, false)
    return cache.visibleDecorCollected
end

function addon:GetVisibleDecorRecordCount()
    if not self.indexesBuilt then return 0 end
    local cache = GetCountCache(self)
    if cache.visibleDecorRecordCount ~= nil then return cache.visibleDecorRecordCount end
    cache.visibleDecorRecordCount = CountVisibleRecords(self, false, true, false)
    return cache.visibleDecorRecordCount
end

function addon:GetVisibleTotalDecorOwnedCount()
    if not self.indexesBuilt then return 0 end
    local cache = GetCountCache(self)
    if cache.visibleTotalDecorOwned ~= nil then return cache.visibleTotalDecorOwned end
    cache.visibleTotalDecorOwned = CountVisibleRecords(self, true, true, true)
    return cache.visibleTotalDecorOwned
end

addon:RegisterInternalEvent("DATA_LOADED", function()
    addon.shopDecorLookupBuilt = false
    addon:BuildShopDecorLookup()
end)
