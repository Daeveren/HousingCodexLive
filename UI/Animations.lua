--[[
    Housing Codex - Animations.lua
    Shared UI animation helpers: tile icon hover zoom, wishlist star twinkle,
    selection-bar stretch & settle, and the idle gold title shimmer.
    All effects run exclusively on addon-owned frames/textures.
]]

local _, addon = ...

local COLORS = addon.CONSTANTS.COLORS

--------------------------------------------------------------------------------
-- Shared helpers
--------------------------------------------------------------------------------

local function EaseOutQuad(t)
    return 1 - (1 - t) * (1 - t)
end

local function EaseOutCubic(t)
    local u = 1 - t
    return 1 - u * u * u
end

local function IsUsableNumber(value)
    return type(value) == "number" and not (issecretvalue and issecretvalue(value))
end

-- Shared guard for frame dimension reads (secret-value safe)
function addon:IsUsableUINumber(value)
    return IsUsableNumber(value)
end

--------------------------------------------------------------------------------
-- Tile Icon Hover Zoom ("Gentle Zoom")
-- Grows the 2D icon toward 1.08x around its center by shrinking the anchor
-- insets; the tile frame itself stays put. ModelScene tiles are skipped —
-- live-resizing a ModelScene has no safe Blizzard precedent.
--------------------------------------------------------------------------------

local ZOOM_SCALE = 1.10
local ZOOM_HALF_GROW = (ZOOM_SCALE - 1) / 2  -- growth per side, fraction of icon size
local ZOOM_MAX_GROW_PX = 6                   -- cap = icon side inset, so the icon never crosses the tile border
local ZOOM_IN_DURATION = 0.20
local ZOOM_OUT_DURATION = 0.15

-- Both SetPoint calls must run unconditionally in the same tick: the icon is a
-- two-anchor region and a half-updated pair leaves it distorted for a frame
local function ApplyTileIconZoom(tile, progress)
    local icon = tile.icon
    if not icon then return end

    local insets = addon.CONSTANTS.TILE_ICON_INSETS
    local w, h = tile:GetWidth(), tile:GetHeight()
    if not IsUsableNumber(w) or not IsUsableNumber(h) or w <= 0 or h <= 0 then return end

    local eased = EaseOutCubic(progress)
    local gx = math.min((w - insets.LEFT - insets.RIGHT) * ZOOM_HALF_GROW, ZOOM_MAX_GROW_PX) * eased
    local gy = math.min((h - insets.TOP - insets.BOTTOM) * ZOOM_HALF_GROW, ZOOM_MAX_GROW_PX) * eased

    icon:SetPoint("TOPLEFT", insets.LEFT - gx, -(insets.TOP - gy))
    icon:SetPoint("BOTTOMRIGHT", -(insets.RIGHT - gx), insets.BOTTOM - gy)
end

local function TileZoomOnUpdate(tile, dt)
    local target = tile.zoomTarget or 0
    local duration = target > 0 and ZOOM_IN_DURATION or ZOOM_OUT_DURATION
    local progress = tile.zoomProgress or 0

    if target > 0 then
        progress = math.min(1, progress + dt / duration)
    else
        progress = math.max(0, progress - dt / duration)
    end
    tile.zoomProgress = progress

    ApplyTileIconZoom(tile, progress)

    if progress == target then
        tile:SetScript("OnUpdate", nil)
    end
end

function addon:StartTileIconZoom(tile)
    if not tile.icon then return end
    -- Model-only tiles render via ModelScene; the 2D icon is hidden
    if tile.modelScene and tile.modelScene:IsShown() then return end

    tile.zoomTarget = 1
    tile:SetScript("OnUpdate", TileZoomOnUpdate)
end

function addon:StopTileIconZoom(tile)
    if not tile.zoomProgress or tile.zoomProgress == 0 then
        tile.zoomTarget = nil
        return
    end
    tile.zoomTarget = 0
    tile:SetScript("OnUpdate", TileZoomOnUpdate)
end

-- Hard reset for ScrollBox element resetters (recycled tiles must start clean)
function addon:ResetTileIconZoom(tile)
    tile:SetScript("OnUpdate", nil)
    tile.zoomTarget = nil
    if tile.zoomProgress and tile.zoomProgress > 0 then
        tile.zoomProgress = 0
        ApplyTileIconZoom(tile, 0)
    end
end

