-- SlamFrames 3.1.0 - Raid frames, compact layouts, opacity, click casting, and healing support.
-- Conservative Vanilla/OctoWoW module: lazy frame creation avoids touching
-- the 40-player raid grid during addon startup.

SlamFrames = SlamFrames or {}

local SF = SlamFrames
local C = SlamFrames_Config

local TEST_NAMES = {
    "Aegis", "Moonleaf", "Ashen", "Stormcall", "Cinder",
    "Thargrim", "Lunareth", "Bromric", "Vaelys", "Grukzul"
}

local TEST_CLASS_TOKENS = {
    "WARRIOR", "PRIEST", "MAGE", "ROGUE", "DRUID",
    "PALADIN", "HUNTER", "WARLOCK", "SHAMAN", "WARRIOR"
}

-- 1.12-safe class colors. Prefer the client's RAID_CLASS_COLORS table when it
-- exists, but keep a local fallback so OctoWoW test frames can still preview
-- class-colored names without depending on a modern API.
local RAID_CLASS_COLOR_FALLBACK = {
    WARRIOR = { 0.78, 0.61, 0.43 },
    PALADIN = { 0.96, 0.55, 0.73 },
    HUNTER = { 0.67, 0.83, 0.45 },
    ROGUE = { 1.00, 0.96, 0.41 },
    PRIEST = { 1.00, 1.00, 1.00 },
    SHAMAN = { 0.00, 0.44, 0.87 },
    MAGE = { 0.41, 0.80, 0.94 },
    WARLOCK = { 0.58, 0.51, 0.79 },
    DRUID = { 1.00, 0.49, 0.04 }
}

local function GetRaidClassColor(classToken)
    if not classToken then
        return 1.0, 0.82, 0.0
    end

    local c = nil
    if RAID_CLASS_COLORS then
        c = RAID_CLASS_COLORS[classToken]
    end
    if c then
        return c.r or c[1] or 1, c.g or c[2] or 1, c.b or c[3] or 1
    end

    c = RAID_CLASS_COLOR_FALLBACK[classToken]
    if c then
        return c[1], c[2], c[3]
    end

    return 1.0, 0.82, 0.0
end

local function GetRaidClassToken(index, unit)
    if SF.testMode then
        return TEST_CLASS_TOKENS[math.mod((tonumber(index) or 1) - 1, table.getn(TEST_CLASS_TOKENS)) + 1]
    end

    if type(GetRaidRosterInfo) == "function" then
        local ok, name, rank, subgroup, level, className, classToken = pcall(GetRaidRosterInfo, index)
        if ok and classToken then
            return classToken
        end
    end

    if unit and UnitExists(unit) and type(UnitClass) == "function" then
        local className, classToken = UnitClass(unit)
        if classToken then
            return classToken
        end
    end

    return nil
end

local function ApplyRaidNameColor(frame, index, unit)
    if not frame or not frame.name then
        return
    end

    if not SlamFramesDB or not SlamFramesDB.raidClassColoredNames then
        frame.name:SetTextColor(1.0, 0.82, 0.0)
        return
    end

    local r, g, b = GetRaidClassColor(GetRaidClassToken(index, unit))
    frame.name:SetTextColor(r, g, b)
end

local function IsRaidMainTank(index)
    if SF.testMode then
        if SlamFramesDB and SlamFramesDB.raidPreviewMainTanks then
            return index == 1 or index == 6
        end
        return false
    end

    if type(GetRaidRosterInfo) ~= "function" then
        return false
    end

    local ok, name, rank, subgroup, level, className, classToken, zone, online, isDead, role = pcall(GetRaidRosterInfo, index)
    if not ok or not role then
        return false
    end

    return string.lower(tostring(role)) == "maintank"
end

local function ClampRaid(value, low, high)
    if value < low then
        return low
    end
    if value > high then
        return high
    end
    return value
end

local function GetRaidOpacity()
    if not SlamFramesDB then
        return 1.00
    end
    return ClampRaid(tonumber(SlamFramesDB.raidOpacity) or 1.00, 0.20, 1.00)
end

local function ApplyRaidOpacity()
    local alpha = GetRaidOpacity()
    local index

    if SF.raidFrames then
        for index = 1, table.getn(SF.raidFrames) do
            if SF.raidFrames[index] then
                SF.raidFrames[index]:SetAlpha(alpha)
            end
        end
    end

    if SF.raidHeaders then
        for index = 1, 8 do
            if SF.raidHeaders[index] then
                SF.raidHeaders[index]:SetAlpha(alpha)
            end
        end
    end
end

local function GetRaidCount()
    if SF.testMode then
        return tonumber(SlamFramesDB.raidPreviewSize) or 20
    end

    if type(GetNumRaidMembers) == "function" then
        local ok, count = pcall(GetNumRaidMembers)
        if ok and count then
            return tonumber(count) or 0
        end
    end

    return 0
end

local function ApplyRaidRootAnchor(frame)
    local anchor = nil

    if SlamFramesDB.anchors then
        anchor = SlamFramesDB.anchors.raid
    end

    if not anchor then
        anchor = {
            point = "TOPLEFT",
            relativePoint = "TOPLEFT",
            x = 28,
            y = -210
        }
    end

    frame:ClearAllPoints()
    frame:SetPoint(
        anchor.point or "TOPLEFT",
        UIParent,
        anchor.relativePoint or "TOPLEFT",
        anchor.x or 28,
        anchor.y or -210
    )
end

