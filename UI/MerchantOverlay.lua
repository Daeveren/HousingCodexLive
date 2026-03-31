--[[
    Housing Codex - MerchantOverlay.lua
    Vendor decor indicators - shows HC icon on vendor items that are housing decor,
    with green checkmark for items already owned
]]

local _, addon = ...
local MerchantOverlay = {}
addon.MerchantOverlay = MerchantOverlay

-- Constants
local MERCHANT_ITEMS_PER_PAGE = 10
local HC_ICON_SIZE = 18
local CHECKMARK_SIZE = 16
local HC_ICON_PATH = "Interface\\AddOns\\HousingCodex\\HC64"
-- Storage for button overlays
local buttonOverlays = {}

-- Session cache for catalog lookups (cleared on storage updates and merchant close)
local sessionCache = {}

-- State tracking for market data refresh
local waitingForMarketData = false
local initialized = false

local function ClearSessionCache()
    wipe(sessionCache)
end

-- Get or create overlay textures for button
function MerchantOverlay:GetOverlay(button, index)
    if buttonOverlays[index] then
        return buttonOverlays[index]
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

    buttonOverlays[index] = {
        hcIcon = hcIcon,
        hcShadow = hcShadow,
        checkmark = checkmark,
        checkShadow = checkShadow,
    }
    return buttonOverlays[index]
end


-- Update merchant buttons with decor indicators
function MerchantOverlay:UpdateMerchantButtons()
    if not MerchantFrame or not MerchantFrame:IsShown() then return end
    if not addon.db then return end
    if not C_HousingCatalog or not C_HousingCatalog.GetCatalogEntryInfoByItem then return end

    local showDecorIcon = addon.db.settings.showVendorDecorIndicators
    local showOwnedCheckmark = addon.db.settings.showVendorOwnedCheckmark

    -- Early exit if both settings are off
    if not showDecorIcon and not showOwnedCheckmark then return end

    local numItems = GetMerchantNumItems()
    local pageOffset = (MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE

    for i = 1, MERCHANT_ITEMS_PER_PAGE do
        local button = _G["MerchantItem"..i.."ItemButton"]
        if button and button:IsShown() then
            local overlay = self:GetOverlay(button, i)
            local index = pageOffset + i
            local itemID = index <= numItems and GetMerchantItemID(index)

            -- Session cache: table = decor info, false = queried but not decor, nil = not yet queried
            local catalogInfo
            if itemID then
                local cached = sessionCache[itemID]
                if cached == nil then
                    catalogInfo = C_HousingCatalog.GetCatalogEntryInfoByItem(itemID, true)
                    sessionCache[itemID] = catalogInfo or false
                elseif cached then
                    catalogInfo = cached
                end
            end

            local isDecor = catalogInfo ~= nil
            local isOwned = catalogInfo and addon.IsDecorOwned(catalogInfo)

            overlay.hcShadow:SetShown(isDecor and showDecorIcon)
            overlay.hcIcon:SetShown(isDecor and showDecorIcon)
            overlay.checkShadow:SetShown(isOwned and showOwnedCheckmark)
            overlay.checkmark:SetShown(isOwned and showOwnedCheckmark)
        end
    end
end

-- Hide all overlays
function MerchantOverlay:HideAllOverlays()
    for _, overlay in pairs(buttonOverlays) do
        overlay.hcShadow:Hide()
        overlay.hcIcon:Hide()
        overlay.checkShadow:Hide()
        overlay.checkmark:Hide()
    end
end

-- Hook merchant frame
function MerchantOverlay:HookMerchantFrame()
    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
        self:UpdateMerchantButtons()
    end)
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
            -- Request housing market data refresh when merchant opens
            if C_HousingCatalog and C_HousingCatalog.RequestHousingMarketInfoRefresh then
                C_HousingCatalog.RequestHousingMarketInfoRefresh()
            end
            waitingForMarketData = true
            -- Fallback timer in case event doesn't fire
            C_Timer.After(0.5, function()
                if waitingForMarketData and MerchantFrame and MerchantFrame:IsShown() then
                    waitingForMarketData = false
                    ClearSessionCache()
                    self:UpdateMerchantButtons()
                end
            end)
        elseif event == "HOUSING_MARKET_AVAILABILITY_UPDATED" then
            -- Market data is now ready - always clear flag, refresh if merchant open
            waitingForMarketData = false
            if MerchantFrame and MerchantFrame:IsShown() then
                ClearSessionCache()
                self:UpdateMerchantButtons()
            end
        elseif event == "MERCHANT_CLOSED" then
            waitingForMarketData = false
            ClearSessionCache()
            self:HideAllOverlays()
        end
    end)

    -- Listen for internal ownership updates
    addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", function()
        if not MerchantFrame or not MerchantFrame:IsShown() then return end
        -- Clear session cache to force fresh ownership checks
        ClearSessionCache()
        self:UpdateMerchantButtons()
    end)

    addon:Debug("MerchantOverlay initialized")
end

-- Register for DATA_LOADED
addon:RegisterInternalEvent("DATA_LOADED", function()
    MerchantOverlay:Initialize()
end)
