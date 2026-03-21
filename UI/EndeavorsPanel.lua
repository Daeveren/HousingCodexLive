--[[
    Housing Codex - EndeavorsPanel.lua
    UI layer for the Endeavors mini-panel: XP bar, endeavor bar, task list,
    title bar auto-hide, movability, cogwheel config popup.
]]

local _, addon = ...

local EP = {}
addon.EndeavorsPanel = EP

local CONST = addon.CONSTANTS.ENDEAVORS
local COLORS = addon.CONSTANTS.COLORS
local L = addon.L

-- Scale factor tables
local SCALE_FACTORS = { small = 1.0, normal = 1.25, big = 1.5 }
local TITLE_SCALE_FACTORS = { small = 1.0, normal = 1.25, big = 1.25 }
local scaleFactor = 1.0
local titleScaleFactor = 1.0

-- Round to nearest integer for pixel-crisp results
local function S(value)
    return math.floor(value * scaleFactor + 0.5)
end
local function ST(value)
    return math.floor(value * titleScaleFactor + 0.5)
end
local function UpdateScaleFactors()
    local key = (addon.db and addon.db.endeavors and addon.db.endeavors.scale) or "small"
    scaleFactor = SCALE_FACTORS[key] or 1.0
    titleScaleFactor = TITLE_SCALE_FACTORS[key] or 1.0
end

-- Frame references
local frame = nil
local titleBar, titleBarBg, titleText, xpContainer, endeavorContainer, taskContainer
local xpBarBg, xpBarFill, xpLevelText, xpValueText, xpPctText
local endeavorBarBg, endeavorBarFill, endeavorLabel, endeavorValueText, endeavorPctText
local taskRows = {}
local cogwheelBtn
local configFrame = nil
local hcIcon = nil
local contentBackdrop = nil

-- Title bar auto-hide state
local titleHideTimer = nil
local titleBarVisible = true
local isFirstShow = true   -- true until first auto-hide completes (login grace period)

-- Task prune ticker
local pruneTicker = nil

-- Task expansion state (tasks visible → backdrop stays on, title bar still auto-hides)
local isTaskExpanded = false
-- Frame backdrop alpha tracking
local frameBackdropAlpha = 1

-- Width animation state
local widthAnimTarget = nil
local widthAnimStart = nil
local widthAnimElapsed = nil

-- Bar layout state (stacked ↔ inline transition)
local barLayoutFactor = 0  -- 0 = stacked (2 rows), 1 = inline (side-by-side)
local barLayoutTarget = 0
local barLayoutDriver = nil
local taskGoneTimer = nil  -- delay before collapsing from inline back to stacked
local tasksCollapsed = false  -- true = task section visually collapsed (data preserved for re-expansion)
local widthAnimDriver = nil

-- Cached active tasks (invalidated on each Refresh, persists across animation frames)
local cachedActiveTasks = nil

-- Typewriter animation: tracks which taskIDs have already been animated (play once per session)
local typewriterAnimatedTasks = {}

-- Content backdrop slide state (expanded mode: slides down when title hides, up on hover)
local contentBackdropDriver = nil
local contentBackdropTopOffset = 0  -- 0 = flush with frame top, negative = slid down

-- Post-combat retry state
local combatDeferFrame = CreateFrame("Frame")
local pendingCombatShow = false
combatDeferFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    pendingCombatShow = false
    EP:TryShow()
end)

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

-- Open the Housing Dashboard and navigate to a specific content tab.
-- tabID: the tab ID key on the HouseInfoContent frame (e.g. "houseUpgradeTabID", "endeavorTabID")
local function OpenHousingDashboard(tabID)
    if InCombatLockdown() then return end
    if not HousingDashboardFrame then
        pcall(C_AddOns.LoadAddOn, "Blizzard_HousingDashboard")
    end
    if not HousingDashboardFrame then return end
    ShowUIPanel(HousingDashboardFrame)
    HousingDashboardFrame:SetTab(HousingDashboardFrame.houseInfoTab)
    local contentFrame = HousingDashboardFrame.HouseInfoContent
        and HousingDashboardFrame.HouseInfoContent.ContentFrame
    if contentFrame then
        if not contentFrame.tabsInitialized then
            pcall(contentFrame.Initialize, contentFrame)
        end
        if contentFrame[tabID] then
            contentFrame:SetTab(contentFrame[tabID])
        end
    end
end

local function SetBarProgress(barFill, barBg, progress, max)
    if not barFill or not barBg then return end
    if not max or max <= 0 then
        barFill:SetWidth(0.001)
        return
    end

    local pct = math.min(progress / max, 1)
    local bgWidth = barBg:GetWidth()
    if bgWidth <= 0 then bgWidth = S(CONST.PANEL_WIDTH) - S(20) end

    local fillWidth = math.max(pct * bgWidth, 0.001)
    barFill:SetWidth(fillWidth)
end

local function ApplyScale()
    if not frame then return end
    UpdateScaleFactors()

    -- Snap frame width immediately so UpdateLayout reads correct width
    -- (without this, bars are sized from stale frame:GetWidth() and overflow)
    local targetW = (isTaskExpanded or barLayoutTarget == 1)
        and S(CONST.PANEL_WIDTH_EXPANDED) or S(CONST.PANEL_WIDTH)
    frame:SetWidth(targetW)
    widthAnimTarget = targetW
    if widthAnimDriver then
        widthAnimDriver:SetScript("OnUpdate", nil)
    end

    -- Title bar (size + anchors)
    titleBar:SetHeight(ST(CONST.TITLE_BAR_HEIGHT))
    titleBar:ClearAllPoints()
    titleBar:SetPoint("TOPLEFT", ST(4), -ST(4))
    titleBar:SetPoint("TOPRIGHT", -ST(4), -ST(4))

    -- Title text font + position
    if titleText then
        addon:SetFontSize(titleText, ST(11))
        titleText:ClearAllPoints()
        titleText:SetPoint("LEFT", titleBar, "LEFT", ST(2), 0)
    end

    -- Title bar buttons
    cogwheelBtn:SetSize(ST(16), ST(16))
    cogwheelBtn:ClearAllPoints()
    cogwheelBtn:SetPoint("RIGHT", -ST(2), 0)

    -- Icon
    if frame.iconFrame then
        frame.iconFrame:SetSize(S(18), S(18))
        if frame.iconBg then frame.iconBg:SetSize(S(22), S(22)) end
    end

    -- XP bar heights + font sizes + anchor offsets
    xpContainer:SetHeight(S(CONST.XP_BAR_HEIGHT) + S(4))
    xpBarBg:SetHeight(S(CONST.XP_BAR_HEIGHT))
    xpBarFill:SetHeight(S(CONST.XP_BAR_HEIGHT))
    xpLevelText:ClearAllPoints()
    xpLevelText:SetPoint("LEFT", S(3), 0)
    xpBarBg:ClearAllPoints()
    xpBarBg:SetPoint("LEFT", xpLevelText, "RIGHT", S(4), 0)
    xpBarBg:SetPoint("RIGHT", xpContainer, "RIGHT", -S(6), 0)
    addon:SetFontSize(xpLevelText, S(11))
    addon:SetFontSize(xpValueText, S(10))
    addon:SetFontSize(xpPctText, S(9.5))

    -- Endeavor bar heights + font sizes + anchor offsets
    endeavorContainer:SetHeight(S(CONST.ENDEAVOR_BAR_HEIGHT) + S(4))
    endeavorBarBg:SetHeight(S(CONST.ENDEAVOR_BAR_HEIGHT))
    endeavorBarFill:SetHeight(S(CONST.ENDEAVOR_BAR_HEIGHT))
    endeavorLabel:ClearAllPoints()
    endeavorLabel:SetPoint("LEFT", S(3), 0)
    endeavorBarBg:ClearAllPoints()
    endeavorBarBg:SetPoint("LEFT", endeavorLabel, "RIGHT", S(4), 0)
    endeavorBarBg:SetPoint("RIGHT", endeavorContainer, "RIGHT", -S(6), 0)
    addon:SetFontSize(endeavorLabel, S(11))
    addon:SetFontSize(endeavorValueText, S(10))
    addon:SetFontSize(endeavorPctText, S(9.5))

    -- Task rows (pooled)
    for i = 1, CONST.MAX_VISIBLE_TASKS do
        local row = taskRows[i]
        if row then
            row:SetHeight(S(CONST.TASK_ROW_HEIGHT))
            addon:SetFontSize(row.nameText, S(10))
            addon:SetFontSize(row.progressText, S(10))
        end
    end

    -- Task divider insets
    if taskContainer and taskContainer.divider then
        taskContainer.divider:ClearAllPoints()
        taskContainer.divider:SetPoint("TOPLEFT", S(6), 0)
        taskContainer.divider:SetPoint("TOPRIGHT", -S(6), 0)
    end
