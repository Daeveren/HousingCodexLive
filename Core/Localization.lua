--[[
    Housing Codex - Localization.lua
    Locale detection and string table management
]]

local ADDON_NAME, addon = ...

local locale = GetLocale()

function addon:GetLocaleString(key)
    return self.L[key] or key
end

function addon:FormatLocaleString(key, ...)
    local str = self.L[key]
    return str and string.format(str, ...) or key
end

function addon:IsDefaultLocale()
    return locale == "enUS" or locale == "enGB"
end

function addon:GetCurrentLocale()
    return locale
end
