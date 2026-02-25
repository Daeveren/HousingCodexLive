--[[
    Housing Codex - EndeavorsPanel.lua
    UI layer for the Endeavors mini-panel: XP bar, endeavor bar, task list,
    title bar auto-hide, minimize, movability, cogwheel config popup.
]]

local ADDON_NAME, addon = ...

local EP = {}
addon.EndeavorsPanel = EP

local CONST = addon.CONSTANTS.ENDEAVORS
local COLORS = addon.CONSTANTS.COLORS
local L = addon.L

-- Frame references
local frame = nil
local titleBar, titleBarBg, xpContainer, endeavorContainer, taskContainer
local xpBarBg, xpBarFill, xpLevelText, xpValueText
local endeavorBarBg, endeavorBarFill, endeavorLabel, endeavorValueText
local taskRows = {}
local taskHeaderText
local cogwheelBtn, minimizeBtn
local configFrame = nil
local hcIcon = nil

-- Title bar auto-hide state
local titleHideTimer = nil
local titleBarVisible = true
local isFirstShow = true   -- true until first auto-hide completes (login grace period)

-- Content dim state (separate from title bar hide)
local contentDimTimer = nil
local contentDimmed = false

-- Task prune ticker
local pruneTicker = nil

-- Width animation state
local widthAnimTarget = nil
local widthAnimStart = nil
local widthAnimElapsed = nil

-- Shared backdrop for all panel frames
local FRAME_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function SetBarProgress(barFill, barBg, progress, max)
    if not barFill or not barBg then return end
    if not max or max <= 0 then
        barFill:SetWidth(0.001)
        return
    end

    local pct = math.min(progress / max, 1)
    local bgWidth = barBg:GetWidth()
    if bgWidth <= 0 then bgWidth = CONST.PANEL_WIDTH - 20 end

    local fillWidth = math.max(pct * bgWidth, 0.001)
    barFill:SetWidth(fillWidth)
end

--------------------------------------------------------------------------------
-- Width Animation
--------------------------------------------------------------------------------

local widthAnimDriver = nil

local function AnimateWidth(targetWidth)
    if not frame then return end
    if widthAnimTarget == targetWidth then return end

    widthAnimTarget = targetWidth
    widthAnimStart = frame:GetWidth()
    widthAnimElapsed = 0

    if not widthAnimDriver then
        widthAnimDriver = CreateFrame("Frame", nil, frame)
    end

    widthAnimDriver:SetScript("OnUpdate", function(self, dt)
        widthAnimElapsed = widthAnimElapsed + dt
        local t = math.min(widthAnimElapsed / CONST.WIDTH_ANIM_DURATION, 1)
        -- Ease out quad
        local eased = 1 - (1 - t) * (1 - t)
        local w = widthAnimStart + (widthAnimTarget - widthAnimStart) * eased
        frame:SetWidth(w)
        if t >= 1 then
            self:SetScript("OnUpdate", nil)
            -- Refresh bar fills now that anchored widths have settled
            EP:UpdateXPBar()
            EP:UpdateEndeavorBar()
        end
    end)
end

--------------------------------------------------------------------------------
-- Title Bar Auto-Hide (title bar only — content dim is separate)
--------------------------------------------------------------------------------

local function SetTitleBarAlpha(alpha)
    if not titleBar then return end
    titleBar:SetAlpha(alpha)
    -- titleBarBg uses vertex alpha 0.64 and inherits parent frame alpha — no SetAlpha needed
    if titleBar.divider then titleBar.divider:SetAlpha(alpha * 0.6) end
end

local function FadeTitleBar(alpha, duration)
    if not titleBar then return end
    local startAlpha = titleBar:GetAlpha()
    local elapsed = 0

    if titleBar.fadeFrame then
        titleBar.fadeFrame:SetScript("OnUpdate", nil)
    else
        titleBar.fadeFrame = CreateFrame("Frame", nil, titleBar)
    end

    titleBar.fadeFrame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local t = math.min(elapsed / duration, 1)
        local a = startAlpha + (alpha - startAlpha) * t
        SetTitleBarAlpha(a)
        if t >= 1 then
            self:SetScript("OnUpdate", nil)
        end
    end)
end

local function ShowTitleBar()
    if titleBarVisible then return end
    titleBarVisible = true
    if titleHideTimer then
        titleHideTimer:Cancel()
        titleHideTimer = nil
    end
    FadeTitleBar(1, CONST.TITLE_FADE_IN)