end

--------------------------------------------------------------------------------
-- Width Animation
--------------------------------------------------------------------------------

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
-- Bar Layout Animation (stacked ↔ inline)
--------------------------------------------------------------------------------

local function AnimateBarLayout(targetFactor)
    if barLayoutTarget == targetFactor then return end
    barLayoutTarget = targetFactor

    local startFactor = barLayoutFactor
    local elapsed = 0

    if not barLayoutDriver then
        barLayoutDriver = CreateFrame("Frame", nil, frame)
    end

    barLayoutDriver:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local t = math.min(elapsed / CONST.BAR_LAYOUT_DURATION, 1)
        local eased = 1 - (1 - t) * (1 - t)
        barLayoutFactor = startFactor + (targetFactor - startFactor) * eased

        EP:UpdateLayout()

        if t >= 1 then
            barLayoutFactor = targetFactor
            self:SetScript("OnUpdate", nil)
            -- Final bar update after animation settles
            EP:UpdateXPBar()
            EP:UpdateEndeavorBar()
        end
    end)
end

local function ResetBarLayout()
    if taskGoneTimer then taskGoneTimer:Cancel(); taskGoneTimer = nil end
    barLayoutFactor = 0
    barLayoutTarget = 0
    if barLayoutDriver then barLayoutDriver:SetScript("OnUpdate", nil) end
end

--------------------------------------------------------------------------------
-- Frame Backdrop Fade (synced with title bar — fades when idle, shows on hover/tasks)
--------------------------------------------------------------------------------

local backdropFadeDriver = nil

local function SetFrameBackdropAlpha(alpha)
    if not frame then return end
    frameBackdropAlpha = alpha
    frame:SetBackdropColor(0.02, 0.02, 0.03, 0.75 * alpha)
    frame:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.40 * alpha)
end

local function FadeFrameBackdrop(targetAlpha, duration)
    if not frame then return end
    local startAlpha = frameBackdropAlpha
    if math.abs(startAlpha - targetAlpha) < 0.01 then
        SetFrameBackdropAlpha(targetAlpha)
        return
    end
    local elapsed = 0

    if not backdropFadeDriver then
        backdropFadeDriver = CreateFrame("Frame", nil, frame)
    end

    backdropFadeDriver:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local t = math.min(elapsed / duration, 1)
        local a = startAlpha + (targetAlpha - startAlpha) * t
        SetFrameBackdropAlpha(a)
        if t >= 1 then
            self:SetScript("OnUpdate", nil)
        end
    end)
end

--------------------------------------------------------------------------------
-- Content Backdrop Slide (expanded mode: rounded contour slides down/up)
--------------------------------------------------------------------------------

local function SetContentBackdropTop(yOfs)
    if not contentBackdrop then return end
    contentBackdropTopOffset = yOfs
    contentBackdrop:ClearAllPoints()
    contentBackdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, yOfs)
    contentBackdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
end

local function SlideContentBackdrop(targetY, duration)
    if not contentBackdrop then return end
    local startY = contentBackdropTopOffset
    if math.abs(startY - targetY) < 0.5 then
        SetContentBackdropTop(targetY)
        return
    end
    local elapsed = 0

    if not contentBackdropDriver then
        contentBackdropDriver = CreateFrame("Frame", nil, frame)
    end

    contentBackdropDriver:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local t = math.min(elapsed / duration, 1)
        -- Ease-out quad for smooth deceleration
        t = 1 - (1 - t) * (1 - t)
        local y = startY + (targetY - startY) * t
        SetContentBackdropTop(y)
        if t >= 1 then
            self:SetScript("OnUpdate", nil)
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
    if isTaskExpanded and contentBackdrop and contentBackdrop:IsShown() then
        -- Expanded mode: slide content backdrop up to cover title bar
        SlideContentBackdrop(0, CONST.TITLE_FADE_IN)
        FadeFrameBackdrop(0, 0)  -- keep main backdrop hidden
    else
        FadeFrameBackdrop(1, CONST.TITLE_FADE_IN)
    end
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
            if isTaskExpanded and contentBackdrop and contentBackdrop:IsShown() then
                -- Expanded mode: slide content backdrop down below title bar
                local slideY = -(ST(CONST.TITLE_BAR_HEIGHT) - 2)
                SlideContentBackdrop(slideY, CONST.TITLE_FADE_OUT)
            else
                FadeFrameBackdrop(0, CONST.TITLE_FADE_OUT)
            end
        end
    end)
end

-- Called on task progress — resets the timer that clears the task list on expiry
local function OnTaskProgressActivity()
    if not frame or not frame:IsShown() then return end
    if not isTaskExpanded then return end

    if taskGoneTimer then taskGoneTimer:Cancel() end
    taskGoneTimer = C_Timer.NewTimer(CONST.TASK_COLLAPSE_DELAY, function()
        taskGoneTimer = nil
        tasksCollapsed = true
        EP:Refresh()
    end)
end

--------------------------------------------------------------------------------
-- Task Row Pool
--------------------------------------------------------------------------------

