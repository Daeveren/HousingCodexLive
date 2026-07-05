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
local TITLE_BAR_HEIGHT = 46
local CONTENT_INSET = 3

StaticPopupDialogs["HOUSINGCODEX_CLEAR_HIDDEN_CONFIRM"] = {
    text = "%s",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        addon:ClearHiddenDecor()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function CreateTitle(frame)
    local title = addon:CreateFontString(frame.titleBar, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame.titleBar, "TOPLEFT", 16, -8)
    title:SetText(L["HIDDEN_ITEMS_TITLE"])
    title:SetTextColor(unpack(COLORS.GOLD))
    addon:SetFontSize(title, 17)
    frame.title = title
end

local function CreateEmptyState(frame)
    local empty = CreateFrame("Frame", nil, frame.contentFrame)
    empty:SetAllPoints()
    empty:Hide()

    local msg = addon:CreateFontString(empty, "OVERLAY", "GameFontNormalLarge")
    msg:SetPoint("CENTER", 0, 18)
    msg:SetText(L["HIDDEN_ITEMS_EMPTY"])
    msg:SetTextColor(unpack(COLORS.TEXT_SECONDARY))
    addon:SetFontSize(msg, 18)

    local desc = addon:CreateFontString(empty, "OVERLAY", "GameFontNormal")
    desc:SetPoint("TOP", msg, "BOTTOM", 0, -10)
    desc:SetText(L["HIDDEN_ITEMS_EMPTY_DESC"])
    desc:SetTextColor(unpack(COLORS.TEXT_TERTIARY))
    desc:SetWidth(380)
    desc:SetJustifyH("CENTER")
    addon:SetFontSize(desc, 12)

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
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()
    self.frame = frame

    table.insert(UISpecialFrames, FRAME_NAME)

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 3, -3)
    titleBar:SetPoint("TOPRIGHT", -3, -3)
    titleBar:SetHeight(TITLE_BAR_HEIGHT)
    titleBar:SetFrameLevel(frame:GetFrameLevel() + 3)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    frame.titleBar = titleBar

    local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints()
    titleBg:SetColorTexture(unpack(COLORS.TITLEBAR_BG))

    local titleDivider = titleBar:CreateTexture(nil, "ARTWORK")
    titleDivider:SetPoint("BOTTOMLEFT")
    titleDivider:SetPoint("BOTTOMRIGHT")
    titleDivider:SetHeight(1)
    titleDivider:SetColorTexture(0.2, 0.2, 0.25, 1)

    CreateTitle(frame)

    local count = addon:CreateFontString(titleBar, "OVERLAY", "GameFontNormal")
    count:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -3)
    count:SetTextColor(unpack(COLORS.TEXT_SECONDARY))
    addon:SetFontSize(count, 12)
    frame.countText = count

    local close = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function()
        frame:Hide()
    end)
    frame.closeButton = close

    local clearAll = addon:CreateActionButton(titleBar, L["HIDDEN_ITEMS_CLEAR_ALL"], function()
        local countHidden = addon:GetHiddenDecorCount()
        if countHidden <= 0 then return end
        StaticPopup_Show("HOUSINGCODEX_CLEAR_HIDDEN_CONFIRM", string.format(L["HIDDEN_ITEMS_CLEAR_ALL_CONFIRM"], countHidden))
    end, function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["HIDDEN_ITEMS_CLEAR_ALL"], 1, 0.82, 0)
        GameTooltip:AddLine(L["HIDDEN_ITEMS_CLEAR_ALL_TOOLTIP"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    clearAll:SetPoint("RIGHT", close, "LEFT", -10, 0)
    frame.clearAllButton = clearAll

    local contentFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    contentFrame:SetPoint("TOPLEFT", CONTENT_INSET, -TITLE_BAR_HEIGHT - CONTENT_INSET)
    contentFrame:SetPoint("BOTTOMRIGHT", -CONTENT_INSET, CONTENT_INSET)
    contentFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    contentFrame:SetBackdropColor(0.04, 0.04, 0.06, 1)
    contentFrame:SetBackdropBorderColor(0.22, 0.22, 0.27, 1)
    contentFrame:SetFrameLevel(frame:GetFrameLevel() + 1)
    frame.contentFrame = contentFrame

    local scrollContainer = CreateFrame("Frame", nil, contentFrame)
    scrollContainer:SetPoint("TOPLEFT", 6, -6)
    scrollContainer:SetPoint("BOTTOMRIGHT", -28, 6)

    local scrollBox = CreateFrame("Frame", nil, scrollContainer, "WowScrollBoxList")
    scrollBox:SetAllPoints()
    self.scrollBox = scrollBox

    local scrollBar = CreateFrame("EventFrame", nil, contentFrame, "MinimalScrollBar")
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