--------------------------------------------------------------------------------
-- Wishlist Star Twinkle
-- Star and spark effects are driven manually with OnUpdate so they do not rely
-- on restricted SimpleAnimGroup creation APIs.
--------------------------------------------------------------------------------

local SPARK_TEXTURE = "Interface\\Cooldown\\star4"
local SPARK_COLOR = { 1, 0.9, 0.4 }
local SPARK_DURATION = 0.45
local SPARK_OFFSETS = {
    { -1.1, 0.8 },
    { 1.2, 0.6 },
    { -0.8, -1.0 },
    { 0.9, -0.9 },
}

local function GetStarSize(star)
    local width, height = star:GetSize()
    width = IsUsableNumber(width) and width > 0 and width or 20
    height = IsUsableNumber(height) and height > 0 and height or width
    return width, height
end

local function CreateSpark(host, starSize, dx, dy)
    local tex = host:CreateTexture(nil, "OVERLAY", nil, 7)
    tex:SetTexture(SPARK_TEXTURE)
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(SPARK_COLOR[1], SPARK_COLOR[2], SPARK_COLOR[3])
    tex:SetSize(starSize * 0.55, starSize * 0.55)
    tex:SetAlpha(0)
    tex:Hide()
    return { tex = tex, dx = dx, dy = dy }
end

local function ResetStarTwinkleState(twinkle)
    if not twinkle then return end

    if twinkle.star then
        twinkle.star:SetAlpha(twinkle.baseAlpha or 1)
    end

    for _, spark in ipairs(twinkle.sparks or {}) do
        spark.tex:ClearAllPoints()
        if twinkle.star then
            spark.tex:SetPoint("CENTER", twinkle.star, "CENTER", 0, 0)
        end
        spark.tex:SetAlpha(0)
        spark.tex:Hide()
    end
end

local function StarTwinkleOnUpdate(driver, dt)
    local twinkle = driver.twinkle
    if not twinkle or not twinkle.star then
        driver:SetScript("OnUpdate", nil)
        return
    end

    twinkle.elapsed = (twinkle.elapsed or 0) + dt
    local progress = math.min(twinkle.elapsed / SPARK_DURATION, 1)
    local popProgress = progress < 0.35 and progress / 0.35 or 1 - ((progress - 0.35) / 0.65)
    popProgress = math.max(0, math.min(popProgress, 1))
    twinkle.star:SetAlpha(0.85 + 0.15 * EaseOutQuad(popProgress))

    local eased = EaseOutCubic(progress)
    for _, spark in ipairs(twinkle.sparks) do
        spark.tex:ClearAllPoints()
        spark.tex:SetPoint("CENTER", twinkle.star, "CENTER", spark.dx * twinkle.starSize * eased, spark.dy * twinkle.starSize * eased)
        spark.tex:SetAlpha(math.max(0, 1 - progress))
        spark.tex:Show()
    end

    if progress >= 1 then
        driver:SetScript("OnUpdate", nil)
        ResetStarTwinkleState(twinkle)
    end
end

-- @param star: the star texture to pop (must be a region of host or a child's)
-- @param host: frame that owns the effect (sparks are created on it once)
function addon:PlayStarTwinkle(star, host)
    if not star or not host then return end

    local twinkle = host.hcStarTwinkle
    if not twinkle or twinkle.star ~= star then
        self:StopStarTwinkle(host)
        local baseWidth, baseHeight = GetStarSize(star)
        twinkle = {
            star = star,
            baseWidth = baseWidth,
            baseHeight = baseHeight,
            baseAlpha = star:GetAlpha() or 1,
            starSize = math.max(baseWidth, baseHeight),
            sparks = {},
            driver = CreateFrame("Frame", nil, host),
        }
        twinkle.driver.twinkle = twinkle
        for i, offset in ipairs(SPARK_OFFSETS) do
            twinkle.sparks[i] = CreateSpark(host, twinkle.starSize, offset[1], offset[2])
        end
        host.hcStarTwinkle = twinkle
    else
        twinkle.baseWidth, twinkle.baseHeight = GetStarSize(star)
        twinkle.baseAlpha = twinkle.baseAlpha or star:GetAlpha() or 1
        twinkle.starSize = math.max(twinkle.baseWidth, twinkle.baseHeight)
    end

    twinkle.elapsed = 0
    ResetStarTwinkleState(twinkle)
    twinkle.driver:SetScript("OnUpdate", StarTwinkleOnUpdate)
end

-- Cleanup for ScrollBox element resetters (recycled tiles must not keep playing)
function addon:StopStarTwinkle(host)
    local twinkle = host and host.hcStarTwinkle
    if not twinkle then return end

    if twinkle.driver then
        twinkle.driver:SetScript("OnUpdate", nil)
    end
    ResetStarTwinkleState(twinkle)
end
--------------------------------------------------------------------------------
-- Selection Bar Stretch & Settle (vertical)
-- Animates a gold bar between two row positions in a left-column panel:
-- phase 1 stretches the bar to span both rows, phase 2 contracts it onto the
-- target row. Coordinates are y-offsets measured downward from anchorParent's
-- top edge; anchorParent is the rows' shared parent (scroll target or list
-- container) so the bar moves with scrolled content.
--------------------------------------------------------------------------------