local function SaveRaidRootAnchor(frame)
    local point, relative, relativePoint, x, y = frame:GetPoint(1)

    if not point then
        return
    end

    if not SlamFramesDB.anchors then
        SlamFramesDB.anchors = {}
    end

    SlamFramesDB.anchors.raid = {
        point = point,
        relativePoint = relativePoint or point,
        x = x or 0,
        y = y or 0
    }
end

local function EnsureRaidHeader(groupIndex)
    if not SF.raidHeaders then
        SF.raidHeaders = {}
    end

    if SF.raidHeaders[groupIndex] then
        return SF.raidHeaders[groupIndex]
    end

    local header = CreateFrame("Frame", nil, UIParent)
    header:SetWidth(120)
    header:SetHeight(18)
    header:SetFrameStrata("MEDIUM")

    local text = header:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    text:SetTextColor(1, 0.82, 0)
    text:SetPoint("CENTER", header, "CENTER", 0, 0)
    text:SetText("Group " .. groupIndex)

    header.text = text
    SF.raidHeaders[groupIndex] = header

    return header
end

local function HideRaidHeaders()
    if not SF.raidHeaders then
        return
    end

    local groupIndex
    for groupIndex = 1, 8 do
        if SF.raidHeaders[groupIndex] then
            SF.raidHeaders[groupIndex]:Hide()
        end
    end
end

local function HideRaidFrames()
    if not SF.raidFrames then
        HideRaidHeaders()
        return
    end

    local index
    for index = 1, table.getn(SF.raidFrames) do
        if SF.raidFrames[index] then
            SF.raidFrames[index]:Hide()
        end
    end

    HideRaidHeaders()
end

-- Compact raid mode. This is intentionally a health-first layout rather
-- than simply shrinking the portrait frame.  The result keeps the SlamFrames
-- health fill, click target, names and health text while removing portrait,
-- level badge and the large decorative portrait endcap.
local COMPACT_BASE_WIDTH = 176
local COMPACT_BASE_HEIGHT = 34
local COMPACT_WIDTH_STEP = 10
local COMPACT_INSET = 2
local COMPACT_LIGHT_TOP = { 0.76, 0.60, 0.20 }
local COMPACT_LIGHT_BOTTOM = { 0.52, 0.40, 0.10 }
local COMPACT_DARK_TOP = { 0.38, 0.39, 0.42 }
local COMPACT_DARK_BOTTOM = { 0.16, 0.17, 0.19 }

local function ApplyCompactDecorSkin(decor)
    if not decor then
        return
    end

    local dark = not SlamFramesDB or SlamFramesDB.skin ~= "light"
    local topColor
    local bottomColor

    if dark then
        topColor = COMPACT_DARK_TOP
        bottomColor = COMPACT_DARK_BOTTOM
        decor.bg:SetVertexColor(0.018, 0.020, 0.024, 0.97)
    else
        topColor = COMPACT_LIGHT_TOP
        bottomColor = COMPACT_LIGHT_BOTTOM
        decor.bg:SetVertexColor(0.035, 0.035, 0.035, 0.94)
    end

    decor.top:SetVertexColor(topColor[1], topColor[2], topColor[3], 1)
    decor.left:SetVertexColor(topColor[1], topColor[2], topColor[3], 1)
    decor.bottom:SetVertexColor(bottomColor[1], bottomColor[2], bottomColor[3], 1)
    decor.right:SetVertexColor(bottomColor[1], bottomColor[2], bottomColor[3], 1)
end

local function CompactFontSize(base, scale, multiplier)
    local size = math.floor((base or 10) * (scale or 1) * (multiplier or 1) + 0.5)
    if size < 6 then
        size = 6
    end
    return size
end

local function EnsureCompactDecor(frame)
    if frame.raidCompactDecorFrame then
        return frame.raidCompactDecorFrame
    end

    local decor = CreateFrame("Frame", nil, frame)
    decor:SetAllPoints(frame)
    decor:SetFrameLevel(frame:GetFrameLevel() + 3)

    decor.bg = decor:CreateTexture(nil, "BACKGROUND")
    decor.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    decor.bg:SetAllPoints(decor)
    decor.bg:SetVertexColor(0.035, 0.035, 0.035, 0.94)

    decor.top = decor:CreateTexture(nil, "BORDER")
    decor.top:SetTexture("Interface\\Buttons\\WHITE8X8")
    decor.top:SetPoint("TOPLEFT", decor, "TOPLEFT", 0, 0)
    decor.top:SetPoint("TOPRIGHT", decor, "TOPRIGHT", 0, 0)
    decor.top:SetHeight(1)

    decor.bottom = decor:CreateTexture(nil, "BORDER")
    decor.bottom:SetTexture("Interface\\Buttons\\WHITE8X8")
    decor.bottom:SetPoint("BOTTOMLEFT", decor, "BOTTOMLEFT", 0, 0)
    decor.bottom:SetPoint("BOTTOMRIGHT", decor, "BOTTOMRIGHT", 0, 0)
    decor.bottom:SetHeight(1)

    decor.left = decor:CreateTexture(nil, "BORDER")
    decor.left:SetTexture("Interface\\Buttons\\WHITE8X8")
    decor.left:SetPoint("TOPLEFT", decor, "TOPLEFT", 0, 0)
    decor.left:SetPoint("BOTTOMLEFT", decor, "BOTTOMLEFT", 0, 0)
    decor.left:SetWidth(1)

    decor.right = decor:CreateTexture(nil, "BORDER")
    decor.right:SetTexture("Interface\\Buttons\\WHITE8X8")
    decor.right:SetPoint("TOPRIGHT", decor, "TOPRIGHT", 0, 0)
    decor.right:SetPoint("BOTTOMRIGHT", decor, "BOTTOMRIGHT", 0, 0)
    decor.right:SetWidth(1)

    frame.raidCompactDecorFrame = decor
    ApplyCompactDecorSkin(decor)
    return decor