local function CreateTaskRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(S(CONST.TASK_ROW_HEIGHT))
    row:SetPoint("LEFT", S(12), 0)
    row:SetPoint("RIGHT", -S(12), 0)

    local nameText = addon:CreateFontString(row, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", 0, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    addon:SetFontSize(nameText, S(10))
    row.nameText = nameText

    local progressText = addon:CreateFontString(row, "OVERLAY", "GameFontNormalSmall")
    progressText:SetPoint("RIGHT", 0, 0)
    progressText:SetJustifyH("RIGHT")
    addon:SetFontSize(progressText, S(10))
    row.progressText = progressText

    -- Constrain name text so it doesn't overlap progress text
    nameText:SetPoint("RIGHT", progressText, "LEFT", -S(4), 0)

    -- Tooltip on hover
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        local data = self.taskData
        if not data then return end

        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("LEFT", self, "RIGHT", 15, 0)
        GameTooltip:AddLine(data.taskName or "", 1, 0.82, 0)

        if data.timesCompleted and data.timesCompleted > 0 then
            GameTooltip:AddLine(string.format(L["ENDEAVORS_COMPLETED_TIMES"], data.timesCompleted), 1, 1, 1)
        end

        if data.rewardQuestID and data.rewardQuestID > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip_AddQuestRewardsToTooltip(GameTooltip, data.rewardQuestID, TOOLTIP_QUEST_REWARDS_STYLE_INITIATIVE_TASK)
        end

        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    row:Hide()
    return row
end

local function StopTypewriterAnimation(row)
    if row.typewriterDriver then
        row.typewriterDriver:SetScript("OnUpdate", nil)
    end
    row.typewriterActiveTaskID = nil
end

local function StartTypewriterAnimation(row, taskID, fullText, r, g, b, alpha)
    local totalChars = strlenutf8(fullText)
    if totalChars == 0 then
        row.nameText:SetText(fullText)
        return
    end

    local elapsed = 0
    row.nameText:SetText("")
    row.nameText:SetTextColor(r, g, b, alpha)
    row.typewriterActiveTaskID = taskID

    if not row.typewriterDriver then
        row.typewriterDriver = CreateFrame("Frame", nil, row)
    end

    local byteLen = #fullText
    local lastCharsShown = 0
    row.typewriterDriver:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local charsToShow = math.floor(elapsed / CONST.TYPEWRITER_CHAR_DELAY)
        if charsToShow >= totalChars then
            row.nameText:SetText(fullText)
            self:SetScript("OnUpdate", nil)
            row.typewriterActiveTaskID = nil
            return
        end
        -- Skip SetText if no new character this frame
        if charsToShow == lastCharsShown then return end
        lastCharsShown = charsToShow
        -- Walk bytes once to find the byte offset for charsToShow UTF-8 characters
        local count = 0
        local i = 1
        while i <= byteLen and count < charsToShow do
            local byte = fullText:byte(i)
            if byte >= 0xF0 then i = i + 4
            elseif byte >= 0xE0 then i = i + 3
            elseif byte >= 0xC0 then i = i + 2
            else i = i + 1
            end
            count = count + 1
        end
        row.nameText:SetText(fullText:sub(1, i - 1))
    end)
end

local function UpdateTaskRow(row, taskData)
    if not row or not taskData then return end

    -- Cancel any ongoing typewriter animation if row is being reassigned to a different task
    if row.typewriterActiveTaskID and row.typewriterActiveTaskID ~= taskData.taskID then
        StopTypewriterAnimation(row)
    end

    row.taskData = taskData
    row.progressText:SetText(taskData.current .. "/" .. taskData.max)

    -- Fade out over last 20% of the task timeout
    local alpha = 1.0
    local fadeStart = CONST.TASK_FADE_TIMEOUT * 0.8
    if taskData.age > fadeStart then
        local fadePct = (taskData.age - fadeStart) / (CONST.TASK_FADE_TIMEOUT - fadeStart)
        alpha = 1.0 - (fadePct * 0.5)  -- fade from 1.0 to 0.5
    end
    row.progressText:SetTextColor(0.65, 0.65, 0.65, alpha)

    -- Typewriter animation: play once per task, let it run through layout refreshes
    if row.typewriterActiveTaskID == taskData.taskID then
        -- Animation still in progress for this task — don't interrupt
    elseif not typewriterAnimatedTasks[taskData.taskID] then
        typewriterAnimatedTasks[taskData.taskID] = true
        StartTypewriterAnimation(row, taskData.taskID, taskData.taskName, 0.65, 0.65, 0.65, alpha)
    else
        row.nameText:SetText(taskData.taskName)
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

    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    GameTooltip:SetPoint("LEFT", self, "RIGHT", 15, 0)
    GameTooltip:AddLine(info.title or L["ENDEAVORS_TITLE"], 1, 0.82, 0)

    if info.description then
        GameTooltip:AddLine(info.description, 1, 1, 1, true)
    end

    -- Time remaining
    if info.duration and info.duration > 0 then
        local timeStr
        if info.duration >= 86400 then
            local days = math.floor(info.duration / 86400)
            timeStr = string.format(L["ENDEAVORS_TIME_DAYS_LEFT"], days)
        else
            local hours = math.max(1, math.floor(info.duration / 3600))
            timeStr = string.format(L["ENDEAVORS_TIME_HOURS_LEFT"], hours)
        end
        GameTooltip:AddLine(timeStr, 0.7, 0.7, 0.7)
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

    -- Community Coupons (currency 3363)
    local ok, currInfo = pcall(C_CurrencyInfo.GetCurrencyInfo, CONST.COMMUNITY_COUPON_CURRENCY_ID)
    if ok and currInfo then
        local earned = currInfo.useTotalEarnedForMaxQty and currInfo.totalEarned or currInfo.quantity
        local cap = currInfo.maxQuantity
        if cap and cap > 0 then
            GameTooltip:AddLine(string.format(L["ENDEAVORS_COUPONS_EARNED"], currInfo.name, earned, cap), 0.7, 0.7, 0.7)
        end
    end

    -- Milestones (compare currentProgress against requiredContributionAmount)
    if info.milestones and #info.milestones > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["ENDEAVORS_MILESTONES"], 1, 0.82, 0)
        local currentProgress = info.currentProgress or 0
        for _, milestone in ipairs(info.milestones) do
            local isReached = currentProgress >= milestone.requiredContributionAmount
            -- Show reward title from first reward entry, fall back to threshold number
            local rewardTitle = milestone.rewards and milestone.rewards[1] and milestone.rewards[1].title
            local label = (rewardTitle and rewardTitle ~= "") and rewardTitle or tostring(milestone.requiredContributionAmount)
            if isReached then
                -- Gray text with green "completed" marker
                GameTooltip:AddLine(label .. " |cFF22BB22" .. L["ENDEAVORS_MILESTONE_COMPLETED"] .. "|r", 0.7, 0.7, 0.7)
            else
                GameTooltip:AddLine("[-] " .. label, 0.5, 0.5, 0.5)
            end
        end
    end

    GameTooltip:Show()
end

--------------------------------------------------------------------------------
-- Config Sub-Panel
--------------------------------------------------------------------------------

local function CreateSectionHeader(parent, labelKey, yOffset)
    local header = addon:CreateFontString(parent, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 12, yOffset)
    header:SetText(L[labelKey])
    header:SetTextColor(1, 0.82, 0)

    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset - 14)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset - 14)
    divider:SetColorTexture(0.3, 0.3, 0.35, 0.6)

    return yOffset - 20
end

local function SetCheckboxEnabled(checkbox, enabled)
    checkbox:SetEnabled(enabled)
    checkbox:SetAlpha(enabled and 1 or 0.5)
end

local function CreateConfigCheckbox(parent, labelKey, tooltipKey, dbKey, yOffset, xOffset)
    local db = addon.db.endeavors
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", xOffset or 8, yOffset)
    check.Text:SetFontObject(addon:GetFontObject("GameFontNormal"))
    addon:RegisterFontString(check.Text, "GameFontNormal")
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

local function CreateScaleButton(parent, label, scaleKey, x, yOffset, allButtons)
    local db = addon.db.endeavors
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(66, 22)
    btn:SetPoint("TOPLEFT", x, yOffset)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.15, 0.18, 0.8)
    btn.bg = bg

    local text = addon:CreateFontString(btn, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER")
    text:SetText(label)
    btn.label = text

    local function UpdateVisual(selected)
        if selected then
            bg:SetColorTexture(0.25, 0.22, 0.1, 0.9)
            text:SetTextColor(1, 0.82, 0)
        else
            bg:SetColorTexture(0.15, 0.15, 0.18, 0.8)
            text:SetTextColor(0.7, 0.7, 0.7)
        end
    end
    btn.UpdateVisual = UpdateVisual
    btn.scaleKey = scaleKey

    UpdateVisual(db.scale == scaleKey)

    btn:SetScript("OnClick", function()
        db.scale = scaleKey
        ApplyScale()
        EP:Refresh()
        for _, b in ipairs(allButtons) do
            b.UpdateVisual(b == btn)
        end
    end)

    btn:SetScript("OnEnter", function(self)
        if db.scale ~= scaleKey then
            bg:SetColorTexture(0.2, 0.2, 0.24, 1)
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["ENDEAVORS_OPT_SCALE_TIP"])
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        UpdateVisual(db.scale == scaleKey)
        GameTooltip:Hide()
    end)

    return btn