local SELBAR_WIDTH = 3
local SELBAR_STRETCH_DURATION = 0.13
local SELBAR_SETTLE_DURATION = 0.16

local function GetSelectionBar(anchorParent)
    local bar = anchorParent.hcSelectionBar
    if bar then return bar end

    -- Own frame so the bar renders above sibling row frames
    local overlay = CreateFrame("Frame", nil, anchorParent)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(anchorParent:GetFrameLevel() + 10)

    local tex = overlay:CreateTexture(nil, "ARTWORK")
    tex:SetWidth(SELBAR_WIDTH)
    tex:SetColorTexture(unpack(COLORS.GOLD))
    tex:Hide()

    bar = { overlay = overlay, tex = tex }
    anchorParent.hcSelectionBar = bar
    return bar
end

local function ApplySelectionBarRect(bar, xOffset, top, height)
    bar.curTop, bar.curHeight = top, height
    bar.tex:SetPoint("TOPLEFT", bar.overlay, "TOPLEFT", xOffset, -top)
    bar.tex:SetHeight(math.max(height, 1))
end

-- @param onFinish: called once the bar lands (also when a newer animation
--   replaces this one — the callback must re-derive current selection state)
function addon:PlaySelectionBarStretch(anchorParent, xOffset, fromTop, fromHeight, toTop, toHeight, onFinish)
    local bar = GetSelectionBar(anchorParent)

    -- Restart from the currently displayed rect if an animation is in flight.
    -- The pending onFinish is dropped, not fired: the caller has already
    -- re-applied static selection state, and this animation's own onFinish
    -- will do the final border reveal.
    if bar.animating and bar.curTop then
        bar.onFinish = nil
        fromTop, fromHeight = bar.curTop, bar.curHeight
    end

    local spanTop = math.min(fromTop, toTop)
    local spanHeight = math.max(fromTop + fromHeight, toTop + toHeight) - spanTop

    bar.onFinish = onFinish
    bar.animating = true
    ApplySelectionBarRect(bar, xOffset, fromTop, fromHeight)
    bar.tex:Show()

    local elapsed = 0
    bar.overlay:SetScript("OnUpdate", function(overlay, dt)
        elapsed = elapsed + dt

        if elapsed < SELBAR_STRETCH_DURATION then
            local e = EaseOutQuad(elapsed / SELBAR_STRETCH_DURATION)
            ApplySelectionBarRect(bar, xOffset,
                fromTop + (spanTop - fromTop) * e,
                fromHeight + (spanHeight - fromHeight) * e)
        else
            local t = math.min((elapsed - SELBAR_STRETCH_DURATION) / SELBAR_SETTLE_DURATION, 1)
            local e = EaseOutQuad(t)
            ApplySelectionBarRect(bar, xOffset,
                spanTop + (toTop - spanTop) * e,
                spanHeight + (toHeight - spanHeight) * e)

            if t >= 1 then
                overlay:SetScript("OnUpdate", nil)
                bar.animating = false
                bar.tex:Hide()
                local finish = bar.onFinish
                bar.onFinish = nil
                if finish then finish() end
            end
        end
    end)
end