end

local function ApplyCompactHealthTextLayout(frame, scale)
    if not frame or not frame.health then
        return
    end

    local mode = SlamFramesDB.raidHealthTextMode or "percent"
    local width = frame:GetWidth()
    local inset = COMPACT_INSET * scale
    local nameMultiplier = (SlamFramesDB and SlamFramesDB.nameTextScale) or 1.30
    local healthMultiplier = (SlamFramesDB and SlamFramesDB.healthTextScale) or 1.00
    local nameSize = CompactFontSize(11, scale, nameMultiplier)
    local healthBase = 8
    if mode == "amount" then
        healthBase = 7
    end
    local healthSize = CompactFontSize(healthBase, scale, healthMultiplier)
    local nameOffset = (tonumber(SlamFramesDB.raidNameOffset) or 0) * scale
    local leftPad = 5 * scale + nameOffset
    if frame.raidPreviewDebuffVisible then
        leftPad = leftPad + math.max(11, 19 * scale)
    end
    local rightPad = 5 * scale
    local healthWidth

    frame.name:ClearAllPoints()
    frame.name:SetPoint("LEFT", frame, "LEFT", leftPad, 0)
    if mode == "amount" then
        frame.name:SetWidth(math.max(20, width * 0.43))
    else
        frame.name:SetWidth(math.max(20, width * 0.63))
    end
    frame.name:SetHeight(math.max(10, COMPACT_BASE_HEIGHT * scale))
    frame.name:SetFont("Fonts\\FRIZQT__.TTF", nameSize, "OUTLINE")
    frame.name:SetJustifyH("LEFT")

    if mode == "amount" then
        healthWidth = math.max(30, width * 0.54)
    else
        healthWidth = math.max(24, width * 0.34)
    end

    frame.healthPercentText:ClearAllPoints()
    frame.healthPercentText:SetPoint("RIGHT", frame, "RIGHT", -rightPad, 0)
    frame.healthPercentText:SetWidth(healthWidth)
    frame.healthPercentText:SetHeight(math.max(10, COMPACT_BASE_HEIGHT * scale))
    frame.healthPercentText:SetFont("Fonts\\FRIZQT__.TTF", healthSize, "OUTLINE")
    frame.healthPercentText:SetJustifyH("RIGHT")

    frame.healthValueText:ClearAllPoints()
    frame.healthValueText:SetPoint("RIGHT", frame, "RIGHT", -rightPad, 0)
    frame.healthValueText:SetWidth(healthWidth)
    frame.healthValueText:SetHeight(math.max(10, COMPACT_BASE_HEIGHT * scale))
    frame.healthValueText:SetFont("Fonts\\FRIZQT__.TTF", healthSize, "OUTLINE")
    frame.healthValueText:SetJustifyH("RIGHT")
end


local RAID_PREVIEW_DEBUFFS = {
    {
        name = "Magic",
        icon = "Interface\\Icons\\Spell_Holy_DispelMagic",
        color = { 0.20, 0.55, 1.00 }
    },
    {
        name = "Curse",
        icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges",
        color = { 0.70, 0.25, 0.95 }
    },
    {
        name = "Poison",
        icon = "Interface\\Icons\\Ability_PoisonSting",
        color = { 0.20, 0.85, 0.25 }
    },
    {
        name = "Disease",
        icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion",
        color = { 0.70, 0.45, 0.10 }
    }
}

local function EnsureRaidPreviewDebuff(frame)
    if frame.raidPreviewDebuffFrame then
        return frame.raidPreviewDebuffFrame
    end

    local alert = CreateFrame("Frame", nil, frame)
    alert:SetAllPoints(frame)
    alert:SetFrameStrata(frame.sfUnitStrata or "MEDIUM")
    alert:SetFrameLevel((frame.sfLayerBase or frame:GetFrameLevel()) + 28)
    alert:EnableMouse(false)

    alert.top = alert:CreateTexture(nil, "OVERLAY")
    alert.top:SetTexture("Interface\\Buttons\\WHITE8X8")
    alert.top:SetPoint("TOPLEFT", alert, "TOPLEFT", 0, 0)
    alert.top:SetPoint("TOPRIGHT", alert, "TOPRIGHT", 0, 0)

    alert.bottom = alert:CreateTexture(nil, "OVERLAY")
    alert.bottom:SetTexture("Interface\\Buttons\\WHITE8X8")
    alert.bottom:SetPoint("BOTTOMLEFT", alert, "BOTTOMLEFT", 0, 0)
    alert.bottom:SetPoint("BOTTOMRIGHT", alert, "BOTTOMRIGHT", 0, 0)

    alert.left = alert:CreateTexture(nil, "OVERLAY")
    alert.left:SetTexture("Interface\\Buttons\\WHITE8X8")
    alert.left:SetPoint("TOPLEFT", alert, "TOPLEFT", 0, 0)
    alert.left:SetPoint("BOTTOMLEFT", alert, "BOTTOMLEFT", 0, 0)

    alert.right = alert:CreateTexture(nil, "OVERLAY")
    alert.right:SetTexture("Interface\\Buttons\\WHITE8X8")
    alert.right:SetPoint("TOPRIGHT", alert, "TOPRIGHT", 0, 0)
    alert.right:SetPoint("BOTTOMRIGHT", alert, "BOTTOMRIGHT", 0, 0)

    alert.iconFrame = CreateFrame("Frame", nil, alert)
    alert.iconFrame:SetFrameLevel(alert:GetFrameLevel() + 1)
    alert.icon = alert.iconFrame:CreateTexture(nil, "ARTWORK")
    alert.icon:SetAllPoints(alert.iconFrame)
    alert.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    alert:Hide()
    frame.raidPreviewDebuffFrame = alert
    return alert