end

local function WireParentCheckbox(parent, children)
    local origOnClick = parent:GetScript("OnClick")
    parent:SetScript("OnClick", function(self)
        if origOnClick then origOnClick(self) end
        local on = self:GetChecked()
        for _, child in ipairs(children) do
            SetCheckboxEnabled(child, on)
        end
    end)
end

local function CreateConfigFrame()
    if configFrame then return configFrame end

    local cf = CreateFrame("Frame", "HousingCodexEndeavorsConfig", UIParent, "BackdropTemplate")
    cf:SetWidth(240)
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

    local db = addon.db.endeavors
    local yOfs = -38

    ---------- General ----------
    yOfs = CreateSectionHeader(cf, "ENDEAVORS_OPT_SECTION_GENERAL", yOfs)

    local enableCheck = CreateFrame("CheckButton", nil, cf, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", 10, yOfs)
    enableCheck.Text:SetFontObject(addon:GetFontObject("GameFontNormal"))
    addon:RegisterFontString(enableCheck.Text, "GameFontNormal")
    enableCheck.Text:SetTextColor(0.9, 0.9, 0.9)
    enableCheck.Text:SetText(L["ENDEAVORS_OPT_ENABLED"])
    enableCheck:SetChecked(db.enabled)
    enableCheck:SetScript("OnClick", function(self)
        db.enabled = self:GetChecked()
        if db.enabled then
            addon.EndeavorsData:RecheckNeighborhoodZone()
            EP:TryShow()
        else
            EP:TryHide()
        end
    end)
    enableCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["ENDEAVORS_OPT_ENABLED_TIP"])
        GameTooltip:Show()
    end)
    enableCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cf.enableCheck = enableCheck

    ---------- House XP ----------
    yOfs = yOfs - 38
    yOfs = CreateSectionHeader(cf, "ENDEAVORS_OPT_SECTION_HOUSE_XP", yOfs)

    local xpParent = CreateConfigCheckbox(cf, "ENDEAVORS_OPT_SHOW_HOUSE_XP", "ENDEAVORS_OPT_SHOW_HOUSE_XP_TIP", "showHouseXP", yOfs, 10)
    yOfs = yOfs - 22
    local xpText = CreateConfigCheckbox(cf, "ENDEAVORS_OPT_SHOW_XP_TEXT", "ENDEAVORS_OPT_SHOW_XP_TEXT_TIP", "showXPText", yOfs, 30)
    yOfs = yOfs - 22
    local xpPct = CreateConfigCheckbox(cf, "ENDEAVORS_OPT_SHOW_XP_PCT", "ENDEAVORS_OPT_SHOW_XP_PCT_TIP", "showXPPct", yOfs, 30)

    SetCheckboxEnabled(xpText, db.showHouseXP)
    SetCheckboxEnabled(xpPct, db.showHouseXP)
    WireParentCheckbox(xpParent, { xpText, xpPct })

    ---------- Endeavor Progress ----------
    yOfs = yOfs - 38
    yOfs = CreateSectionHeader(cf, "ENDEAVORS_OPT_SECTION_ENDEAVOR", yOfs)

    local endParent = CreateConfigCheckbox(cf, "ENDEAVORS_OPT_SHOW_ENDEAVOR", "ENDEAVORS_OPT_SHOW_ENDEAVOR_TIP", "showEndeavorProgress", yOfs, 10)
    yOfs = yOfs - 22
    local endText = CreateConfigCheckbox(cf, "ENDEAVORS_OPT_SHOW_ENDEAVOR_TEXT", "ENDEAVORS_OPT_SHOW_ENDEAVOR_TEXT_TIP", "showEndeavorText", yOfs, 30)
    yOfs = yOfs - 22
    local endPct = CreateConfigCheckbox(cf, "ENDEAVORS_OPT_SHOW_ENDEAVOR_PCT", "ENDEAVORS_OPT_SHOW_ENDEAVOR_PCT_TIP", "showEndeavorPct", yOfs, 30)

    SetCheckboxEnabled(endText, db.showEndeavorProgress)
    SetCheckboxEnabled(endPct, db.showEndeavorProgress)
    WireParentCheckbox(endParent, { endText, endPct })

    -- Dedicated handler: wire showEndeavorProgress toggle to data lifecycle
    local prevEndOnClick = endParent:GetScript("OnClick")
    endParent:SetScript("OnClick", function(self)
        if prevEndOnClick then prevEndOnClick(self) end
        if db.showEndeavorProgress then
            -- Start fetching + polling if we're in a neighborhood with the panel visible
            if addon.EndeavorsData:IsInNeighborhood() and frame and frame:IsShown() then
                C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo()
                addon.EndeavorsData:StartInitiativePoll()
            end
        else
            -- Stop background polling; Refresh() already clears cached tasks
            addon.EndeavorsData:StopInitiativePoll()
        end
    end)

    ---------- Panel Size ----------
    yOfs = yOfs - 38
    yOfs = CreateSectionHeader(cf, "ENDEAVORS_OPT_SECTION_SIZE", yOfs)

    local scaleBtns = {}
    local scaleOptions = {
        { "small",  L["ENDEAVORS_OPT_SCALE_SMALL"]  },
        { "normal", L["ENDEAVORS_OPT_SCALE_NORMAL"] },
        { "big",    L["ENDEAVORS_OPT_SCALE_BIG"]    },
    }

    for idx, opt in ipairs(scaleOptions) do
        local x = 12 + (idx - 1) * 70
        scaleBtns[idx] = CreateScaleButton(cf, opt[2], opt[1], x, yOfs, scaleBtns)
    end
    yOfs = yOfs - 22

    ---------- Finalize ----------
    cf:SetHeight(math.abs(yOfs) + 14)

    -- Sync checkbox/button states from DB each time the popup opens
    cf:SetScript("OnShow", function()
        local curDB = addon.db.endeavors
        -- Enable checkbox
        enableCheck:SetChecked(curDB.enabled)
        -- House XP checkboxes
        xpParent:SetChecked(curDB.showHouseXP)
        xpText:SetChecked(curDB.showXPText)
        xpPct:SetChecked(curDB.showXPPct)
        SetCheckboxEnabled(xpText, curDB.showHouseXP)
        SetCheckboxEnabled(xpPct, curDB.showHouseXP)
        -- Endeavor Progress checkboxes
        endParent:SetChecked(curDB.showEndeavorProgress)
        endText:SetChecked(curDB.showEndeavorText)
        endPct:SetChecked(curDB.showEndeavorPct)
        SetCheckboxEnabled(endText, curDB.showEndeavorProgress)
        SetCheckboxEnabled(endPct, curDB.showEndeavorProgress)
        -- Scale buttons
        for _, btn in ipairs(scaleBtns) do
            btn.UpdateVisual(curDB.scale == btn.scaleKey)
        end
    end)

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
-- Frame Creation
--------------------------------------------------------------------------------

