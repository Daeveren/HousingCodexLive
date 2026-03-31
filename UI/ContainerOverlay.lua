--[[
    Housing Codex - ContainerOverlay.lua
    Container decor indicators - shows HC icon on items in bags, bank, and warband bank
    that are housing decor, with green checkmark for items already owned
]]

local _, addon = ...
local ContainerOverlay = {}
addon.ContainerOverlay = ContainerOverlay

-- Constants (scaled for smaller bag slots ~37px vs larger merchant buttons ~45px)
local HC_ICON_SIZE = 14
local CHECKMARK_SIZE = 12
local HC_ICON_PATH = "Interface\\AddOns\\HousingCodex\\HC64"
-- Cache for catalog lookups: table = decor info, false = not decor, nil = not yet queried
local itemDecorCache = {}

-- State
local initialized = false
local trackedButtons = {}  -- buttons we've added overlays to (for HideAllOverlays)

local function ClearCache()
    wipe(itemDecorCache)
end

-- Look up decor info for an itemID (with caching)
local function GetDecorInfo(itemID)
    if not itemID then return nil end

    local cached = itemDecorCache[itemID]
    if cached ~= nil then
        return cached or nil
    end

    local catalogInfo = C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem
        and C_HousingCatalog.GetCatalogEntryInfoByItem(itemID, true)

    itemDecorCache[itemID] = catalogInfo or false
    return catalogInfo
end

-- Get or create overlay textures for a button
function ContainerOverlay:GetOrCreateOverlay(button)
    if button.hcOverlay then
        return button.hcOverlay
    end

    -- HC icon with shadow (smaller offsets for bag-sized buttons)
    local hcIcon, hcShadow = addon.CreateIconWithShadow(button, HC_ICON_SIZE, 6)
    hcShadow:SetPoint("TOPLEFT", button, "TOPLEFT", -8, 8)
    hcShadow:SetTexture(HC_ICON_PATH)
    hcIcon:SetPoint("TOPLEFT", button, "TOPLEFT", -5, 5)
    hcIcon:SetTexture(HC_ICON_PATH)

    -- Checkmark with shadow
    local checkmark, checkShadow = addon.CreateIconWithShadow(button, CHECKMARK_SIZE, 4)
    checkShadow:SetPoint("TOP", hcIcon, "BOTTOM", 0, 4)
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

-- Hide overlay on a single button (if it has one)
local function HideButtonOverlay(button)
    if button.hcOverlay then
        button.hcOverlay.hcShadow:Hide()
        button.hcOverlay.hcIcon:Hide()
        button.hcOverlay.checkShadow:Hide()
        button.hcOverlay.checkmark:Hide()
    end
end

-- Update a single button with decor overlay
function ContainerOverlay:UpdateButton(button, itemID)
    if not button or not addon.db then return end

    local showDecorIcon = addon.db.settings.showContainerDecorIndicators
    local showOwnedCheckmark = addon.db.settings.showContainerOwnedCheckmark

    -- Early exit if both settings are off
    if not showDecorIcon and not showOwnedCheckmark then
        HideButtonOverlay(button)
        return
    end

    local catalogInfo = GetDecorInfo(itemID)

    if not catalogInfo then
        HideButtonOverlay(button)
        return
    end

    local isOwned = addon.IsDecorOwned(catalogInfo)

    local overlay = self:GetOrCreateOverlay(button)
    overlay.hcShadow:SetShown(showDecorIcon)
    overlay.hcIcon:SetShown(showDecorIcon)
    overlay.checkShadow:SetShown(isOwned and showOwnedCheckmark)
    overlay.checkmark:SetShown(isOwned and showOwnedCheckmark)
end

-- Update all buttons in a container frame
function ContainerOverlay:UpdateContainerFrame(frame)
    if not frame or not frame:IsShown() then return end
    if not frame.EnumerateValidItems then return end

    for _, itemButton in frame:EnumerateValidItems() do
        if itemButton:IsShown() then
            local bagID = itemButton:GetBagID()
            local slotID = itemButton:GetID()
            local itemID = bagID and slotID and C_Container.GetContainerItemID(bagID, slotID)
            self:UpdateButton(itemButton, itemID)
        end
    end
end

-- Update all visible container frames (individual bags + combined view)
function ContainerOverlay:UpdateAllContainerFrames()
    for i = 1, NUM_CONTAINER_FRAMES do
        self:UpdateContainerFrame(_G["ContainerFrame"..i])
    end
    self:UpdateContainerFrame(ContainerFrameCombinedBags)
end

-- Hide all overlays on every tracked button
function ContainerOverlay:HideAllOverlays()
    for button in pairs(trackedButtons) do
        HideButtonOverlay(button)
    end
end

local function RefreshAll()
    ClearCache()
    ContainerOverlay:UpdateAllContainerFrames()
end

-- Initialize hooks and events
function ContainerOverlay:Initialize()
    if initialized then return end
    initialized = true

    -- Hook ContainerFrame_OnShow (global function called by all container frame
    -- types: individual bags, backpack, and combined bags). Items render via
    -- async ContinueOnLoad inside Update(), which completes synchronously for
    -- cached bag items. A one-frame delay ensures UpdateItems() has finished.
    hooksecurefunc("ContainerFrame_OnShow", function(frame)
        C_Timer.After(0, function()
            if frame:IsShown() then
                self:UpdateContainerFrame(frame)
            end
        end)
    end)
    addon:Debug("ContainerOverlay: Hooked ContainerFrame_OnShow")

    -- Hook bank button refresh on each tab's item button instances.
    -- BankFrame tabs are created on demand, so hook the Refresh method
    -- on BankPanelItemButtonMixin — bank buttons are created AFTER addon load
    -- (when the bank panel opens), so mixin-level hook works here.
    if BankPanelItemButtonMixin then
        hooksecurefunc(BankPanelItemButtonMixin, "Refresh", function(button)
            local itemID = button.itemInfo and button.itemInfo.itemID
            self:UpdateButton(button, itemID)
        end)
        addon:Debug("ContainerOverlay: Hooked BankPanelItemButtonMixin.Refresh")
    end

    -- WoW events
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    self.eventFrame:RegisterEvent("HOUSING_MARKET_AVAILABILITY_UPDATED")
    self.eventFrame:SetScript("OnEvent", function()
        RefreshAll()
    end)

    -- Internal ownership updates (clear cache — API returns fresh structs per call)
    addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", function()
        RefreshAll()
    end)

    addon:Debug("ContainerOverlay initialized")
end

-- Register for DATA_LOADED
addon:RegisterInternalEvent("DATA_LOADED", function()
    ContainerOverlay:Initialize()
end)
