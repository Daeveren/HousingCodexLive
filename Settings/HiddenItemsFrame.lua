--[[
    Housing Codex - HiddenItemsFrame.lua
    Settings-accessible manager for user-hidden decor.
]]

local _, addon = ...
local L = addon.L
local CONSTS = addon.CONSTANTS
local COLORS = CONSTS.COLORS
local ICON_CROP_COORDS = CONSTS.ICON_CROP_COORDS

local HiddenItemsFrame = {}
addon.HiddenItemsFrame = HiddenItemsFrame

local FRAME_NAME = "HousingCodexHiddenItemsFrame"
local ROW_HEIGHT = 34
local ICON_SIZE = 26

local function CreateTitle(frame)
    local title = addon:CreateFontString(frame, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText(L["HIDDEN_ITEMS_TITLE"])
    title:SetTextColor(unpack(COLORS.GOLD))
    addon:SetFontSize(title, 16)
    frame.title = title
end

local function CreateEmptyState(frame)
    local empty = addon:CreateEmptyStateFrame(frame, "HIDDEN_ITEMS_EMPTY", "HIDDEN_ITEMS_EMPTY_DESC", 360)
    empty:SetPoint("CENTER", frame, "CENTER", 0, -8)
    frame.emptyState = empty
end

local function RowUnhideOnClick(button)
    local row = button:GetParent()
    if row and row.recordID then
        addon:SetDecorHidden(row.recordID, false)
    end
end

local function SetupRow(row, elementData)
    if not row.initialized then
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:SetPoint("LEFT", 8, 0)
        row.icon = icon

        local name = addon:CreateFontString(row, "OVERLAY", "GameFontNormal")
        name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        name:SetPoint("RIGHT", -118, 0)
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)
        row.name = name

        local idText = addon:CreateFontString(row, "OVERLAY", "GameFontNormalSmall")
        idText:SetPoint("RIGHT", -72, 0)
        idText:SetJustifyH("RIGHT")
        idText:SetTextColor(0.58, 0.58, 0.58, 1)
        row.idText = idText

        local unhide = addon:CreateActionButton(row, L["HIDDEN_ITEMS_UNHIDE"], RowUnhideOnClick)
        unhide:SetPoint("RIGHT", -4, 0)
        row.unhideButton = unhide

        row.initialized = true
    end

    local recordID = elementData.recordID
    local record = addon:GetRecord(recordID) or addon:ResolveRecord(recordID)
    row.recordID = recordID

    if record then
        if record.iconType == "atlas" then
            row.icon:SetAtlas(record.icon)
            row.icon:SetTexCoord(0, 1, 0, 1)
        else
            row.icon:SetTexture(record.icon)
            row.icon:SetTexCoord(unpack(ICON_CROP_COORDS))
        end
    else
        row.icon:SetTexture(addon:ResolveDecorIcon(recordID))
        row.icon:SetTexCoord(unpack(ICON_CROP_COORDS))
    end

    row.name:SetText(addon:ResolveDecorName(recordID, record))
    addon:SetFontSize(row.name, 13, "")
    row.idText:SetText(tostring(recordID))
end

function HiddenItemsFrame:Create()
    if self.frame then return end

    local frame = CreateFrame("Frame", FRAME_NAME, UIParent, "BackdropTemplate")
    frame:SetSize(560, 460)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.07, 0.98)
    frame:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    frame:Hide()
    self.frame = frame

    table.insert(UISpecialFrames, FRAME_NAME)

    CreateTitle(frame)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    frame.closeButton = close

    local clearAll = addon:CreateActionButton(frame, L["HIDDEN_ITEMS_CLEAR_ALL"], function()
        addon:ClearHiddenDecor()
    end, function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["HIDDEN_ITEMS_CLEAR_ALL"], 1, 0.82, 0)
        GameTooltip:AddLine(L["HIDDEN_ITEMS_CLEAR_ALL_TOOLTIP"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    clearAll:SetPoint("TOPRIGHT", close, "BOTTOMLEFT", -8, -4)
    frame.clearAllButton = clearAll

    local count = addon:CreateFontString(frame, "OVERLAY", "GameFontNormalSmall")
    count:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -6)
    count:SetTextColor(0.7, 0.7, 0.7, 1)
    frame.countText = count

    local scrollContainer = CreateFrame("Frame", nil, frame)
    scrollContainer:SetPoint("TOPLEFT", 12, -58)
    scrollContainer:SetPoint("BOTTOMRIGHT", -30, 14)

    local scrollBox = CreateFrame("Frame", nil, scrollContainer, "WowScrollBoxList")
    scrollBox:SetAllPoints()
    self.scrollBox = scrollBox

    local scrollBar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollContainer, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollContainer, "BOTTOMRIGHT", 4, 0)
    self.scrollBar = scrollBar

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Button", SetupRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

    self.dataProvider = CreateDataProvider()
    scrollBox:SetDataProvider(self.dataProvider)

    CreateEmptyState(frame)

    frame:SetScript("OnShow", function()
        self:Refresh()
    end)
end

function HiddenItemsFrame:Refresh()
    if not self.frame or not self.dataProvider then return end

    local ids = addon:GetHiddenDecorIDs()
    local elements = {}
    for _, recordID in ipairs(ids) do
        elements[#elements + 1] = { recordID = recordID }
    end

    self.dataProvider:Flush()
    if #elements > 0 then
        self.dataProvider:InsertTable(elements)
    end

    self.frame.countText:SetText(string.format(L["HIDDEN_ITEMS_COUNT"], #elements))
    self.frame.clearAllButton:SetEnabled(#elements > 0)
    self.frame.emptyState:SetShown(#elements == 0)
    self.scrollBox:SetShown(#elements > 0)
    self.scrollBar:SetShown(#elements > 0)
end

function HiddenItemsFrame:ShowFrame()
    if InCombatLockdown() then
        addon:Print(L["COMBAT_LOCKDOWN_MESSAGE"])
        return
    end
    self:Create()
    self.frame:Show()
end

addon:RegisterInternalEvent(addon.Events.DECOR_VISIBILITY_CHANGED, function()
    if HiddenItemsFrame.frame and HiddenItemsFrame.frame:IsShown() then
        HiddenItemsFrame:Refresh()
    end
end)