local function CreateEndeavorsFrame()
    if frame then return frame end
    UpdateScaleFactors()

    local db = addon.db.endeavors

    -- Main frame
    frame = CreateFrame("Frame", "HousingCodexEndeavorsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(S(CONST.PANEL_WIDTH), 100) -- height is dynamic
    frame:SetFrameStrata("MEDIUM")
    frame:SetBackdrop(FRAME_BACKDROP)
    frame:SetBackdropColor(0.02, 0.02, 0.03, 0.75)
    frame:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.40)
    frame:SetClampedToScreen(true)
    frame:Hide()

    -- Persistent ambient panel — do NOT add to UISpecialFrames (ESC would hide it)

    -- Mouse enter/leave for title bar auto-hide
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function()
        ShowTitleBar()
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
    titleBar:SetHeight(ST(CONST.TITLE_BAR_HEIGHT))
    titleBar:SetPoint("TOPLEFT", ST(4), -ST(4))
    titleBar:SetPoint("TOPRIGHT", -ST(4), -ST(4))

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

    -- Title bar mouse events for auto-hide
    titleBar:SetScript("OnEnter", function()
        ShowTitleBar()
    end)
    titleBar:SetScript("OnLeave", ScheduleHideTitleBar)

    -- HC icon (left of progress bars — positioned dynamically in UpdateLayout)
    local iconFrame = CreateFrame("Frame", nil, frame)
    iconFrame:SetFrameLevel(titleBar:GetFrameLevel() + 1)
    iconFrame:SetSize(S(18), S(18))
    -- Initial anchor; UpdateLayout repositions vertically centered on bars
    iconFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", S(6), -(ST(CONST.TITLE_BAR_HEIGHT) + S(6)))

    -- Circular dark background for HC icon (stays visible when title bar + backdrop fade)
    local iconBg = iconFrame:CreateTexture(nil, "BACKGROUND")
    iconBg:SetPoint("CENTER")
    iconBg:SetSize(S(22), S(22))
    iconBg:SetColorTexture(0.02, 0.02, 0.03, 0.9)
    local iconMask = iconFrame:CreateMaskTexture()
    iconMask:SetAllPoints(iconBg)
    iconMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    iconBg:AddMaskTexture(iconMask)

    hcIcon = iconFrame:CreateTexture(nil, "OVERLAY")
    hcIcon:SetAllPoints()
    hcIcon:SetTexture("Interface\\AddOns\\HousingCodex\\HC64")
    frame.iconFrame = iconFrame  -- ref for UpdateLayout positioning
    frame.iconBg = iconBg        -- ref for toggling circular bg

    -- Title text (module-level ref for ApplyScale)
    titleText = addon:CreateFontString(titleBar, "OVERLAY", "GameFontNormalSmall")
    titleText:SetPoint("LEFT", titleBar, "LEFT", ST(2), 0)
    titleText:SetText(L["ENDEAVORS_TITLE"])
    titleText:SetTextColor(unpack(COLORS.GOLD))
    addon:SetFontSize(titleText, ST(11))

    -- Cogwheel button (rightmost)
    cogwheelBtn = CreateFrame("Button", nil, titleBar)
    cogwheelBtn:SetSize(ST(16), ST(16))
    cogwheelBtn:SetPoint("RIGHT", -ST(2), 0)
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
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["ENDEAVORS_OPTIONS_TOOLTIP"])
        GameTooltip:Show()
    end)
    cogwheelBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
        ScheduleHideTitleBar()
    end)

    -- Divider below title bar
    local titleDivider = frame:CreateTexture(nil, "ARTWORK")
    titleDivider:SetHeight(1)
    titleDivider:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -1)
    titleDivider:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, -1)
    titleDivider:SetColorTexture(0.3, 0.3, 0.35, 0.4)
    titleBar.divider = titleDivider

    -- Content backdrop (rounded contour that slides down when title bar hides in expanded mode)
    contentBackdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    contentBackdrop:SetFrameLevel(frame:GetFrameLevel())
    contentBackdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    contentBackdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    contentBackdrop:SetBackdrop(FRAME_BACKDROP)
    contentBackdrop:SetBackdropColor(0.02, 0.02, 0.03, 0.75)
    contentBackdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.40)
    contentBackdrop:Hide()

    ----------------------------------------------------------------------------
    -- XP Container (House Level + XP Bar) -- inline layout
    ----------------------------------------------------------------------------
    xpContainer = CreateFrame("Frame", nil, frame)
    xpContainer:SetHeight(S(CONST.XP_BAR_HEIGHT) + S(4)) -- bar + padding
    xpContainer:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -S(4))
    xpContainer:SetPoint("RIGHT", frame, "RIGHT", -S(4), 0)

    -- Level text: just the number, inline left of bar
    xpLevelText = addon:CreateFontString(xpContainer, "OVERLAY", "GameFontNormalSmall")
    xpLevelText:SetPoint("LEFT", S(3), 0)
    xpLevelText:SetTextColor(0.9, 0.9, 0.9, 1)
    addon:SetFontSize(xpLevelText, S(11))

    -- XP bar background (right of level text)
    xpBarBg = xpContainer:CreateTexture(nil, "BACKGROUND")
    xpBarBg:SetHeight(S(CONST.XP_BAR_HEIGHT))
    xpBarBg:SetPoint("LEFT", xpLevelText, "RIGHT", S(4), 0)
    xpBarBg:SetPoint("RIGHT", xpContainer, "RIGHT", -S(6), 0)
    xpBarBg:SetColorTexture(0.15, 0.15, 0.18, 1)

    -- XP bar fill (muted blue)
    xpBarFill = xpContainer:CreateTexture(nil, "ARTWORK")
    xpBarFill:SetHeight(S(CONST.XP_BAR_HEIGHT))
    xpBarFill:SetPoint("TOPLEFT", xpBarBg, "TOPLEFT")
    xpBarFill:SetColorTexture(0.25, 0.5, 0.75, 1)
    xpBarFill:SetWidth(0.001)

    -- XP value text (overlaid on bar, centered, shown on hover or when enabled)
    xpValueText = addon:CreateFontString(xpContainer, "OVERLAY", "GameFontNormalSmall")
    xpValueText:SetPoint("CENTER", xpBarBg, "CENTER", 0, 0)
    xpValueText:SetTextColor(0.9, 0.9, 0.9, 1)
    addon:SetFontSize(xpValueText, S(10))

    -- XP percentage text (overlaid on bar fill, subtle white)
    xpPctText = addon:CreateFontString(xpContainer, "OVERLAY", "GameFontNormalSmall")
    xpPctText:SetPoint("CENTER", xpBarBg, "CENTER", 0, 0)
    xpPctText:SetTextColor(1, 1, 1, 0.70)
    xpPctText:SetShadowOffset(1, -1)
    addon:SetFontSize(xpPctText, S(9.5))

    -- Hover-to-show XP text + tooltip, click to open Housing Dashboard
    xpContainer:EnableMouse(true)
    xpContainer:SetScript("OnEnter", function(self)
        ShowTitleBar()
        if not db.showXPText and xpValueText.storedText then
            xpValueText:SetText(xpValueText.storedText)
            xpValueText:Show()
            -- Hide pct text while value text is shown (avoid overlap)
            if db.showXPPct then xpPctText:Hide() end
        end
        -- Tooltip with detailed House XP info
        local data = addon.EndeavorsData
        local level = data:GetHouseLevel()
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("LEFT", self, "RIGHT", 15, 0)
        GameTooltip:AddLine(L["ENDEAVORS_XP_TOOLTIP_TITLE"], 1, 0.82, 0)
        if data:IsMaxLevel() then
            GameTooltip:AddLine(string.format(L["ENDEAVORS_XP_TOOLTIP_LEVEL_MAX"], level), 1, 1, 1)
        else
            GameTooltip:AddLine(string.format(L["ENDEAVORS_XP_TOOLTIP_LEVEL"], level), 1, 1, 1)
            local totalFavor, totalFavorNeeded = data:GetHouseXPTotal()
            totalFavor = math.floor(totalFavor)
            totalFavorNeeded = math.floor(totalFavorNeeded)
            if totalFavorNeeded > 0 then
                local pct = math.floor(totalFavor / totalFavorNeeded * 100)
                GameTooltip:AddLine(string.format(L["ENDEAVORS_XP_TOOLTIP_PROGRESS"],
                    BreakUpLargeNumbers(totalFavor), BreakUpLargeNumbers(totalFavorNeeded), pct), 0.7, 0.7, 0.7)
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["ENDEAVORS_XP_TOOLTIP_CLICK"], 0.5, 0.8, 1)
        GameTooltip:Show()
    end)
    xpContainer:SetScript("OnLeave", function()
        GameTooltip:Hide()
        ScheduleHideTitleBar()
        if not db.showXPText then
            xpValueText:Hide()
            -- Restore pct text if enabled
            if db.showXPPct and xpPctText.storedPct then
                xpPctText:SetText(xpPctText.storedPct)
                xpPctText:Show()
            end
        end
    end)
    xpContainer:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then return end
        OpenHousingDashboard("houseUpgradeTabID")
    end)

    ----------------------------------------------------------------------------
    -- Endeavor Container (Initiative Progress Bar) -- inline layout
    ----------------------------------------------------------------------------
    endeavorContainer = CreateFrame("Frame", nil, frame)
    endeavorContainer:SetHeight(S(CONST.ENDEAVOR_BAR_HEIGHT) + S(4))

    -- Endeavor label: "E" inline left of bar
    endeavorLabel = addon:CreateFontString(endeavorContainer, "OVERLAY", "GameFontNormalSmall")
    endeavorLabel:SetPoint("LEFT", S(3), 0)
    endeavorLabel:SetText("E")
    endeavorLabel:SetTextColor(0.9, 0.9, 0.9, 1)
    addon:SetFontSize(endeavorLabel, S(11))

    -- Endeavor bar background (right of "E" label)
    endeavorBarBg = endeavorContainer:CreateTexture(nil, "BACKGROUND")
    endeavorBarBg:SetHeight(S(CONST.ENDEAVOR_BAR_HEIGHT))
    endeavorBarBg:SetPoint("LEFT", endeavorLabel, "RIGHT", S(4), 0)
    endeavorBarBg:SetPoint("RIGHT", endeavorContainer, "RIGHT", -S(6), 0)
    endeavorBarBg:SetColorTexture(0.15, 0.15, 0.18, 1)

    -- Endeavor bar fill (muted green)
    endeavorBarFill = endeavorContainer:CreateTexture(nil, "ARTWORK")
    endeavorBarFill:SetHeight(S(CONST.ENDEAVOR_BAR_HEIGHT))
    endeavorBarFill:SetPoint("TOPLEFT", endeavorBarBg, "TOPLEFT")
    endeavorBarFill:SetColorTexture(0.15, 0.55, 0.3, 1)
    endeavorBarFill:SetWidth(0.001)

    -- Endeavor value text (overlaid on bar, centered, shown on hover or when enabled)
    endeavorValueText = addon:CreateFontString(endeavorContainer, "OVERLAY", "GameFontNormalSmall")
    endeavorValueText:SetPoint("CENTER", endeavorBarBg, "CENTER", 0, 0)
    endeavorValueText:SetTextColor(0.9, 0.9, 0.9, 1)
    addon:SetFontSize(endeavorValueText, S(10))

    -- Endeavor percentage text (overlaid on bar fill, subtle white)
    endeavorPctText = addon:CreateFontString(endeavorContainer, "OVERLAY", "GameFontNormalSmall")
    endeavorPctText:SetPoint("CENTER", endeavorBarBg, "CENTER", 0, 0)
    endeavorPctText:SetTextColor(1, 1, 1, 0.70)
    endeavorPctText:SetShadowOffset(1, -1)
    addon:SetFontSize(endeavorPctText, S(9.5))

    -- Tooltip + hover-to-show on endeavor area + click to open Endeavors tab
    endeavorContainer:EnableMouse(true)
    endeavorContainer:SetScript("OnEnter", function(self)
        ShowTitleBar()
        ShowEndeavorTooltip(self)
        -- Add click hint at end of tooltip
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["ENDEAVORS_TOOLTIP_CLICK"], 0.5, 0.8, 1)
        GameTooltip:Show()
        if not db.showEndeavorText and endeavorValueText.storedText then
            endeavorValueText:SetText(endeavorValueText.storedText)
            endeavorValueText:Show()
            -- Hide pct text while value text is shown (avoid overlap)
            if db.showEndeavorPct then endeavorPctText:Hide() end
        end
    end)
    endeavorContainer:SetScript("OnLeave", function()
        GameTooltip:Hide()
        ScheduleHideTitleBar()
        if not db.showEndeavorText then
            endeavorValueText:Hide()
            -- Restore pct text if enabled
            if db.showEndeavorPct and endeavorPctText.storedPct then
                endeavorPctText:SetText(endeavorPctText.storedPct)
                endeavorPctText:Show()
            end
        end
    end)
    endeavorContainer:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then return end
        OpenHousingDashboard("endeavorTabID")
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
    taskDivider:SetPoint("TOPLEFT", S(6), 0)
    taskDivider:SetPoint("TOPRIGHT", -S(6), 0)
    taskDivider:SetColorTexture(0.3, 0.3, 0.35, 0.4)
    taskContainer.divider = taskDivider

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
    UpdateScaleFactors()

    local db = addon.db.endeavors

    if not cachedActiveTasks then cachedActiveTasks = addon.EndeavorsData:GetActiveTasks() end

    local yOffset = -(ST(CONST.TITLE_BAR_HEIGHT) + S(4))  -- Below title bar + padding
    local showXP = db.showHouseXP and addon.EndeavorsData:HasHouse()
    local showEndeavor = db.showEndeavorProgress and addon.EndeavorsData:IsInitiativeEnabled()

    local barLeftInset = S(28)  -- Space for icon (6 + 22 circle bg)
    local barsTop = yOffset  -- Track where bars start for icon centering
    local factor = barLayoutFactor  -- 0 = stacked, 1 = inline
    local frameW = frame:GetWidth()
    local availW = frameW - barLeftInset - S(4)
    local gap = S(4)
    local halfW = math.max((availW - gap) / 2, S(20))

    -- XP container (stays top-left, width shrinks to half when inline)
    if showXP then
        local xpW = showEndeavor and (availW - factor * (availW - halfW)) or availW
        xpContainer:ClearAllPoints()
        xpContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", barLeftInset, yOffset)
        xpContainer:SetWidth(xpW)
        xpContainer:Show()
    else
        xpContainer:Hide()
    end

    -- Endeavor container (animates from row 2 to right side when going inline)
    if showEndeavor then
        local endW, endX, endY
        if showXP then
            endW = availW - factor * (availW - halfW)
            endX = barLeftInset + factor * (halfW + gap)
            local stackedY = yOffset - xpContainer:GetHeight() - S(2)
            endY = stackedY + factor * (yOffset - stackedY)
        else
            endW = availW
            endX = barLeftInset
            endY = yOffset
        end
        endeavorContainer:ClearAllPoints()
        endeavorContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", endX, endY)
        endeavorContainer:SetWidth(endW)
        endeavorContainer:Show()
    else
        endeavorContainer:Hide()
    end

    -- yOffset after bars (interpolated between stacked and inline height)
    if showXP and showEndeavor then
        local barH = xpContainer:GetHeight()
        local stackedDrop = 2 * (barH + S(2))
        local inlineDrop = barH + S(2)
        yOffset = yOffset - (stackedDrop - factor * (stackedDrop - inlineDrop))
    elseif showXP then
        yOffset = yOffset - xpContainer:GetHeight() - S(2)
    elseif showEndeavor then
        yOffset = yOffset - endeavorContainer:GetHeight() - S(2)
    end

    -- Position icon vertically centered on visible bars
    local iconFrame = frame.iconFrame
    if iconFrame then
        local hasBars = showXP or showEndeavor
        if hasBars then
            local barsBottom = yOffset + 2  -- undo last -2 spacing
            local barsMidY = (barsTop + barsBottom) / 2  -- negative offset from frame top
            local iconHalfH = iconFrame:GetHeight() / 2
            -- Icon Y nudge: +1 (up) in mini, -2 (down) in expanded
            local iconNudge = 0 - factor * S(2)
            iconFrame:ClearAllPoints()
            iconFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", S(6), barsMidY + iconHalfH + iconNudge)
            iconFrame:Show()
            -- Hide circular bg in expanded (inline) mode
            if frame.iconBg then
                if factor > 0.5 then
                    frame.iconBg:Hide()
                else
                    frame.iconBg:Show()
                end
            end
        else
            iconFrame:Hide()
        end
    end

    -- Task container
    local activeTasks = cachedActiveTasks
    local taskCount = math.min(#activeTasks, CONST.MAX_VISIBLE_TASKS)
    local hasVisibleTasks = taskCount > 0 and not tasksCollapsed

    if hasVisibleTasks then
        taskContainer:ClearAllPoints()
        taskContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, yOffset - S(2))
        taskContainer:SetPoint("RIGHT", frame, "RIGHT", 0, 0)

        local taskYOffset = -S(4)  -- Below divider

        for i = 1, CONST.MAX_VISIBLE_TASKS do
            if i <= taskCount then
                taskRows[i]:ClearAllPoints()
                taskRows[i]:SetPoint("TOPLEFT", taskContainer, "TOPLEFT", S(12), taskYOffset)
                taskRows[i]:SetPoint("RIGHT", taskContainer, "RIGHT", -S(12), 0)
                UpdateTaskRow(taskRows[i], activeTasks[i])
                taskYOffset = taskYOffset - S(CONST.TASK_ROW_HEIGHT)
            else
                taskRows[i]:Hide()
            end
        end

        local taskHeight = S(4) + (taskCount * S(CONST.TASK_ROW_HEIGHT)) + S(4)
        taskContainer:SetHeight(taskHeight)
        taskContainer:Show()
        yOffset = yOffset - taskHeight - S(2)
    else
        taskContainer:Hide()
        for i = 1, CONST.MAX_VISIBLE_TASKS do
            taskRows[i]:Hide()
        end
    end

    -- If nothing is visible, collapse to title-bar-only
    -- instead of hiding the frame entirely — hiding breaks re-show logic
    if not showXP and not showEndeavor and not hasVisibleTasks then
        isTaskExpanded = false
        ResetBarLayout()
        if frame.iconFrame then frame.iconFrame:Hide() end
        if contentBackdrop then contentBackdrop:Hide() end
        local titleOnlyHeight = ST(CONST.TITLE_BAR_HEIGHT) + S(12)
        frame:SetHeight(titleOnlyHeight)
        AnimateWidth(S(CONST.PANEL_WIDTH))
        return
    end

    -- Track task expansion: tasks appeared → animate to inline layout
    local wasTaskExpanded = isTaskExpanded
    isTaskExpanded = hasVisibleTasks

    if isTaskExpanded and not wasTaskExpanded then
        -- Tasks just appeared: animate to inline layout
        if taskGoneTimer then taskGoneTimer:Cancel(); taskGoneTimer = nil end
        if showXP and showEndeavor then
            AnimateBarLayout(1)
        end
        -- Show content backdrop (rounded contour) and hide main frame backdrop
        if contentBackdrop then
            SetContentBackdropTop(0)
            contentBackdrop:SetAlpha(1)
            contentBackdrop:Show()
        end
        FadeFrameBackdrop(0, 0)  -- immediately hide main backdrop, content backdrop takes over
        ShowTitleBar()
        ScheduleHideTitleBar()
        -- After 1 min of no task progress, collapse task section visually (data preserved)
        taskGoneTimer = C_Timer.NewTimer(CONST.TASK_COLLAPSE_DELAY, function()
            taskGoneTimer = nil
            tasksCollapsed = true
            EP:Refresh()
        end)
    elseif not isTaskExpanded and wasTaskExpanded then
        -- Tasks gone — collapse to stacked + mini width
        if taskGoneTimer then taskGoneTimer:Cancel(); taskGoneTimer = nil end
        AnimateBarLayout(0)
        -- Fade out content backdrop
        if contentBackdrop and contentBackdrop:IsShown() then
            local startAlpha = contentBackdrop:GetAlpha()
            local elapsed = 0
            local driver = contentBackdrop.fadeDriver
            if not driver then
                driver = CreateFrame("Frame", nil, frame)
                contentBackdrop.fadeDriver = driver
            end
            driver:SetScript("OnUpdate", function(self, dt)
                elapsed = elapsed + dt
                local t = math.min(elapsed / CONST.TITLE_FADE_OUT, 1)
                contentBackdrop:SetAlpha(startAlpha * (1 - t))
                if t >= 1 then
                    self:SetScript("OnUpdate", nil)
                    contentBackdrop:Hide()
                end
            end)
        end
        ScheduleHideTitleBar()
    end

    -- Set total frame height
    local bottomPad = hasVisibleTasks and 0 or S(3)
    local totalHeight = math.abs(yOffset) + bottomPad
    frame:SetHeight(math.max(totalHeight, S(40)))

    -- Dynamic width: expanded when tasks visible or inline layout active
    if hasVisibleTasks or barLayoutTarget == 1 then
        AnimateWidth(S(CONST.PANEL_WIDTH_EXPANDED))
    else
        AnimateWidth(S(CONST.PANEL_WIDTH))
    end
