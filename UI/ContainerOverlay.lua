--[[
    Housing Codex - ContainerOverlay.lua
    Container decor indicators - shows HC icon on items in bags, bank, and warband bank
    that are housing decor, with green checkmark for items already owned
]]

local _, addon = ...
local ContainerOverlay = {}
addon.ContainerOverlay = ContainerOverlay

-- Cache for catalog lookups: table = decor info, false = not decor, nil = not yet queried
local itemDecorCache = {}

-- State
local initialized = false
local trackedButtons = setmetatable({}, { __mode = "k" })  -- button => addon-owned overlay
local dirty = false         -- deferred refresh pending (set when events fire while bags closed)

local function ClearCache()
    wipe(itemDecorCache)
end

local function ShouldShowAnyContainerOverlay()
    local settings = addon.db and addon.db.settings
    return settings and (settings.showContainerDecorIndicators or settings.showContainerOwnedCheckmark)
end

local function IsSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function CanAccessAllValues(...)
    if type(canaccessallvalues) == "function" then
        return canaccessallvalues(...)
    end

    for i = 1, select("#", ...) do
        if IsSecretValue(select(i, ...)) then
            return false
        end
    end

    return true
end

local function IsSafeValue(value)
    return value ~= nil and not IsSecretValue(value) and CanAccessAllValues(value)
end

local function IsSafeAnchor(frame)
    return IsSafeValue(frame)
end

-- Look up decor info for an itemID (with caching)
local function GetDecorInfo(itemID)
    if not IsSafeValue(itemID) then return nil end

    local cached = itemDecorCache[itemID]
    if cached ~= nil then
        return cached or nil
    end

    local catalogInfo = C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem
        and C_HousingCatalog.GetCatalogEntryInfoByItem(itemID)

    itemDecorCache[itemID] = catalogInfo or false
    return catalogInfo
end

-- Get or create addon-owned overlay textures for a Blizzard item button.
function ContainerOverlay:GetOrCreateOverlay(button)
    local overlay = trackedButtons[button]
    if overlay then
        return overlay
    end

    local frame = addon.CreateItemButtonOverlayFrame("HousingCodexContainerItemButtonOverlayTemplate")

    -- HC icon with shadow (sizes and anchors are defined in XML)
    local hcIcon, hcShadow = addon.SetupIconWithShadow(frame.HCIcon, frame.HCShadow)

    -- Owned checkmark with shadow (sizes and anchors are defined in XML)
    local checkmark, checkShadow = addon.SetupOwnedCheckmark(frame.Checkmark, frame.CheckShadow)

    overlay = {
        frame = frame,
        hcIcon = hcIcon,
        hcShadow = hcShadow,
        checkmark = checkmark,
        checkShadow = checkShadow,
    }

    trackedButtons[button] = overlay

    return overlay
end

-- Hide overlay on a single button (if it has one)
local function HideButtonOverlay(button)
    local overlay = button and trackedButtons[button]
    if overlay then
        overlay.hcShadow:Hide()
        overlay.hcIcon:Hide()
        overlay.checkShadow:Hide()
        overlay.checkmark:Hide()
        overlay.frame:Hide()
    end
end

function ContainerOverlay:HideContainerFrameOverlays(frame)
    if not frame or not frame.EnumerateValidItems then return end

    for _, itemButton in frame:EnumerateValidItems() do
        HideButtonOverlay(itemButton)
    end
end

-- Update a single button with decor overlay
function ContainerOverlay:UpdateButton(button, itemID)
    if not button or not addon.db then return end

    local showDecorIcon = addon.db.settings.showContainerDecorIndicators
    local showOwnedCheckmark = addon.db.settings.showContainerOwnedCheckmark

    -- Early exit if both settings are off
    if not ShouldShowAnyContainerOverlay() then
        HideButtonOverlay(button)
        return
    end

    local catalogInfo = GetDecorInfo(itemID)

    if not catalogInfo then
        HideButtonOverlay(button)
        return
    end

    if catalogInfo.entryID and not addon:ShouldDisplayDecor(catalogInfo.entryID.recordID) then
        HideButtonOverlay(button)
        return
    end

    local isOwned = addon.IsDecorOwned(catalogInfo)
    local showCheckmark = isOwned and showOwnedCheckmark
    if not showDecorIcon and not showCheckmark then
        HideButtonOverlay(button)
        return
    end

    if not IsSafeAnchor(button) then
        HideButtonOverlay(button)
        return
    end

    local overlay = self:GetOrCreateOverlay(button)
    if not overlay then return end

    overlay.frame:ClearAllPoints()
    overlay.frame:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    overlay.hcShadow:SetShown(showDecorIcon)
    overlay.hcIcon:SetShown(showDecorIcon)
    overlay.checkShadow:SetShown(showCheckmark)
    overlay.checkmark:SetShown(showCheckmark)
    overlay.frame:Show()
end

