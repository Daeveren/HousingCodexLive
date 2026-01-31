--[[
    Housing Codex - MerchantOverlay.lua
    Vendor decor indicators - shows HC icon on vendor items that are housing decor,
    with green checkmark for items already owned
]]

local ADDON_NAME, addon = ...
local MerchantOverlay = {}
addon.MerchantOverlay = MerchantOverlay

-- Constants
local MERCHANT_ITEMS_PER_PAGE = 10
local HC_ICON_SIZE = 18
local CHECKMARK_SIZE = 16
local HC_ICON_PATH = "Interface\\AddOns\\HousingCodex\\HC64"
local SHADOW_COLOR = { 0, 0, 0, 0.7 }

-- Storage for button overlays
local buttonOverlays = {}

-- Session cache for catalog lookups (cleared on storage updates and merchant close)
local sessionCache = {}

local function ClearSessionCache()
    wipe(sessionCache)
end

-- Create icon with shadow (shadow is slightly larger and offset)
local function CreateIconWithShadow(button, size, shadowOffset)
    local shadow = button:CreateTexture(nil, "OVERLAY", nil, 6)
    shadow:SetSize(size + shadowOffset, size + shadowOffset)
    shadow:SetVertexColor(unpack(SHADOW_COLOR))

    local icon = button:CreateTexture(nil, "OVERLAY", nil, 7)
    icon:SetSize(size, size)

    return icon, shadow
end

-- Get or create overlay textures for button
function MerchantOverlay:GetOverlay(button, index)
    if buttonOverlays[index] then
        return buttonOverlays[index]
    end

    -- HC icon with shadow
    local hcIcon, hcShadow = CreateIconWithShadow(button, HC_ICON_SIZE, 8)
    hcShadow:SetPoint("TOPLEFT", button, "TOPLEFT", -11, 11)
    hcShadow:SetTexture(HC_ICON_PATH)
    hcIcon:SetPoint("TOPLEFT", button, "TOPLEFT", -7, 7)
    hcIcon:SetTexture(HC_ICON_PATH)

    -- Checkmark with shadow
    local checkmark, checkShadow = CreateIconWithShadow(button, CHECKMARK_SIZE, 6)
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

-- Check if decor is owned (stored + placed, matching Blizzard's total calculation)
local function IsDecorOwned(catalogInfo)
    if type(catalogInfo) ~= "table" then return false end
    local total = (catalogInfo.quantity or 0) + (catalogInfo.remainingRedeemable or 0) + (catalogInfo.numPlaced or 0)
    return total > 0
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

            -- Use cached catalog info or fetch and cache
            local catalogInfo = itemID and sessionCache[itemID]
            if itemID and not catalogInfo then
                catalogInfo = C_HousingCatalog.GetCatalogEntryInfoByItem(itemID, true)
                sessionCache[itemID] = catalogInfo
            end

            local isDecor = catalogInfo ~= nil
            local isOwned = catalogInfo and IsDecorOwned(catalogInfo)

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
    self:HookMerchantFrame()

    -- Listen for housing storage updates and merchant close
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("HOUSING_STORAGE_UPDATED")
    self.eventFrame:RegisterEvent("HOUSING_STORAGE_ENTRY_UPDATED")
    self.eventFrame:RegisterEvent("MERCHANT_CLOSED")
    self.eventFrame:SetScript("OnEvent", function(_, event)
        ClearSessionCache()
        if event == "MERCHANT_CLOSED" then
            self:HideAllOverlays()
        else
            -- Storage updated - refresh so checkmarks appear after purchase
            self:UpdateMerchantButtons()
        end
    end)

    addon:Debug("MerchantOverlay initialized")
end

-- Register for DATA_LOADED
addon:RegisterInternalEvent("DATA_LOADED", function()
    MerchantOverlay:Initialize()
end)
