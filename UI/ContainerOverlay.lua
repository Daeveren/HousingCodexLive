--[[
    Housing Codex - ContainerOverlay.lua
    Container decor indicators - shows HC icon on items in bags, bank, and warband bank
    that are housing decor, with green checkmark for items already owned
]]

local _, addon = ...
local ContainerOverlay = {}
addon.ContainerOverlay = ContainerOverlay

-- Stable classification cache: recordID = decor, false = not decor, nil = not queried.
-- Ownership remains live in addon records/indexes and is never cached here.
local itemDecorCache = {}

-- State
local initialized = false
local trackedButtons = setmetatable({}, { __mode = "k" })  -- button => addon-owned overlay
local dirty = false         -- full refresh pending (set when ownership/visibility changes while hidden)
local pendingBagUpdates = {}
local bagRefreshScheduled = false

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
    if IsSecretValue(value) then return false end
    if not CanAccessAllValues(value) then return false end
    return value ~= nil
end

local function IsSafeAnchor(frame)
    return IsSafeValue(frame)
end

-- Look up the stable decor record ID for an itemID (with caching)
local function GetDecorRecordID(itemID)
    if not IsSafeValue(itemID) then return nil end

    local cached = itemDecorCache[itemID]
    if cached ~= nil then
        return cached or nil
    end

    local catalogInfo = C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem
        and C_HousingCatalog.GetCatalogEntryInfoByItem(itemID)

    local recordID = catalogInfo and catalogInfo.recordID
    itemDecorCache[itemID] = recordID or false
    return recordID
end

local function IsDecorRecordOwned(recordID)
    local record = recordID and (addon:GetRecord(recordID) or addon:ResolveRecord(recordID))
    if record then return record.isCollected == true end
    return addon.indexes and addon.indexes.collected
        and addon.indexes.collected[recordID] == true
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

-- Container-frame contract only. BaseContainerFrameMixin:EnumerateValidItems
-- yields (index, itemButton); BankPanelMixin's same-named method wraps
-- EnumerateActive() and yields the button first, so passing BankFrame.BankPanel
-- here binds itemButton to a pool boolean and silently no-ops. Bank buttons go
-- through RefreshAllItemsForSelectedTab and the BankPanelItemButtonMixin hook.
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

    local recordID = GetDecorRecordID(itemID)

    if not recordID then
        HideButtonOverlay(button)
        return
    end

    if not addon:ShouldDisplayDecor(recordID) then
        HideButtonOverlay(button)
        return
    end

    local isOwned = IsDecorRecordOwned(recordID)
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
function ContainerOverlay:UpdateContainerFrame(frame, changedBagID)
    if not addon.IsFrameShown(frame) then return end
    if not frame.EnumerateValidItems then return end

    for _, itemButton in frame:EnumerateValidItems() do
        if addon.IsFrameShown(itemButton) then
            local bagID = itemButton:GetBagID()
            if not IsSafeValue(bagID) then
                HideButtonOverlay(itemButton)
            elseif changedBagID == nil or bagID == changedBagID then
                HideButtonOverlay(itemButton)
                local slotID = itemButton:GetID()
                local itemID
                if C_Container and C_Container.GetContainerItemID
                    and IsSafeValue(slotID)
                    and CanAccessAllValues(bagID, slotID) then
                    itemID = C_Container.GetContainerItemID(bagID, slotID)
                end
                self:UpdateButton(itemButton, itemID)
            end
        end
    end
end

-- Check if any container frame is currently visible (combined bags mode first, then individual)
local function AreBagsVisible()
    if addon.IsFrameShown(ContainerFrameCombinedBags) then
        return true
    end
    for i = 1, NUM_CONTAINER_FRAMES do
        local f = _G["ContainerFrame"..i]
        if addon.IsFrameShown(f) then return true end
    end
    return false
end

local function IsBankPanelVisible()
    return BankFrame and addon.IsFrameShown(BankFrame.BankPanel)
