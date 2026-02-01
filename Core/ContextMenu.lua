--[[
    Housing Codex - ContextMenu.lua
    Centralized right-click context menu for all item lists
    Uses modern MenuUtil.CreateContextMenu API (WoW 12.0+)
]]

local ADDON_NAME, addon = ...
local L = addon.L

addon.ContextMenu = {}

local MENU_TAG = "HOUSING_CODEX_CONTEXT_MENU"

--------------------------------------------------------------------------------
-- Shared Helpers
--------------------------------------------------------------------------------

-- Add decor-specific menu options (wishlist, tracking, link to chat)
local function AddDecorOptions(rootDescription, record, recordID)
    if not record then return end

    -- Wishlist toggle
    local isWishlisted = addon:IsWishlisted(recordID)
    local wishlistText = isWishlisted and L["WISHLIST_REMOVE"] or L["WISHLIST_ADD"]
    rootDescription:CreateButton(wishlistText, function()
        addon:ToggleWishlist(recordID)
    end)

    -- Track toggle (only if trackable)
    if record.isTrackable then
        local isTracked = addon:IsRecordTracked(recordID)
        local trackText = isTracked and L["ACTION_UNTRACK"] or L["ACTION_TRACK"]
        rootDescription:CreateButton(trackText, function()
            addon:ToggleTracking(recordID)
        end)
    end

    -- Link to chat
    rootDescription:CreateButton(L["CONTEXT_MENU_LINK_TO_CHAT"], function()
        local linkText = string.format("|cFFFFD100[%s]|r", record.name)
        ChatFrameUtil.OpenChat(linkText)
    end)
end

-- Add Wowhead link option
local function AddWowheadOption(rootDescription, owner, url)
    rootDescription:CreateButton(L["CONTEXT_MENU_COPY_WOWHEAD"], function()
        addon:ShowURLPopup(url, owner)
    end)
end

--------------------------------------------------------------------------------
-- Decor Items (Grid, WishlistFrame)
--------------------------------------------------------------------------------

function addon.ContextMenu:ShowForDecor(owner, recordID)
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:SetTag(MENU_TAG)

        local record = addon:GetRecord(recordID)
        if not record then return end

        AddDecorOptions(rootDescription, record, recordID)
        AddWowheadOption(rootDescription, owner, addon:CreateWowheadURL(record))
    end)
end

--------------------------------------------------------------------------------
-- Quest Items (QuestsTab)
--------------------------------------------------------------------------------

function addon.ContextMenu:ShowForQuest(owner, questID, recordID)
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:SetTag(MENU_TAG)

        local record = recordID and addon:GetRecord(recordID)
        AddDecorOptions(rootDescription, record, recordID)

        -- Quest Wowhead link (always available if numeric questID)
        if type(questID) == "number" then
            AddWowheadOption(rootDescription, owner, "https://www.wowhead.com/quest=" .. questID)
        end
    end)
end

--------------------------------------------------------------------------------
-- Achievement Items (AchievementsTab)
--------------------------------------------------------------------------------

function addon.ContextMenu:ShowForAchievement(owner, achievementID, recordID)
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:SetTag(MENU_TAG)

        local record = recordID and addon:GetRecord(recordID)
        AddDecorOptions(rootDescription, record, recordID)

        -- Achievement Wowhead link (always available)
        AddWowheadOption(rootDescription, owner, "https://www.wowhead.com/achievement=" .. achievementID)
    end)
end