-- Update all buttons in a container frame
function ContainerOverlay:UpdateContainerFrame(frame)
    if not frame or not frame:IsShown() then return end
    if not frame.EnumerateValidItems then return end

    self:HideContainerFrameOverlays(frame)

    for _, itemButton in frame:EnumerateValidItems() do
        if itemButton:IsShown() then
            local bagID = itemButton:GetBagID()
            local slotID = itemButton:GetID()
            local itemID
            if C_Container and C_Container.GetContainerItemID
                and IsSafeValue(bagID)
                and IsSafeValue(slotID)
                and CanAccessAllValues(bagID, slotID) then
                itemID = C_Container.GetContainerItemID(bagID, slotID)
            end
            self:UpdateButton(itemButton, itemID)
        end
    end
end

-- Check if any container frame is currently visible (combined bags mode first, then individual)
local function AreBagsVisible()
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
        return true
    end
    for i = 1, NUM_CONTAINER_FRAMES do
        local f = _G["ContainerFrame"..i]
        if f and f:IsShown() then return true end
    end
    return false
end

local function IsBankPanelVisible()
    return BankFrame and BankFrame.BankPanel and BankFrame.BankPanel:IsShown()
end

-- Flush deferred cache invalidation (called before updating any visible container)
local function FlushDirtyCache()
    if not dirty then return end
    dirty = false
    ClearCache()
end

-- Update all visible container frames (individual bags + combined view)
function ContainerOverlay:UpdateAllContainerFrames()
    FlushDirtyCache()
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

-- Refresh visible bank panel buttons via Blizzard's bulk API.
-- BankFrame.BankPanel hosts both character and account (warband) bank tabs.
function ContainerOverlay:UpdateVisibleBankPanel()
    if BankFrame and BankFrame.BankPanel and BankFrame.BankPanel:IsShown() then
        BankFrame.BankPanel:RefreshAllItemsForSelectedTab()
    end
end

local function RefreshAll()
    if not ShouldShowAnyContainerOverlay() then
        dirty = false
        ClearCache()
        ContainerOverlay:HideAllOverlays()
        return
    end

    local bagsVisible = AreBagsVisible()
    local bankVisible = IsBankPanelVisible()
    if not bagsVisible and not bankVisible then
        dirty = true
        return
    end
    dirty = false
    ClearCache()
    if bagsVisible then
        ContainerOverlay:UpdateAllContainerFrames()
    end
    if bankVisible then
        ContainerOverlay:UpdateVisibleBankPanel()
    end
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
                FlushDirtyCache()
                self:UpdateContainerFrame(frame)
            end
        end)
    end)
    addon:Debug("ContainerOverlay: Hooked ContainerFrame_OnShow")

    if type(ContainerFrame_OnHide) == "function" then
        hooksecurefunc("ContainerFrame_OnHide", function(frame)
            self:HideContainerFrameOverlays(frame)
        end)
        addon:Debug("ContainerOverlay: Hooked ContainerFrame_OnHide")
    end

    -- Hook bank button refresh on each tab's item button instances.
    -- BankFrame tabs are created on demand, so hook the Refresh method
    -- on BankPanelItemButtonMixin — bank buttons are created AFTER addon load
    -- (when the bank panel opens), so mixin-level hook works here.
    if BankPanelItemButtonMixin then
        hooksecurefunc(BankPanelItemButtonMixin, "Refresh", function(button)
            FlushDirtyCache()
            local itemID = button.itemInfo and button.itemInfo.itemID
            self:UpdateButton(button, itemID)
        end)
        addon:Debug("ContainerOverlay: Hooked BankPanelItemButtonMixin.Refresh")
    end

    -- WoW events
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    self.eventFrame:RegisterEvent("HOUSING_MARKET_AVAILABILITY_UPDATED")
    self.eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    self.eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
            local interactionType = ...
            if interactionType == Enum.PlayerInteractionType.Banker
               or interactionType == Enum.PlayerInteractionType.CharacterBanker
               or interactionType == Enum.PlayerInteractionType.AccountBanker then
                if dirty then RefreshAll() end
                self:UpdateVisibleBankPanel()
            end
        elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
            local interactionType = ...
            if interactionType == Enum.PlayerInteractionType.Banker
               or interactionType == Enum.PlayerInteractionType.CharacterBanker
               or interactionType == Enum.PlayerInteractionType.AccountBanker then
                self:HideAllOverlays()
                if AreBagsVisible() then
                    self:UpdateAllContainerFrames()
                end
            end
        else
            RefreshAll()
        end
    end)

    -- Internal ownership updates (clear cache — API returns fresh structs per call)
    addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", function(recordID, collectionStateChanged)
        if not collectionStateChanged then return end
        RefreshAll()
    end)

    addon:Debug("ContainerOverlay initialized")
end

-- Register for DATA_LOADED
addon:RegisterInternalEvent("DATA_LOADED", function()
    ContainerOverlay:Initialize()
end)

addon:RegisterInternalEvent(addon.Events.DECOR_VISIBILITY_CHANGED, function()
    dirty = true
    if AreBagsVisible() or IsBankPanelVisible() then
        ContainerOverlay:UpdateAllContainerFrames()
        ContainerOverlay:UpdateVisibleBankPanel()
    end
end)