end

-- Update all visible container frames (individual bags + combined view)
function ContainerOverlay:UpdateAllContainerFrames()
    for i = 1, NUM_CONTAINER_FRAMES do
        self:UpdateContainerFrame(_G["ContainerFrame"..i])
    end
    self:UpdateContainerFrame(ContainerFrameCombinedBags)
end

function ContainerOverlay:UpdateVisibleBag(bagID)
    if not IsSafeValue(bagID) or not ShouldShowAnyContainerOverlay() then return end

    for i = 1, NUM_CONTAINER_FRAMES do
        self:UpdateContainerFrame(_G["ContainerFrame"..i], bagID)
    end
    self:UpdateContainerFrame(ContainerFrameCombinedBags, bagID)

    local bankPanel = BankFrame and BankFrame.BankPanel
    if addon.IsFrameShown(bankPanel) and bankPanel.GetSelectedTabID then
        local selectedTabID = bankPanel:GetSelectedTabID()
        if IsSafeValue(selectedTabID) and selectedTabID == bagID then
            bankPanel:RefreshAllItemsForSelectedTab()
        end
    end
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
    if BankFrame and addon.IsFrameShown(BankFrame.BankPanel) then
        BankFrame.BankPanel:RefreshAllItemsForSelectedTab()
    end
end

local function RefreshAll()
    if not ShouldShowAnyContainerOverlay() then
        dirty = false
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
    if bagsVisible then
        ContainerOverlay:UpdateAllContainerFrames()
    end
    if bankVisible then
        ContainerOverlay:UpdateVisibleBankPanel()
    end
end


local function FlushPendingBagUpdates()
    bagRefreshScheduled = false
    for bagID in pairs(pendingBagUpdates) do
        pendingBagUpdates[bagID] = nil
        ContainerOverlay:UpdateVisibleBag(bagID)
    end
end

local function QueueBagUpdate(bagID)
    if not IsSafeValue(bagID) then return end
    pendingBagUpdates[bagID] = true
    if bagRefreshScheduled then return end

    bagRefreshScheduled = true
    C_Timer.After(0, FlushPendingBagUpdates)
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
            if addon.IsFrameShown(frame) then
                if dirty then
                    RefreshAll()
                else
                    self:UpdateContainerFrame(frame)
                end
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
            local itemID = button.itemInfo and button.itemInfo.itemID
            self:UpdateButton(button, itemID)
        end)
        addon:Debug("ContainerOverlay: Hooked BankPanelItemButtonMixin.Refresh")
    end

    -- WoW events
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("BAG_UPDATE")
    self.eventFrame:RegisterEvent("HOUSING_MARKET_AVAILABILITY_UPDATED")
    self.eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    self.eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "BAG_UPDATE" then
            QueueBagUpdate(...)
        elseif event == "HOUSING_MARKET_AVAILABILITY_UPDATED" then
            ClearCache()
            RefreshAll()
        elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
            local interactionType = ...
            if interactionType == Enum.PlayerInteractionType.Banker
               or interactionType == Enum.PlayerInteractionType.CharacterBanker
               or interactionType == Enum.PlayerInteractionType.AccountBanker then
                if dirty then
                    RefreshAll()
                else
                    self:UpdateVisibleBankPanel()
                end
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
        end
    end)

    -- Ownership is read live from addon records; classification remains stable.
    addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", function(recordID, collectionStateChanged)
        if not collectionStateChanged then return end
        RefreshAll()
    end)

    addon:Debug("ContainerOverlay initialized")
end

-- Register for DATA_LOADED
addon:RegisterInternalEvent("DATA_LOADED", function()
    ClearCache()
    ContainerOverlay:Initialize()
    RefreshAll()
end)

addon:RegisterInternalEvent(addon.Events.DECOR_VISIBILITY_CHANGED, function()
    RefreshAll()
end)