end

local function LayoutRaidPreviewDebuff(frame, scale, compact)
    local alert = frame and frame.raidPreviewDebuffFrame
    if not alert then
        return
    end

    scale = scale or 1
    local glowSize = 2
    if SlamFramesDB then
        glowSize = ClampRaid(tonumber(SlamFramesDB.raidDebuffGlowSize) or 2, 1, 8)
    end

    -- The slider controls both the visible edge thickness and how far the
    -- colored alert extends beyond the unit cell. This makes the warning read
    -- as a glow instead of just a one-pixel border at larger settings.
    local spread = math.max(0, math.floor(glowSize * 0.75 * scale + 0.5))
    local edge = math.max(1, math.floor((0.75 + glowSize * 0.55) * scale + 0.5))

    alert:ClearAllPoints()
    alert:SetPoint("TOPLEFT", frame, "TOPLEFT", -spread, spread)
    alert:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", spread, -spread)

    alert.top:SetHeight(edge)
    alert.bottom:SetHeight(edge)
    alert.left:SetWidth(edge)
    alert.right:SetWidth(edge)

    local iconSize
    alert.iconFrame:ClearAllPoints()
    if compact then
        iconSize = math.max(9, math.floor(16 * scale + 0.5))
        alert.iconFrame:SetPoint("LEFT", frame, "LEFT", math.max(2, 3 * scale), 0)
    else
        iconSize = math.max(10, math.floor(18 * scale + 0.5))
        alert.iconFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -math.max(2, 4 * scale), -math.max(2, 4 * scale))
    end
    alert.iconFrame:SetWidth(iconSize)
    alert.iconFrame:SetHeight(iconSize)
end

local function ApplyRaidPreviewDebuff(frame, index)
    if not frame then
        return
    end

    local shouldShow = SF.testMode and SlamFramesDB and SlamFramesDB.raidPreviewDebuffs
    local slot = math.mod((tonumber(index) or 1) - 1, 5) + 1
    local info = nil

    if shouldShow and slot <= table.getn(RAID_PREVIEW_DEBUFFS) then
        info = RAID_PREVIEW_DEBUFFS[slot]
    end

    frame.raidPreviewDebuffVisible = info and true or false

    if not info then
        if frame.raidPreviewDebuffFrame then
            frame.raidPreviewDebuffFrame:Hide()
        end
        if SlamFramesDB and SlamFramesDB.raidCompactMode then
            ApplyCompactHealthTextLayout(frame, frame.layoutScale or 1)
        end
        return
    end

    local alert = EnsureRaidPreviewDebuff(frame)
    local c = info.color
    alert.top:SetVertexColor(c[1], c[2], c[3], 1)
    alert.bottom:SetVertexColor(c[1], c[2], c[3], 1)
    alert.left:SetVertexColor(c[1], c[2], c[3], 1)
    alert.right:SetVertexColor(c[1], c[2], c[3], 1)
    alert.icon:SetTexture(info.icon)
    alert.previewName = info.name
    LayoutRaidPreviewDebuff(frame, frame.layoutScale or 1, SlamFramesDB.raidCompactMode)
    alert:Show()

    if SlamFramesDB.raidCompactMode then
        ApplyCompactHealthTextLayout(frame, frame.layoutScale or 1)
    end
end

local function EnsureRaidMainTankDecor(frame)
    if frame.raidMainTankDecor then
        return frame.raidMainTankDecor
    end

    local decor = CreateFrame("Frame", nil, frame)
    decor:SetAllPoints(frame)
    decor:SetFrameStrata(frame.sfUnitStrata or "MEDIUM")
    decor:SetFrameLevel((frame.sfLayerBase or frame:GetFrameLevel()) + 27)
    decor:EnableMouse(false)

    decor.top = decor:CreateTexture(nil, "OVERLAY")
    decor.top:SetTexture("Interface\\Buttons\\WHITE8X8")
    decor.top:SetPoint("TOPLEFT", decor, "TOPLEFT", 0, 0)
    decor.top:SetPoint("TOPRIGHT", decor, "TOPRIGHT", 0, 0)

    decor.bottom = decor:CreateTexture(nil, "OVERLAY")
    decor.bottom:SetTexture("Interface\\Buttons\\WHITE8X8")
    decor.bottom:SetPoint("BOTTOMLEFT", decor, "BOTTOMLEFT", 0, 0)
    decor.bottom:SetPoint("BOTTOMRIGHT", decor, "BOTTOMRIGHT", 0, 0)

    decor.left = decor:CreateTexture(nil, "OVERLAY")
    decor.left:SetTexture("Interface\\Buttons\\WHITE8X8")
    decor.left:SetPoint("TOPLEFT", decor, "TOPLEFT", 0, 0)
    decor.left:SetPoint("BOTTOMLEFT", decor, "BOTTOMLEFT", 0, 0)

    decor.right = decor:CreateTexture(nil, "OVERLAY")
    decor.right:SetTexture("Interface\\Buttons\\WHITE8X8")
    decor.right:SetPoint("TOPRIGHT", decor, "TOPRIGHT", 0, 0)
    decor.right:SetPoint("BOTTOMRIGHT", decor, "BOTTOMRIGHT", 0, 0)

    -- A second inner rail keeps the Main Tank identity visible even if an
    -- outer debuff glow is active on the same player.
    decor.innerTop = decor:CreateTexture(nil, "OVERLAY")
    decor.innerTop:SetTexture("Interface\\Buttons\\WHITE8X8")
    decor.innerBottom = decor:CreateTexture(nil, "OVERLAY")
    decor.innerBottom:SetTexture("Interface\\Buttons\\WHITE8X8")

    decor:Hide()
    frame.raidMainTankDecor = decor
    return decor
