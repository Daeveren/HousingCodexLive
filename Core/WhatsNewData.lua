--[[
    Housing Codex - WhatsNewData.lua
    Feature highlight data for What's New and Welcome popups
]]

local _, addon = ...

-- Version-specific feature highlights (newest first)
addon.WhatsNewVersions = {
    {
        version = "1.5.0",
        features = {
            {
                titleKey = "WHATSNEW_V150_F1_TITLE",
                descKey = "WHATSNEW_V150_F1_DESC",
                image = "Interface\\AddOns\\HousingCodex\\Textures\\whatsnew_progress",
            },
            {
                titleKey = "WHATSNEW_V150_F2_TITLE",
                descKey = "WHATSNEW_V150_F2_DESC",
                image = "Interface\\AddOns\\HousingCodex\\Textures\\whatsnew_progress",
            },
            {
                titleKey = "WHATSNEW_V150_F3_TITLE",
                descKey = "WHATSNEW_V150_F3_DESC",
                image = "Interface\\AddOns\\HousingCodex\\Textures\\whatsnew_progress",
            },
            {
                titleKey = "WHATSNEW_V150_F4_TITLE",
                descKey = "WHATSNEW_V150_F4_DESC",
                image = "Interface\\AddOns\\HousingCodex\\Textures\\whatsnew_progress",
            },
        },
    },
}

-- Welcome screen feature highlights (shown to new users)
addon.WelcomeFeatures = {
    {
        titleKey = "WELCOME_F1_TITLE",
        descKey = "WELCOME_F1_DESC",
    },
    {
        titleKey = "WELCOME_F2_TITLE",
        descKey = "WELCOME_F2_DESC",
    },
    {
        titleKey = "WELCOME_F3_TITLE",
        descKey = "WELCOME_F3_DESC",
    },
    {
        titleKey = "WELCOME_F4_TITLE",
        descKey = "WELCOME_F4_DESC",
    },
    {
        titleKey = "WELCOME_F5_TITLE",
        descKey = "WELCOME_F5_DESC",
    },
    {
        titleKey = "WELCOME_F6_TITLE",
        descKey = "WELCOME_F6_DESC",
    },
}