end

local function ScheduleHideTitleBar(forceDelay)
    if titleHideTimer then titleHideTimer:Cancel() end
    local delay = (type(forceDelay) == "number") and forceDelay or CONST.TITLE_HIDE_DELAY
    titleHideTimer = C_Timer.NewTimer(delay, function()
        titleHideTimer = nil
        isFirstShow = false
        if frame and frame:IsShown() and not frame:IsMouseOver() then
            titleBarVisible = false
            FadeTitleBar(0, CONST.TITLE_FADE_OUT)
        end
    end)
end

--------------------------------------------------------------------------------
-- Content Dim (2-min inactivity — independent of title bar hide)
--------------------------------------------------------------------------------

local contentFadeDriver = nil

local function SetContentAlpha(alpha)
    if xpContainer then xpContainer:SetAlpha(alpha) end
    if endeavorContainer then endeavorContainer:SetAlpha(alpha) end
    if taskContainer then taskContainer:SetAlpha(alpha) end
end

local function FadeContent(targetAlpha, duration)
    local startAlpha = xpContainer and xpContainer:GetAlpha() or 1
    local elapsed = 0

    if not contentFadeDriver then
        contentFadeDriver = CreateFrame("Frame", nil, frame)
    end

    contentFadeDriver:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local t = math.min(elapsed / duration, 1)
        local a = startAlpha + (targetAlpha - startAlpha) * t
        SetContentAlpha(a)
        if t >= 1 then
            self:SetScript("OnUpdate", nil)
        end
    end)
end

local function UndimContent()
    if not contentDimmed then return end
    contentDimmed = false
    FadeContent(1, CONST.TITLE_FADE_IN)
end

local function DimContent()
    if contentDimmed then return end
    contentDimmed = true
    FadeContent(CONST.TITLE_IDLE_DIM, CONST.TITLE_FADE_OUT)
end

local function ScheduleContentDim()
    if contentDimTimer then contentDimTimer:Cancel() end
    contentDimTimer = C_Timer.NewTimer(CONST.CONTENT_DIM_DELAY, function()
        contentDimTimer = nil
        if frame and frame:IsShown() then
            DimContent()
        end
    end)
end

-- Called on any activity: mouseover, task update, initiative update
local function OnActivity()
    if not frame or not frame:IsShown() then return end
    UndimContent()
    ScheduleContentDim()
end

--------------------------------------------------------------------------------
-- Task Row Pool
--------------------------------------------------------------------------------

local function CreateTaskRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(CONST.TASK_ROW_HEIGHT)
    row:SetPoint("LEFT", 12, 0)
    row:SetPoint("RIGHT", -12, 0)

    local nameText = addon:CreateFontString(row, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", 0, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    local progressText = addon:CreateFontString(row, "OVERLAY", "GameFontNormalSmall")
    progressText:SetPoint("RIGHT", 0, 0)
    progressText:SetJustifyH("RIGHT")
    row.progressText = progressText

    -- Constrain name text so it doesn't overlap progress text
    nameText:SetPoint("RIGHT", progressText, "LEFT", -4, 0)

    row:Hide()
    return row
end

local function UpdateTaskRow(row, taskData)
    if not row or not taskData then return end

    row.nameText:SetText(taskData.taskName)

    if taskData.completed then
        row.progressText:SetText(taskData.current .. "/" .. taskData.max .. " [X]")
        row.progressText:SetTextColor(unpack(COLORS.PROGRESS_COMPLETE))
        row.nameText:SetTextColor(unpack(COLORS.PROGRESS_COMPLETE))
    else
        row.progressText:SetText(taskData.current .. "/" .. taskData.max)

        -- Fade out over last 20% of the task timeout
        local alpha = 1.0
        local fadeStart = CONST.TASK_FADE_TIMEOUT * 0.8
        if taskData.age > fadeStart then
            local fadePct = (taskData.age - fadeStart) / (CONST.TASK_FADE_TIMEOUT - fadeStart)
            alpha = 1.0 - (fadePct * 0.5)  -- fade from 1.0 to 0.5
        end
        row.progressText:SetTextColor(0.65, 0.65, 0.65, alpha)
        row.nameText:SetTextColor(0.65, 0.65, 0.65, alpha)
    end

    row:Show()
end

--------------------------------------------------------------------------------
-- Endeavor Tooltip
--------------------------------------------------------------------------------

local function ShowEndeavorTooltip(self)
    local data = addon.EndeavorsData
    local info = data:GetInitiativeInfo()
    if not info then return end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(info.title or L["ENDEAVORS_TITLE"], 1, 0.82, 0)

    if info.description then
        GameTooltip:AddLine(info.description, 1, 1, 1, true)
    end

    -- Progress
    if info.currentProgress and info.progressRequired then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format(L["ENDEAVORS_PROGRESS_FORMAT"], info.currentProgress, info.progressRequired), 0.7, 0.7, 0.7)
    end

    -- Player contribution
    if info.playerTotalContribution and info.playerTotalContribution > 0 then
        GameTooltip:AddLine(string.format(L["ENDEAVORS_YOUR_CONTRIBUTION"], info.playerTotalContribution), 0.7, 0.7, 0.7)
    end

    -- Milestones (compare currentProgress against requiredContributionAmount)
    if info.milestones and #info.milestones > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["ENDEAVORS_MILESTONES"], 1, 0.82, 0)
        local currentProgress = info.currentProgress or 0
        for _, milestone in ipairs(info.milestones) do
            local isReached = currentProgress >= milestone.requiredContributionAmount
            local marker = isReached and "[X]" or "[-]"
            local r, g, b = 0.5, 0.5, 0.5
            if isReached then r, g, b = 0.2, 1, 0.2 end
            -- Show reward title from first reward entry if available
            local label = ""
            if milestone.rewards and milestone.rewards[1] then
                label = milestone.rewards[1].title or ""
            end
            if label == "" then
                label = tostring(milestone.requiredContributionAmount)
            end
            GameTooltip:AddLine(marker .. " " .. label, r, g, b)
        end
    end

    GameTooltip:Show()