end

local function LayoutRaidMainTankDecor(frame, scale)
    local decor = frame and frame.raidMainTankDecor
    if not decor then
        return
    end

    scale = scale or 1
    decor:ClearAllPoints()
    decor:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    decor:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    local edge = math.max(1, math.floor(2.2 * scale + 0.5))
    local inner = math.max(1, math.floor(1.1 * scale + 0.5))
    decor.top:SetHeight(edge)
    decor.bottom:SetHeight(edge)
    decor.left:SetWidth(edge)
    decor.right:SetWidth(edge)

    decor.innerTop:ClearAllPoints()
    decor.innerTop:SetPoint("TOPLEFT", decor, "TOPLEFT", edge, -edge - 1)
    decor.innerTop:SetPoint("TOPRIGHT", decor, "TOPRIGHT", -edge, -edge - 1)
    decor.innerTop:SetHeight(inner)

    decor.innerBottom:ClearAllPoints()
    decor.innerBottom:SetPoint("BOTTOMLEFT", decor, "BOTTOMLEFT", edge, edge + 1)
    decor.innerBottom:SetPoint("BOTTOMRIGHT", decor, "BOTTOMRIGHT", -edge, edge + 1)
    decor.innerBottom:SetHeight(inner)

    local dark = not SlamFramesDB or SlamFramesDB.skin ~= "light"
    if dark then
        decor.top:SetVertexColor(0.52, 0.82, 1.00, 1)
        decor.left:SetVertexColor(0.52, 0.82, 1.00, 1)
        decor.bottom:SetVertexColor(0.16, 0.38, 0.62, 1)
        decor.right:SetVertexColor(0.16, 0.38, 0.62, 1)
        decor.innerTop:SetVertexColor(0.85, 0.94, 1.00, 0.95)
        decor.innerBottom:SetVertexColor(0.24, 0.55, 0.78, 0.95)
    else
        decor.top:SetVertexColor(0.72, 0.91, 1.00, 1)
        decor.left:SetVertexColor(0.72, 0.91, 1.00, 1)
        decor.bottom:SetVertexColor(0.25, 0.55, 0.72, 1)
        decor.right:SetVertexColor(0.25, 0.55, 0.72, 1)
        decor.innerTop:SetVertexColor(0.92, 0.98, 1.00, 0.95)
        decor.innerBottom:SetVertexColor(0.38, 0.66, 0.80, 0.95)
    end
end

local function ApplyRaidMainTank(frame, index)
    if not frame then
        return
    end

    local isMainTank = IsRaidMainTank(index)
    frame.raidIsMainTank = isMainTank and true or false

    if not isMainTank then
        if frame.raidMainTankDecor then
            frame.raidMainTankDecor:Hide()
        end
        return
    end

    local decor = EnsureRaidMainTankDecor(frame)
    LayoutRaidMainTankDecor(frame, frame.layoutScale or 1)
    decor:Show()
end

local function LayoutCompactRaidFrame(frame, scale)
    local preset = 1
    if SlamFramesDB.widthPresets and SlamFramesDB.widthPresets.raid ~= nil then
        preset = tonumber(SlamFramesDB.widthPresets.raid) or 1
    end
    preset = ClampRaid(math.floor(preset + 0.5), 0, 3)

    local baseWidth = COMPACT_BASE_WIDTH - (preset * COMPACT_WIDTH_STEP)
    local width = baseWidth * scale
    local height = COMPACT_BASE_HEIGHT * scale
    local inset = COMPACT_INSET * scale
    local decor = EnsureCompactDecor(frame)
    ApplyCompactDecorSkin(decor)

    frame.layoutScale = scale
    frame.widthTrim = preset * COMPACT_WIDTH_STEP
    frame:SetScale(1)
    frame:SetWidth(width)
    frame:SetHeight(height)

    if frame.artFrame then frame.artFrame:Hide() end
    if frame.portrait then frame.portrait:Hide() end
    if frame.levelBadge then frame.levelBadge:Hide() end
    if frame.power then frame.power:Hide() end

    decor:Show()
    decor:SetFrameStrata(frame.sfUnitStrata or "MEDIUM")
    decor:SetFrameLevel((frame.sfLayerBase or frame:GetFrameLevel()) + 3)

    frame.health:ClearAllPoints()
    frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    frame.health:SetWidth(math.max(20, width - (inset * 2)))
    frame.health:SetHeight(math.max(8, height - (inset * 2)))
    frame.health.fullWidth = math.max(20, width - (inset * 2))
    frame.health.fullHeight = math.max(8, height - (inset * 2))
    frame.health.fill:ClearAllPoints()
    frame.health.fill:SetPoint("LEFT", frame.health, "LEFT", 0, 0)
    frame.health.fill:SetHeight(frame.health.fullHeight)
    frame.health:UpdateVisual()
    frame.health:Show()

    ApplyCompactHealthTextLayout(frame, scale)

    frame.moveLabel:ClearAllPoints()
    frame.moveLabel:SetPoint("TOP", frame, "TOP", 0, 16 * scale)
    frame.moveLabel:SetWidth(math.max(80, width))
    frame.moveLabel:SetHeight(18 * scale)
    LayoutRaidPreviewDebuff(frame, scale, true)
    LayoutRaidMainTankDecor(frame, scale)
