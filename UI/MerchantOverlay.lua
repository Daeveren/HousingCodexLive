--[[
    Housing Codex - MerchantOverlay.lua
    Vendor decor indicators - shows HC icon on vendor items that are housing decor,
    with green checkmark for items already owned
]]

local _, addon = ...
local MerchantOverlay = {}
addon.MerchantOverlay = MerchantOverlay

-- Constants
local DEFAULT_MERCHANT_PAGE_SIZE = 10
local MAX_MERCHANT_OVERLAY_SCAN = 200
local HC_ICON_SIZE = 18
local CHECKMARK_SIZE = 16
local HC_ICON_PATH = "Interface\\AddOns\\HousingCodex\\HC64"
-- Storage for button overlays
local trackedButtons = {}

-- Session cache for catalog lookups (cleared on storage updates and merchant close)
local sessionCache = {}

-- State tracking for market data refresh
local waitingForMarketData = false
local initialized = false
local updateScheduled = false
local marketFallbackTimer = nil

local function ClearSessionCache()
    wipe(sessionCache)
end

local function CancelMarketFallbackTimer()
    if marketFallbackTimer then
        marketFallbackTimer:Cancel()
        marketFallbackTimer = nil
    end
end

local function IsSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function GetMerchantPageSize()
    local pageSize = _G.MERCHANT_ITEMS_PER_PAGE
    if pageSize == nil or IsSecretValue(pageSize) or type(pageSize) ~= "number" or pageSize < 1 then
        return DEFAULT_MERCHANT_PAGE_SIZE
    end

    pageSize = math.floor(pageSize)

    return math.min(pageSize, MAX_MERCHANT_OVERLAY_SCAN)
end

local function HideButtonOverlay(button)
    if not button or not button.hcOverlay then
        return
    end

    button.hcOverlay.hcShadow:Hide()
    button.hcOverlay.hcIcon:Hide()
    button.hcOverlay.checkShadow:Hide()
    button.hcOverlay.checkmark:Hide()
end

local function GetLookupKey(button, displayIndex, numItems)
    local itemID

    if displayIndex and displayIndex > 0 and displayIndex <= numItems and type(GetMerchantItemID) == "function" then
        itemID = GetMerchantItemID(displayIndex)
    end

    if itemID ~= nil and not IsSecretValue(itemID) and type(itemID) == "number" then
        return itemID
    end

    local link = button and button.link
    if link ~= nil and not IsSecretValue(link) then
        local linkType = type(link)
        if linkType == "string" or linkType == "number" then
            return link
        end
    end

    return nil
end

-- Get or create overlay textures for button
function MerchantOverlay:GetOverlay(button)
    if button.hcOverlay then
        return button.hcOverlay
    end

    -- HC icon with shadow
    local hcIcon, hcShadow = addon.CreateIconWithShadow(button, HC_ICON_SIZE, 8)
    hcShadow:SetPoint("TOPLEFT", button, "TOPLEFT", -11, 11)
    hcShadow:SetTexture(HC_ICON_PATH)
    hcIcon:SetPoint("TOPLEFT", button, "TOPLEFT", -7, 7)
    hcIcon:SetTexture(HC_ICON_PATH)

    -- Checkmark with shadow
    local checkmark, checkShadow = addon.CreateIconWithShadow(button, CHECKMARK_SIZE, 6)
    checkShadow:SetPoint("TOP", hcIcon, "BOTTOM", 0, 5)
    checkShadow:SetAtlas("common-icon-checkmark")
    checkmark:SetPoint("TOP", hcIcon, "BOTTOM", 0, 2)
    checkmark:SetAtlas("common-icon-checkmark")
    checkmark:SetVertexColor(0, 1, 0, 1)

    button.hcOverlay = {
        hcIcon = hcIcon,
        hcShadow = hcShadow,
        checkmark = checkmark,
        checkShadow = checkShadow,
    }
    trackedButtons[button] = true

    return button.hcOverlay
end

function MerchantOverlay:ScheduleUpdateMerchantButtons()
    if updateScheduled then
        return
    end

    updateScheduled = true
    C_Timer.After(0, function()
        updateScheduled = false
        self:UpdateMerchantButtons()
    end)
end