end

--------------------------------------------------------------------------------
-- Config Sub-Panel
--------------------------------------------------------------------------------

local function CreateConfigCheckbox(parent, labelKey, tooltipKey, dbKey, yOffset)
    local db = addon.db.endeavors
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", 8, yOffset)
    check.Text:SetFontObject(GameFontNormal)
    check.Text:SetTextColor(0.9, 0.9, 0.9)
    check.Text:SetText(L[labelKey])
    check:SetChecked(db[dbKey])

    check:SetScript("OnClick", function(self)
        db[dbKey] = self:GetChecked()
        EP:Refresh()
    end)

    check:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L[tooltipKey])
        GameTooltip:Show()
    end)

    check:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return check
end

local function CreateConfigFrame()
    if configFrame then return configFrame end

    local cf = CreateFrame("Frame", "HousingCodexEndeavorsConfig", UIParent, "BackdropTemplate")
    cf:SetSize(220, 150)
    cf:SetFrameStrata("DIALOG")
    cf:SetBackdrop(FRAME_BACKDROP)
    cf:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
    cf:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    cf:Hide()
    cf:EnableMouse(true)

    -- Title
    local title = addon:CreateFontString(cf, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText(L["ENDEAVORS_OPTIONS"])
    title:SetTextColor(1, 0.82, 0)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, cf, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", 2, 2)
    closeBtn:SetSize(20, 20)
    closeBtn:SetScript("OnClick", function() cf:Hide() end)

    -- Checkboxes
    local yOfs = -28
    CreateConfigCheckbox(cf, "ENDEAVORS_OPT_SHOW_HOUSE_XP", "ENDEAVORS_OPT_SHOW_HOUSE_XP_TIP", "showHouseXP", yOfs)
    yOfs = yOfs - 26
    CreateConfigCheckbox(cf, "ENDEAVORS_OPT_SHOW_ENDEAVOR", "ENDEAVORS_OPT_SHOW_ENDEAVOR_TIP", "showEndeavorProgress", yOfs)
    yOfs = yOfs - 26
    CreateConfigCheckbox(cf, "ENDEAVORS_OPT_SHOW_XP_TEXT", "ENDEAVORS_OPT_SHOW_XP_TEXT_TIP", "showXPText", yOfs)
    yOfs = yOfs - 26
    CreateConfigCheckbox(cf, "ENDEAVORS_OPT_SHOW_ENDEAVOR_TEXT", "ENDEAVORS_OPT_SHOW_ENDEAVOR_TEXT_TIP", "showEndeavorText", yOfs)

    -- ESC to close
    tinsert(UISpecialFrames, "HousingCodexEndeavorsConfig")

    configFrame = cf
    return cf
end

function EP:ToggleConfig(anchorFrame)
    local cf = CreateConfigFrame()
    if cf:IsShown() then
        cf:Hide()
        return
    end

    cf:ClearAllPoints()
    if anchorFrame then
        cf:SetPoint("TOPLEFT", anchorFrame, "BOTTOMRIGHT", 20, 0)
    else
        cf:SetPoint("CENTER")
    end
    cf:Show()
end

--------------------------------------------------------------------------------
-- Minimize / Expand
--------------------------------------------------------------------------------

local function UpdateMinimizeButton()
    if not minimizeBtn then return end
    local db = addon.db.endeavors
    if db.minimized then
        minimizeBtn:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-UP")
        minimizeBtn:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-DOWN")
    else
        minimizeBtn:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-UP")
        minimizeBtn:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-DOWN")
    end
end

local function ToggleMinimize()
    local db = addon.db.endeavors
    db.minimized = not db.minimized
    UpdateMinimizeButton()
    EP:Refresh()

    ScheduleHideTitleBar()
end

--------------------------------------------------------------------------------
-- Frame Creation
--------------------------------------------------------------------------------

local function CreateEndeavorsFrame()
    if frame then return frame end

    local db = addon.db.endeavors

    -- Main frame
    frame = CreateFrame("Frame", "HousingCodexEndeavorsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(CONST.PANEL_WIDTH, 100) -- height is dynamic
    frame:SetFrameStrata("MEDIUM")
    frame:SetBackdrop(FRAME_BACKDROP)
    frame:SetBackdropColor(0.04, 0.04, 0.06, 0.60)
    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.60)
    frame:SetClampedToScreen(true)
    frame:Hide()

    -- ESC to close
    tinsert(UISpecialFrames, "HousingCodexEndeavorsFrame")

    -- Mouse enter/leave for title bar auto-hide + activity tracking
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function()
        ShowTitleBar()
        OnActivity()
    end)
    frame:SetScript("OnLeave", ScheduleHideTitleBar)

    -- Restore saved position or default to top-left area
    if not addon:RestoreFramePosition(frame, "endeavors") then
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 144, -150)
    end

    ----------------------------------------------------------------------------
    -- Title Bar
    ----------------------------------------------------------------------------
    titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetHeight(CONST.TITLE_BAR_HEIGHT)
    titleBar:SetPoint("TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", -4, -4)

    -- Title bar background texture (inherits parent alpha for auto-hide fade)
    titleBarBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBarBg:SetAllPoints()
    titleBarBg:SetColorTexture(0.06, 0.06, 0.08, 0.64)

    -- Make title bar the drag handle
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        addon:SaveFramePosition(frame, "endeavors")
    end)
    frame:SetMovable(true)

    -- Title bar mouse events for auto-hide + activity tracking
    titleBar:SetScript("OnEnter", function()
        ShowTitleBar()
        OnActivity()
    end)
    titleBar:SetScript("OnLeave", ScheduleHideTitleBar)

    -- HC icon (on its own frame above titleBar so titleBarBg doesn't cover it)
    local iconFrame = CreateFrame("Frame", nil, frame)
    iconFrame:SetFrameLevel(titleBar:GetFrameLevel() + 1)
    iconFrame:SetSize(18, 18)
    iconFrame:SetPoint("TOPLEFT", titleBar, "TOPLEFT", 2, 0)
    hcIcon = iconFrame:CreateTexture(nil, "OVERLAY")
    hcIcon:SetAllPoints()
    hcIcon:SetTexture("Interface\\AddOns\\HousingCodex\\HC64")

    -- Title text
    local titleText = addon:CreateFontString(titleBar, "OVERLAY", "GameFontNormalSmall")
    titleText:SetPoint("LEFT", hcIcon, "RIGHT", 4, 0)
    titleText:SetText(L["ENDEAVORS_TITLE"])
    titleText:SetTextColor(unpack(COLORS.GOLD))

    -- Cogwheel button (rightmost)
    cogwheelBtn = CreateFrame("Button", nil, titleBar)
    cogwheelBtn:SetSize(16, 16)
    cogwheelBtn:SetPoint("RIGHT", -2, 0)
    cogwheelBtn:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    cogwheelBtn:GetNormalTexture():SetVertexColor(0.8, 0.8, 0.8, 0.9)
    cogwheelBtn:SetPushedTexture("Interface\\Buttons\\UI-OptionsButton")
    cogwheelBtn:GetPushedTexture():SetVertexColor(0.6, 0.6, 0.6, 1)
    cogwheelBtn:SetHighlightTexture("Interface\\Buttons\\UI-OptionsButton")
    cogwheelBtn:GetHighlightTexture():SetAlpha(0.3)
    cogwheelBtn:SetScript("OnClick", function(self)
        EP:ToggleConfig(self)
    end)
    cogwheelBtn:SetScript("OnEnter", function(self)
        ShowTitleBar()
        OnActivity()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["ENDEAVORS_OPTIONS_TOOLTIP"])
        GameTooltip:Show()
    end)
    cogwheelBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
        ScheduleHideTitleBar()
    end)

    -- Minimize button (left of cogwheel)
    minimizeBtn = CreateFrame("Button", nil, titleBar)
    minimizeBtn:SetSize(16, 16)
    minimizeBtn:SetPoint("RIGHT", cogwheelBtn, "LEFT", -2, 0)
    minimizeBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
    minimizeBtn:GetHighlightTexture():SetAlpha(0.3)
    UpdateMinimizeButton()
    minimizeBtn:SetScript("OnClick", function()
        ToggleMinimize()
    end)
    minimizeBtn:SetScript("OnEnter", function(self)
        ShowTitleBar()
        OnActivity()
    end)
    minimizeBtn:SetScript("OnLeave", function()
        ScheduleHideTitleBar()
    end)

    -- Divider below title bar
    local titleDivider = frame:CreateTexture(nil, "ARTWORK")
    titleDivider:SetHeight(1)
    titleDivider:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -2)
    titleDivider:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, -2)
    titleDivider:SetColorTexture(0.3, 0.3, 0.35, 0.6)
    titleBar.divider = titleDivider

    ----------------------------------------------------------------------------
    -- XP Container (House Level + XP Bar) -- inline layout
    ----------------------------------------------------------------------------
    xpContainer = CreateFrame("Frame", nil, frame)
    xpContainer:SetHeight(CONST.XP_BAR_HEIGHT + 6) -- bar + padding
    xpContainer:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -6)
    xpContainer:SetPoint("RIGHT", frame, "RIGHT", -4, 0)

    -- Level text: just the number, inline left of bar
    xpLevelText = addon:CreateFontString(xpContainer, "OVERLAY", "GameFontNormalSmall")
    xpLevelText:SetPoint("LEFT", 6, 0)
    xpLevelText:SetTextColor(0.9, 0.9, 0.9, 1)

    -- XP bar background (right of level text)
    xpBarBg = xpContainer:CreateTexture(nil, "BACKGROUND")
    xpBarBg:SetHeight(CONST.XP_BAR_HEIGHT)
    xpBarBg:SetPoint("LEFT", xpLevelText, "RIGHT", 4, 0)
    xpBarBg:SetPoint("RIGHT", xpContainer, "RIGHT", -6, 0)
    xpBarBg:SetColorTexture(0.15, 0.15, 0.18, 1)

    -- XP bar fill (muted blue)
    xpBarFill = xpContainer:CreateTexture(nil, "ARTWORK")
    xpBarFill:SetHeight(CONST.XP_BAR_HEIGHT)
    xpBarFill:SetPoint("TOPLEFT", xpBarBg, "TOPLEFT")
    xpBarFill:SetColorTexture(0.25, 0.5, 0.75, 1)
    xpBarFill:SetWidth(0.001)

    -- XP value text (overlaid on bar, centered, shown on hover or when enabled)
    xpValueText = addon:CreateFontString(xpContainer, "OVERLAY", "GameFontNormalSmall")
    xpValueText:SetPoint("CENTER", xpBarBg, "CENTER", 0, 0)
    xpValueText:SetTextColor(0.9, 0.9, 0.9, 1)
    addon:SetFontSize(xpValueText, 12)

    -- Hover-to-show XP text
    xpContainer:EnableMouse(true)
    xpContainer:SetScript("OnEnter", function()
        ShowTitleBar()
        OnActivity()
        if not db.showXPText and xpValueText.storedText then
            xpValueText:SetText(xpValueText.storedText)
            xpValueText:Show()
        end
    end)
    xpContainer:SetScript("OnLeave", function()
        ScheduleHideTitleBar()
        if not db.showXPText then
            xpValueText:Hide()
        end
    end)

    ----------------------------------------------------------------------------
    -- Endeavor Container (Initiative Progress Bar) -- inline layout
    ----------------------------------------------------------------------------
    endeavorContainer = CreateFrame("Frame", nil, frame)
    endeavorContainer:SetHeight(CONST.ENDEAVOR_BAR_HEIGHT + 6)

    -- Endeavor label: "E" inline left of bar
    endeavorLabel = addon:CreateFontString(endeavorContainer, "OVERLAY", "GameFontNormalSmall")
    endeavorLabel:SetPoint("LEFT", 6, 0)
    endeavorLabel:SetText("E")
    endeavorLabel:SetTextColor(0.9, 0.9, 0.9, 1)

    -- Endeavor bar background (right of "E" label)
    endeavorBarBg = endeavorContainer:CreateTexture(nil, "BACKGROUND")
    endeavorBarBg:SetHeight(CONST.ENDEAVOR_BAR_HEIGHT)
    endeavorBarBg:SetPoint("LEFT", endeavorLabel, "RIGHT", 4, 0)
    endeavorBarBg:SetPoint("RIGHT", endeavorContainer, "RIGHT", -6, 0)
    endeavorBarBg:SetColorTexture(0.15, 0.15, 0.18, 1)

    -- Endeavor bar fill (muted green)
    endeavorBarFill = endeavorContainer:CreateTexture(nil, "ARTWORK")
    endeavorBarFill:SetHeight(CONST.ENDEAVOR_BAR_HEIGHT)
    endeavorBarFill:SetPoint("TOPLEFT", endeavorBarBg, "TOPLEFT")
    endeavorBarFill:SetColorTexture(0.15, 0.55, 0.3, 1)
    endeavorBarFill:SetWidth(0.001)

    -- Endeavor value text (overlaid on bar, centered, shown on hover or when enabled)
    endeavorValueText = addon:CreateFontString(endeavorContainer, "OVERLAY", "GameFontNormalSmall")
    endeavorValueText:SetPoint("CENTER", endeavorBarBg, "CENTER", 0, 0)
    endeavorValueText:SetTextColor(0.9, 0.9, 0.9, 1)
    addon:SetFontSize(endeavorValueText, 12)

    -- Tooltip + hover-to-show on endeavor area
    endeavorContainer:EnableMouse(true)
    endeavorContainer:SetScript("OnEnter", function(self)
        ShowTitleBar()
        OnActivity()
        ShowEndeavorTooltip(self)
        if not db.showEndeavorText and endeavorValueText.storedText then
            endeavorValueText:SetText(endeavorValueText.storedText)
            endeavorValueText:Show()
        end
    end)
    endeavorContainer:SetScript("OnLeave", function()
        GameTooltip:Hide()
        ScheduleHideTitleBar()
        if not db.showEndeavorText then
            endeavorValueText:Hide()
        end
    end)

    ----------------------------------------------------------------------------
    -- Task Container
    ----------------------------------------------------------------------------
    taskContainer = CreateFrame("Frame", nil, frame)
    taskContainer:SetPoint("LEFT", 0, 0)
    taskContainer:SetPoint("RIGHT", 0, 0)

    -- Task divider (top border of task section)
    local taskDivider = taskContainer:CreateTexture(nil, "ARTWORK")
    taskDivider:SetHeight(1)
    taskDivider:SetPoint("TOPLEFT", 6, 0)
    taskDivider:SetPoint("TOPRIGHT", -6, 0)
    taskDivider:SetColorTexture(0.3, 0.3, 0.35, 0.4)
    taskContainer.divider = taskDivider

    -- Task header label: "last 3 endeavors progressed"
    taskHeaderText = addon:CreateFontString(taskContainer, "OVERLAY", "GameFontNormalSmall")
    taskHeaderText:SetPoint("TOPLEFT", 12, -4)
    taskHeaderText:SetText(L["ENDEAVORS_TASK_HEADER"])
    taskHeaderText:SetTextColor(0.5, 0.5, 0.5, 1)
    addon:SetFontSize(taskHeaderText, 10)
    taskHeaderText:Hide()

    -- Pre-create task row pool
    for i = 1, CONST.MAX_VISIBLE_TASKS do
        local row = CreateTaskRow(taskContainer, i)
        taskRows[i] = row
    end

    return frame
