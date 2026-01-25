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

function addon:ApplyFontSettings()
    local useCustom = self:UseCustomFont()
    local count = 0

    for id, entry in pairs(self.fontStringRegistry) do
        local fs = entry.fontString
        if fs and fs:IsObjectType("FontString") then
            local fontObj = useCustom and self.customFonts[entry.templateName]
                or _G[entry.templateName] or GameFontNormal
            fs:SetFontObject(fontObj)
            count = count + 1
        else
            self.fontStringRegistry[id] = nil
        end
    end

    self:Debug("Applied font settings to " .. count .. " FontStrings")
end

function addon:ToggleCustomFont()
    if not self.db then return false end

    self.db.settings.useCustomFont = not self.db.settings.useCustomFont
    self:ApplyFontSettings()
    return self.db.settings.useCustomFont
end

function addon:InitializeFonts()
    CreateCustomFontObjects()
end

addon:RegisterInternalEvent("DATA_LOADED", function()
    addon:ApplyFontSettings()
end)

CreateCustomFontObjects()