end

local function LayoutStandardRaidFrame(frame, scale)
    SF:LayoutFrame(frame, "raid", scale)
    if frame.raidCompactDecorFrame then frame.raidCompactDecorFrame:Hide() end
    if frame.artFrame then frame.artFrame:Show() end
    if frame.portrait then frame.portrait:Show() end
    if frame.levelBadge then frame.levelBadge:Show() end
    if frame.power then frame.power:Show() end
    LayoutRaidPreviewDebuff(frame, scale, false)
    LayoutRaidMainTankDecor(frame, scale)
end

function SF:CreateRaidFrames()
    if self.raidFrames then
        return true
    end

    if not self.CreateUnitFrame then
        return false
    end

    if not C or not C.raid then
        return false
    end

    self.raidFrames = {}

    local index
    for index = 1, 40 do
        local raidCfg = (self.activeConfigs and self.activeConfigs.raid) or C.raid
        local frame = self.CreateUnitFrame(
            "Raid" .. index,
            "raid",
            "raid" .. index,
            raidCfg
        )

        if not frame then
            self.raidFrames = nil
            return false
        end

        frame.raidIndex = index
        self.raidFrames[index] = frame
    end

    self:InstallRaidDragHooks()
    return true
end

function SF:EnsureRaidFrames()
    if self.raidFrames then
        return true
    end

    return self:CreateRaidFrames()
end

function SF:LayoutRaidFrames()
    if not self.raidFrames then
        return
    end

    local scale = ClampRaid(tonumber(SlamFramesDB.scales.raid) or 0.60, 0.40, 3.00)
    local raidAlpha = GetRaidOpacity()
    local rowGap = (tonumber(SlamFramesDB.raidSpacing) or 4) * scale
    local groupGap = (tonumber(SlamFramesDB.raidGroupSpacing) or 10) * scale
    local groupRowGap = (tonumber(SlamFramesDB.raidGroupRowSpacing) or 36) * scale
    local groupsPerRow = tonumber(SlamFramesDB.raidGroupsPerRow) or 8
    local raidCount = GetRaidCount()
    local groupCount = math.floor((raidCount + 4) / 5)

    if groupsPerRow ~= 2 and groupsPerRow ~= 4 and groupsPerRow ~= 8 then
        groupsPerRow = 8
    end
    if groupCount < 1 then
        groupCount = 1
    end
    if groupCount > 8 then
        groupCount = 8
    end

    local index
    local frame
    local groupIndex
    local memberIndex
    local groupColumn
    local previous
    local previousGroupFirst
    local aboveGroupLast

    for index = 1, 40 do
        frame = self.raidFrames[index]
        if SlamFramesDB.raidCompactMode then
            LayoutCompactRaidFrame(frame, scale)
        else
            LayoutStandardRaidFrame(frame, scale)
        end
        frame:SetAlpha(raidAlpha)

        groupIndex = math.floor((index - 1) / 5) + 1
        memberIndex = math.mod(index - 1, 5) + 1
        groupColumn = math.mod(groupIndex - 1, groupsPerRow) + 1

        frame:ClearAllPoints()

        if index == 1 then
            ApplyRaidRootAnchor(frame)
        elseif memberIndex == 1 then
            if groupColumn == 1 then
                -- Wrapped layouts (4-across or 2-across): start the next bank
                -- beneath the matching first group from the bank above. Anchor to that
                -- group's fifth member so the slider controls only the gap
                -- between the two banks, not the full group height.
                local aboveGroup = groupIndex - groupsPerRow
                local aboveLastIndex = ((aboveGroup - 1) * 5) + 5
                aboveGroupLast = self.raidFrames[aboveLastIndex]
                frame:SetPoint("TOPLEFT", aboveGroupLast, "BOTTOMLEFT", 0, -groupRowGap)
            else
                previousGroupFirst = self.raidFrames[index - 5]
                frame:SetPoint("TOPLEFT", previousGroupFirst, "TOPRIGHT", groupGap, 0)
            end
        else
            previous = self.raidFrames[index - 1]
            frame:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -rowGap)
        end

        if frame.moveLabel then
            if index == 1 and not SlamFramesDB.locked then
                frame.moveLabel:SetText("RAID  " .. string.format("%.2f", scale) .. "x")
                frame.moveLabel:Show()
            else
                frame.moveLabel:Hide()
            end
        end
    end

    for groupIndex = 1, 8 do
        local header = EnsureRaidHeader(groupIndex)
        local firstFrame = self.raidFrames[((groupIndex - 1) * 5) + 1]

        header:ClearAllPoints()
        header:SetPoint("BOTTOM", firstFrame, "TOP", 0, 2 * scale)
        header:SetWidth(firstFrame:GetWidth())
        header:SetAlpha(raidAlpha)

        if SlamFramesDB.showRaidFrames
            and SlamFramesDB.raidShowGroupHeaders
            and raidCount > 0
            and groupIndex <= groupCount then
            header:Show()
        else
            header:Hide()
        end
    end
end

local function SetRaidHealth(frame, currentHealth, maxHealth)
    frame.health:SetValue(currentHealth, maxHealth, SF.testMode)

    local mode = SlamFramesDB.raidHealthTextMode or "percent"

    if maxHealth <= 0 or mode == "off" then
        frame.healthPercentText:SetText("")
        frame.healthValueText:SetText("")
        return
    end

    if mode == "amount" then
        frame.healthPercentText:SetText("")
        frame.healthValueText:SetText(
            tostring(math.floor(currentHealth + 0.5))
            .. " / "
            .. tostring(math.floor(maxHealth + 0.5))
        )
    else
        local percent = math.floor((currentHealth / maxHealth) * 100 + 0.5)
        frame.healthPercentText:SetText(tostring(percent) .. "%")
        frame.healthValueText:SetText("")
    end

    SF:ApplyHealthTextMode(frame)
    if SlamFramesDB.raidCompactMode then
        ApplyCompactHealthTextLayout(frame, frame.layoutScale or 1)
    end
