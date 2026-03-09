--[[
    Housing Codex - Localization.lua
    Locale detection and string table management
]]

local _, addon = ...

-- Safety net: missing L["KEY"] returns the key name itself (debug aid)
setmetatable(addon.L, { __index = function(_, key) return key end })

-- Game entity name overrides for non-English clients (drop sources, vendor names, etc.)
-- Populated by locale files (e.g., frFR.lua). English fallback is the original name.
addon.sourceNameLocale = {}

function addon:GetLocalizedSourceName(name)
    if not name then return name end
    return self.sourceNameLocale[name] or name
end
