--[[
    Housing Codex - TabBase.lua
    Shared mixin for hierarchy tabs (QuestsTab, AchievementsTab)
    Provides common toolbar, filter state, and visual helpers
]]

local ADDON_NAME, addon = ...

addon.TabBaseMixin = {}
local TabBaseMixin = addon.TabBaseMixin

local CONSTS = addon.CONSTANTS
local COLORS = CONSTS.COLORS

--------------------------------------------------------------------------------
-- Wishlist Star Helper
--------------------------------------------------------------------------------

-- Update wishlist star visibility and position (shared across hierarchy tabs)
-- @param frame: Row frame with .wishlistStar and .label elements
-- @param isWishlisted: boolean
function TabBaseMixin:UpdateWishlistStar(frame, isWishlisted)
    if not frame or not frame.wishlistStar or not frame.label then return end
    frame.wishlistStar:SetShown(isWishlisted)
    if isWishlisted then
        frame.wishlistStar:ClearAllPoints()
        frame.wishlistStar:SetPoint("LEFT", frame.label, "LEFT", frame.label:GetStringWidth() + 4, 0)
    end
end

--------------------------------------------------------------------------------
-- Progress Color Helper
--------------------------------------------------------------------------------

-- Get progress text color based on percentage
-- @param percent: 0-100 percentage value
-- @param useAltDim: If true, use dimmer gray for low values (zones vs expansions)
-- @return color table {r, g, b, a}
function TabBaseMixin:GetProgressColor(percent, useAltDim)
    if percent == 100 then
        return COLORS.PROGRESS_COMPLETE        -- Green
    elseif percent >= 91 then
        return COLORS.PROGRESS_NEAR_COMPLETE   -- Yellow-green
    elseif percent >= 66 then
        return COLORS.GOLD                     -- Gold/yellow
    elseif percent >= 34 then
        return COLORS.PROGRESS_MID             -- Muted tan
    else
        return useAltDim and COLORS.PROGRESS_LOW_DIM or COLORS.TEXT_TERTIARY  -- Gray
    end
end

--------------------------------------------------------------------------------
-- Responsive Toolbar Layout
--------------------------------------------------------------------------------

-- Update toolbar element visibility based on available width
-- Delegates to shared addon helper, stores layout state on tab
function TabBaseMixin:UpdateToolbarLayout(toolbarWidth)
    local newLayout = addon:UpdateSimpleToolbarLayout(
        self.toolbarLayout, toolbarWidth, self.searchBox, self.filterContainer
    )
    if newLayout then
        self.toolbarLayout = newLayout
        addon:Debug((self.tabName or "Tab") .. " toolbar layout: " .. newLayout .. " (width: " .. math.floor(toolbarWidth) .. ")")
    end
end

--------------------------------------------------------------------------------
-- Ownership Refresh Helper
--------------------------------------------------------------------------------

-- Register debounced RECORD_OWNERSHIP_UPDATED handler for a tab
-- @param refreshFn: function to call when ownership changes affect this tab
function TabBaseMixin:RegisterOwnershipRefresh(refreshFn)
    local ownershipRefreshTimer = nil

    addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", function(recordID, collectionStateChanged, updateKind)
        if collectionStateChanged == false then return end
        if not self:IsShown() then return end

        if updateKind == "targeted" then
            if ownershipRefreshTimer then ownershipRefreshTimer:Cancel() end
            ownershipRefreshTimer = C_Timer.NewTimer(CONSTS.TIMER.OWNERSHIP_REFRESH_DEBOUNCE, function()
                ownershipRefreshTimer = nil
                if self:IsShown() then
                    refreshFn()
                end
            end)
        else
            if ownershipRefreshTimer then
                ownershipRefreshTimer:Cancel()
                ownershipRefreshTimer = nil
            end
            refreshFn()
        end
    end)
end