end

function SF:UpdateRaidFrame(index)
    if not self.raidFrames then
        return
    end

    local frame = self.raidFrames[index]
    if not frame then
        return
    end

    local raidCount = GetRaidCount()
    local unit = "raid" .. index
    frame.unit = unit

    if not SlamFramesDB.showRaidFrames or index > raidCount then
        frame:Hide()
        return
    end

    if not self.testMode and not UnitExists(unit) then
        frame:Hide()
        return
    end

    local currentHealth
    local maxHealth

    if self.testMode and not UnitExists(unit) then
        maxHealth = 7000 + math.mod(index * 173, 1600)
        currentHealth = maxHealth

        if math.mod(index, 11) == 0 then
            currentHealth = math.floor(maxHealth * 0.28)
        elseif math.mod(index, 7) == 0 then
            currentHealth = math.floor(maxHealth * 0.72)
        end

        local testNameIndex = math.mod(index - 1, table.getn(TEST_NAMES)) + 1
        frame.name:SetText(TEST_NAMES[testNameIndex] .. index)

        if frame.levelText then
            frame.levelText:SetText("60")
        end

        if frame.portrait then
            frame.portrait:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
        end
    else
        currentHealth = UnitHealth(unit) or 0
        maxHealth = UnitHealthMax(unit) or 1
        frame.name:SetText(UnitName(unit) or ("Raid " .. index))

        if frame.levelText then
            local level = UnitLevel(unit)
            if level and level > 0 then
                frame.levelText:SetText(tostring(level))
            else
                frame.levelText:SetText("")
            end
        end

        if frame.portrait then
            frame.portrait:SetUnit(unit)
        end
    end

    SetRaidHealth(frame, currentHealth, maxHealth)
    ApplyRaidNameColor(frame, index, unit)
    ApplyRaidPreviewDebuff(frame, index)
    ApplyRaidMainTank(frame, index)
    frame:Show()

    if self.UpdateHealPredictionForFrame then
        self:UpdateHealPredictionForFrame(frame, unit)
    end
end

function SF:UpdateRaidFrames()
    if not SlamFramesDB or not SlamFramesDB.showRaidFrames then
        HideRaidFrames()
        return
    end

    local raidCount = GetRaidCount()

    -- Do not instantiate 40 unit frames during addon startup when the
    -- player is not in a raid. They are created only for Test Frames or a live raid.
    if raidCount <= 0 then
        HideRaidFrames()
        return
    end

    if not self:EnsureRaidFrames() then
        return
    end

    self:LayoutRaidFrames()

    local index
    for index = 1, 40 do
        self:UpdateRaidFrame(index)
    end
end

function SF:SetRaidFramesEnabled(value, quiet)
    SlamFramesDB.showRaidFrames = value and true or false
    self:UpdateRaidFrames()

    if self.RefreshSettings then
        self:RefreshSettings()
    end

    if not quiet and self.Print then
        self.Print("raid frames " .. (SlamFramesDB.showRaidFrames and "ON" or "OFF"))
    end
end

function SF:SetRaidHealthTextMode(value, quiet)
    if value ~= "percent" and value ~= "amount" and value ~= "off" then
        return
    end

    SlamFramesDB.raidHealthTextMode = value
    self:UpdateRaidFrames()

    if self.RefreshSettings then
        self:RefreshSettings()
    end
end

function SF:SetRaidSpacing(value, quiet)
    SlamFramesDB.raidSpacing = ClampRaid(math.floor((tonumber(value) or 4) + 0.5), 0, 40)

    if self.raidFrames then
        self:LayoutRaidFrames()
    end

    if self.RefreshSettings then
        self:RefreshSettings()
    end
end

function SF:SetRaidGroupSpacing(value, quiet)
    SlamFramesDB.raidGroupSpacing = ClampRaid(math.floor((tonumber(value) or 10) + 0.5), 0, 40)

    if self.raidFrames then
        self:LayoutRaidFrames()
    end

    if self.RefreshSettings then
        self:RefreshSettings()
    end
end

function SF:SetRaidGroupRowSpacing(value, quiet)
    SlamFramesDB.raidGroupRowSpacing = ClampRaid(math.floor((tonumber(value) or 36) + 0.5), 0, 80)

    if self.raidFrames then
        self:LayoutRaidFrames()
    end

    if self.RefreshSettings then
        self:RefreshSettings()
    end
end

function SF:SetRaidGroupsPerRow(value, quiet)
    value = tonumber(value) or 8
    if value ~= 2 and value ~= 4 and value ~= 8 then
        value = 8
    end

    SlamFramesDB.raidGroupsPerRow = value

    if self.raidFrames then
        self:LayoutRaidFrames()
    end

    if self.RefreshSettings then
        self:RefreshSettings()
    end

    if not quiet and self.Print then
        if value == 2 then
            self.Print("raid group layout 2 across")
        elseif value == 4 then
            self.Print("raid group layout 4 + 4")
        else
            self.Print("raid group layout 8 across")
        end
    end
end