end

function EP:UpdateXPBar()
    if not frame or not xpContainer:IsShown() then return end

    local data = addon.EndeavorsData
    local db = addon.db.endeavors
    local level = data:GetHouseLevel()
    local isMax = data:IsMaxLevel()

    local valueShown = false
    if isMax then
        xpLevelText:SetText(tostring(level))
        xpValueText.storedText = L["ENDEAVORS_MAX_LEVEL"]
        if db.showXPText then
            xpValueText:SetText(xpValueText.storedText)
            xpValueText:Show()
            valueShown = true
        else
            xpValueText:Hide()
        end
        -- Percentage: show "DONE" at max (hide if value text is visible to avoid overlap)
        xpPctText.storedPct = L["ENDEAVORS_PCT_DONE"]
        if db.showXPPct and not valueShown then
            xpPctText:SetText(L["ENDEAVORS_PCT_DONE"])
            xpPctText:Show()
        else
            xpPctText:Hide()
        end
        SetBarProgress(xpBarFill, xpBarBg, 1, 1)
    else
        xpLevelText:SetText(tostring(level))
        local favor, favorNeeded = data:GetHouseXPProgress()
        -- Use cumulative values for text display (matches Blizzard Housing Dashboard)
        local totalFavor, totalFavorNeeded = data:GetHouseXPTotal()
        totalFavor = math.floor(totalFavor)
        totalFavorNeeded = math.floor(totalFavorNeeded)
        local text = (totalFavorNeeded > 0) and (totalFavor .. "/" .. totalFavorNeeded) or ""
        xpValueText.storedText = text

        if db.showXPText and text ~= "" then
            xpValueText:SetText(text)
            xpValueText:Show()
            valueShown = true
        else
            xpValueText:Hide()
        end

        -- Percentage text on bar (hide if value text is visible to avoid overlap)
        local pctStr = nil
        if favorNeeded and favorNeeded > 0 then
            local pct = math.floor(favor / favorNeeded * 100)
            pctStr = (pct >= 100) and L["ENDEAVORS_PCT_DONE"] or (pct .. "%")
        end
        xpPctText.storedPct = pctStr
        if db.showXPPct and not valueShown and pctStr then
            xpPctText:SetText(pctStr)
            xpPctText:Show()
        else
            xpPctText:Hide()
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
        endeavorPctText:Hide()
        SetBarProgress(endeavorBarFill, endeavorBarBg, 0, 1)
        return
    end

    local current = math.floor(info.currentProgress or 0)
    local max = math.floor(info.progressRequired or 1)
    local text = (max > 0) and (current .. "/" .. max) or ""
    endeavorValueText.storedText = text

    local valueShown = false
    if db.showEndeavorText and text ~= "" then
        endeavorValueText:SetText(text)
        endeavorValueText:Show()
        valueShown = true
    else
        endeavorValueText:Hide()
    end

    -- Percentage text on bar (hide if value text is visible to avoid overlap)
    local pctStr = nil
    if max > 0 then
        local pct = math.floor(current / max * 100)
        pctStr = (pct >= 100) and L["ENDEAVORS_PCT_DONE"] or (pct .. "%")
    end
    endeavorPctText.storedPct = pctStr
    if db.showEndeavorPct and not valueShown and pctStr then
        endeavorPctText:SetText(pctStr)
        endeavorPctText:Show()
    else
        endeavorPctText:Hide()
    end

    SetBarProgress(endeavorBarFill, endeavorBarBg, current, max)