-- Update merchant buttons with decor indicators
function MerchantOverlay:UpdateMerchantButtons()
    if not MerchantFrame or not MerchantFrame:IsShown() then
        self:HideAllOverlays()
        return
    end

    if MerchantFrame.selectedTab and MerchantFrame.selectedTab ~= 1 then
        self:HideAllOverlays()
        return
    end

    if not addon.db or not addon.db.settings then
        self:HideAllOverlays()
        return
    end

    if not C_HousingCatalog or not C_HousingCatalog.GetCatalogEntryInfoByItem then
        self:HideAllOverlays()
        return
    end

    local showDecorIcon = addon.db.settings.showVendorDecorIndicators
    local showOwnedCheckmark = addon.db.settings.showVendorOwnedCheckmark

    -- Early exit if both settings are off
    if not showDecorIcon and not showOwnedCheckmark then
        self:HideAllOverlays()
        return
    end

    self:HideAllOverlays()

    local pageSize = GetMerchantPageSize()
    local numItems = type(GetMerchantNumItems) == "function" and GetMerchantNumItems() or 0
    if numItems == nil or IsSecretValue(numItems) or type(numItems) ~= "number" or numItems <= 0 then
        return
    end

    local currentPage = MerchantFrame.page
    if currentPage == nil or IsSecretValue(currentPage) or type(currentPage) ~= "number" or currentPage < 1 then
        currentPage = 1
    end

    local pageOffset = (currentPage - 1) * pageSize
    local remainingItems = math.max(0, numItems - pageOffset)
    local scanCount = math.min(pageSize, remainingItems, MAX_MERCHANT_OVERLAY_SCAN)

    for i = 1, scanCount do
        local button = _G["MerchantItem"..i.."ItemButton"]
        if button and button:IsShown() then
            local buttonID = button:GetID()
            local displayIndex
            if buttonID ~= nil and not IsSecretValue(buttonID) and type(buttonID) == "number" and buttonID > 0 and buttonID <= numItems then
                displayIndex = buttonID
            else
                displayIndex = pageOffset + i
            end

            local lookupKey = GetLookupKey(button, displayIndex, numItems)

            -- Session cache: table = decor info, false = queried but not decor, nil = not yet queried
            local catalogInfo
            if lookupKey then
                local cached = sessionCache[lookupKey]
                if cached == nil then
                    catalogInfo = C_HousingCatalog.GetCatalogEntryInfoByItem(lookupKey)
                    sessionCache[lookupKey] = catalogInfo or false
                elseif cached then
                    catalogInfo = cached
                end
            end

            local isDecor = catalogInfo ~= nil
            if isDecor and catalogInfo.entryID and not addon:ShouldDisplayDecor(catalogInfo.entryID.recordID) then
                isDecor = false
            end
            local isOwned = isDecor and catalogInfo and addon.IsDecorOwned(catalogInfo)

            local overlay = self:GetOverlay(button)
            overlay.hcShadow:SetShown(isDecor and showDecorIcon)
            overlay.hcIcon:SetShown(isDecor and showDecorIcon)
            overlay.checkShadow:SetShown(isOwned and showOwnedCheckmark)
            overlay.checkmark:SetShown(isOwned and showOwnedCheckmark)
        end
    end
end

-- Hide all overlays
function MerchantOverlay:HideAllOverlays()
    for button in pairs(trackedButtons) do
        HideButtonOverlay(button)
    end
end

-- Hook merchant frame
function MerchantOverlay:HookMerchantFrame()
    if type(MerchantFrame_UpdateMerchantInfo) == "function" then
        hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
            self:ScheduleUpdateMerchantButtons()
        end)
    end
    addon:Debug("MerchantOverlay: Hooked MerchantFrame_UpdateMerchantInfo")
end

-- Initialize
function MerchantOverlay:Initialize()
    if initialized then return end
    initialized = true

    self:HookMerchantFrame()

    -- Listen for merchant events and market data
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("MERCHANT_CLOSED")
    self.eventFrame:RegisterEvent("MERCHANT_SHOW")
    self.eventFrame:RegisterEvent("HOUSING_MARKET_AVAILABILITY_UPDATED")
    self.eventFrame:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_SHOW" then
            CancelMarketFallbackTimer()
            -- Request housing market data refresh when merchant opens
            if C_HousingCatalog and C_HousingCatalog.RequestHousingMarketInfoRefresh then
                C_HousingCatalog.RequestHousingMarketInfoRefresh()
            end
            waitingForMarketData = true
            -- Fallback timer in case event doesn't fire
            marketFallbackTimer = C_Timer.NewTimer(0.5, function()
                marketFallbackTimer = nil
                if waitingForMarketData and MerchantFrame and MerchantFrame:IsShown() then
                    waitingForMarketData = false
                    ClearSessionCache()
                    self:ScheduleUpdateMerchantButtons()
                end
            end)
        elseif event == "HOUSING_MARKET_AVAILABILITY_UPDATED" then
            -- Market data is now ready - always clear flag, refresh if merchant open
            waitingForMarketData = false
            CancelMarketFallbackTimer()
            if MerchantFrame and MerchantFrame:IsShown() then
                ClearSessionCache()
                self:ScheduleUpdateMerchantButtons()
            end
        elseif event == "MERCHANT_CLOSED" then
            waitingForMarketData = false
            CancelMarketFallbackTimer()
            ClearSessionCache()
            self:HideAllOverlays()
        end
    end)

    -- Listen for internal ownership updates
    addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", function()
        if not MerchantFrame or not MerchantFrame:IsShown() then return end
        -- Clear session cache to force fresh ownership checks
        ClearSessionCache()
        self:ScheduleUpdateMerchantButtons()
    end)

    addon:Debug("MerchantOverlay initialized")
end

-- Register for DATA_LOADED
addon:RegisterInternalEvent("DATA_LOADED", function()
    MerchantOverlay:Initialize()
end)

addon:RegisterInternalEvent(addon.Events.DECOR_VISIBILITY_CHANGED, function()
    ClearSessionCache()
    MerchantOverlay:ScheduleUpdateMerchantButtons()
end)
