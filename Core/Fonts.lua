--[[
    Housing Codex - Fonts.lua
    Custom font system (Roboto Condensed) matching DaevTools pattern
]]

local ADDON_NAME, addon = ...

local CUSTOM_FONT_PATH = "Interface\\AddOns\\HousingCodex\\Fonts\\Roboto_Condensed_semibold.ttf"

local FONT_TEMPLATES = {
    "GameFontNormalSmall",
    "GameFontHighlightSmall",
    "GameFontNormal",
    "GameFontHighlight",
    "GameFontNormalLarge",
    "GameFontHighlightLarge",
    "GameFontNormalHuge",
    "GameFontNormalHuge2",
    "GameFontNormalHuge3",
    "NumberFontNormal",
}

addon.customFonts = {}
addon.fontStringRegistry = {}
local registryCounter = 0

local function CreateCustomFontObjects()
    for _, templateName in ipairs(FONT_TEMPLATES) do
        local fontObjName = "HousingCodex_" .. templateName
        local fontObj = CreateFont(fontObjName)
        local baseFont = _G[templateName]

        if baseFont then
            fontObj:CopyFontObject(baseFont)
            local _, size, flags = baseFont:GetFont()
            fontObj:SetFont(CUSTOM_FONT_PATH, size, flags or "")
        else
            -- Fallback if template doesn't exist
            fontObj:SetFont(CUSTOM_FONT_PATH, 12, "")
        end

        addon.customFonts[templateName] = fontObj
    end

    addon:Debug("Created " .. #FONT_TEMPLATES .. " custom font objects")
end

function addon:UseCustomFont()
    return self.db and self.db.settings and self.db.settings.useCustomFont
end

function addon:GetFontPath()
    return self:UseCustomFont() and CUSTOM_FONT_PATH or STANDARD_TEXT_FONT
end

function addon:GetFontObject(templateName)
    if self:UseCustomFont() and self.customFonts[templateName] then
        return self.customFonts[templateName]
    end
    return _G[templateName] or GameFontNormal
end

function addon:CreateFontString(parent, layer, templateName)
    templateName = templateName or "GameFontNormal"
    local fontString = parent:CreateFontString(nil, layer or "OVERLAY")
    fontString:SetFontObject(self:GetFontObject(templateName))

    registryCounter = registryCounter + 1
    fontString.hcFontRegistryID = registryCounter
    self.fontStringRegistry[registryCounter] = {
        fontString = fontString,
        templateName = templateName,
    }

    return fontString
end

function addon:UnregisterFontString(fontString)
    if fontString and fontString.hcFontRegistryID then
        self.fontStringRegistry[fontString.hcFontRegistryID] = nil
        fontString.hcFontRegistryID = nil
    end
end

-- Sets font with custom size, storing info for re-application when font settings change
function addon:SetFontSize(fontString, size, flags)
    flags = flags or ""
    fontString:SetFont(self:GetFontPath(), size, flags)

    -- Store size info for re-application when settings change
    local entry = fontString.hcFontRegistryID and self.fontStringRegistry[fontString.hcFontRegistryID]
    if entry then
        entry.customSize = size
        entry.customFlags = flags
    end
end

function addon:ApplyFontSettings()
    local fontPath = self:GetFontPath()
    local useCustom = self:UseCustomFont()
    local count = 0

    for id, entry in pairs(self.fontStringRegistry) do
        local fs = entry.fontString
        if fs and fs:IsObjectType("FontString") then
            if entry.customSize then
                fs:SetFont(fontPath, entry.customSize, entry.customFlags or "")
            elseif useCustom and self.customFonts[entry.templateName] then
                fs:SetFontObject(self.customFonts[entry.templateName])
            else
                fs:SetFontObject(_G[entry.templateName] or GameFontNormal)
            end
            count = count + 1
        else
            self.fontStringRegistry[id] = nil
        end
    end

    self:Debug("Applied font settings to " .. count .. " FontStrings")
end

addon:RegisterInternalEvent("DATA_LOADED", function()
    addon:ApplyFontSettings()
end)

CreateCustomFontObjects()