end

--------------------------------------------------------------------------------
-- Layout & Refresh
--------------------------------------------------------------------------------

function EP:UpdateLayout()
    if not frame then return end

    local db = addon.db.endeavors

    -- When minimized: only show title bar
    if db.minimized then
        xpContainer:Hide()
        endeavorContainer:Hide()
        taskContainer:Hide()
        for i = 1, CONST.MAX_VISIBLE_TASKS do
            taskRows[i]:Hide()
        end
        taskHeaderText:Hide()

        -- Title bar only height
        local titleOnlyHeight = CONST.TITLE_BAR_HEIGHT + 12
        frame:SetHeight(titleOnlyHeight)
        AnimateWidth(CONST.PANEL_WIDTH)
        return
    end

    local yOffset = -(CONST.TITLE_BAR_HEIGHT + 10)  -- Below title bar + padding
    local showXP = db.showHouseXP
    local showEndeavor = db.showEndeavorProgress and addon.EndeavorsData:IsInitiativeEnabled()

    -- XP container
    if showXP then
        xpContainer:ClearAllPoints()
        xpContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, yOffset)
        xpContainer:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
        xpContainer:Show()
        yOffset = yOffset - xpContainer:GetHeight() - 4
    else
        xpContainer:Hide()
    end

    -- Endeavor container
    if showEndeavor then
        endeavorContainer:ClearAllPoints()
        endeavorContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, yOffset)
        endeavorContainer:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
        endeavorContainer:Show()
        yOffset = yOffset - endeavorContainer:GetHeight() - 2
    else
        endeavorContainer:Hide()
    end

    -- Task container
    local activeTasks = addon.EndeavorsData:GetActiveTasks()
    local taskCount = math.min(#activeTasks, CONST.MAX_VISIBLE_TASKS)
    local hasVisibleTasks = taskCount > 0

    if hasVisibleTasks then
        taskContainer:ClearAllPoints()
        taskContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, yOffset - 2)
        taskContainer:SetPoint("RIGHT", frame, "RIGHT", 0, 0)

        -- Show header label
        taskHeaderText:Show()
        local taskYOffset = -4 - 12  -- Below divider + header

        for i = 1, CONST.MAX_VISIBLE_TASKS do
            if i <= taskCount then
                taskRows[i]:ClearAllPoints()
                taskRows[i]:SetPoint("TOPLEFT", taskContainer, "TOPLEFT", 12, taskYOffset)
                taskRows[i]:SetPoint("RIGHT", taskContainer, "RIGHT", -12, 0)
                UpdateTaskRow(taskRows[i], activeTasks[i])
                taskYOffset = taskYOffset - CONST.TASK_ROW_HEIGHT
            else
                taskRows[i]:Hide()
            end
        end

        local taskHeight = 4 + 12 + (taskCount * CONST.TASK_ROW_HEIGHT) + 4
        taskContainer:SetHeight(taskHeight)
        taskContainer:Show()
        yOffset = yOffset - taskHeight - 4
    else
        taskContainer:Hide()
        taskHeaderText:Hide()
        for i = 1, CONST.MAX_VISIBLE_TASKS do
            taskRows[i]:Hide()
        end
    end

    -- If nothing is visible, hide the panel entirely
    if not showXP and not showEndeavor and not hasVisibleTasks then
        frame:Hide()
        return
    end

    -- Set total frame height
    local totalHeight = math.abs(yOffset) + 6  -- bottom padding
    frame:SetHeight(math.max(totalHeight, 40))

    -- Dynamic width: narrow when no tasks, expanded when tasks visible
    if hasVisibleTasks then
        AnimateWidth(CONST.PANEL_WIDTH_EXPANDED)
    else
        AnimateWidth(CONST.PANEL_WIDTH)
    end