-- Cancel without landing (e.g., the panel's list was rebuilt mid-animation)
function addon:CancelSelectionBarStretch(anchorParent)
    local bar = anchorParent and anchorParent.hcSelectionBar
    if not bar or not bar.animating then return end

    bar.overlay:SetScript("OnUpdate", nil)
    bar.animating = false
    bar.tex:Hide()
    local finish = bar.onFinish
    bar.onFinish = nil
    if finish then finish() end
end

--------------------------------------------------------------------------------
-- Idle Gold Shimmer
-- Every 3 seconds while the owning frame is shown, a soft highlight band
-- sweeps across the FontString letter by letter via per-character color
-- escape codes, alternating direction each sweep (left-to-right first).
-- Base color and font are untouched; the plain text is restored after every
-- sweep (escape codes do not affect GetStringWidth).
--------------------------------------------------------------------------------

local SHIMMER_INTERVAL = 3       -- seconds between sweeps (first sweep = 3s after show)
local SHIMMER_DURATION = 1.4     -- seconds per sweep
local SHIMMER_BAND_WIDTH = 0.35  -- highlight band half-width, fraction of text length
local SHIMMER_TICK = 0.03        -- rebuild throttle (~33fps)
local SHIMMER_HIGHLIGHT = { 1, 0.98, 0.8 }

-- UTF-8 safe character splitter (pure Lua 5.1, no client helpers required)
local function SplitIntoChars(text)
    local chars = {}
    local i = 1
    local len = #text
    while i <= len do
        local b = text:byte(i)
        local size = (b >= 240 and 4) or (b >= 224 and 3) or (b >= 192 and 2) or 1
        chars[#chars + 1] = text:sub(i, i + size - 1)
        i = i + size
    end
    return chars
end

local function BuildShimmerText(state, sweepProgress)
    local base = state.baseColor
    local n = #state.chars
    -- Band center travels from just left of the text to just right of it
    local center = -SHIMMER_BAND_WIDTH + sweepProgress * (1 + 2 * SHIMMER_BAND_WIDTH)

    local parts = state.parts
    for i = 1, n do
        local pos = (i - 0.5) / n
        local intensity = 1 - math.abs(pos - center) / SHIMMER_BAND_WIDTH
        if intensity < 0 then intensity = 0 end
        intensity = intensity ^ 1.5  -- softer falloff = slightly wider, brighter band

        local r = base[1] + (SHIMMER_HIGHLIGHT[1] - base[1]) * intensity
        local g = base[2] + (SHIMMER_HIGHLIGHT[2] - base[2]) * intensity
        local b = base[3] + (SHIMMER_HIGHLIGHT[3] - base[3]) * intensity
        parts[i] = string.format("|cFF%02x%02x%02x%s",
            math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), state.chars[i])
    end
    parts[n + 1] = "|r"

    return table.concat(parts, "", 1, n + 1)
end

-- Attaches an idle shimmer to a FontString. visibilityFrame drives the
-- lifecycle: the sweep ticker starts on show and stops (with the plain text
-- restored) on hide.
-- @param baseColor: {r, g, b} the FontString's resting text color
function addon:AttachGoldShimmer(fontString, visibilityFrame, baseColor)
    if fontString.hcShimmer then return end

    local state = {
        text = fontString:GetText() or "",
        baseColor = baseColor,
        parts = {},
    }
    state.chars = SplitIntoChars(state.text)
    fontString.hcShimmer = state

    if #state.chars == 0 then return end

    local driver = CreateFrame("Frame", nil, visibilityFrame)
    local sweepElapsed, tickAccum = 0, 0

    local function StopSweep()
        driver:SetScript("OnUpdate", nil)
        fontString:SetText(state.text)
    end

    local function SweepOnUpdate(_, dt)
        sweepElapsed = sweepElapsed + dt
        if sweepElapsed >= SHIMMER_DURATION then
            StopSweep()
            return
        end
        tickAccum = tickAccum + dt
        if tickAccum < SHIMMER_TICK then return end
        tickAccum = 0
        local progress = sweepElapsed / SHIMMER_DURATION
        if state.reverse then
            progress = 1 - progress
        end
        fontString:SetText(BuildShimmerText(state, progress))
    end

    local function StartSweep()
        state.reverse = not state.reverse  -- alternate direction each sweep
        sweepElapsed, tickAccum = 0, 0
        driver:SetScript("OnUpdate", SweepOnUpdate)
    end

    visibilityFrame:HookScript("OnShow", function()
        state.reverse = true  -- flipped by StartSweep: first sweep runs left-to-right
        if state.ticker then state.ticker:Cancel() end
        state.ticker = C_Timer.NewTicker(SHIMMER_INTERVAL, StartSweep)
    end)

    visibilityFrame:HookScript("OnHide", function()
        if state.ticker then
            state.ticker:Cancel()
            state.ticker = nil
        end
        StopSweep()
    end)
end