function SF:RefreshRaidCompactSkin()
    if not self.raidFrames then
        return
    end

    local index
    for index = 1, table.getn(self.raidFrames) do
        local frame = self.raidFrames[index]
        if frame and frame.raidCompactDecorFrame then
            ApplyCompactDecorSkin(frame.raidCompactDecorFrame)
        end
        if frame and frame.raidMainTankDecor then
            LayoutRaidMainTankDecor(frame, frame.layoutScale or 1)
        end
    end
end

function SF:SetRaidOpacity(value, quiet)
    local alpha = tonumber(value) or 1.00
    if alpha > 1.00 then
        alpha = alpha / 100
    end
    SlamFramesDB.raidOpacity = ClampRaid(alpha, 0.20, 1.00)

    ApplyRaidOpacity()

    if self.RefreshSettings then
        self:RefreshSettings()
    end

    if not quiet and self.Print then
        self.Print("raid opacity " .. tostring(math.floor(SlamFramesDB.raidOpacity * 100 + 0.5)) .. "%")
    end
end

function SF:SetRaidNameOffset(value, quiet)
    local rounded = math.floor(((tonumber(value) or 0) + 2.5) / 5) * 5
    SlamFramesDB.raidNameOffset = ClampRaid(rounded, -150, 150)

    if self.raidFrames then
        self:LayoutRaidFrames()
    end

    if self.RefreshSettings then
        self:RefreshSettings()
    end
end

function SF:SetRaidClassColoredNames(value, quiet)
    SlamFramesDB.raidClassColoredNames = value and true or false

    if self.raidFrames then
        self:UpdateRaidFrames()
    end

    if self.RefreshSettings then
        self:RefreshSettings()
    end

    if not quiet and self.Print then
        self.Print("raid class-colored names " .. (SlamFramesDB.raidClassColoredNames and "ON" or "OFF"))
    end
end

function SF:SetRaidGroupHeaders(value, quiet)
    SlamFramesDB.raidShowGroupHeaders = value and true or false

    if self.raidFrames then
        self:LayoutRaidFrames()
    else
        HideRaidHeaders()
    end

    if self.RefreshSettings then
        self:RefreshSettings()
    end
end

function SF:SetRaidCompactMode(value, quiet)
    SlamFramesDB.raidCompactMode = value and true or false

    if self.raidFrames then
        self:LayoutRaidFrames()
        self:UpdateRaidFrames()
    end

    if self.RefreshSettings then
        self:RefreshSettings()
    end

    if not quiet and self.Print then
        self.Print("raid compact mode " .. (SlamFramesDB.raidCompactMode and "ON" or "OFF"))
    end
end

function SF:SetRaidPreviewDebuffs(value, quiet)
    SlamFramesDB.raidPreviewDebuffs = value and true or false

    if self.raidFrames then
        self:UpdateRaidFrames()
    end

    if self.RefreshSettings then
        self:RefreshSettings()
    end

    if not quiet and self.Print then
        self.Print("raid debuff preview " .. (SlamFramesDB.raidPreviewDebuffs and "ON" or "OFF"))
    end
end

function SF:SetRaidDebuffGlowSize(value, quiet)
    SlamFramesDB.raidDebuffGlowSize = ClampRaid(math.floor((tonumber(value) or 2) + 0.5), 1, 8)

    if self.raidFrames then
        local index
        for index = 1, table.getn(self.raidFrames) do
            local frame = self.raidFrames[index]
            if frame and frame.raidPreviewDebuffFrame then
                LayoutRaidPreviewDebuff(frame, frame.layoutScale or 1, SlamFramesDB.raidCompactMode)
            end
        end
    end

    if self.RefreshSettings then
        self:RefreshSettings()
    end
end

function SF:SetRaidPreviewMainTanks(value, quiet)
    SlamFramesDB.raidPreviewMainTanks = value and true or false

    if self.raidFrames then
        self:UpdateRaidFrames()
    end

    if self.RefreshSettings then
        self:RefreshSettings()
    end

    if not quiet and self.Print then
        self.Print("raid main-tank preview " .. (SlamFramesDB.raidPreviewMainTanks and "ON" or "OFF"))
    end
end

function SF:SetRaidPreviewSize(value, quiet)
    value = tonumber(value) or 20

    if value ~= 5 and value ~= 10 and value ~= 15 and value ~= 20 and value ~= 40 then
        value = 20
    end

    SlamFramesDB.raidPreviewSize = value

    if self.testMode then
        self:UpdateRaidFrames()
    end

    if self.RefreshSettings then
        self:RefreshSettings()
    end
end

function SF:ResetRaidPosition()
    if not SlamFramesDB.anchors then
        SlamFramesDB.anchors = {}
    end

    SlamFramesDB.anchors.raid = {
        point = "TOPLEFT",
        relativePoint = "TOPLEFT",
        x = 28,
        y = -210
    }

    if self.raidFrames then
        self:LayoutRaidFrames()
    end

    if self.RefreshSettings then
        self:RefreshSettings()
    end
end

function SF:InstallRaidDragHooks()
    if not self.raidFrames then
        return
    end

    local index
    for index = 1, 40 do
        local frame = self.raidFrames[index]

        frame:SetScript("OnDragStart", function()
            if not SlamFramesDB.locked and SF.raidFrames and SF.raidFrames[1] then
                SF.raidFrames[1]:StartMoving()
            end
        end)

        frame:SetScript("OnDragStop", function()
            if SF.raidFrames and SF.raidFrames[1] then
                SF.raidFrames[1]:StopMovingOrSizing()
                SaveRaidRootAnchor(SF.raidFrames[1])
                SF:LayoutRaidFrames()
            end
        end)
    end
end

SF.raidModuleLoaded = true