end

function EP:UpdateXPBar()
    if not frame or not xpContainer:IsShown() then return end

    local data = addon.EndeavorsData
    local db = addon.db.endeavors
    local level = data:GetHouseLevel()
    local isMax = data:IsMaxLevel()

    if isMax then
        xpLevelText:SetText(tostring(level))
        xpValueText.storedText = L["ENDEAVORS_MAX_LEVEL"]
        if db.showXPText then
            xpValueText:SetText(xpValueText.storedText)
            xpValueText:Show()
        else
            xpValueText:Hide()
        end
        SetBarProgress(xpBarFill, xpBarBg, 1, 1)
    else
        xpLevelText:SetText(tostring(level))
        local favor, favorNeeded = data:GetHouseXPProgress()
        favor = math.floor(favor)
        favorNeeded = math.floor(favorNeeded)
        local text = (favorNeeded > 0) and (favor .. "/" .. favorNeeded) or ""
        xpValueText.storedText = text

        if db.showXPText and text ~= "" then
            xpValueText:SetText(text)
            xpValueText:Show()
        else
            xpValueText:Hide()
        end

        SetBarProgress(xpBarFill, xpBarBg, favor, favorNeeded)
    end
end

function EP:UpdateEndeavorBar()
    if not frame or not endeavorContainer:IsShown() then return end

    local data = addon.EndeavorsData
    local db = addon.db.endeavors
    local info = data:GetInitiativeInfo()

    if not info then
        endeavorValueText.storedText = nil
        endeavorValueText:Hide()
        SetBarProgress(endeavorBarFill, endeavorBarBg, 0, 1)
        return
    end

    local current = math.floor(info.currentProgress or 0)
    local max = math.floor(info.progressRequired or 1)
    local text = (max > 0) and (current .. "/" .. max) or ""
    endeavorValueText.storedText = text

    if db.showEndeavorText and text ~= "" then
        endeavorValueText:SetText(text)
        endeavorValueText:Show()
    else
        endeavorValueText:Hide()
    end

    SetBarProgress(endeavorBarFill, endeavorBarBg, current, max)