end

function EP:Refresh()
    if not frame or not frame:IsShown() then return end
    UpdateScaleFactors()

    cachedActiveTasks = nil  -- force fresh data on explicit refresh
    self:UpdateLayout()
    self:UpdateXPBar()
    self:UpdateEndeavorBar()
end

--------------------------------------------------------------------------------
-- Show / Hide Logic
--------------------------------------------------------------------------------

function EP:ShouldShow()
    if not addon.db or not addon.db.endeavors then return false end
    local db = addon.db.endeavors
    if not db.enabled then return false end
    if not addon.EndeavorsData:IsInNeighborhood() then return false end
    -- Need at least one content source: house XP or initiative
    if not (addon.EndeavorsData:HasHouse() or addon.EndeavorsData:IsInitiativeEnabled()) then return false end
    return true
end

function EP:TryShow()
    if not self:ShouldShow() then return end
    if InCombatLockdown() then
        if not pendingCombatShow then
            pendingCombatShow = true
            combatDeferFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
        return
    end

    if not frame then
        CreateEndeavorsFrame()
    end

    UpdateScaleFactors()
    frame:Show()
    SetFrameBackdropAlpha(1)
    self:Refresh()

    -- Auto-hide title bar: 6s grace period on first show (login), 2s after mouseover thereafter
    local delay = isFirstShow and CONST.TITLE_HIDE_DELAY_LOGIN or nil
    ScheduleHideTitleBar(delay)

    -- Start initiative progress poll (NEIGHBORHOOD_INITIATIVE_UPDATED is request/response only)
    -- Skip if endeavor bar is disabled — poll feeds task diff tracking too,
    -- but without the bar there's no visible consumer
    if addon.db.endeavors.showEndeavorProgress then
        addon.EndeavorsData:StartInitiativePoll()
    end

    -- Start prune ticker
    if not pruneTicker then
        pruneTicker = C_Timer.NewTicker(CONST.FADE_CHECK_INTERVAL, function()
            if not frame or not frame:IsShown() then return end
            local pruned = addon.EndeavorsData:PruneExpiredTasks()
            if pruned then
                EP:Refresh()
            end
        end)
    end