end

function EP:Refresh()
    if not frame or not frame:IsShown() then return end

    self:UpdateXPBar()
    self:UpdateEndeavorBar()
    self:UpdateLayout()
end

--------------------------------------------------------------------------------
-- Show / Hide Logic
--------------------------------------------------------------------------------

function EP:ShouldShow()
    if not addon.db or not addon.db.endeavors then return false end
    if not addon.db.endeavors.shown then return false end
    if not addon.EndeavorsData:IsInNeighborhood() then return false end
    if not addon.EndeavorsData:HasHouse() then return false end
    return true
end

function EP:TryShow()
    if not self:ShouldShow() then return end
    if InCombatLockdown() then return end

    if not frame then
        CreateEndeavorsFrame()
    end

    frame:Show()
    SetContentAlpha(1)
    contentDimmed = false
    self:Refresh()

    -- Auto-hide title bar: 6s grace period on first show (login), 2s after mouseover thereafter
    local delay = isFirstShow and CONST.TITLE_HIDE_DELAY_LOGIN or nil
    ScheduleHideTitleBar(delay)

    -- Start 2-min inactivity dim timer
    ScheduleContentDim()

    -- Start prune ticker
    if not pruneTicker then
        pruneTicker = C_Timer.NewTicker(CONST.FADE_CHECK_INTERVAL, function()
            if not frame or not frame:IsShown() then return end
            local pruned = addon.EndeavorsData:PruneExpiredTasks()
            if pruned then
                EP:UpdateLayout()
            end
        end)
    end
end

function EP:TryHide()
    if frame and frame:IsShown() then
        frame:Hide()
    end

    -- Stop content dim timer
    if contentDimTimer then
        contentDimTimer:Cancel()
        contentDimTimer = nil
    end
    contentDimmed = false

    -- Stop prune ticker
    if pruneTicker then
        pruneTicker:Cancel()
        pruneTicker = nil
    end

    -- Hide config if open
    if configFrame and configFrame:IsShown() then
        configFrame:Hide()
    end
end

--------------------------------------------------------------------------------
-- Internal Event Handlers
--------------------------------------------------------------------------------

addon:RegisterInternalEvent("ENDEAVORS_ZONE_CHANGED", function(isInNeighborhood)
    if isInNeighborhood then
        -- Delayed show attempt: house data arrives async after zone detection
        C_Timer.After(1.5, function()
            if EP:ShouldShow() and (not frame or not frame:IsShown()) then
                EP:TryShow()
            end
        end)
    else
        EP:TryHide()
    end
end)

addon:RegisterInternalEvent("ENDEAVORS_HOUSE_LEVEL_UPDATED", function()
    if EP:ShouldShow() then
        EP:TryShow()
    elseif frame and frame:IsShown() then
        -- hasHouse may have become false
        EP:TryHide()
    end
end)

addon:RegisterInternalEvent("ENDEAVORS_INITIATIVE_UPDATED", function()
    if frame and frame:IsShown() then
        EP:Refresh()
        OnActivity()
    end
end)

addon:RegisterInternalEvent("ENDEAVORS_TASK_COMPLETED", function()
    if frame and frame:IsShown() then
        EP:Refresh()
        OnActivity()
    end
end)

--------------------------------------------------------------------------------
-- Settings Panel Integration: Open config from main settings
--------------------------------------------------------------------------------

function EP:OpenConfigFromSettings(anchorFrame)
    self:ToggleConfig(anchorFrame)
end