end

function EP:TryHide()
    -- Safety net: don't hide while player is still in a neighborhood with the feature enabled
    local db = addon.db and addon.db.endeavors
    if db and db.enabled then
        if addon.EndeavorsData:IsInNeighborhood() then return end
        -- Live API fallback: cached state may be stale from flicker
        if C_Housing.IsOnNeighborhoodMap() or C_Housing.IsInsideHouseOrPlot() then return end
    end

    if frame and frame:IsShown() then
        frame:Hide()
    end

    -- Cancel pending combat retry
    if pendingCombatShow then
        pendingCombatShow = false
        combatDeferFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end

    -- Stop title bar fade timer
    if titleHideTimer then
        titleHideTimer:Cancel()
        titleHideTimer = nil
    end

    -- Reset bar layout to stacked
    isTaskExpanded = false
    tasksCollapsed = false
    ResetBarLayout()

    -- Reset typewriter tracking (new tasks in next neighborhood get fresh animation)
    wipe(typewriterAnimatedTasks)

    -- Stop initiative progress poll
    addon.EndeavorsData:StopInitiativePoll()

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
        -- Delayed show attempt: zone APIs need a moment to settle
        C_Timer.After(0.5, function()
            if EP:ShouldShow() and (not frame or not frame:IsShown()) then
                EP:TryShow()
            end
        end)
    else
        -- Re-check after delay to guard against zone micro-transitions
        -- (IsOnNeighborhoodMap can flicker false during sub-zone transitions)
        C_Timer.After(2.0, function()
            -- Re-probe live API (cached state may be stale from flicker)
            addon.EndeavorsData:RecheckNeighborhoodZone()
            if not addon.EndeavorsData:IsInNeighborhood() then
                EP:TryHide()
            end
        end)
    end
end)

addon:RegisterInternalEvent("ENDEAVORS_HOUSE_LEVEL_UPDATED", function()
    if EP:ShouldShow() then
        EP:TryShow()
    elseif frame and frame:IsShown() then
        -- Panel already visible — just refresh, don't hide on transient async data gaps
        EP:Refresh()
    end
end)

addon:RegisterInternalEvent("ENDEAVORS_INITIATIVE_UPDATED", function(hasChanges)
    if hasChanges then tasksCollapsed = false end

    if EP:ShouldShow() and (not frame or not frame:IsShown()) then
        EP:TryShow()
    elseif frame and frame:IsShown() then
        EP:Refresh()
        if hasChanges then
            OnTaskProgressActivity()
        end
    end
end)

addon:RegisterInternalEvent("ENDEAVORS_TASK_COMPLETED", function()
    tasksCollapsed = false
    if EP:ShouldShow() and (not frame or not frame:IsShown()) then
        EP:TryShow()
    elseif frame and frame:IsShown() then
        EP:Refresh()
        OnTaskProgressActivity()
    end
end)

--------------------------------------------------------------------------------
-- Settings Panel Integration: Open config from main settings
--------------------------------------------------------------------------------

function EP:OpenConfigFromSettings(anchorFrame)
    self:ToggleConfig(anchorFrame)
end
