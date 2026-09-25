-- SlamFrames v3.1.0
-- OctoWoW / 1.12-era compatible unit frames.
-- Uses old event globals (event, arg1, this) intentionally.

SlamFrames = SlamFrames or {}
local SF = SlamFrames
local C = SlamFrames_Config
local Bars = SlamFrames_BarEngine
local TEX = C.texturePath

local DEFAULTS = {
    -- SlamFrames 1.0 ships with the author's tested everyday profile as the
    -- fresh-install baseline. Existing SavedVariables are preserved.
    locked = true,
    hideBlizzard = true,
    showAuras = true,
    smoothBars = true,
    testMode = false,
    healthTextMode = "amount", -- percent | amount | both | off
    showPowerNumbers = true,
    showRestingEffect = true,
    showCCEffect = true,
    showCombatGlow = true,
    selfTargetOnClick = true,
    combatGlowIntensity = 1.30,
    showMinimapButton = true,
    skin = "dark",
    artResolution = "4k", -- 4k | 1080

    -- Party-frame defaults. The group uses one shared visual profile
    -- so all four members stay consistent while still being movable as a unit.
    showPartyFrames = true,
    partyHideInRaid = true,
    showPartyPower = true,
    partySpacing = 8,
    partyNameOffset = 0,

    -- Raid-frame defaults. Raid frames intentionally inherit the compact
    -- Party/ToT visual language and add an 8-group x 5-member layout.
    showRaidFrames = true,
    raidSpacing = 4,
    raidGroupSpacing = 10,
    raidGroupRowSpacing = 36,
    raidGroupsPerRow = 8, -- 8 Across | 4 = 4+4 | 2 = two groups across
    raidNameOffset = 0,
    raidShowGroupHeaders = true,
    raidCompactMode = false,
    raidOpacity = 1.00, -- 0.20 - 1.00; visual only, click targets remain active
    raidClassColoredNames = false,
    raidPreviewSize = 20,
    raidPreviewDebuffs = false,
    raidDebuffGlowSize = 2,
    raidPreviewMainTanks = false,
    minimapAngle = -0.4897411260673095,
    minimapRadius = 80,

    -- Player cast bar defaults from the 1.0 release profile.
    showPlayerCastbar = true,
    hideBlizzardCastbar = true,
    hideBlizzardErrorText = false, -- suppress UI_ERROR_MESSAGE red text only
    castbarShowIcon = true,
    castbarShowTimer = true,
    castbarShowLatency = true,
    castbarScale = 0.80,
    castbarWidth = 360,
    castbarStyle = 1,
    castbarAnchor = nil, -- fresh installs receive the 1.0 anchor during DBInit

    -- Text / aura presentation.
    nameTextScale = 1.30,
    healthTextScale = 1.80,
    powerTextScale = 1.30,
    levelTextScale = 1.00,
    auraScale = 1.30,
    auraRowSpacing = 1.00,
    auraShowCooldownSweep = false, -- retired/compatibility only
    auraShowTimerText = true,
    auraTimerTextScale = 1.00,

    -- 0=full, 1=~90%, 2=~80%, 3=~70% bar length.
    widthPresets = { player = 1, target = 1, tot = 1, party = 1, raid = 1 },
    portraitZooms = { player = 1.00, target = 1.00, tot = 1.08, party = 1.08, raid = 1.08 },
    ccAnchor = nil, -- fresh installs receive the 1.0 anchor during DBInit
}

local DEFAULT_ANCHORS = {
    player = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 395.0000032142003, y = -495.0000133355117 },
    target = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 784.0657184958282, y = -500.5849639301763 },
    tot    = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 969.5351682404736, y = -582.4043413313806 },
    party  = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 28, y = -210 },
    raid   = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 28, y = -210 },
}

local DEFAULT_TOT_RELATION = { point="TOPRIGHT", relativePoint="BOTTOMRIGHT", x=0, y=-10 }

-- The compact 0.60 presentation from the user's in-game screenshot is now the
-- reset/fresh-install baseline. Scaling is performed by explicit layout rather
-- than Frame:SetScale, so child text and geometry stay proportional.
local DEFAULT_SCALES = { player = 0.60, target = 0.60, tot = 0.60, party = 0.60, raid = 0.60 }

local function Print(msg)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffcc33SlamFrames:|r " .. msg) end
end
SF.Print = Print

local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function Round(v)
    return math.floor(v + 0.5)
end

local function FontSize(base, scale)
    return math.max(6, Round((base or 10) * (scale or 1)))
end

local function CopyAnchor(src)
    return { point=src.point, relativePoint=src.relativePoint, x=src.x, y=src.y }
end

-- Settings are stored per character.  Keep the old account-wide
-- SlamFramesDB declared for one-way migration compatibility, but make the
-- character SavedVariables table the active database used by the addon.
-- The first character loaded after upgrading snapshots the old shared profile
-- into SlamFramesAccountDB.characterSeed; every character that has not yet
-- created its own profile starts from that same snapshot, then diverges.
local function DeepCopyTable(src, seen)
    if type(src) ~= "table" then return src end
    seen = seen or {}
    if seen[src] then return seen[src] end
    local out = {}
    seen[src] = out
    local k,v
    for k,v in pairs(src) do
        out[DeepCopyTable(k, seen)] = DeepCopyTable(v, seen)
    end
    return out
end

local function GetCharacterProfileLabel()
    local name = nil
    if type(UnitName) == "function" then name = UnitName("player") end
    if not name or name == "" then name = "Unknown" end
    local realm = nil
    if type(GetRealmName) == "function" then realm = GetRealmName() end
    if realm and realm ~= "" then return name .. " - " .. realm end
    return name
end


local ART_RESOLUTION_FACTORS = {
    ["4k"] = 1.00,
    ["1080"] = 0.82,
}

function SF:GetArtResolution()
    local r = nil
    if SlamFramesDB and SlamFramesDB.artResolution then
        r = string.lower(tostring(SlamFramesDB.artResolution))
    end
    if r ~= "1080" and r ~= "4k" then
        r = "4k"
    end
    return r
end

function SF:GetTextureRoot()
    local root = C.texturePath or "Interface\\AddOns\\SlamFrames\\Textures\\"
    if self:GetArtResolution() == "1080" then
        return root .. "1080\\"
    end
    return root
end

local function Scaled(v, factor)
    if type(v) ~= "number" then return v end
    return math.max(1, Round(v * factor))
end

local function BuildResolvedUnitConfig(baseCfg, factor)
    if not baseCfg or factor == 1 then return DeepCopyTable(baseCfg) end
    local cfg = DeepCopyTable(baseCfg)
    cfg.width = Scaled(cfg.width, factor)
    cfg.height = Scaled(cfg.height, factor)
    if cfg.widthSlices then
        cfg.widthSlices.left = Scaled(cfg.widthSlices.left, factor)
        cfg.widthSlices.right = Scaled(cfg.widthSlices.right, factor)
        cfg.widthSlices.step = Scaled(cfg.widthSlices.step, factor)
    end
    local parts = {"portrait","health","power","name","levelBadge","aura"}
    local partIndex, part, k
    for partIndex=1,table.getn(parts) do
        part = cfg[parts[partIndex]]
        if type(part) == "table" then
            for k,v in pairs(part) do
                if type(v) == "number" and k ~= "zoom" and k ~= "offsetX" and k ~= "offsetY" and k ~= "slices" then
                    part[k] = Scaled(v, factor)
                end
            end
        end
    end
    if cfg.healthPercentFont then cfg.healthPercentFont = Scaled(cfg.healthPercentFont, factor) end
    if cfg.healthValueFont then cfg.healthValueFont = Scaled(cfg.healthValueFont, factor) end
    if cfg.powerFont then cfg.powerFont = Scaled(cfg.powerFont, factor) end
    if cfg.healthPercentOffset then cfg.healthPercentOffset = Scaled(cfg.healthPercentOffset, factor) end
    if cfg.healthValueOffset then cfg.healthValueOffset = math.floor((cfg.healthValueOffset or 0) * factor + (cfg.healthValueOffset and cfg.healthValueOffset < 0 and -0.5 or 0.5)) end
    return cfg
end

function SF:ApplyArtResolutionConfigs()
    local factor = ART_RESOLUTION_FACTORS[self:GetArtResolution()] or 1.00
    self.activeConfigs = {
        player = BuildResolvedUnitConfig(C.player, factor),
        target = BuildResolvedUnitConfig(C.target, factor),
        tot    = BuildResolvedUnitConfig(C.tot, factor),
        party  = BuildResolvedUnitConfig(C.party, factor),
        raid   = BuildResolvedUnitConfig(C.raid, factor),
    }
    self.activeArtFactor = factor
end

function SF:SetArtResolution(name, quiet)
    local mode = string.lower(tostring(name or "4k"))
    if mode ~= "1080" and mode ~= "4k" then mode = "4k" end
    SlamFramesDB.artResolution = mode
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("art resolution set to "..string.upper(mode)..". Please /reload to rebuild textures and geometry.") end
    return true
end

local function ActivateCharacterDB()
    if type(SlamFramesAccountDB) ~= "table" then SlamFramesAccountDB = {} end

    -- Capture the older account-wide profile exactly once.  This prevents a
    -- later character from inheriting edits made on whichever character was
    -- most recently logged out after the migration.
    if type(SlamFramesAccountDB.characterSeed) ~= "table" then
        if type(SlamFramesDB) == "table" then
            SlamFramesAccountDB.characterSeed = DeepCopyTable(SlamFramesDB)
            SlamFramesAccountDB.migratedFromShared = true
        else
            SlamFramesAccountDB.characterSeed = {}
            SlamFramesAccountDB.migratedFromShared = false
        end
        SlamFramesAccountDB.schemaVersion = 1
    end

    if type(SlamFramesCharacterDB) ~= "table" or SlamFramesCharacterDB.__sfPerCharacter ~= true then
        SlamFramesCharacterDB = DeepCopyTable(SlamFramesAccountDB.characterSeed or {})
        SlamFramesCharacterDB.__sfPerCharacter = true
        SlamFramesCharacterDB.__sfCharacter = GetCharacterProfileLabel()
    end

    SlamFramesDB = SlamFramesCharacterDB
    SF.activeCharacterProfile = SlamFramesCharacterDB.__sfCharacter or GetCharacterProfileLabel()
end

local function DBInit()
    ActivateCharacterDB()
    if not SlamFramesDB then SlamFramesDB = {} end
    local oldVersion = SlamFramesDB.dbVersion or 0
    local k,v
    for k,v in pairs(DEFAULTS) do if SlamFramesDB[k] == nil then SlamFramesDB[k] = v end end

    -- v0.6 used a single showNumbers toggle. Preserve the intent but move to a
    -- clearer text-mode setting. New installs default to the 1.0 amount display.
    if SlamFramesDB.healthTextMode == nil then
        if oldVersion > 0 and SlamFramesDB.showNumbers == false then
            SlamFramesDB.healthTextMode = "off"
        else
            SlamFramesDB.healthTextMode = (oldVersion == 0) and "amount" or "percent"
        end
    end
    -- ToT has its own compact health-text choice so the main Player/Target
    -- display can remain independent. Existing installs inherit a sensible
    -- equivalent from the old shared setting on first migration.
    if SlamFramesDB.totHealthTextMode == nil then
        if oldVersion == 0 then
            SlamFramesDB.totHealthTextMode = "percent"
        elseif SlamFramesDB.healthTextMode == "amount" then
            SlamFramesDB.totHealthTextMode = "amount"
        else
            SlamFramesDB.totHealthTextMode = "percent"
        end
    end
    if SlamFramesDB.totHealthTextMode ~= "percent" and SlamFramesDB.totHealthTextMode ~= "amount" then
        SlamFramesDB.totHealthTextMode = "percent"
    end
    if SlamFramesDB.partyHealthTextMode == nil then SlamFramesDB.partyHealthTextMode = "percent" end
    if SlamFramesDB.partyHealthTextMode ~= "percent" and SlamFramesDB.partyHealthTextMode ~= "amount" and SlamFramesDB.partyHealthTextMode ~= "off" then
        SlamFramesDB.partyHealthTextMode = "percent"
    end
    if SlamFramesDB.showPartyFrames == nil then SlamFramesDB.showPartyFrames = true end
    if SlamFramesDB.partyHideInRaid == nil then SlamFramesDB.partyHideInRaid = true end
    if SlamFramesDB.showPartyPower == nil then SlamFramesDB.showPartyPower = true end
    SlamFramesDB.partySpacing = Clamp(tonumber(SlamFramesDB.partySpacing) or 8, 0, 40)
    SlamFramesDB.partyNameOffset = Clamp(tonumber(SlamFramesDB.partyNameOffset) or 0, -150, 150)
    if SlamFramesDB.raidHealthTextMode == nil then SlamFramesDB.raidHealthTextMode = "percent" end
    if SlamFramesDB.raidHealthTextMode ~= "percent" and SlamFramesDB.raidHealthTextMode ~= "amount" and SlamFramesDB.raidHealthTextMode ~= "off" then SlamFramesDB.raidHealthTextMode = "percent" end
    if SlamFramesDB.showRaidFrames == nil then SlamFramesDB.showRaidFrames = true end
    if SlamFramesDB.raidShowGroupHeaders == nil then SlamFramesDB.raidShowGroupHeaders = true end
    if SlamFramesDB.raidCompactMode == nil then SlamFramesDB.raidCompactMode = false end
    SlamFramesDB.raidOpacity = Clamp(tonumber(SlamFramesDB.raidOpacity) or 1.00,0.20,1.00)
    SlamFramesDB.raidSpacing = Clamp(tonumber(SlamFramesDB.raidSpacing) or 4,0,40)
    SlamFramesDB.raidGroupSpacing = Clamp(tonumber(SlamFramesDB.raidGroupSpacing) or 10,0,40)
    SlamFramesDB.raidGroupRowSpacing = Clamp(tonumber(SlamFramesDB.raidGroupRowSpacing) or 36,0,80)
    local rgpr=tonumber(SlamFramesDB.raidGroupsPerRow) or 8
    if rgpr~=2 and rgpr~=4 and rgpr~=8 then rgpr=8 end
    SlamFramesDB.raidGroupsPerRow=rgpr
    SlamFramesDB.raidNameOffset = Clamp(tonumber(SlamFramesDB.raidNameOffset) or 0,-150,150)
    local rps=tonumber(SlamFramesDB.raidPreviewSize) or 20
    if rps~=5 and rps~=10 and rps~=15 and rps~=20 and rps~=40 then rps=20 end
    SlamFramesDB.raidPreviewSize=rps
    if SlamFramesDB.raidClassColoredNames == nil then SlamFramesDB.raidClassColoredNames = false end
    if SlamFramesDB.raidPreviewDebuffs == nil then SlamFramesDB.raidPreviewDebuffs = false end
    SlamFramesDB.raidDebuffGlowSize = Clamp(tonumber(SlamFramesDB.raidDebuffGlowSize) or 2,1,8)
    if SlamFramesDB.raidPreviewMainTanks == nil then SlamFramesDB.raidPreviewMainTanks = false end

    if SlamFramesDB.showPowerNumbers == nil then SlamFramesDB.showPowerNumbers = true end
    if SlamFramesDB.showRestingEffect == nil then SlamFramesDB.showRestingEffect = true end
    if SlamFramesDB.showCCEffect == nil then SlamFramesDB.showCCEffect = true end
    if SlamFramesDB.showCombatGlow == nil then SlamFramesDB.showCombatGlow = true end
    if SlamFramesDB.combatGlowIntensity == nil then SlamFramesDB.combatGlowIntensity = 1.30 end
    SlamFramesDB.combatGlowIntensity = Clamp(tonumber(SlamFramesDB.combatGlowIntensity) or 1.30, 0.50, 2.00)
    if SlamFramesDB.showMinimapButton == nil then SlamFramesDB.showMinimapButton = true end
    if SlamFramesDB.skin ~= "light" and SlamFramesDB.skin ~= "dark" then SlamFramesDB.skin = "dark" end
    if SlamFramesDB.artResolution ~= "1080" and SlamFramesDB.artResolution ~= "4k" then SlamFramesDB.artResolution = "4k" end

    if SlamFramesDB.showPlayerCastbar == nil then SlamFramesDB.showPlayerCastbar = true end
    if SlamFramesDB.hideBlizzardCastbar == nil then SlamFramesDB.hideBlizzardCastbar = true end
    if SlamFramesDB.hideBlizzardErrorText == nil then SlamFramesDB.hideBlizzardErrorText = false end
    if SlamFramesDB.castbarShowIcon == nil then SlamFramesDB.castbarShowIcon = true end
    if SlamFramesDB.castbarShowTimer == nil then SlamFramesDB.castbarShowTimer = true end
    if SlamFramesDB.castbarShowLatency == nil then SlamFramesDB.castbarShowLatency = true end
    SlamFramesDB.castbarScale = Clamp(tonumber(SlamFramesDB.castbarScale) or 0.80, 0.50, 1.60)
    SlamFramesDB.castbarWidth = math.floor((Clamp(tonumber(SlamFramesDB.castbarWidth) or 360,260,540)+5)/10)*10
    -- Style 2 is parked for later development; always migrate back to Style 1.
    SlamFramesDB.castbarStyle = 1
    if SlamFramesDB.castbarAnchor ~= nil and type(SlamFramesDB.castbarAnchor) ~= "table" then SlamFramesDB.castbarAnchor = nil end
    if oldVersion == 0 and SlamFramesDB.castbarAnchor == nil then
        SlamFramesDB.castbarAnchor = { x = -18.33375010796635, y = -240.8081150486736 }
    end

    -- v0.8 had one textScale for everything. Migrate that preference into
    -- the name only, while returning health/resource/level text to their
    -- stable authored sizes. This prevents one adjustment from knocking the
    -- other text out of alignment.
    local oldTextScale = SlamFramesDB.textScale
    if oldVersion < 9 and oldTextScale and math.abs(oldTextScale - 1.00) > 0.001 then
        SlamFramesDB.nameTextScale = oldTextScale
    elseif SlamFramesDB.nameTextScale == nil then
        SlamFramesDB.nameTextScale = 1.30
    end
    if SlamFramesDB.healthTextScale == nil then SlamFramesDB.healthTextScale = 1.80 end
    if SlamFramesDB.powerTextScale == nil then SlamFramesDB.powerTextScale = 1.30 end
    if SlamFramesDB.levelTextScale == nil then SlamFramesDB.levelTextScale = 1.00 end
    if SlamFramesDB.auraScale == nil then SlamFramesDB.auraScale = 1.30 end
    if SlamFramesDB.auraRowSpacing == nil then SlamFramesDB.auraRowSpacing = 1.00 end
    -- Sweep was experimental and is intentionally retired. Force it off so old
    -- SavedVariables cannot resurrect the broken cooldown-model path.
    SlamFramesDB.auraShowCooldownSweep = false
    if SlamFramesDB.auraShowTimerText == nil then SlamFramesDB.auraShowTimerText = true end
    if SlamFramesDB.auraTimerTextScale == nil then SlamFramesDB.auraTimerTextScale = 1.00 end

    SlamFramesDB.nameTextScale = Clamp(SlamFramesDB.nameTextScale, 0.60, 2.00)
    SlamFramesDB.healthTextScale = Clamp(SlamFramesDB.healthTextScale, 0.60, 2.00)
    SlamFramesDB.powerTextScale = Clamp(SlamFramesDB.powerTextScale, 0.60, 2.00)
    SlamFramesDB.levelTextScale = Clamp(SlamFramesDB.levelTextScale, 0.60, 2.00)
    SlamFramesDB.auraScale = Clamp(SlamFramesDB.auraScale, 0.60, 2.00)
    SlamFramesDB.auraRowSpacing = Clamp(tonumber(SlamFramesDB.auraRowSpacing) or 1.00, 0.00, 12.00)
    SlamFramesDB.auraTimerTextScale = Clamp(tonumber(SlamFramesDB.auraTimerTextScale) or 1.00, 0.50, 2.00)

    if not SlamFramesDB.widthPresets then SlamFramesDB.widthPresets = {} end
    if SlamFramesDB.widthPresets.player == nil then SlamFramesDB.widthPresets.player = 1 end
    if SlamFramesDB.widthPresets.target == nil then SlamFramesDB.widthPresets.target = 1 end
    if SlamFramesDB.widthPresets.tot == nil then SlamFramesDB.widthPresets.tot = 1 end
    if SlamFramesDB.widthPresets.party == nil then SlamFramesDB.widthPresets.party = 1 end
    if SlamFramesDB.widthPresets.raid == nil then SlamFramesDB.widthPresets.raid = 1 end
    SlamFramesDB.widthPresets.player = Clamp(math.floor((SlamFramesDB.widthPresets.player or 0) + 0.5), 0, (C.player.widthSlices and C.player.widthSlices.maxPreset) or 0)
    SlamFramesDB.widthPresets.target = Clamp(math.floor((SlamFramesDB.widthPresets.target or 0) + 0.5), 0, (C.target.widthSlices and C.target.widthSlices.maxPreset) or 0)
    SlamFramesDB.widthPresets.tot = Clamp(math.floor((SlamFramesDB.widthPresets.tot or 0) + 0.5), 0, (C.tot.widthSlices and C.tot.widthSlices.maxPreset) or 0)
    SlamFramesDB.widthPresets.party = Clamp(math.floor((SlamFramesDB.widthPresets.party or 0) + 0.5), 0, (C.party.widthSlices and C.party.widthSlices.maxPreset) or 0)
    SlamFramesDB.widthPresets.raid = Clamp(math.floor((SlamFramesDB.widthPresets.raid or 0) + 0.5), 0, (C.raid.widthSlices and C.raid.widthSlices.maxPreset) or 0)

    if not SlamFramesDB.portraitZooms then SlamFramesDB.portraitZooms = {} end
    if SlamFramesDB.portraitZooms.player == nil then SlamFramesDB.portraitZooms.player = 1.00 end
    if SlamFramesDB.portraitZooms.target == nil then SlamFramesDB.portraitZooms.target = 1.00 end
    if SlamFramesDB.portraitZooms.tot == nil then SlamFramesDB.portraitZooms.tot = C.tot.portrait.zoom or 1.00 end
    if SlamFramesDB.portraitZooms.party == nil then SlamFramesDB.portraitZooms.party = C.party.portrait.zoom or 1.08 end
    if SlamFramesDB.portraitZooms.raid == nil then SlamFramesDB.portraitZooms.raid = C.raid.portrait.zoom or 1.08 end
    SlamFramesDB.portraitZooms.player = Clamp(tonumber(SlamFramesDB.portraitZooms.player) or 1.00, 1.00, 1.50)
    SlamFramesDB.portraitZooms.target = Clamp(tonumber(SlamFramesDB.portraitZooms.target) or 1.00, 1.00, 1.50)
    SlamFramesDB.portraitZooms.tot = Clamp(tonumber(SlamFramesDB.portraitZooms.tot) or 1.08, 1.00, 1.50)
    SlamFramesDB.portraitZooms.party = Clamp(tonumber(SlamFramesDB.portraitZooms.party) or 1.08, 1.00, 1.50)
    SlamFramesDB.portraitZooms.raid = Clamp(tonumber(SlamFramesDB.portraitZooms.raid) or 1.08, 1.00, 1.50)
    if SlamFramesDB.ccAnchor ~= nil and type(SlamFramesDB.ccAnchor) ~= "table" then SlamFramesDB.ccAnchor = nil end
    if oldVersion == 0 and SlamFramesDB.ccAnchor == nil then
        SlamFramesDB.ccAnchor = { x = -35.55593730832338, y = 73.98975554593724 }
    end

    if SlamFramesDB.minimapAngle == nil then SlamFramesDB.minimapAngle = -0.4897411260673095 end
    if SlamFramesDB.minimapRadius == nil then SlamFramesDB.minimapRadius = 80 end
    SlamFramesDB.minimapRadius = Clamp(tonumber(SlamFramesDB.minimapRadius) or 80, 65, 105)

    if not SlamFramesDB.anchors then SlamFramesDB.anchors = {} end
    if not SlamFramesDB.scales then SlamFramesDB.scales = {} end

    if not SlamFramesDB.anchors.player then
        if SlamFramesDB.playerX ~= nil and SlamFramesDB.playerY ~= nil then
            SlamFramesDB.anchors.player = {point="CENTER",relativePoint="CENTER",x=SlamFramesDB.playerX,y=SlamFramesDB.playerY}
        else SlamFramesDB.anchors.player = CopyAnchor(DEFAULT_ANCHORS.player) end
    end
    if not SlamFramesDB.anchors.target then
        if SlamFramesDB.targetX ~= nil and SlamFramesDB.targetY ~= nil then
            SlamFramesDB.anchors.target = {point="CENTER",relativePoint="CENTER",x=SlamFramesDB.targetX,y=SlamFramesDB.targetY}
        else SlamFramesDB.anchors.target = CopyAnchor(DEFAULT_ANCHORS.target) end
    end
    if not SlamFramesDB.anchors.tot then SlamFramesDB.anchors.tot = CopyAnchor(DEFAULT_ANCHORS.tot) end
    if not SlamFramesDB.anchors.party then SlamFramesDB.anchors.party = CopyAnchor(DEFAULT_ANCHORS.party) end
    if not SlamFramesDB.anchors.raid then SlamFramesDB.anchors.raid = CopyAnchor(DEFAULT_ANCHORS.raid) end

    local oldScale = SlamFramesDB.scale
    if SlamFramesDB.scales.player == nil then SlamFramesDB.scales.player = oldScale or DEFAULT_SCALES.player end
    if SlamFramesDB.scales.target == nil then SlamFramesDB.scales.target = oldScale or DEFAULT_SCALES.target end
    if SlamFramesDB.scales.tot == nil then SlamFramesDB.scales.tot = oldScale or DEFAULT_SCALES.tot end
    if SlamFramesDB.scales.party == nil then SlamFramesDB.scales.party = DEFAULT_SCALES.party end
    if SlamFramesDB.scales.raid == nil then SlamFramesDB.scales.raid = DEFAULT_SCALES.raid end

    if SF.InitClickCastingDB then SF:InitClickCastingDB() end
    SlamFramesDB.dbVersion = 24
end

local function FormatNumber(n)
    n = math.floor((n or 0) + 0.5)
    local s = tostring(n)
    local sign = ""
    if string.sub(s, 1, 1) == "-" then sign = "-"; s = string.sub(s, 2) end
    local out = ""
    local count = 0
    local i
    for i = string.len(s), 1, -1 do
        out = string.sub(s, i, i) .. out
        count = count + 1
        if count == 3 and i > 1 then out = "," .. out; count = 0 end
    end
    return sign .. out
end
SF.FormatNumber = FormatNumber

local function PowerColor(unit)
    local p = UnitPowerType(unit)
    if p == 1 then return 0.95, 0.12, 0.08 end -- rage
    if p == 3 then return 0.95, 0.78, 0.10 end -- energy
    if p == 2 then return 1.00, 0.55, 0.00 end -- focus
    return 0.05, 0.45, 1.00 -- mana/default
end

local function MakeText(parent, size, justify, fontPath, flags)
    local f = parent:CreateFontString(nil, "OVERLAY")
    f.sfFontPath = fontPath or "Fonts\\FRIZQT__.TTF"
    f.sfBaseFontSize = size or 10
    f.sfFlags = flags or "OUTLINE"
    f:SetFont(f.sfFontPath, f.sfBaseFontSize, f.sfFlags)
    f:SetTextColor(1.0, 0.82, 0.0)
    f:SetJustifyH(justify or "CENTER")
    f:SetShadowColor(0,0,0,1)
    f:SetShadowOffset(1,-1)
    return f
end

local function SetScaledFont(fs, base, frameScale, elementScale)
    local effective = (frameScale or 1) * (elementScale or 1)
    fs:SetFont(fs.sfFontPath or "Fonts\\FRIZQT__.TTF", FontSize(base or fs.sfBaseFontSize, effective), fs.sfFlags or "OUTLINE")
    fs:SetShadowOffset(math.max(1, Round(effective)), -math.max(1, Round(effective)))
end

local function MakeFrameTexture(parent, cfg)
    local art = { cfg = cfg, parent = parent }

    if not cfg.widthSlices then
        art.single = parent:CreateTexture(nil, "ARTWORK")
        art.single:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(cfg.frame)) or (TEX .. cfg.frame))
        art.single:SetTexCoord(0, cfg.textureUMax, 0, cfg.textureVMax)
        function art:SetLayout(scale, trim)
            self.single:ClearAllPoints()
            self.single:SetAllPoints(parent)
        end
        return art
    end

    -- Three-slice renderer: fixed portrait/endcap regions + flexible center.
    -- This gives us real bar-length presets without squashing the portrait or
    -- bevels and without needing separate artwork files for every length.
    local ws = cfg.widthSlices
    local leftPx = ws.left
    local rightPx = ws.right
    local rightStartPx = cfg.width - rightPx
    local leftU = (leftPx / cfg.width) * cfg.textureUMax
    local rightU = (rightStartPx / cfg.width) * cfg.textureUMax

    art.left = parent:CreateTexture(nil, "ARTWORK")
    art.middle = parent:CreateTexture(nil, "ARTWORK")
    art.right = parent:CreateTexture(nil, "ARTWORK")
    art.left:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(cfg.frame)) or (TEX .. cfg.frame))
    art.middle:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(cfg.frame)) or (TEX .. cfg.frame))
    art.right:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(cfg.frame)) or (TEX .. cfg.frame))
    art.left:SetTexCoord(0, leftU, 0, cfg.textureVMax)
    art.middle:SetTexCoord(leftU, rightU, 0, cfg.textureVMax)
    art.right:SetTexCoord(rightU, cfg.textureUMax, 0, cfg.textureVMax)

    function art:SetLayout(scale, trim)
        scale = scale or 1
        trim = math.max(0, trim or 0)
        local middlePx = math.max(20, cfg.width - leftPx - rightPx - trim)
        local h = cfg.height * scale

        self.left:ClearAllPoints()
        self.left:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        self.left:SetWidth(leftPx * scale)
        self.left:SetHeight(h)

        self.right:ClearAllPoints()
        self.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
        self.right:SetWidth(rightPx * scale)
        self.right:SetHeight(h)

        self.middle:ClearAllPoints()
        self.middle:SetPoint("TOPLEFT", self.left, "TOPRIGHT", 0, 0)
        self.middle:SetWidth(middlePx * scale)
        self.middle:SetHeight(h)
    end

    return art
end

local function FrameForKey(key)
    if key == "player" then return SF.player end
    if key == "target" then return SF.target end
    if key == "tot" then return SF.tot end
    if key == "party" then return SF.partyFrames and SF.partyFrames[1] end
    if key == "raid" then return SF.raidFrames and SF.raidFrames[1] end
end
SF.FrameForKey = FrameForKey

local function NormalizeKey(key)
    key = string.lower(key or "")
    if key == "p" or key == "player" then return "player" end
    if key == "t" or key == "target" then return "target" end
    if key == "tot" or key == "targettarget" or key == "target-of-target" then return "tot" end
    if key == "party" or key == "group" or key == "p1" then return "party" end
    if key == "raid" or key == "r" then return "raid" end
end
SF.NormalizeKey = NormalizeKey

local function GetWidthPreset(key)
    if not SlamFramesDB or not SlamFramesDB.widthPresets then return 0 end
    return SlamFramesDB.widthPresets[key] or 0
end

local function GetWidthTrim(key, cfg)
    if not cfg or not cfg.widthSlices then return 0 end
    local preset = GetWidthPreset(key)
    preset = Clamp(math.floor((preset or 0) + 0.5), 0, cfg.widthSlices.maxPreset or 0)
    return preset * (cfg.widthSlices.step or 0)
end

local function WidthPercent(key, cfg)
    if not cfg or not cfg.health then return 100 end
    local trim = GetWidthTrim(key, cfg)
    return Round((math.max(20, cfg.health.w - trim) / cfg.health.w) * 100)
end
SF.WidthPercent = WidthPercent

local function SaveAnchor(frame, key)
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then return end
    local a = { point=point, relativePoint=relativePoint or point, x=x or 0, y=y or 0 }
    if key=="tot" then
        if relativeTo==SF.target then a.relativeKey="target"
        elseif SF.target and relativeTo==SF.target.health then a.relativeKey="targetHealth" end
    end
    SlamFramesDB.anchors[key] = a
end

local function ApplyAnchor(frame, key)
    local a = SlamFramesDB.anchors[key] or DEFAULT_ANCHORS[key]
    frame:ClearAllPoints()
    local relative=UIParent
    if a.relativeKey=="target" and SF.target then relative=SF.target
    elseif a.relativeKey=="targetHealth" and SF.target and SF.target.health then relative=SF.target.health end
    frame:SetPoint(a.point or "CENTER", relative, a.relativePoint or "CENTER", a.x or 0, a.y or 0)
end

local function UpdateFrameMouseState(frame)
    if not frame then return end
    -- While locked, a real Button child owns unit-frame clicks. This
    -- keeps spell/item execution inside Button OnClick, matching proven 1.12
    -- healer-frame implementations. While unlocked, the parent owns the mouse
    -- so movement/scaling continues to work exactly as before.
    frame:EnableMouse(true)
    if frame.EnableMouseWheel then frame:EnableMouseWheel(not SlamFramesDB.locked) end
    if SF.EnsureUnitClickButton then SF:EnsureUnitClickButton(frame) end
    if SF.RefreshUnitClickButton then SF:RefreshUnitClickButton(frame) end
end

local slamFramesUnitDropDown = nil

local function SafeUnitIsUnit(a,b)
    if type(UnitIsUnit)~="function" then return false end
    local ok,same=pcall(UnitIsUnit,a,b)
    return ok and same and true or false
end

local function SlamFramesUnitMenuType(unit)
    -- Vanilla 1.12 menu resolver used only for unit tokens that do not have
    -- one of Blizzard's native dropdown frames available to us.
    if SafeUnitIsUnit(unit,"player") then return "SELF" end
    if SafeUnitIsUnit(unit,"pet") then return "PET" end

    if type(UnitIsPlayer)=="function" and UnitIsPlayer(unit) then
        local grouped=false
        if type(UnitInParty)=="function" then
            local ok,v=pcall(UnitInParty,unit)
            if ok and v then grouped=true end
        end
        if not grouped and type(UnitInRaid)=="function" then
            local ok,v=pcall(UnitInRaid,unit)
            if ok and v then grouped=true end
        end
        if not grouped then
            local prefix=string.sub(unit or "",1,5)
            if prefix=="party" or string.sub(unit or "",1,4)=="raid" then grouped=true end
        end
        if grouped then return "PARTY" end
        return "PLAYER"
    end

    return "RAID_TARGET_ICON"
end

local function ToggleNativeUnitDropDown(dropdown)
    if not dropdown or type(ToggleDropDownMenu)~="function" then return false end
    -- Use Blizzard's already-created/initialized 1.12 dropdown objects.
    -- Anchoring at the cursor avoids depending on the stock Player/Party/
    -- Target frame itself being visible (SlamFrames normally hides them).
    ToggleDropDownMenu(1,nil,dropdown,"cursor",0,0)
    return true
end

local function EnsureSlamFramesUnitDropDown()
    if slamFramesUnitDropDown then return slamFramesUnitDropDown end
    if type(CreateFrame)~="function" then return nil end
    slamFramesUnitDropDown=CreateFrame("Frame","SlamFramesUnitDropDown",UIParent,"UIDropDownMenuTemplate")

    -- Stock 1.12 does real setup work inside UIDropDownMenu_Initialize; simply
    -- setting displayMode/initialize on the table is not equivalent. Initialize
    -- this custom fallback exactly as Blizzard initializes its own unit menus.
    if type(UIDropDownMenu_Initialize)=="function" then
        slamFramesUnitDropDown.initialize=function() end
        UIDropDownMenu_Initialize(slamFramesUnitDropDown,slamFramesUnitDropDown.initialize,"MENU")
    else
        slamFramesUnitDropDown.displayMode="MENU"
    end
    return slamFramesUnitDropDown
end

local slamFramesContextMenu = nil

local function UnitTokenIsGrouped(unit)
    if not unit then return false end
    local p=string.sub(unit,1,5)
    if p=="party" or string.sub(unit,1,4)=="raid" then return true end
    if type(UnitInParty)=="function" then
        local ok,v=pcall(UnitInParty,unit)
        if ok and v then return true end
    end
    if type(UnitInRaid)=="function" then
        local ok,v=pcall(UnitInRaid,unit)
        if ok and v then return true end
    end
    return false
end

local function InAnyGroup()
    local p=(type(GetNumPartyMembers)=="function" and GetNumPartyMembers()) or 0
    local r=(type(GetNumRaidMembers)=="function" and GetNumRaidMembers()) or 0
    return (p>0 or r>0)
end

local function CanCooperateWith(unit)
    if type(UnitCanCooperate)~="function" then return true end
    local ok,v=pcall(UnitCanCooperate,"player",unit)
    if not ok then return true end
    return v and true or false
end

local function FindRaidIndexByName(name)
    if not name or type(GetNumRaidMembers)~="function" or type(GetRaidRosterInfo)~="function" then return nil end
    local n=GetNumRaidMembers() or 0
    local i
    for i=1,n do
        local rn=GetRaidRosterInfo(i)
        if rn==name then return i end
    end
    return nil
end

local function HideSlamFramesContextMenu()
    if slamFramesContextMenu then slamFramesContextMenu:Hide() end
end

local function ContextActionButton(parent,index,label,action)
    local b=parent.buttons[index]
    if not b then
        b=CreateFrame("Button",nil,parent)
        b:SetHeight(20)
        b:SetPoint("TOPLEFT",parent,"TOPLEFT",8,-8-((index-1)*20))
        b:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-8,-8-((index-1)*20))
        local hl=b:CreateTexture(nil,"BACKGROUND")
        hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        hl:SetBlendMode("ADD")
        hl:SetAllPoints(b)
        hl:Hide()
        b.highlight=hl
        b:SetScript("OnEnter",function() if this.highlight then this.highlight:Show() end end)
        b:SetScript("OnLeave",function() if this.highlight then this.highlight:Hide() end end)
        local fs=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        fs:SetPoint("LEFT",b,"LEFT",4,0)
        fs:SetJustifyH("LEFT")
        b.text=fs
        b:SetScript("OnClick",function()
            local fn=this.sfAction
            HideSlamFramesContextMenu()
            if fn then fn() end
        end)
        parent.buttons[index]=b
    end
    b.sfAction=action
    b.text:SetText(label)
    b:Show()
    return b
end

local function EnsureSlamFramesContextMenu(anchorFrame)
    if slamFramesContextMenu then return slamFramesContextMenu end
    if type(CreateFrame)~="function" then return nil end
    -- UIParent is expected on Vanilla, but use the clicked frame's parent as a
    -- last-resort parent so the menu still exists on stripped/custom FrameXML.
    local parent=UIParent
    if not parent and anchorFrame and anchorFrame.GetParent then parent=anchorFrame:GetParent() end
    if not parent then return nil end
    local f=CreateFrame("Frame",nil,parent)
    if f.SetFrameStrata then f:SetFrameStrata("TOOLTIP") end
    if f.SetFrameLevel then f:SetFrameLevel(1000) end
    f:SetWidth(180)
    f:SetHeight(40)
    f:EnableMouse(true)
    if f.SetBackdrop then
        f:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
        if f.SetBackdropColor then f:SetBackdropColor(0.04,0.04,0.04,0.98) end
        if f.SetBackdropBorderColor then f:SetBackdropBorderColor(0.65,0.50,0.22,1) end
    else
        local bg=f:CreateTexture(nil,"BACKGROUND")
        bg:SetTexture(0.04,0.04,0.04,0.98)
        bg:SetAllPoints(f)
        f.sfBackground=bg
    end
    f.buttons={}
    f:Hide()
    slamFramesContextMenu=f
    return f
end

local function AddContextItem(items,label,fn)
    if type(fn)=="function" then table.insert(items,{label=label,fn=fn}) end
end

local function ShowSlamFramesContextMenu(frame)
    if not frame or not frame.unit then return false end
    local unit=frame.unit
    local exists=nil
    if type(UnitExists)=="function" then exists=UnitExists(unit) end
    local name=nil
    if type(UnitName)=="function" then name=UnitName(unit) end
    if not name then name=unit end
    if SF.clickCastDebug then
        Print("CLICKDBG: standalone menu precheck unit="..tostring(unit).." exists="..tostring(exists).." name="..tostring(name).." UIParent="..tostring(UIParent~=nil).." CreateFrame="..tostring(type(CreateFrame)))
    end
    local menu=EnsureSlamFramesContextMenu(frame)
    if not menu then
        if SF.clickCastDebug then Print("CLICKDBG: standalone menu creation FAILED") end
        return false
    end

    local isSelf=SafeUnitIsUnit(unit,"player")
    if frame.frameKey=="player" or unit=="player" then isSelf=true end
    local isPlayer=false
    if type(UnitIsPlayer)=="function" then isPlayer=UnitIsPlayer(unit) and true or false end
    if isSelf or string.sub(unit,1,5)=="party" or string.sub(unit,1,4)=="raid" then isPlayer=true end
    local grouped=UnitTokenIsGrouped(unit)
    local coop=CanCooperateWith(unit)
    local items={}

    if isSelf then
        if InAnyGroup() and type(LeaveParty)=="function" then
            AddContextItem(items,"Leave Party",function() LeaveParty() end)
        end
        if type(StaticPopup_Show)=="function" then
            AddContextItem(items,"Reset Instances",function() StaticPopup_Show("CONFIRM_RESET_INSTANCES") end)
        end
    elseif isPlayer then
        if name and type(ChatFrame_SendTell)=="function" then
            AddContextItem(items,"Whisper",function() ChatFrame_SendTell(name) end)
        end
        if coop and type(InspectUnit)=="function" then
            AddContextItem(items,"Inspect",function() InspectUnit(unit) end)
        end
        if coop and type(InitiateTrade)=="function" then
            AddContextItem(items,"Trade",function() InitiateTrade(unit) end)
        end
        if coop and name and type(FollowByName)=="function" then
            AddContextItem(items,"Follow",function() FollowByName(name,1) end)
        end
        if coop and type(StartDuelUnit)=="function" then
            AddContextItem(items,"Duel",function() StartDuelUnit(unit) end)
        end
        if not grouped then
            if type(InviteToParty)=="function" then
                AddContextItem(items,"Invite",function() InviteToParty(unit) end)
            elseif name and type(InviteByName)=="function" then
                AddContextItem(items,"Invite",function() InviteByName(name) end)
            end
        end

        local _,_,partyIndex=string.find(unit or "","^party([1-4])$")
        if partyIndex and type(IsPartyLeader)=="function" and IsPartyLeader() then
            if type(PromoteToPartyLeader)=="function" then
                AddContextItem(items,"Promote to Leader",function() PromoteToPartyLeader(unit) end)
            end
            if type(UninviteFromParty)=="function" then
                AddContextItem(items,"Remove from Party",function() UninviteFromParty(unit) end)
            end
        end

        local raidIndex=FindRaidIndexByName(name)
        if raidIndex then
            local canRaidManage=false
            if type(IsRaidLeader)=="function" and IsRaidLeader() then canRaidManage=true end
            if type(IsRaidOfficer)=="function" and IsRaidOfficer() then canRaidManage=true end
            if canRaidManage then
                if type(PromoteByName)=="function" then
                    AddContextItem(items,"Promote to Raid Leader",function() PromoteByName(name) end)
                end
                if type(PromoteToAssistant)=="function" then
                    AddContextItem(items,"Promote Assistant",function() PromoteToAssistant(name) end)
                end
                if type(DemoteAssistant)=="function" then
                    AddContextItem(items,"Demote Assistant",function() DemoteAssistant(name) end)
                end
                if type(UninviteFromRaid)=="function" then
                    AddContextItem(items,"Remove from Raid",function() UninviteFromRaid(raidIndex) end)
                end
            end
        end
    else
        -- Vanilla's stock non-player target menu is mostly raid-marker control.
        -- Keep one useful normal action here instead of presenting an empty menu.
        if type(SetRaidTarget)=="function" then
            AddContextItem(items,"Clear Raid Marker",function() SetRaidTarget(unit,0) end)
        end
    end

    AddContextItem(items,"Cancel",function() end)

    local i
    for i=1,table.getn(items) do
        ContextActionButton(menu,i,items[i].label,items[i].fn)
    end
    for i=table.getn(items)+1,table.getn(menu.buttons) do
        menu.buttons[i]:Hide()
    end

    menu:SetHeight(16+(table.getn(items)*20))
    menu:ClearAllPoints()
    local parent=UIParent
    if not parent and menu.GetParent then parent=menu:GetParent() end
    local anchored=false
    if parent and type(GetCursorPosition)=="function" then
        local x,y=GetCursorPosition()
        local scale=1
        if parent.GetEffectiveScale then scale=parent:GetEffectiveScale() or 1 end
        if scale==0 then scale=1 end
        x=x/scale; y=y/scale
        if y < menu:GetHeight()+12 then
            menu:SetPoint("BOTTOMLEFT",parent,"BOTTOMLEFT",x,y)
        else
            menu:SetPoint("TOPLEFT",parent,"BOTTOMLEFT",x,y)
        end
        anchored=true
    end
    if not anchored then
        menu:SetPoint("TOPLEFT",frame,"BOTTOMLEFT",0,-4)
    end
    menu:Show()
    if menu.Raise then menu:Raise() end
    if SF.clickCastDebug then Print("CLICKDBG: standalone menu shown items="..tostring(table.getn(items)).." visible="..tostring(menu:IsVisible())) end
    return true
end

local function UnitMenuForFrame(self, frame)
    -- All callers invoke this as SF:UnitMenuForFrame(frame).  With Lua colon
    -- syntax the first argument is SF itself, so the method must accept self
    -- before the actual clicked frame.  an earlier implementation declared only
    -- one parameter, causing `frame` to be SF and returning false immediately.
    if not frame or not frame.unit then
        if SF.clickCastDebug then Print("CLICKDBG: menu route rejected frame="..tostring(frame).." frame.unit="..tostring(frame and frame.unit)) end
        return false
    end

    local unit=frame.unit
    if SF.clickCastDebug then
        local exists=nil
        if type(UnitExists)=="function" then exists=UnitExists(unit) end
        Print("CLICKDBG: menu route unit="..tostring(unit).." exists="..tostring(exists).." ToggleDropDownMenu="..tostring(type(ToggleDropDownMenu)).." UnitPopup_ShowMenu="..tostring(type(UnitPopup_ShowMenu)))
    end

    -- Prefer Blizzard's native 1.12 dropdowns when this client exposes them.
    if SafeUnitIsUnit(unit,"player") and PlayerFrameDropDown then
        if ToggleNativeUnitDropDown(PlayerFrameDropDown) then return true end
    end

    local _,_,partyIndex=string.find(unit or "","^party([1-4])$")
    if partyIndex then
        local dd=nil
        if type(getglobal)=="function" then dd=getglobal("PartyMemberFrame"..partyIndex.."DropDown") end
        if not dd and _G then dd=_G["PartyMemberFrame"..partyIndex.."DropDown"] end
        if dd and ToggleNativeUnitDropDown(dd) then return true end
    end

    if unit=="target" and TargetFrameDropDown then
        if ToggleNativeUnitDropDown(TargetFrameDropDown) then return true end
    end

    -- Some OctoWoW/SuperWoW installations intentionally do not expose the
    -- Blizzard UnitPopup/UIDropDown globals at all. If they do exist, use them.
    if type(ToggleDropDownMenu)=="function" and type(UnitPopup_ShowMenu)=="function" then
        local dropdown=EnsureSlamFramesUnitDropDown()
        if dropdown then
            local which=SlamFramesUnitMenuType(unit)
            local name=nil
            if which=="RAID_TARGET_ICON" then name=RAID_TARGET_ICON end
            dropdown.unit=unit
            dropdown.name=UnitName(unit)
            dropdown.which=which
            dropdown.initialize=function(level)
                UnitPopup_ShowMenu(dropdown,which,unit,name)
            end
            dropdown.displayMode="MENU"
            ToggleDropDownMenu(1,nil,dropdown,"cursor",0,0)
            return true
        end
    end

    -- Standalone fallback. This deliberately does not depend on
    -- UIDropDownMenu, UnitPopup or ClassicAPI secure attributes, so SlamFrames
    -- still provides the expected player/party context actions on stripped UI
    -- builds such as the user's SuperWoW 2.2 environment.
    local shown=ShowSlamFramesContextMenu(frame)
    if SF.clickCastDebug then Print("CLICKDBG: standalone fallback result="..tostring(shown)) end
    return shown
end
SF.UnitMenuForFrame = UnitMenuForFrame

local function TargetIsPlayer()
    if not UnitExists("target") then return false end
    if type(UnitIsUnit)=="function" then
        local ok,same=pcall(UnitIsUnit,"target","player")
        if ok then return same and true or false end
    end
    -- Safe 1.12 fallback. Player names are unique on a realm.
    local tn=UnitName("target")
    local pn=UnitName("player")
    return tn and pn and tn==pn
end

function SF:SetSelfTargetOnClick(v, quiet)
    SlamFramesDB.selfTargetOnClick=v and true or false
    -- If the feature is enabled while the player is already self-targeted,
    -- immediately suppress ToT to match the click behavior. Disabling it
    -- restores normal target-of-target handling on the next refresh.
    if self.UpdateTargetOfTarget then self:UpdateTargetOfTarget() end
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet then Print("click Player to target self is now "..(SlamFramesDB.selfTargetOnClick and "ON" or "OFF")..".") end
end

local function PanelIsShown(frame)
    return frame and frame.IsShown and frame:IsShown()
end

function SF:HasBlockingUIPanel()
    -- Vanilla 1.12 keeps the currently managed Blizzard panels on UIParent.
    -- We only lower SlamFrames while one of those panels is actually visible.
    -- This lets unit frames stay above world/nameplate frames during gameplay,
    -- while profession/character/merchant/etc. panels still cover SlamFrames.
    if type(GetFullScreenFrame)=="function" and PanelIsShown(GetFullScreenFrame()) then return true end
    if type(GetDoublewideFrame)=="function" and PanelIsShown(GetDoublewideFrame()) then return true end
    if type(GetCenterFrame)=="function" and PanelIsShown(GetCenterFrame()) then return true end
    if type(GetLeftFrame)=="function" and PanelIsShown(GetLeftFrame()) then return true end
    return false
end

function SF:GetUnitFrameStrata()
    if self:HasBlockingUIPanel() then return "LOW" end
    return "MEDIUM"
end

function SF:ApplyFrameLayerBase(frame, base)
    if not frame then return end

    -- Keep the complete unit frame inside a small, safe frame-level band.
    -- v0.8 raised barFrame but not the health/power child frames themselves;
    -- on the old client that left the fills underneath the opaque frame art.
    -- Explicitly level every nested frame so the bars can never disappear.
    frame.sfLayerBase = base or 10

    -- Dynamic strata.  MEDIUM is required during normal gameplay so
    -- world/nameplate frames never cut through SlamFrames.  When a managed
    -- Blizzard UIPanel is open we temporarily drop to LOW so that panel wins.
    local unitStrata = self:GetUnitFrameStrata()
    frame.sfUnitStrata = unitStrata
    frame:SetFrameStrata(unitStrata)
    frame:SetFrameLevel(frame.sfLayerBase)
    if frame.portrait then frame.portrait:SetFrameStrata(unitStrata); frame.portrait:SetFrameLevel(frame.sfLayerBase + 1) end
    if frame.artFrame then frame.artFrame:SetFrameStrata(unitStrata); frame.artFrame:SetFrameLevel(frame.sfLayerBase + 2) end
    if frame.barFrame then frame.barFrame:SetFrameStrata(unitStrata); frame.barFrame:SetFrameLevel(frame.sfLayerBase + 3) end
    if frame.health then frame.health:SetFrameStrata(unitStrata); frame.health:SetFrameLevel(frame.sfLayerBase + 4) end
    if frame.power then frame.power:SetFrameStrata(unitStrata); frame.power:SetFrameLevel(frame.sfLayerBase + 4) end
    if frame.raidCompactDecorFrame then frame.raidCompactDecorFrame:SetFrameStrata(unitStrata); frame.raidCompactDecorFrame:SetFrameLevel(frame.sfLayerBase + 3) end
    if frame.raidPreviewDebuffFrame then
        frame.raidPreviewDebuffFrame:SetFrameStrata(unitStrata)
        frame.raidPreviewDebuffFrame:SetFrameLevel(frame.sfLayerBase + 28)
        if frame.raidPreviewDebuffFrame.iconFrame then
            frame.raidPreviewDebuffFrame.iconFrame:SetFrameStrata(unitStrata)
            frame.raidPreviewDebuffFrame.iconFrame:SetFrameLevel(frame.sfLayerBase + 29)
        end
    end
    if frame.textFrame then frame.textFrame:SetFrameStrata(unitStrata); frame.textFrame:SetFrameLevel(frame.sfLayerBase + 5) end
    -- Status glows sit above the portrait/art but below the level medallion.
    -- This keeps resting/combat light from shining through the level badge.
    if frame.statusFrame then frame.statusFrame:SetFrameStrata(unitStrata); frame.statusFrame:SetFrameLevel(frame.sfLayerBase + 7) end
    -- Dedicated click-cast button sits above the core frame but below target
    -- aura buttons, preserving aura hover/click behavior.
    if frame.sfClickButton then
        frame.sfClickButton:SetFrameStrata(unitStrata)
        frame.sfClickButton:SetFrameLevel(frame.sfLayerBase + 6)
    end
    -- Special portrait back/front pieces are sibling frames rather than normal
    -- children, so move their strata with the owning unit frame as well.
    if frame.sfSpecialBackFrame then frame.sfSpecialBackFrame:SetFrameStrata(unitStrata) end
    if frame.sfSpecialFrontFrame then frame.sfSpecialFrontFrame:SetFrameStrata(unitStrata) end
    if frame.frameKey == "target" and self.auras then
        local i,a,auraLevel
        for i=1,table.getn(self.auras) do
            a=self.auras[i]
            auraLevel=frame.sfLayerBase + 8
            a:SetFrameStrata(unitStrata)
            a:SetFrameLevel(auraLevel)

            -- Aura timer text lives on its own child frame. The current
            -- dynamic unit-frame layering can raise/lower the aura button long
            -- after that timer frame was created. On the 1.12 client an
            -- explicitly-set child frame level can remain at its old absolute
            -- level, leaving the icon/border visible while the timer text is
            -- rendered underneath it. Re-lock every aura child to the current
            -- owning aura level whenever SlamFrames reconciles frame layers.
            if a.cooldown then
                a.cooldown:SetFrameStrata(unitStrata)
                a.cooldown:SetFrameLevel(auraLevel + 1)
            end
            if a.timerFrame then
                a.timerFrame:SetFrameStrata(unitStrata)
                a.timerFrame:SetFrameLevel(auraLevel + 4)
            end
        end
    end
    if self.ApplyClickAlertLayer then self:ApplyClickAlertLayer(frame,unitStrata,frame.sfLayerBase) end
    if frame.levelBadge then frame.levelBadge:SetFrameStrata(unitStrata); frame.levelBadge:SetFrameLevel(frame.sfLayerBase + 10) end

    -- Refresh after a layer change; this is intentionally redundant and
    -- protects against old-client frame-level reparent/render quirks.
    if frame.health and frame.health.UpdateVisual then frame.health:UpdateVisual() end
    if frame.power and frame.power.UpdateVisual then frame.power:UpdateVisual() end
end

function SF:RefreshFrameLayers(topKey)
    local bases = { player = 10, target = 25, tot = 40 }
    local keys = {"player","target","tot"}
    local i,key,frame
    self.topFrameKey = topKey or self.topFrameKey
    for i=1,table.getn(keys) do
        key=keys[i]; frame=FrameForKey(key)
        if frame then
            self:ApplyFrameLayerBase(frame, (self.topFrameKey == key) and 60 or bases[key])
        end
    end

    -- Party frames are one movable visual group, but each member is its own
    -- unit frame. Keep all four on the same layer so no member can cut through
    -- another when the group is raised or when Blizzard panels are opened.
    if self.partyFrames then
        local partyBase=(self.topFrameKey=="party") and 70 or 50
        for i=1,table.getn(self.partyFrames) do
            if self.partyFrames[i] then self:ApplyFrameLayerBase(self.partyFrames[i],partyBase+i-1) end
        end
    end
    if self.raidFrames then
        local raidBase=(self.topFrameKey=="raid") and 80 or 55
        for i=1,table.getn(self.raidFrames) do
            if self.raidFrames[i] then self:ApplyFrameLayerBase(self.raidFrames[i],raidBase+i-1) end
        end
    end
end

function SF:BringToFront(frame)
    if not frame then return end
    self:RefreshFrameLayers(frame.frameKey)
end

local function SetupDrag(frame, key)
    frame.frameKey = key
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    -- We manage the complete frame stack ourselves; automatic toplevel raising
    -- can separate a parent from its explicitly leveled child frames on 1.12.
    frame:SetScript("OnMouseDown", function()
        SF:BringToFront(this)
    end)
    frame:SetScript("OnMouseUp", function()
        -- Locked clicks are handled by the dedicated child Button's
        -- OnClick script. The parent OnMouseUp is intentionally inert while
        -- locked so one hardware click can never dispatch twice.
        if SlamFramesDB.locked then return end
    end)
    frame:SetScript("OnEnter", function()
        if SF.ShowClickCastingTooltip then SF:ShowClickCastingTooltip(this) end
    end)
    frame:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    frame:SetScript("OnDragStart", function()
        if not SlamFramesDB.locked then
            SF:BringToFront(this)
            if this.frameKey=="party" and SF.partyFrames and SF.partyFrames[1] then
                SF.partyFrames[1]:StartMoving()
            else
                this:StartMoving()
            end
        end
    end)
    frame:SetScript("OnDragStop", function()
        if this.frameKey=="party" and SF.partyFrames and SF.partyFrames[1] then
            local root=SF.partyFrames[1]
            root:StopMovingOrSizing()
            SaveAnchor(root,"party")
            if SF.LayoutPartyFrames then SF:LayoutPartyFrames() end
        else
            this:StopMovingOrSizing()
            SaveAnchor(this, this.frameKey)
        end
    end)
    if frame.EnableMouseWheel then
        frame:SetScript("OnMouseWheel", function()
            if SlamFramesDB.locked then return end
            local key2 = this.frameKey
            local current = SlamFramesDB.scales[key2] or DEFAULT_SCALES[key2]
            local delta = arg1 or 0
            if delta > 0 then current = current + 0.05 else current = current - 0.05 end
            SF:SetFrameScale(key2, current, true)
        end)
    end
    UpdateFrameMouseState(frame)
end

local function MakePortrait(parent, cfg)
    local pf = CreateFrame("Frame", nil, parent)
    local p = cfg.portrait
    local slices = p.slices or 40

    pf.slices = {}
    pf.sliceDefs = {}
    pf.base = p
    pf.zoom = p.zoom or 1.0

    local i,t,v0n,v1n,vm,yn,half,u0n,u1n
    for i=1,slices do
        v0n = (i - 1) / slices
        v1n = i / slices
        vm = (v0n + v1n) * 0.5
        yn = (vm - 0.5) * 2
        half = math.sqrt(math.max(0, 1 - yn * yn)) * 0.5
        u0n = 0.5 - half
        u1n = 0.5 + half
        t = pf:CreateTexture(nil,"ARTWORK")
        pf.slices[i] = t
        pf.sliceDefs[i] = {u0n=u0n,u1n=u1n,v0n=v0n,v1n=v1n}
    end

    function pf:SetZoom(zoom)
        zoom=Clamp(tonumber(zoom) or self.base.zoom or 1.0,1.00,1.50)
        self.zoom=zoom
        local cropW=1/zoom
        local cropH=1/zoom
        local cropL=(1-cropW)*0.5+(self.base.offsetX or 0)
        local cropT=(1-cropH)*0.5+(self.base.offsetY or 0)
        cropL=Clamp(cropL,0,1-cropW)
        cropT=Clamp(cropT,0,1-cropH)
        local j,tex,d,u0,u1,v0,v1
        for j=1,table.getn(self.slices) do
            tex=self.slices[j]; d=self.sliceDefs[j]
            u0=cropL+d.u0n*cropW
            u1=cropL+d.u1n*cropW
            v0=cropT+d.v0n*cropH
            v1=cropT+d.v1n*cropH
            tex.sfTexCoord={u0,u1,v0,v1}
            tex:SetTexCoord(u0,u1,v0,v1)
        end
    end

    function pf:SetLayout(scale, xShift)
        local size = self.base.size * scale
        xShift = xShift or 0
        self:SetWidth(size); self:SetHeight(size)
        self:ClearAllPoints()
        self:SetPoint("CENTER", parent, "BOTTOMLEFT", (self.base.x + xShift) * scale, self.base.y * scale)
        local bandH = size / table.getn(self.slices)
        local j,tex,d
        for j=1,table.getn(self.slices) do
            tex=self.slices[j]; d=self.sliceDefs[j]
            tex:ClearAllPoints()
            tex:SetWidth(math.max(1, size * (d.u1n-d.u0n) + 1.5*scale))
            tex:SetHeight(bandH + 1.25*scale)
            tex:SetPoint("TOP",self,"TOP",0,-((j-1)*bandH))
        end
    end

    function pf:SetUnit(unit)
        local j,tex,c
        for j=1,table.getn(self.slices) do
            tex=self.slices[j]
            SetPortraitTexture(tex,unit)
            c=tex.sfTexCoord
            tex:SetTexCoord(c[1],c[2],c[3],c[4])
            tex:Show()
        end
    end
    function pf:SetImage(path)
        local j,tex,c
        for j=1,table.getn(self.slices) do
            tex=self.slices[j]; tex:SetTexture(path); c=tex.sfTexCoord
            tex:SetTexCoord(c[1],c[2],c[3],c[4]); tex:Show()
        end
    end
    function pf:ClearImage()
        local j
        for j=1,table.getn(self.slices) do self.slices[j]:SetTexture(nil) end
    end

    pf:SetFrameLevel(parent:GetFrameLevel()+2)
    pf:SetZoom(p.zoom or 1.0)
    pf:SetLayout(1)
    return pf
end

local function CreateUnitFrame(kind,key,unit,cfg)
    local f=CreateFrame("Frame","SlamFrames_"..kind,UIParent)
    f.unit=unit; f.cfg=cfg; f.frameKey=key; f.layoutScale=1

    f.portrait=MakePortrait(f,cfg)

    f.artFrame=CreateFrame("Frame",nil,f)
    f.artFrame:SetAllPoints(f); f.artFrame:SetFrameLevel(f:GetFrameLevel()+5)
    f.art=MakeFrameTexture(f.artFrame,cfg)

    f.barFrame=CreateFrame("Frame",nil,f)
    f.barFrame:SetAllPoints(f); f.barFrame:SetFrameLevel(f:GetFrameLevel()+10)
    f.health=Bars:Create(f.barFrame,cfg.health,TEX,"health_fill.tga")
    f.health:SetSmooth(SlamFramesDB.smoothBars)
    if cfg.power then
        f.power=Bars:Create(f.barFrame,cfg.power,TEX,"power_fill.tga")
        f.power:SetSmooth(SlamFramesDB.smoothBars)
        if key=="party" then
            -- Party resources are a real second bar, not an overlay hidden
            -- behind the health bar. Dragonflight: Reloaded's Turtle/1.18
            -- implementation uses the same UnitMana/UnitPowerType APIs with a
            -- dedicated 7px party power bar, so keep ours separate and force
            -- it one frame level above the health bar.
            f.power:SetFrameLevel(f.barFrame:GetFrameLevel()+2)
            f.partyPowerBg=f.power:CreateTexture(nil,"BACKGROUND")
            f.partyPowerBg:SetTexture("Interface\\Buttons\\WHITE8X8")
            f.partyPowerBg:SetVertexColor(0.035,0.040,0.050,0.96)
            f.partyPowerBg:SetAllPoints(f.power)
        end
    end

    f.textFrame=CreateFrame("Frame",nil,f)
    f.textFrame:SetAllPoints(f); f.textFrame:SetFrameLevel(f:GetFrameLevel()+20)

    f.name=MakeText(f.textFrame,cfg.name.font,cfg.name.justify,cfg.name.fontPath,cfg.name.flags)

    if cfg.levelBadge then
        f.levelBadge=CreateFrame("Frame",nil,f)
        f.levelBadge:SetFrameLevel(f:GetFrameLevel()+25)
        f.levelBadgeTexture=f.levelBadge:CreateTexture(nil,"ARTWORK")
        f.levelBadgeTexture:SetAllPoints(f.levelBadge)
        f.levelBadgeTexture:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(C.levelBadgeTexture or "level_badge.tga")) or (TEX..(C.levelBadgeTexture or "level_badge.tga")))
        f.levelText=MakeText(f.levelBadge,cfg.levelBadge.font or 16,"CENTER",cfg.levelBadge.fontPath,cfg.levelBadge.flags)
        f.levelText:SetTextColor(1.0,0.82,0.0)
        f.levelSkull=f.levelBadge:CreateTexture(nil,"OVERLAY")
        f.levelSkull:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
        f.levelSkull:SetVertexColor(1.0,0.15,0.10)
        f.levelSkull:Hide()
    end

    f.healthPercentText=MakeText(f.textFrame,cfg.healthPercentFont or 13,"CENTER")
    f.healthPercentText:SetTextColor(1,1,1)
    f.healthValueText=MakeText(f.textFrame,cfg.healthValueFont or 10,"CENTER")
    f.healthValueText:SetTextColor(1,1,1)
    if cfg.power then
        f.powerText=MakeText(f.textFrame,cfg.powerFont or 11,"CENTER")
        f.powerText:SetTextColor(1,1,1)
    end

    f.moveLabel=MakeText(f.textFrame,12,"CENTER")
    f.moveLabel:SetTextColor(1,0.35,0.10); f.moveLabel:Hide()

    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    SetupDrag(f,key)
    return f
end

SF.CreateUnitFrame = CreateUnitFrame

local function LayoutText(frame,scale,trim)
    local cfg=frame.cfg
    trim=trim or 0
    local nameScale=(SlamFramesDB and SlamFramesDB.nameTextScale) or 1.30
    local healthScale=(SlamFramesDB and SlamFramesDB.healthTextScale) or 1.00
    local powerScale=(SlamFramesDB and SlamFramesDB.powerTextScale) or 1.00
    local levelScale=(SlamFramesDB and SlamFramesDB.levelTextScale) or 1.00

    -- Name: geometry follows the unit frame, font size has its own multiplier.
    frame.name:ClearAllPoints()
    local nameX=cfg.name.x
    if frame.frameKey=="party" then nameX=nameX+(tonumber(SlamFramesDB.partyNameOffset) or 0) end
    if frame.frameKey=="raid" then nameX=nameX+(tonumber(SlamFramesDB.raidNameOffset) or 0) end
    frame.name:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",nameX*scale,cfg.name.y*scale)
    frame.name:SetWidth(math.max(40,cfg.name.w-trim)*scale)
    frame.name:SetHeight(math.max(cfg.name.h*scale,(cfg.name.font+8)*scale*nameScale))
    SetScaledFont(frame.name,cfg.name.font,scale,nameScale)

    if frame.levelBadge then
        frame.levelBadge:ClearAllPoints()
        local levelX=cfg.levelBadge.x
        if frame.frameKey=="target" then levelX=levelX-trim end
        frame.levelBadge:SetPoint("CENTER",frame,"BOTTOMLEFT",levelX*scale,cfg.levelBadge.y*scale)
        frame.levelBadge:SetWidth(cfg.levelBadge.size*scale); frame.levelBadge:SetHeight(cfg.levelBadge.size*scale)
        frame.levelText:ClearAllPoints(); frame.levelText:SetPoint("CENTER",frame.levelBadge,"CENTER",0,0)
        frame.levelText:SetWidth(cfg.levelBadge.size*scale)
        frame.levelText:SetHeight(math.max(cfg.levelBadge.size*scale,(cfg.levelBadge.font+5)*scale*levelScale))
        SetScaledFont(frame.levelText,cfg.levelBadge.font,scale,levelScale)
        if frame.levelSkull then
            frame.levelSkull:ClearAllPoints()
            frame.levelSkull:SetPoint("CENTER",frame.levelBadge,"CENTER",0,0)
            frame.levelSkull:SetWidth(cfg.levelBadge.size*0.62*scale)
            frame.levelSkull:SetHeight(cfg.levelBadge.size*0.62*scale)
        end
    end

    -- Health text is anchored to the health bar itself rather than to the
    -- outer artwork. Changing font size therefore never changes its center.
    frame.healthPercentText:ClearAllPoints()
    frame.healthPercentText:SetPoint("CENTER",frame.health,"CENTER",0,0)
    frame.healthPercentText:SetWidth(math.max(20,cfg.health.w-trim)*scale)
    frame.healthPercentText:SetHeight(math.max(cfg.health.h*scale,(cfg.healthPercentFont+6)*scale*healthScale))
    SetScaledFont(frame.healthPercentText,cfg.healthPercentFont,scale,healthScale)

    frame.healthValueText:ClearAllPoints()
    frame.healthValueText:SetPoint("CENTER",frame.health,"CENTER",0,0)
    frame.healthValueText:SetWidth(math.max(20,cfg.health.w-trim)*scale)
    frame.healthValueText:SetHeight(math.max(cfg.health.h*scale,(cfg.healthValueFont+6)*scale*healthScale))
    SetScaledFont(frame.healthValueText,cfg.healthValueFont,scale,healthScale)

    -- Resource text stays mathematically centered in the bar at every size.
    if frame.powerText and cfg.power then
        frame.powerText:ClearAllPoints()
        frame.powerText:SetPoint("CENTER",frame.power,"CENTER",0,0)
        frame.powerText:SetWidth(math.max(20,cfg.power.w-trim)*scale)
        frame.powerText:SetHeight(math.max(cfg.power.h*scale,(cfg.powerFont+6)*scale*powerScale))
        SetScaledFont(frame.powerText,cfg.powerFont,scale,powerScale)
    end

    frame.moveLabel:ClearAllPoints(); frame.moveLabel:SetPoint("TOP",frame,"TOP",0,16*scale)
    frame.moveLabel:SetWidth(math.max(100,cfg.width-trim)*scale); frame.moveLabel:SetHeight(18*scale)
    SetScaledFont(frame.moveLabel,12,scale,1.00)
end

function SF:LayoutFrame(frame,key,scale)
    if not frame then return end
    local cfg=frame.cfg
    scale=Clamp(scale or DEFAULT_SCALES[key],0.40,3.00)
    local trim=GetWidthTrim(key,cfg)
    frame.layoutScale=scale
    frame.widthTrim=trim
    frame:SetScale(1)
    frame:SetWidth(math.max(100,cfg.width-trim)*scale); frame:SetHeight(cfg.height*scale)
    if frame.art and frame.art.SetLayout then frame.art:SetLayout(scale,trim) end

    -- Player portrait stays fixed to the left endcap. Target portrait moves
    -- inward with the fixed right endcap as the bar gets shorter.
    local portraitShift=0
    if key=="target" then portraitShift=-trim end
    local portraitZoom=(SlamFramesDB.portraitZooms and SlamFramesDB.portraitZooms[key]) or cfg.portrait.zoom or 1.00
    frame.portrait:SetZoom(portraitZoom)
    frame.portrait:SetLayout(scale,portraitShift)

    frame.health:SetLayout(scale,trim)
    if frame.power then
        frame.power:SetLayout(scale,trim)
        if key=="party" and not SlamFramesDB.showPartyPower then frame.power:Hide() end
    end
    LayoutText(frame,scale,trim)
    if key=="target" then self:LayoutAuras() end
    if key=="player" and self.LayoutPlayerEffects then self:LayoutPlayerEffects() end
    self:ApplyHealthTextMode(frame)
end

function SF:LayoutPartyFrames()
    if not self.partyFrames then return end
    local scale=SlamFramesDB.scales.party or DEFAULT_SCALES.party
    local spacing=(SlamFramesDB.partySpacing or 8)*scale
    local i,f,previous
    for i=1,table.getn(self.partyFrames) do
        f=self.partyFrames[i]
        if f then
            self:LayoutFrame(f,"party",scale)
            f:ClearAllPoints()
            if i==1 then
                ApplyAnchor(f,"party")
            else
                previous=self.partyFrames[i-1]
                f:SetPoint("TOPLEFT",previous,"BOTTOMLEFT",0,-spacing)
            end
        end
    end
    self:RefreshFrameLayers(self.topFrameKey)
end

function SF:SetFrameScale(key,value,quiet)
    key=NormalizeKey(key)
    if not key then return end
    value=Clamp(tonumber(value) or DEFAULT_SCALES[key] or 0.60,0.40,3.00)
    SlamFramesDB.scales[key]=value
    if key=="party" then
        self:LayoutPartyFrames()
    elseif key=="raid" then
        if self.LayoutRaidFrames then self:LayoutRaidFrames() end
    else
        local f=FrameForKey(key)
        if f then self:LayoutFrame(f,key,value) end
    end
    self:UpdateMoveLabels()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet then Print(key.." scale set to "..string.format("%.2f",value)) end
end

local function RelayoutAllText()
    if SF.player then
        SF:LayoutFrame(SF.player,"player",SlamFramesDB.scales.player or DEFAULT_SCALES.player)
        SF:LayoutFrame(SF.target,"target",SlamFramesDB.scales.target or DEFAULT_SCALES.target)
        SF:LayoutFrame(SF.tot,"tot",SlamFramesDB.scales.tot or DEFAULT_SCALES.tot)
        if SF.LayoutPartyFrames then SF:LayoutPartyFrames() end
        if SF.LayoutRaidFrames then SF:LayoutRaidFrames() end
    end
    if SF.RefreshSettings then SF:RefreshSettings() end
end

function SF:SetNameTextScale(value,quiet)
    value=Clamp(tonumber(value) or 1.30,0.60,2.00)
    SlamFramesDB.nameTextScale=value
    RelayoutAllText()
    if not quiet then Print("name text scale set to "..string.format("%.2f",value)) end
end

function SF:SetHealthTextScale(value,quiet)
    value=Clamp(tonumber(value) or 1.00,0.60,2.00)
    SlamFramesDB.healthTextScale=value
    RelayoutAllText()
    if not quiet then Print("health text scale set to "..string.format("%.2f",value)) end
end

function SF:SetPowerTextScale(value,quiet)
    value=Clamp(tonumber(value) or 1.00,0.60,2.00)
    SlamFramesDB.powerTextScale=value
    RelayoutAllText()
    if not quiet then Print("resource text scale set to "..string.format("%.2f",value)) end
end

function SF:SetLevelTextScale(value,quiet)
    value=Clamp(tonumber(value) or 1.00,0.60,2.00)
    SlamFramesDB.levelTextScale=value
    RelayoutAllText()
    if not quiet then Print("level text scale set to "..string.format("%.2f",value)) end
end

-- Backward-compatible command: sets all text categories together. The settings
-- panel no longer exposes this because independent controls are much cleaner.
function SF:SetTextScale(value,quiet)
    value=Clamp(tonumber(value) or 1.00,0.60,2.00)
    SlamFramesDB.nameTextScale=value
    SlamFramesDB.healthTextScale=value
    SlamFramesDB.powerTextScale=value
    SlamFramesDB.levelTextScale=value
    RelayoutAllText()
    if not quiet then Print("all text scales set to "..string.format("%.2f",value)) end
end

function SF:SetAuraScale(value,quiet)
    value=Clamp(tonumber(value) or 1.00,0.60,2.00)
    SlamFramesDB.auraScale=value
    self:LayoutAuras()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet then Print("aura size scale set to "..string.format("%.2f",value)) end
end

function SF:SetAuraRowSpacing(value,quiet)
    value=Clamp(tonumber(value) or 1.00,0.00,12.00)
    value=math.floor(value*2+0.5)/2
    SlamFramesDB.auraRowSpacing=value
    self:LayoutAuras()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet then Print("aura row spacing set to "..string.format("%.1f",value)..".") end
end

function SF:SetAuraTimerText(v,quiet)
    SlamFramesDB.auraShowTimerText=v and true or false
    self:UpdateAuras()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet then Print("target aura timer text "..(SlamFramesDB.auraShowTimerText and "ON" or "OFF")..".") end
end

function SF:SetAuraTimerTextScale(value,quiet)
    value=Clamp(tonumber(value) or 1.00,0.50,2.00)
    value=math.floor(value*20+0.5)/20
    SlamFramesDB.auraTimerTextScale=value
    self:LayoutAuras()
    self:UpdateAuras()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet then Print("target aura timer size set to "..tostring(math.floor(value*100+0.5)).."%.") end
end


function SF:SetCombatGlowIntensity(value,quiet)
    value=Clamp(tonumber(value) or 1.30,0.50,2.00)
    value=math.floor(value*100+0.5)/100
    SlamFramesDB.combatGlowIntensity=value
    if self.UpdatePlayerEffects then self:UpdatePlayerEffects(true) end
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet then Print("combat glow intensity set to "..tostring(math.floor(value*100+0.5)).."%") end
    return true
end

function SF:SetPortraitZoom(key,value,quiet)
    key=NormalizeKey(key)
    if key~="player" and key~="target" and key~="tot" and key~="party" and key~="raid" then return false end
    value=Clamp(tonumber(value) or 1.00,1.00,1.50)
    value=math.floor(value*100+0.5)/100
    SlamFramesDB.portraitZooms[key]=value
    if (key=="party" or key=="raid") then
        local frames=(key=="party") and self.partyFrames or self.raidFrames
        local i
        if frames then for i=1,table.getn(frames) do if frames[i] and frames[i].portrait then frames[i].portrait:SetZoom(value) end end end
    else
        local f=FrameForKey(key)
        if f and f.portrait then f.portrait:SetZoom(value) end
    end
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet then Print(key.." portrait zoom set to "..string.format("%.2f",value)) end
    return true
end

function SF:ResetToTRelative()
    SlamFramesDB.anchors.tot={point=DEFAULT_TOT_RELATION.point,relativePoint=DEFAULT_TOT_RELATION.relativePoint,relativeKey="targetHealth",x=DEFAULT_TOT_RELATION.x,y=DEFAULT_TOT_RELATION.y}
    if self.tot then ApplyAnchor(self.tot,"tot") end
    self:RefreshFrameLayers(self.topFrameKey)
    if self.RefreshSettings then self:RefreshSettings() end
    Print("Target of Target reset beneath the target health bar.")
end

function SF:SetWidthPreset(key,value,quiet)
    key=NormalizeKey(key)
    if key~="player" and key~="target" and key~="tot" and key~="party" and key~="raid" then
        if not quiet then Print("bar length is adjustable for player, target, target-of-target, party, or raid") end
        return false
    end
    local cfg=(key=="player") and C.player or ((key=="target") and C.target or ((key=="tot") and C.tot or ((key=="raid") and C.raid or C.party)))
    local maxPreset=(cfg.widthSlices and cfg.widthSlices.maxPreset) or 0
    value=Clamp(math.floor((tonumber(value) or 0)+0.5),0,maxPreset)
    SlamFramesDB.widthPresets[key]=value
    if key=="party" then
        self:LayoutPartyFrames()
    elseif key=="raid" then
        if self.LayoutRaidFrames then self:LayoutRaidFrames() end
    else
        local f=FrameForKey(key)
        if f then self:LayoutFrame(f,key,SlamFramesDB.scales[key] or DEFAULT_SCALES[key]) end
    end
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet then Print(key.." bar length set to "..WidthPercent(key,cfg).."%") end
    return true
end

function SF:ApplyPositions()
    if not self.player then return end
    self:LayoutFrame(self.player,"player",SlamFramesDB.scales.player or DEFAULT_SCALES.player)
    self:LayoutFrame(self.target,"target",SlamFramesDB.scales.target or DEFAULT_SCALES.target)
    self:LayoutFrame(self.tot,"tot",SlamFramesDB.scales.tot or DEFAULT_SCALES.tot)
    ApplyAnchor(self.player,"player"); ApplyAnchor(self.target,"target"); ApplyAnchor(self.tot,"tot")
    self:LayoutPartyFrames()
    if self.LayoutRaidFrames then self:LayoutRaidFrames() end
    self:RefreshFrameLayers(self.topFrameKey)
end

function SF:UpdateMoveLabels()
    local _,key,f
    for _,key in pairs({"player","target","tot"}) do
        f=FrameForKey(key)
        if f and f.moveLabel then
            f.moveLabel:SetText(string.upper(key).."  "..string.format("%.2f",SlamFramesDB.scales[key] or DEFAULT_SCALES[key]).."x")
            if SlamFramesDB.locked then f.moveLabel:Hide() else f.moveLabel:Show() end
            UpdateFrameMouseState(f)
        end
    end
    if self.partyFrames then
        local i
        for i=1,table.getn(self.partyFrames) do
            f=self.partyFrames[i]
            if f and f.moveLabel then
                if i==1 and not SlamFramesDB.locked then
                    f.moveLabel:SetText("PARTY  "..string.format("%.2f",SlamFramesDB.scales.party or DEFAULT_SCALES.party).."x")
                    f.moveLabel:Show()
                else
                    f.moveLabel:Hide()
                end
                UpdateFrameMouseState(f)
            end
        end
    end
    if self.raidFrames then
        local i
        for i=1,table.getn(self.raidFrames) do
            f=self.raidFrames[i]
            if f and f.moveLabel then
                if i==1 and not SlamFramesDB.locked then f.moveLabel:SetText("RAID  "..string.format("%.2f",SlamFramesDB.scales.raid or DEFAULT_SCALES.raid).."x"); f.moveLabel:Show() else f.moveLabel:Hide() end
                UpdateFrameMouseState(f)
            end
        end
    end
end

function SF:SetSmoothBars(enabled)
    SlamFramesDB.smoothBars=enabled and true or false
    local frames={self.player,self.target,self.tot}
    local i,f
    if self.partyFrames then for i=1,table.getn(self.partyFrames) do table.insert(frames,self.partyFrames[i]) end end
    if self.raidFrames then for i=1,table.getn(self.raidFrames) do table.insert(frames,self.raidFrames[i]) end end
    for i=1,table.getn(frames) do
        f=frames[i]
        if f then
            if f.health then f.health:SetSmooth(SlamFramesDB.smoothBars) end
            if f.power then f.power:SetSmooth(SlamFramesDB.smoothBars) end
        end
    end
    if self.RefreshSettings then self:RefreshSettings() end
end

local function HealthTextModeForFrame(f)
    if f and f.frameKey=="tot" then
        local mode=SlamFramesDB.totHealthTextMode or "percent"
        if mode=="amount" then return "amount" end
        return "percent"
    end
    if f and f.frameKey=="party" then
        local mode=SlamFramesDB.partyHealthTextMode or "percent"
        if mode=="amount" or mode=="off" then return mode end
        return "percent"
    end
    if f and f.frameKey=="raid" then
        local mode=SlamFramesDB.raidHealthTextMode or "percent"
        if mode=="amount" or mode=="off" then return mode end
        return "percent"
    end
    return SlamFramesDB.healthTextMode or "percent"
end

function SF:ApplyHealthTextMode(f)
    if not f then return end
    local mode=HealthTextModeForFrame(f)
    local cfg=f.cfg
    local scale=f.layoutScale or 1

    if mode=="percent" then
        f.healthPercentText:ClearAllPoints()
        f.healthPercentText:SetPoint("CENTER",f.health,"CENTER",0,0)
        f.healthValueText:SetText("")
    elseif mode=="amount" then
        f.healthValueText:ClearAllPoints()
        f.healthValueText:SetPoint("CENTER",f.health,"CENTER",0,0)
        f.healthPercentText:SetText("")
    elseif mode=="both" then
        f.healthPercentText:ClearAllPoints()
        f.healthPercentText:SetPoint("CENTER",f.health,"CENTER",0,(cfg.healthPercentOffset or 5)*scale)
        f.healthValueText:ClearAllPoints()
        f.healthValueText:SetPoint("CENTER",f.health,"CENTER",0,(cfg.healthValueOffset or -8)*scale)
    else
        f.healthPercentText:SetText("")
        f.healthValueText:SetText("")
    end
end

function SF:SetHealthTextMode(mode,quiet)
    mode=string.lower(mode or "")
    if mode~="percent" and mode~="amount" and mode~="both" and mode~="off" then return false end
    SlamFramesDB.healthTextMode=mode
    self:RefreshAll()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet then Print("health text: "..mode) end
    return true
end

function SF:SetToTHealthTextMode(mode,quiet)
    mode=string.lower(mode or "")
    if mode~="percent" and mode~="amount" then return false end
    SlamFramesDB.totHealthTextMode=mode
    if self.tot then self:UpdateTargetOfTarget() end
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet then Print("ToT health text: "..mode) end
    return true
end

function SF:SetPartyHealthTextMode(mode,quiet)
    mode=string.lower(mode or "")
    if mode~="percent" and mode~="amount" and mode~="off" then return false end
    SlamFramesDB.partyHealthTextMode=mode
    self:UpdatePartyFrames()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet then Print("party health text: "..mode) end
    return true
end

function SF:SetPartyNameOffset(value,quiet)
    value=Clamp(tonumber(value) or 0,-150,150)
    value=Clamp(math.floor((value+2.5)/5)*5,-150,150)
    SlamFramesDB.partyNameOffset=value
    self:LayoutPartyFrames()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet then Print("party name X set to "..value) end
end

function SF:SetPartySpacing(value,quiet)
    value=Clamp(tonumber(value) or 8,0,40)
    value=math.floor(value+0.5)
    SlamFramesDB.partySpacing=value
    self:LayoutPartyFrames()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet then Print("party spacing set to "..value) end
end

function SF:SetPartyFramesEnabled(v,quiet)
    SlamFramesDB.showPartyFrames=v and true or false
    self:UpdatePartyFrames()
    self:UpdateBlizzardPartyFrames()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet then Print("party frames "..(SlamFramesDB.showPartyFrames and "ON" or "OFF")) end
end

function SF:SetPartyHideInRaid(v,quiet)
    SlamFramesDB.partyHideInRaid=v and true or false
    self:UpdatePartyFrames()
    self:UpdateBlizzardPartyFrames()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet then Print("hide party frames in raid "..(SlamFramesDB.partyHideInRaid and "ON" or "OFF")) end
end

function SF:SetPartyPowerEnabled(v,quiet)
    SlamFramesDB.showPartyPower=v and true or false
    local i
    if self.partyFrames then
        for i=1,table.getn(self.partyFrames) do
            if SlamFramesDB.showPartyPower then
                self:UpdatePartyFramePower(i)
            elseif self.partyFrames[i] and self.partyFrames[i].power then
                self.partyFrames[i].power:Hide()
                if self.partyFrames[i].powerText then self.partyFrames[i].powerText:SetText("") end
            end
        end
    end
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet then Print("party resource bar "..(SlamFramesDB.showPartyPower and "ON" or "OFF")) end
end

function SF:ResetPartyPosition()
    SlamFramesDB.anchors.party=CopyAnchor(DEFAULT_ANCHORS.party); SlamFramesDB.anchors.raid=CopyAnchor(DEFAULT_ANCHORS.raid)
    self:LayoutPartyFrames()
    if self.RefreshSettings then self:RefreshSettings() end
    Print("party frame position reset.")
end

local function SetHealthTexts(f,cur,maxv)
    local mode=HealthTextModeForFrame(f)
    if maxv<=0 or mode=="off" then f.healthPercentText:SetText(""); f.healthValueText:SetText(""); return end
    local pct=math.floor((cur/maxv)*100+0.5).."%"
    local amount=FormatNumber(cur).." / "..FormatNumber(maxv)
    if mode=="percent" then f.healthPercentText:SetText(pct); f.healthValueText:SetText("")
    elseif mode=="amount" then f.healthPercentText:SetText(""); f.healthValueText:SetText(amount)
    else f.healthPercentText:SetText(pct); f.healthValueText:SetText(amount) end
    SF:ApplyHealthTextMode(f)
end

local function SetPowerText(f,cur,maxv)
    if not f.powerText then return end
    if not SlamFramesDB.showPowerNumbers or maxv<=0 then f.powerText:SetText(""); return end
    f.powerText:SetText(FormatNumber(cur).." / "..FormatNumber(maxv))
end

local function UpdatePortrait(frame)
    if SF.testMode and not UnitExists(frame.unit) then frame.portrait:SetImage("Interface\\Icons\\INV_Misc_QuestionMark"); return end
    if UnitExists(frame.unit) then frame.portrait:SetUnit(frame.unit) else frame.portrait:ClearImage() end
end

local function UnitDisplayName(unit,testName)
    if SF.testMode and not UnitExists(unit) then return testName or "Unknown" end
    if not UnitExists(unit) then return "" end
    return UnitName(unit) or ""
end

local function UnitLevelLabel(unit,testLevel)
    if SF.testMode and not UnitExists(unit) then return tostring(testLevel or 80) end
    if not UnitExists(unit) then return "" end
    local level=UnitLevel(unit)
    if not level or level==0 then return "" end
    if level<0 then return "??" end
    return tostring(level)
end

local function UnitIsHostileForLevel(unit,testEnemy)
    if SF.testMode and not UnitExists(unit) then return testEnemy and true or false end
    if not UnitExists(unit) then return false end
    if UnitCanAttack then return UnitCanAttack("player",unit) and true or false end
    if UnitIsFriend then return not UnitIsFriend("player",unit) end
    return false
end

local function GrayMobLevel(playerLevel)
    playerLevel=tonumber(playerLevel) or 1
    if playerLevel<=5 then return 0 end
    if playerLevel<=39 then return playerLevel-5-math.floor(playerLevel/10) end
    if playerLevel<=59 then return playerLevel-1-math.floor(playerLevel/5) end
    -- Level 60 Vanilla/Turtle rule: mobs 51 and below are gray.  Keeping the
    -- same nine-level gap above 60 is a safe fallback for custom servers.
    return playerLevel-9
end

local function DifficultyColor(level, playerLevel)
    -- Do NOT use GetQuestDifficultyColor here.  Quest difficulty and mob XP
    -- difficulty do not share the same gray cutoff on Vanilla-era clients.
    -- Example: a level 15 player still earns XP from a level 10 mob, so it must
    -- be green rather than gray.
    playerLevel=tonumber(playerLevel) or UnitLevel("player") or 1
    level=tonumber(level) or playerLevel
    local d=level-playerLevel
    if d>=5 then return 1.00,0.10,0.10 end       -- red
    if d>=3 then return 1.00,0.45,0.05 end       -- orange
    if d>=-2 then return 1.00,0.90,0.10 end      -- yellow
    if level>GrayMobLevel(playerLevel) then
        return 0.25,1.00,0.25                    -- green: still grants XP
    end
    return 0.55,0.55,0.55                        -- gray: trivial / no XP
end

local function SetLevelIndicator(f,unit,testLevel,testEnemy)
    if not f or not f.levelText then return end
    local exists=UnitExists(unit)
    local level
    if SF.testMode and not exists then level=testLevel or 80 else level=UnitLevel(unit) end
    if not level or level==0 then
        f.levelText:SetText(""); f.levelText:Show()
        if f.levelSkull then f.levelSkull:Hide() end
        return
    end

    local enemy=UnitIsHostileForLevel(unit,testEnemy)
    local playerLevel=(SF.testMode and not exists) and 80 or (UnitLevel("player") or 1)
    local skull=enemy and (level<0 or (level>0 and playerLevel>0 and level>=playerLevel+10))

    if skull and f.levelSkull then
        f.levelText:SetText(""); f.levelText:Hide(); f.levelSkull:Show()
        return
    end

    if f.levelSkull then f.levelSkull:Hide() end
    f.levelText:Show()
    f.levelText:SetText(level<0 and "??" or tostring(level))
    if enemy then
        local r,g,b=DifficultyColor(level,playerLevel)
        f.levelText:SetTextColor(r,g,b)
    else
        f.levelText:SetTextColor(1.0,0.82,0.0)
    end
end

function SF:UpdatePlayer()
    local f=self.player; if not f then return end
    local cur,maxv,pcur,pmax
    if self.testMode then cur,maxv,pcur,pmax=8342,8500,18,100
    else cur,maxv=UnitHealth("player") or 0,UnitHealthMax("player") or 1; pcur,pmax=UnitMana("player") or 0,UnitManaMax("player") or 0 end
    f.health:SetValue(cur,maxv,self.testMode); SetHealthTexts(f,cur,maxv)
    if f.power then local r,g,b=PowerColor("player"); f.power:SetFillColor(r,g,b,1); f.power:SetValue(pcur,pmax,self.testMode); SetPowerText(f,pcur,pmax) end
    f.name:SetText(self.testMode and "Cenotaph" or (UnitName("player") or "Player"))
    SetLevelIndicator(f,"player",80,false)
    UpdatePortrait(f); f:Show()
end

function SF:UpdateTarget()
    local f=self.target; if not f then return end
    if not UnitExists("target") and not self.testMode then f:Hide(); if self.tot then self.tot:Hide() end; self:UpdateAuras(); return end
    local cur,maxv,pcur,pmax
    if self.testMode and not UnitExists("target") then cur,maxv,pcur,pmax=12420,12420,0,100
    else cur,maxv=UnitHealth("target") or 0,UnitHealthMax("target") or 1; pcur,pmax=UnitMana("target") or 0,UnitManaMax("target") or 0 end
    f.health:SetValue(cur,maxv,self.testMode); SetHealthTexts(f,cur,maxv)
    if f.power then local r,g,b=PowerColor("target"); f.power:SetFillColor(r,g,b,1); f.power:SetValue(pcur,pmax,self.testMode); SetPowerText(f,pcur,pmax) end
    f.name:SetText(UnitDisplayName("target","Blackrock Grunt")); SetLevelIndicator(f,"target",82,true)
    UpdatePortrait(f); f:Show(); self:UpdateTargetOfTarget(); self:UpdateAuras()
end

function SF:UpdateTargetOfTarget()
    local f=self.tot; if not f then return end
    -- When Player-frame self targeting is enabled, selecting yourself should
    -- not create a redundant self -> self Target-of-Target frame. Test mode
    -- intentionally bypasses this so layout previews still show all frames.
    if SlamFramesDB.selfTargetOnClick and TargetIsPlayer() and not self.testMode then f:Hide(); return end
    if not UnitExists("targettarget") and not self.testMode then f:Hide(); return end
    local cur,maxv
    if self.testMode and not UnitExists("targettarget") then cur,maxv=5210,5210 else cur,maxv=UnitHealth("targettarget") or 0,UnitHealthMax("targettarget") or 1 end
    f.health:SetValue(cur,maxv,self.testMode); SetHealthTexts(f,cur,maxv)
    f.name:SetText(UnitDisplayName("targettarget","Ragepaw Worg")); SetLevelIndicator(f,"targettarget",82,true)
    UpdatePortrait(f); f:Show()
end

function SF:IsInRaidGroup()
    if type(GetNumRaidMembers)=="function" then
        local ok,n=pcall(GetNumRaidMembers)
        if ok and (tonumber(n) or 0)>0 then return true end
    end
    return false
end

local PARTY_TEST_NAMES={"Aegis","Moonleaf","Ashen","Stormcall"}
local PARTY_TEST_HEALTH={{6840,7200},{5120,6900},{7990,8100},{4360,6200}}
local PARTY_TEST_POWER={
    {64,100,0.05,0.45,1.00}, -- mana
    {72,100,0.95,0.12,0.08}, -- rage
    {48,100,0.95,0.78,0.10}, -- energy
    {87,100,0.05,0.45,1.00}, -- mana
}

function SF:UpdatePartyFrame(index)
    local f=self.partyFrames and self.partyFrames[index]
    if not f then return end
    local unit="party"..index
    f.unit=unit

    if not SlamFramesDB.showPartyFrames then f:Hide(); return end
    if SlamFramesDB.partyHideInRaid and self:IsInRaidGroup() and not self.testMode then f:Hide(); return end
    if not UnitExists(unit) and not self.testMode then f:Hide(); return end

    local cur,maxv
    if self.testMode and not UnitExists(unit) then
        cur=PARTY_TEST_HEALTH[index][1]; maxv=PARTY_TEST_HEALTH[index][2]
    else
        cur=UnitHealth(unit) or 0; maxv=UnitHealthMax(unit) or 1
    end
    f.health:SetValue(cur,maxv,self.testMode)
    SetHealthTexts(f,cur,maxv)
    f.name:SetText(UnitDisplayName(unit,PARTY_TEST_NAMES[index]))
    SetLevelIndicator(f,unit,math.max(1,(UnitLevel("player") or 60)-(index-1)),false)
    -- Party portraits are the most expensive part of a full member refresh:
    -- each circular portrait is composed from many texture slices. Queue the
    -- slices instead of calling SetPortraitTexture on all of them in one frame.
    if self.testMode and not UnitExists(unit) then
        UpdatePortrait(f)
    elseif self.QueuePartyPortraitUpdate then
        self:QueuePartyPortraitUpdate(index,false)
    else
        UpdatePortrait(f)
    end
    f:Show()
    self:UpdatePartyFramePower(index)
    if self.UpdateHealPredictionForFrame then self:UpdateHealPredictionForFrame(f,unit) end
end

function SF:UpdatePartyFramePower(index)
    local f=self.partyFrames and self.partyFrames[index]
    if not f or not f.power then return end
    local unit="party"..index
    f.unit=unit

    if not SlamFramesDB.showPartyFrames or not SlamFramesDB.showPartyPower then
        f.power:Hide()
        if f.powerText then f.powerText:SetText("") end
        return
    end
    if SlamFramesDB.partyHideInRaid and self:IsInRaidGroup() and not self.testMode then
        f.power:Hide()
        if f.powerText then f.powerText:SetText("") end
        return
    end
    if not UnitExists(unit) and not self.testMode then
        f.power:Hide()
        if f.powerText then f.powerText:SetText("") end
        return
    end

    local cur,maxv,r,g,b,powerType
    if self.testMode and not UnitExists(unit) then
        local d=PARTY_TEST_POWER[index] or PARTY_TEST_POWER[1]
        cur,maxv,r,g,b=d[1],d[2],d[3],d[4],d[5]
    else
        -- Vanilla/Turtle party frames expose all resource types through the
        -- UnitMana/UnitManaMax pair; UnitPowerType tells us how to color them.
        -- This is also the path used by Dragonflight: Reloaded on Turtle 1.18.
        cur=UnitMana(unit) or 0
        maxv=UnitManaMax(unit) or 0
        powerType=UnitPowerType(unit)
        r,g,b=PowerColor(unit)
        -- Some old-client/server combinations briefly report max=0 while a
        -- rage/energy token is settling. Keep the bar allocated instead of
        -- flashing it away; these resources use a 0-100 scale.
        if maxv<=0 and (powerType==1 or powerType==2 or powerType==3) then maxv=100 end
    end
    if maxv<=0 then
        f.power:Hide()
        if f.powerText then f.powerText:SetText("") end
        return
    end

    f.power:SetFillColor(r,g,b,1)
    f.power:SetValue(cur,maxv,self.testMode)
    f.power:Show()
    -- Party resource bars intentionally use color rather than numbers. Keeping
    -- text off preserves the compact frame and avoids extra font updates on
    -- rapid rage/energy events.
    if f.powerText then f.powerText:SetText(""); f.powerText:Hide() end
end

function SF:QueuePartyPowerUpdate(index)
    if not index or index<1 or index>4 then return end
    self.partyPowerUpdatePending=self.partyPowerUpdatePending or {}
    self.partyPowerUpdatePending[index]=true
end

function SF:ProcessPartyPowerUpdates(elapsed)
    if not self.partyPowerUpdatePending or self.partyRosterRefreshPending then return end
    self.partyPowerUpdateElapsed=(tonumber(self.partyPowerUpdateElapsed) or 0)+(tonumber(elapsed) or 0)
    -- Cap Party resource rendering at 20 Hz. This coalesces rapid rage/energy
    -- event bursts without delaying normal visual feedback.
    if self.partyPowerUpdateElapsed<0.05 then return end
    self.partyPowerUpdateElapsed=0
    local i
    for i=1,4 do
        if self.partyPowerUpdatePending[i] then
            self.partyPowerUpdatePending[i]=nil
            self:UpdatePartyFramePower(i)
        end
    end
end

-- Party portrait work is deliberately amortized. A party portrait uses many
-- circular texture slices, so a four-member roster join can otherwise call
-- SetPortraitTexture hundreds of times in a very short burst on the Vanilla
-- client. Process only a handful of slices per rendered frame.
function SF:QueuePartyPortraitUpdate(index,force)
    if not index or index<1 or index>4 then return end
    local f=self.partyFrames and self.partyFrames[index]
    if not f or not f.portrait or not f.portrait.slices then return end
    local unit="party"..index
    local identity=UnitExists(unit) and (UnitName(unit) or unit) or ""
    if not force and f.sfPartyPortraitIdentity==identity and identity~="" then return end
    self.partyPortraitQueue=self.partyPortraitQueue or {}
    self.partyPortraitQueue[index]={slice=1,identity=identity,unit=unit,clear=(identity=="")}
end

function SF:ProcessPartyPortraitUpdates()
    local q=self.partyPortraitQueue
    if not q then return end
    local budget=6
    local i
    for i=1,4 do
        local job=q[i]
        if job and budget>0 then
            local f=self.partyFrames and self.partyFrames[i]
            local pf=f and f.portrait
            if not pf or not pf.slices then
                q[i]=nil
            else
                local identity=UnitExists(job.unit) and (UnitName(job.unit) or job.unit) or ""
                if identity~=job.identity then
                    job.identity=identity; job.slice=1; job.clear=(identity=="")
                end
                local count=table.getn(pf.slices)
                while job.slice<=count and budget>0 do
                    local tex=pf.slices[job.slice]
                    if job.clear then
                        tex:SetTexture(nil)
                    else
                        SetPortraitTexture(tex,job.unit)
                        local c=tex.sfTexCoord
                        if c then tex:SetTexCoord(c[1],c[2],c[3],c[4]) end
                        tex:Show()
                    end
                    job.slice=job.slice+1
                    budget=budget-1
                end
                if job.slice>count then
                    f.sfPartyPortraitIdentity=job.identity
                    q[i]=nil
                end
            end
        end
        if budget<=0 then break end
    end
end

function SF:UpdatePartyFrameHealth(index)
    local f=self.partyFrames and self.partyFrames[index]
    if not f then return end
    local unit="party"..index
    f.unit=unit

    if not SlamFramesDB.showPartyFrames then f:Hide(); return end
    if SlamFramesDB.partyHideInRaid and self:IsInRaidGroup() and not self.testMode then f:Hide(); return end
    if not UnitExists(unit) and not self.testMode then f:Hide(); return end

    local cur,maxv
    if self.testMode and not UnitExists(unit) then
        cur=PARTY_TEST_HEALTH[index][1]; maxv=PARTY_TEST_HEALTH[index][2]
    else
        cur=UnitHealth(unit) or 0; maxv=UnitHealthMax(unit) or 1
    end
    f.health:SetValue(cur,maxv,self.testMode)
    SetHealthTexts(f,cur,maxv)
    f:Show()
    if self.UpdateHealPredictionForFrame then self:UpdateHealPredictionForFrame(f,unit) end
end

function SF:UpdatePartyFrames()
    if not self.partyFrames then return end
    local i
    for i=1,table.getn(self.partyFrames) do self:UpdatePartyFrame(i) end
end

-- Party roster changes can arrive as a burst of PARTY_MEMBERS_CHANGED plus
-- UNIT_NAME_UPDATE / UNIT_PORTRAIT_UPDATE events.  Updating every portrait,
-- label, level, prediction and debuff alert synchronously in that burst causes
-- a visible hitch on the Vanilla client.  Collapse the burst, wait briefly for
-- the roster to settle, then refresh one party member per rendered frame.
function SF:QueuePartyRosterRefresh(reason)
    if not self.partyFrames then return end
    if self.partyRosterRefreshPending then
        -- A party join commonly emits several roster/leader events. Do not
        -- restart an in-progress refresh from member 1 for every duplicate.
        -- Before processing starts, only extend the short settle delay. Once
        -- processing has begun, request one final pass after the current one.
        if (tonumber(self.partyRosterRefreshIndex) or 1)<=1 then
            self.partyRosterRefreshDelay=0.08
        else
            self.partyRosterRefreshAgain=true
        end
        self.partyRosterRefreshReason=reason
        return
    end
    self.partyRosterRefreshPending=true
    self.partyRosterRefreshIndex=1
    self.partyRosterRefreshDelay=0.08
    self.partyRosterRefreshReason=reason
end

function SF:ProcessPartyRosterRefresh(elapsed)
    if not self.partyRosterRefreshPending then return end
    self.partyRosterRefreshDelay=(tonumber(self.partyRosterRefreshDelay) or 0)-(tonumber(elapsed) or 0)
    if self.partyRosterRefreshDelay>0 then return end

    local index=tonumber(self.partyRosterRefreshIndex) or 1
    if index<=4 then
        self:UpdatePartyFrame(index)
        if self.UpdatePartyDebuffAlert then self:UpdatePartyDebuffAlert(index) end
        self.partyRosterRefreshIndex=index+1
        return
    end

    local again=self.partyRosterRefreshAgain
    self.partyRosterRefreshPending=nil
    self.partyRosterRefreshIndex=nil
    self.partyRosterRefreshDelay=nil
    self.partyRosterRefreshReason=nil
    self.partyRosterRefreshAgain=nil
    if self.UpdateBlizzardPartyFrames then self:UpdateBlizzardPartyFrames() end
    if again then self:QueuePartyRosterRefresh("settled") end
end

local function IsTexturePath(v)
    if type(v)~="string" then return false end
    return string.find(v,"\\")~=nil or string.find(v,"Interface")~=nil or string.find(v,"Icons")~=nil
end

-- Live target aura timing ----------------------------------------------------
--
-- Stock Vanilla exposes an aura icon/stack/spell id but not a trustworthy
-- remaining duration for arbitrary targets.  OctoWoW installations commonly
-- pair SuperWoW with Nampower, whose aura events provide exact GUID + spell-id
-- application/removal information and, when available, exact durationMs.
--
-- SlamFrames keeps this state independently from the visual aura buttons.  It
-- mirrors the exact-GUID cache approach proven in SlamPlates: observe the aura
-- application once, store start/stop by GUID + spell id, then let the visible
-- target aura list decide which cached records are actually rendered.
SF.auraTimingCache=SF.auraTimingCache or {}
SF.auraTimingStats=SF.auraTimingStats or {
    registered={}, auraCast=0, auraAdded=0, auraRemoved=0, superCast=0,
    lastEvent=nil, lastSource=nil,
}
SF.auraPendingCasts=SF.auraPendingCasts or {}
SF.lastTargetAuraGuid=SF.lastTargetAuraGuid or nil

local function NormalizeAuraSpellId(id)
    id=tonumber(id)
    if not id then return nil end
    -- Some Vanilla APIs expose signed 16-bit spell IDs.
    if id < -1 then id=id+65536 end
    if id<=0 then return nil end
    return id
end

local function GetUnitGuidCompat(unit)
    if not unit then return nil end
    if type(UnitGUID)=="function" then
        local ok,guid=pcall(UnitGUID,unit)
        if ok and guid then return guid end
    end
    if type(GetUnitGUID)=="function" then
        local ok,guid=pcall(GetUnitGUID,unit)
        if ok and guid then return guid end
    end
    if type(UnitExists)=="function" then
        local ok,exists,guid=pcall(UnitExists,unit)
        if ok and exists and guid then return guid end
    end
    return nil
end
SF.GetUnitGuidCompat=GetUnitGuidCompat

local function GuidIsUnit(guid,unit)
    if not guid or not unit or type(UnitIsUnit)~="function" then return false end
    local ok,same=pcall(UnitIsUnit,guid,unit)
    return ok and same and true or false
end

local function RememberTargetAuraGuid(guid)
    if not guid then return end
    if GuidIsUnit(guid,"target") then
        SF.lastTargetAuraGuid=guid
    end
end

local function GetCurrentTargetAuraGuid()
    local direct=GetUnitGuidCompat("target")
    if direct then
        SF.lastTargetAuraGuid=direct
        return direct
    end

    local last=SF.lastTargetAuraGuid
    if last and GuidIsUnit(last,"target") then return last end

    -- SuperWoW accepts exact GUID strings as unit tokens.  If the normal
    -- target token did not expose a GUID, locate the current target among the
    -- GUIDs that Nampower/SuperWoW have already told us about.
    local guid
    for guid in pairs(SF.auraTimingCache) do
        if GuidIsUnit(guid,"target") then
            SF.lastTargetAuraGuid=guid
            return guid
        end
    end
    for guid in pairs(SF.auraPendingCasts) do
        if GuidIsUnit(guid,"target") then
            SF.lastTargetAuraGuid=guid
            return guid
        end
    end
    return nil
end
SF.GetCurrentTargetAuraGuid=GetCurrentTargetAuraGuid

local function GetNampowerSpellDuration(spellId)
    spellId=NormalizeAuraSpellId(spellId)
    if not spellId or type(GetSpellDuration)~="function" then return nil end
    local ms=tonumber(GetSpellDuration(spellId))
    if not ms or ms<=0 then return nil end
    -- Nampower documents GetSpellDuration in milliseconds.
    return ms/1000
end

local function EnsureAuraGuidTable(guid)
    if not guid then return nil end
    if type(SF.auraTimingCache[guid])~="table" then SF.auraTimingCache[guid]={} end
    return SF.auraTimingCache[guid]
end

local function CacheAuraTiming(guid,spellId,duration,kind,source,startTime,luaSlot,auraSlot,preferExistingStart)
    spellId=NormalizeAuraSpellId(spellId)
    duration=tonumber(duration)
    if not guid or not spellId or not duration or duration<=0 then return nil end
    local states=EnsureAuraGuidTable(guid)
    local old=states[spellId]
    local now=startTime or GetTime()

    -- AURA_CAST carries the most exact application timestamp/duration.  A
    -- following BUFF/DEBUFF_ADDED event should annotate kind/slot without
    -- moving that start time a few frames later.
    if preferExistingStart and old and old.start and old.stop and old.stop>GetTime() then
        old.kind=kind or old.kind
        old.luaSlot=luaSlot or old.luaSlot
        old.auraSlot=auraSlot or old.auraSlot
        if source then old.lastSource=source end
        return old
    end

    local rec=old or {}
    rec.spellId=spellId
    rec.duration=duration
    rec.start=now
    rec.stop=now+duration
    rec.kind=kind or rec.kind
    rec.luaSlot=luaSlot or rec.luaSlot
    rec.auraSlot=auraSlot or rec.auraSlot
    rec.source=source or rec.source or "observed"
    rec.lastSource=source or rec.lastSource
    rec.updated=GetTime()
    states[spellId]=rec
    RememberTargetAuraGuid(guid)
    return rec
end

local function RemoveAuraTiming(guid,spellId,kind)
    spellId=NormalizeAuraSpellId(spellId)
    local states=guid and SF.auraTimingCache[guid]
    if not states or not spellId then return end
    local rec=states[spellId]
    if rec and (not kind or not rec.kind or rec.kind==kind) then states[spellId]=nil end
    if not next(states) then SF.auraTimingCache[guid]=nil end
end

local function GetCachedAuraTiming(guid,spellId,kind)
    spellId=NormalizeAuraSpellId(spellId)
    if not guid or not spellId then return nil end
    local states=SF.auraTimingCache[guid]
    local rec=states and states[spellId]
    if not rec then return nil end
    if kind and rec.kind and rec.kind~=kind then return nil end
    local now=GetTime()
    if not rec.stop or rec.stop<=now then
        states[spellId]=nil
        if not next(states) then SF.auraTimingCache[guid]=nil end
        return nil
    end
    return rec
end

local function ConfirmPendingAura(guid,spellId,kind)
    spellId=NormalizeAuraSpellId(spellId)
    if not guid or not spellId then return nil end
    local pending=SF.auraPendingCasts[guid]
    local p=pending and pending[spellId]
    if not p then return nil end
    if GetTime()-(p.time or 0)>2.0 then pending[spellId]=nil; return nil end
    local duration=p.duration or GetNampowerSpellDuration(spellId)
    if duration and duration>0 then
        pending[spellId]=nil
        return CacheAuraTiming(guid,spellId,duration,kind,"superwow-cast",p.time,nil,nil,false)
    end
    return nil
end

local function PruneAuraTimingCache()
    local now=GetTime()
    local guid,states,id,rec
    for guid,states in pairs(SF.auraTimingCache) do
        for id,rec in pairs(states) do
            if not rec.stop or rec.stop<now-2 then states[id]=nil end
        end
        if not next(states) then SF.auraTimingCache[guid]=nil end
    end
    for guid,states in pairs(SF.auraPendingCasts) do
        for id,rec in pairs(states) do
            if not rec.time or now-rec.time>3 then states[id]=nil end
        end
        if not next(states) then SF.auraPendingCasts[guid]=nil end
    end
end

function SF:HandleNampowerAuraCast(spellId,casterGuid,targetGuid,effect,effectAuraName,effectAmplitude,effectMiscValue,durationMs,auraCapStatus)
    spellId=NormalizeAuraSpellId(spellId)
    local ms=tonumber(durationMs)
    local duration=(ms and ms>0) and (ms/1000) or GetNampowerSpellDuration(spellId)
    self.auraTimingStats.auraCast=(self.auraTimingStats.auraCast or 0)+1
    self.auraTimingStats.lastEvent="AURA_CAST"
    if targetGuid and spellId and duration and duration>0 then
        CacheAuraTiming(targetGuid,spellId,duration,nil,"nampower-aura-cast",GetTime(),nil,nil,false)
        self.auraTimingStats.lastSource="nampower-aura-cast"
    end
end

function SF:HandleNampowerAuraSlot(ev,guid,luaSlot,spellId,stackCount,auraLevel,auraSlot,state)
    spellId=NormalizeAuraSpellId(spellId)
    if not guid or not spellId then return end
    local isDebuff=string.find(ev or "","DEBUFF",1,true)~=nil
    local isRemoved=string.find(ev or "","REMOVED",1,true)~=nil
    local kind=isDebuff and "debuff" or "buff"
    RememberTargetAuraGuid(guid)

    if isRemoved and tonumber(state)~=2 then
        self.auraTimingStats.auraRemoved=(self.auraTimingStats.auraRemoved or 0)+1
        self.auraTimingStats.lastEvent=ev
        RemoveAuraTiming(guid,spellId,kind)
        return
    end

    self.auraTimingStats.auraAdded=(self.auraTimingStats.auraAdded or 0)+1
    self.auraTimingStats.lastEvent=ev
    local existing=GetCachedAuraTiming(guid,spellId,kind)
    if existing then
        existing.kind=kind; existing.luaSlot=tonumber(luaSlot) or existing.luaSlot; existing.auraSlot=tonumber(auraSlot) or existing.auraSlot
        existing.lastSource="nampower-aura-slot"
        return
    end

    -- state 2 is a stack modification, not a fresh application. If the
    -- original add predates SlamFrames, leaving it icon-only is more accurate
    -- than pretending the timer restarted now.
    if tonumber(state)==2 then return end

    local duration=GetNampowerSpellDuration(spellId)
    if duration and duration>0 then
        CacheAuraTiming(guid,spellId,duration,kind,"nampower-aura-slot",GetTime(),tonumber(luaSlot),tonumber(auraSlot),true)
        self.auraTimingStats.lastSource="nampower-aura-slot"
    end
end

function SF:HandleSuperWoWAuraCast(casterGuid,targetGuid,castType,spellId)
    spellId=NormalizeAuraSpellId(spellId)
    if not targetGuid or not spellId then return end
    local playerGuid=GetUnitGuidCompat("player")
    if playerGuid and casterGuid and casterGuid~=playerGuid then return end
    if castType and castType~="CAST" then return end
    local duration=GetNampowerSpellDuration(spellId)
    if not duration or duration<=0 then return end
    self.auraTimingStats.superCast=(self.auraTimingStats.superCast or 0)+1
    self.auraTimingStats.lastEvent="UNIT_CASTEVENT"
    self.auraPendingCasts[targetGuid]=self.auraPendingCasts[targetGuid] or {}
    self.auraPendingCasts[targetGuid][spellId]={time=GetTime(),duration=duration}
    RememberTargetAuraGuid(targetGuid)
end

-- OctoWoW/SuperWoW and pure 1.12 clients can expose different UnitBuff /
-- UnitDebuff return signatures. Normalize the common variants so the same
-- aura button can still show an icon, cooldown sweep, and native tooltip.
local function ReadTargetAura(kind,index)
    local r1,r2,r3,r4,r5,r6,r7,r8,r9,r10
    if kind=="debuff" then
        r1,r2,r3,r4,r5,r6,r7,r8,r9,r10=UnitDebuff("target",index)
    else
        r1,r2,r3,r4,r5,r6,r7,r8,r9,r10=UnitBuff("target",index)
    end
    if not r1 then return nil end

    local info={kind=kind,index=index,count=0,duration=0,timeLeft=0}

    -- Compatibility layers sometimes return a modern-style tuple. Preserve
    -- that direct duration data when it is genuinely present.
    if r3 and not IsTexturePath(r1) then
        info.name=r1
        info.icon=r3
        info.count=tonumber(r4) or 0

        local now=GetTime()
        local function Pair(d,v)
            d=tonumber(d); v=tonumber(v)
            if not d or d<=0 or not v or v<0 then return nil,nil end
            local left=v
            if v>d+1 and v>now then left=v-now end
            if left<0 then left=0 end
            if left>d+2 then return nil,nil end
            return d,left
        end
        local d,l=Pair(r5,r6)
        if not d then d,l=Pair(r6,r7) end
        if not d then d,l=Pair(r7,r8) end
        if d then info.duration=d; info.timeLeft=l end

        local vals={r5,r6,r7,r8,r9,r10}
        local j
        for j=1,table.getn(vals) do
            local n=NormalizeAuraSpellId(vals[j])
            if n and n~=info.duration and n~=info.timeLeft then info.spellId=n end
        end
    else
        -- SuperWoW/Vanilla style: UnitBuff usually exposes texture, stacks,
        -- spellId. UnitDebuff commonly places spellId in return 4.
        info.icon=r1
        info.count=tonumber(r2) or 0
        if kind=="debuff" then
            info.spellId=NormalizeAuraSpellId(r4) or NormalizeAuraSpellId(r3)
        else
            info.spellId=NormalizeAuraSpellId(r3) or NormalizeAuraSpellId(r4)
        end
    end

    if info.spellId and type(SpellInfo)=="function" then
        local ok,name,rank,icon=pcall(SpellInfo,info.spellId)
        if ok then
            info.name=name or info.name
            info.icon=icon or info.icon
        end
    end

    -- If the raw aura API did not provide a live remaining time, resolve it
    -- from the exact-GUID Nampower/SuperWoW cache.  This is intentionally done
    -- only after UnitBuff/UnitDebuff proves the aura is actually visible.
    if info.spellId and not (info.duration>0 and info.timeLeft>0) then
        local guid=GetCurrentTargetAuraGuid()
        if guid then
            local rec=GetCachedAuraTiming(guid,info.spellId,kind)
            if not rec then rec=ConfirmPendingAura(guid,info.spellId,kind) end
            if rec then
                rec.kind=rec.kind or kind
                rec.luaSlot=rec.luaSlot or index
                info.duration=rec.duration or 0
                info.timeLeft=math.max(0,(rec.stop or 0)-GetTime())
                info.timingSource=rec.source or rec.lastSource
            end
        end
    end

    return info
end

local function AuraOnEnter()
    if not this or not this.auraIndex then return end
    GameTooltip:SetOwner(this,"ANCHOR_BOTTOMRIGHT")
    local ok=false
    if this.auraType=="debuff" and GameTooltip.SetUnitDebuff then
        ok=pcall(function() GameTooltip:SetUnitDebuff("target",this.auraIndex) end)
    elseif this.auraType=="buff" and GameTooltip.SetUnitBuff then
        ok=pcall(function() GameTooltip:SetUnitBuff("target",this.auraIndex) end)
    end
    if not ok then
        GameTooltip:SetText(this.auraName or (this.auraType=="debuff" and "Debuff" or "Buff"),1,0.82,0)
        if this.auraDuration and this.auraDuration>0 and this.auraTimeLeft and this.auraTimeLeft>0 then
            GameTooltip:AddLine(string.format("%.1fs remaining",this.auraTimeLeft),1,1,1)
        end
    end
    GameTooltip:Show()
end

local function AuraOnLeave()
    GameTooltip:Hide()
end

function SF:CreateAuras()
    self.auras={}
    local i
    for i=1,C.aura.max do
        local a=CreateFrame("Button",nil,self.target)
        a:SetFrameLevel(self.target:GetFrameLevel()+30)
        a:EnableMouse(true)
        a:RegisterForClicks("LeftButtonUp","RightButtonUp")
        a.icon=a:CreateTexture(nil,"ARTWORK")
        a.cooldown=CreateFrame(COOLDOWN_FRAME_TYPE or "Model","SlamFramesTargetAuraCooldown"..i,a,"CooldownFrameTemplate")
        a.cooldown:SetFrameLevel(a:GetFrameLevel()+1)
        -- This frame is reserved for the native radial sweep only.  pfUI and
        -- other cooldown-count hooks commonly honor noCooldownCount; setting
        -- it here prevents them from replacing/augmenting the sweep with a
        -- numeric countdown.
        a.cooldown.noCooldownCount=true
        a.cooldown.pfCooldownStyleAnimation=1
        a.cooldown.pfCooldownStyleText=0
        if a.cooldown.EnableMouse then a.cooldown:EnableMouse(false) end
        a.border=a:CreateTexture(nil,"OVERLAY"); a.border:SetAllPoints(a); a.border:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture("aura_border.tga")) or (TEX.."aura_border.tga"))

        -- Timer text is created through the same helper used by every other
        -- SlamFrames label, then placed above the cooldown model.
        a.timerFrame=CreateFrame("Frame",nil,a)
        a.timerFrame:SetAllPoints(a)
        a.timerFrame:SetFrameLevel(a:GetFrameLevel()+3)
        a.timerText=MakeText(a.timerFrame,10,"CENTER")
        a.timerText:SetTextColor(1,1,1)
        a.timerText:Hide()
        a:SetScript("OnEnter",AuraOnEnter)
        a:SetScript("OnLeave",AuraOnLeave)
        a:Hide(); self.auras[i]=a
    end
    self:LayoutAuras()
end

function SF:LayoutAuras()
    if not self.auras or not self.target then return end
    local scale=self.target.layoutScale or 1
    local auraScale=(SlamFramesDB and SlamFramesDB.auraScale) or 1.00
    local size=C.aura.size*scale*auraScale
    local inset=C.aura.inset*scale*auraScale
    local visiblePad=C.aura.visibleLeftPad*scale*auraScale
    local desiredVisibleGap=1.0*scale
    local gap=(C.target.aura.verticalGap or 5)*scale
    local rowGap=((SlamFramesDB and SlamFramesDB.auraRowSpacing) or 1.00)*scale
    local startOffset=(C.target.aura.startOffset or 0)*scale

    -- aura_border.tga has transparent padding. Base both horizontal and
    -- wrapped-row spacing on the visible border instead of the full texture.
    local visibleSpan=size*(214/256)
    local step=visibleSpan+desiredVisibleGap
    local visibleWidth=visibleSpan
    local rowStep=visibleSpan+rowGap

    -- Stop before the level medallion/portrait region. This is calculated from
    -- the current target width preset, so shorter target frames wrap sooner.
    local trim=self.target.widthTrim or 0
    local cfg=C.target
    local barX=(self.target.power and cfg.power.x or cfg.health.x)*scale
    local startX=barX + startOffset - visiblePad
    local badgeLeft=((cfg.levelBadge.x-trim) - (cfg.levelBadge.size*0.5) - 6)*scale
    local usableWidth=math.max(visibleWidth,badgeLeft-startX)
    local perRow=math.max(1,math.floor((usableWidth-visibleWidth)/step)+1)
    self.auraIconsPerRow=perRow

    local i,a,row,col
    for i=1,table.getn(self.auras) do
        a=self.auras[i]
        a:SetWidth(size); a:SetHeight(size)
        a.icon:ClearAllPoints(); a.icon:SetPoint("TOPLEFT",a,"TOPLEFT",inset,-inset); a.icon:SetPoint("BOTTOMRIGHT",a,"BOTTOMRIGHT",-inset,inset)
        if a.cooldown then
            a.cooldown:ClearAllPoints()
            a.cooldown:SetPoint("TOPLEFT",a,"TOPLEFT",inset,-inset)
            a.cooldown:SetPoint("BOTTOMRIGHT",a,"BOTTOMRIGHT",-inset,inset)
        end
        if a.timerText then
            local timerScale=Clamp(tonumber(SlamFramesDB.auraTimerTextScale) or 1.00,0.50,2.00)
            a.timerText:ClearAllPoints()
            a.timerText:SetPoint("CENTER",a,"CENTER",0,0)
            a.timerText:SetWidth(math.max(12,size-(inset*2)))
            a.timerText:SetHeight(math.max(10,22*scale*auraScale*timerScale))
            SetScaledFont(a.timerText,18,scale*auraScale*timerScale,1.00)
        end

        row=math.floor((i-1)/perRow)
        col=math.mod(i-1,perRow)
        a:ClearAllPoints()
        if self.target.power then
            a:SetPoint("TOPLEFT",self.target.power,"BOTTOMLEFT",startOffset-visiblePad+(col*step),-(gap+row*rowStep))
        else
            a:SetPoint("TOPLEFT",self.target.health,"BOTTOMLEFT",startOffset-visiblePad+(col*step),-(gap+row*rowStep))
        end
    end
    self:RefreshFrameLayers(self.topFrameKey)
end

local function FormatAuraTime(seconds)
    seconds=tonumber(seconds) or 0
    if seconds<=0 then return "" end
    if seconds>=3600 then return tostring(math.floor(seconds/3600+0.5)).."h" end
    if seconds>=60 then return tostring(math.floor(seconds/60+0.5)).."m" end
    if seconds>=10 then return tostring(math.floor(seconds+0.5)) end
    return string.format("%.1f",seconds)
end

local function ApplyAuraToButton(button,info,testDuration,testTimeLeft)
    if not button or not info then return end
    button.auraType=info.kind
    button.auraIndex=info.index
    button.auraName=info.name
    button.auraDuration=info.duration or testDuration or 0
    button.auraTimeLeft=info.timeLeft or testTimeLeft or 0
    button.icon:SetTexture(info.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

    local duration=button.auraDuration or 0
    local timeLeft=button.auraTimeLeft or 0
    local timed=(duration>0 and timeLeft>0)

    -- Radial Sweep was experimental and is retired for now. Keep any cooldown
    -- model completely disabled so external cooldown-count addons cannot inject
    -- duplicate numbers into SlamFrames aura icons.
    if button.cooldown then
        button.cooldown.noCooldownCount=true
        button.cooldown.pfCooldownStyleAnimation=0
        button.cooldown.pfCooldownStyleText=0
        if type(CooldownFrame_SetTimer)=="function" then
            pcall(CooldownFrame_SetTimer,button.cooldown,0,0,0)
        end
        if button.cooldown.pfCooldownText then button.cooldown.pfCooldownText:Hide() end
        button.cooldown:Hide()
    end

    if button.timerText then
        if timed and SlamFramesDB.auraShowTimerText then
            button.timerText:SetText(FormatAuraTime(timeLeft))
            button.timerText:Show()
        else
            button.timerText:SetText("")
            button.timerText:Hide()
        end
    end
    button:Show()
end

function SF:UpdateAuras()
    if not self.auras then return end
    local i,shown=1,0
    local info
    if not SlamFramesDB.showAuras or (not UnitExists("target") and not self.testMode) then
        for i=1,table.getn(self.auras) do self.auras[i]:Hide() end
        return
    end

    i=1
    while i<=16 and shown<C.aura.max do
        info=ReadTargetAura("debuff",i)
        if not info then break end
        shown=shown+1; ApplyAuraToButton(self.auras[shown],info); i=i+1
    end

    i=1
    while i<=16 and shown<C.aura.max do
        info=ReadTargetAura("buff",i)
        if not info then break end
        shown=shown+1; ApplyAuraToButton(self.auras[shown],info); i=i+1
    end

    if self.testMode then
        if not self.auraTestEpoch then self.auraTestEpoch=GetTime() end
        local elapsed=GetTime()-self.auraTestEpoch
        local function TestLeft(duration,offset)
            local passed=math.mod(elapsed+(offset or 0),duration)
            return duration-passed
        end
        -- Intentionally enough samples to force 2+ rows at normal widths.
        local testAuras={
            {kind="buff",index=1,name="Test Blessing",icon="Interface\\Icons\\Spell_Holy_SealOfProtection",duration=30,timeLeft=TestLeft(30,9)},
            {kind="buff",index=2,name="Test Aura",icon="Interface\\Icons\\Spell_Holy_RetributionAura",duration=120,timeLeft=TestLeft(120,46)},
            {kind="buff",index=3,name="Test Power",icon="Interface\\Icons\\Spell_Nature_Lightning",duration=15,timeLeft=TestLeft(15,7)},
            {kind="buff",index=4,name="Test Shield",icon="Interface\\Icons\\Spell_Holy_PowerWordShield",duration=45,timeLeft=TestLeft(45,11)},
            {kind="buff",index=5,name="Test Fortitude",icon="Interface\\Icons\\Spell_Holy_WordFortitude",duration=180,timeLeft=TestLeft(180,37)},
            {kind="buff",index=6,name="Test Intellect",icon="Interface\\Icons\\Spell_Holy_MagicalSentry",duration=90,timeLeft=TestLeft(90,21)},
            {kind="buff",index=7,name="Test Speed",icon="Interface\\Icons\\Spell_Nature_Invisibilty",duration=25,timeLeft=TestLeft(25,3)},
            {kind="buff",index=8,name="Test Ward",icon="Interface\\Icons\\Spell_Frost_FrostWard",duration=60,timeLeft=TestLeft(60,14)},
            {kind="debuff",index=1,name="Test Sunder",icon="Interface\\Icons\\Ability_Warrior_Sunder",duration=30,timeLeft=TestLeft(30,18)},
            {kind="debuff",index=2,name="Test Pain",icon="Interface\\Icons\\Spell_Shadow_ShadowWordPain",duration=18,timeLeft=TestLeft(18,9)},
            {kind="debuff",index=3,name="Test Rend",icon="Interface\\Icons\\Ability_Gouge",duration=21,timeLeft=TestLeft(21,5)},
            {kind="debuff",index=4,name="Test Curse",icon="Interface\\Icons\\Spell_Shadow_CurseOfTounges",duration=40,timeLeft=TestLeft(40,13)},
            {kind="debuff",index=5,name="Test Slow",icon="Interface\\Icons\\Spell_Nature_Slow",duration=32,timeLeft=TestLeft(32,17)},
            {kind="debuff",index=6,name="Test Burn",icon="Interface\\Icons\\Spell_Fire_Fire",duration=12,timeLeft=TestLeft(12,2)},
            {kind="debuff",index=7,name="Test Poison",icon="Interface\\Icons\\Ability_PoisonSting",duration=24,timeLeft=TestLeft(24,8)},
            {kind="debuff",index=8,name="Test Disease",icon="Interface\\Icons\\Spell_Shadow_AbominationExplosion",duration=36,timeLeft=TestLeft(36,19)},
        }
        for i=1,table.getn(testAuras) do
            if shown>=C.aura.max then break end
            shown=shown+1
            ApplyAuraToButton(self.auras[shown],testAuras[i])
        end
    else
        self.auraTestEpoch=nil
    end

    for i=shown+1,table.getn(self.auras) do
        local a=self.auras[i]
        a.auraType=nil; a.auraIndex=nil; a.auraName=nil; a.auraDuration=0; a.auraTimeLeft=0
        if a.cooldown then
            if type(CooldownFrame_SetTimer)=="function" then pcall(CooldownFrame_SetTimer,a.cooldown,0,0,0) end
            a.cooldown:Hide()
        end
        if a.timerText then a.timerText:SetText(""); a.timerText:Hide() end
        a:Hide()
    end
end

local function HardHide(frame)
    if not frame then return end
    frame:Hide(); frame.Show=function() end
end

function SF:UpdateBlizzardPartyFrames()
    local suppress=SlamFramesDB and SlamFramesDB.showPartyFrames
    local i,bf
    for i=1,4 do
        if type(getglobal)=="function" then bf=getglobal("PartyMemberFrame"..i)
        elseif _G then bf=_G["PartyMemberFrame"..i] else bf=nil end
        if bf then
            if suppress then
                -- Party performance fix: suppress Blizzard's party frames once
                -- instead of re-hiding all four frames every 0.20 seconds.
                -- Alpha=0 and mouse disabled remain persistent while Blizzard
                -- continues to own its normal internal update/event behavior.
                if not bf.sfSlamFramesSuppressed then
                    if bf.sfSlamFramesOldAlpha==nil and bf.GetAlpha then bf.sfSlamFramesOldAlpha=bf:GetAlpha() end
                    if bf.sfSlamFramesOldMouse==nil and bf.IsMouseEnabled then bf.sfSlamFramesOldMouse=bf:IsMouseEnabled() end
                    bf:SetAlpha(0)
                    bf:EnableMouse(false)
                    bf:Hide()
                    bf.sfSlamFramesSuppressed=true
                end
            else
                if bf.sfSlamFramesSuppressed then
                    if bf.sfSlamFramesOldAlpha~=nil then bf:SetAlpha(bf.sfSlamFramesOldAlpha); bf.sfSlamFramesOldAlpha=nil else bf:SetAlpha(1) end
                    if bf.sfSlamFramesOldMouse~=nil then bf:EnableMouse(bf.sfSlamFramesOldMouse and true or false); bf.sfSlamFramesOldMouse=nil else bf:EnableMouse(true) end
                    bf.sfSlamFramesSuppressed=nil
                    -- If Party Frames were disabled while already grouped, Blizzard
                    -- may not emit another roster event to reshow its frame. Restore
                    -- the visible party member immediately; later native events still
                    -- retain ownership of normal Blizzard visibility.
                    if UnitExists("party"..i) and bf.Show then bf:Show() end
                end
            end
        end
    end
end

function SF:HideBlizzardFrames()
    if SlamFramesDB.hideBlizzard then
        HardHide(PlayerFrame); HardHide(TargetFrame); if TargetofTargetFrame then HardHide(TargetofTargetFrame) end
    end
    self:UpdateBlizzardPartyFrames()
end

function SF:SetLocked(v)
    SlamFramesDB.locked=v and true or false
    self:UpdateMoveLabels()
    if self.RefreshSettings then self:RefreshSettings() end
    if SlamFramesDB.locked then
        Print("locked. Left-click party frames targets the member; right-click opens the normal unit menu.")
    else
        Print("unlocked. Drag PLAYER, TARGET, TOT, or any PARTY frame; party members move as one group. Mouse-wheel a frame to resize it.")
    end
end

function SF:Reset(key)
    key=NormalizeKey(key)
    if key then
        SlamFramesDB.anchors[key]=CopyAnchor(DEFAULT_ANCHORS[key]); SlamFramesDB.scales[key]=DEFAULT_SCALES[key]
        if SlamFramesDB.widthPresets and (key=="player" or key=="target" or key=="tot" or key=="party") then SlamFramesDB.widthPresets[key]=1 end
        if SlamFramesDB.portraitZooms then
            if key=="tot" or key=="party" then SlamFramesDB.portraitZooms[key]=1.08 else SlamFramesDB.portraitZooms[key]=1.00 end
        end
        if key=="party" then
            SlamFramesDB.partyNameOffset=0; SlamFramesDB.partySpacing=8
            self:LayoutPartyFrames()
        else
            local f=FrameForKey(key); if f then self:LayoutFrame(f,key,DEFAULT_SCALES[key]); ApplyAnchor(f,key) end
        end
        self:UpdateMoveLabels(); if self.RefreshSettings then self:RefreshSettings() end; Print(key.." reset to the SlamFrames default profile."); return
    end
    SlamFramesDB.anchors.player=CopyAnchor(DEFAULT_ANCHORS.player); SlamFramesDB.anchors.target=CopyAnchor(DEFAULT_ANCHORS.target); SlamFramesDB.anchors.tot=CopyAnchor(DEFAULT_ANCHORS.tot); SlamFramesDB.anchors.party=CopyAnchor(DEFAULT_ANCHORS.party)
    SlamFramesDB.scales.player=DEFAULT_SCALES.player; SlamFramesDB.scales.target=DEFAULT_SCALES.target; SlamFramesDB.scales.tot=DEFAULT_SCALES.tot; SlamFramesDB.scales.party=DEFAULT_SCALES.party; SlamFramesDB.scales.raid=DEFAULT_SCALES.raid
    SlamFramesDB.locked=true
    SlamFramesDB.hideBlizzard=true
    SlamFramesDB.showAuras=true
    SlamFramesDB.smoothBars=true
    SlamFramesDB.healthTextMode="amount"
    SlamFramesDB.totHealthTextMode="percent"
    SlamFramesDB.partyHealthTextMode="percent"
    SlamFramesDB.showPartyFrames=true
    SlamFramesDB.partyHideInRaid=true
    SlamFramesDB.partySpacing=8
    SlamFramesDB.partyNameOffset=0
    SlamFramesDB.showRaidFrames=true
    SlamFramesDB.raidHealthTextMode="percent"
    SlamFramesDB.raidSpacing=4
    SlamFramesDB.raidGroupSpacing=10
    SlamFramesDB.raidGroupRowSpacing=36
    SlamFramesDB.raidGroupsPerRow=8
    SlamFramesDB.raidNameOffset=0
    SlamFramesDB.raidShowGroupHeaders=true
    SlamFramesDB.raidCompactMode=false
    SlamFramesDB.raidOpacity=1.00
    SlamFramesDB.raidClassColoredNames=false
    SlamFramesDB.raidPreviewSize=20
    SlamFramesDB.raidPreviewDebuffs=false
    SlamFramesDB.raidDebuffGlowSize=2
    SlamFramesDB.raidPreviewMainTanks=false
    SlamFramesDB.clickCastingEnabled=false
    SlamFramesDB.clickCastingApplyNormal=false
    SlamFramesDB.clickCastingTooltip=true
    SlamFramesDB.clickBindings={
        LeftButton={mode="base",base="target",spell=""},
        RightButton={mode="base",base="menu",spell=""},
        MiddleButton={mode="base",base="none",spell=""},
    }
    -- Factory click-casting defaults intentionally contain no spell or item names.
    -- Resetting the addon must clear the newer modifier-aware binding table too,
    -- otherwise an old left-click spell can survive a Reset All operation.
    SlamFramesDB.clickBindingSets={
        none={
            LeftButton={action="normal",spell=""},
            RightButton={action="normal",spell=""},
            MiddleButton={action="normal",spell=""},
        },
        shift={
            LeftButton={action="normal",spell=""},
            RightButton={action="normal",spell=""},
            MiddleButton={action="normal",spell=""},
        },
        ctrl={
            LeftButton={action="normal",spell=""},
            RightButton={action="normal",spell=""},
            MiddleButton={action="normal",spell=""},
        },
        alt={
            LeftButton={action="normal",spell=""},
            RightButton={action="normal",spell=""},
            MiddleButton={action="normal",spell=""},
        },
    }
    SlamFramesDB.partyDebuffAlerts=true
    SlamFramesDB.partyDebuffOnlyDispellable=true
    SlamFramesDB.partyDebuffMessage=true
    SlamFramesDB.partyDebuffSound=false
    SlamFramesDB.showPowerNumbers=true
    SlamFramesDB.showRestingEffect=true
    SlamFramesDB.showCCEffect=true
    SlamFramesDB.showCombatGlow=true
    SlamFramesDB.selfTargetOnClick=true
    SlamFramesDB.skin="dark"
    SlamFramesDB.nameTextScale=1.30
    SlamFramesDB.healthTextScale=1.80
    SlamFramesDB.powerTextScale=1.30
    SlamFramesDB.levelTextScale=1.00
    SlamFramesDB.textScale=nil
    SlamFramesDB.auraScale=1.30
    SlamFramesDB.auraRowSpacing=1.00
    SlamFramesDB.auraShowCooldownSweep=false
    SlamFramesDB.auraShowTimerText=true
    SlamFramesDB.auraTimerTextScale=1.00
    SlamFramesDB.widthPresets={player=1,target=1,tot=1,party=1,raid=1}
    SlamFramesDB.portraitZooms={player=1.00,target=1.00,tot=1.08,party=1.08,raid=1.08}
    SlamFramesDB.ccAnchor={x=-35.55593730832338,y=73.98975554593724}
    SlamFramesDB.combatGlowIntensity=1.30
    SlamFramesDB.showMinimapButton=true
    SlamFramesDB.minimapAngle=-0.4897411260673095
    SlamFramesDB.minimapRadius=80
    SlamFramesDB.showPlayerCastbar=true
    SlamFramesDB.hideBlizzardCastbar=true
    SlamFramesDB.hideBlizzardErrorText=false
    SlamFramesDB.castbarShowIcon=true
    SlamFramesDB.castbarShowTimer=true
    SlamFramesDB.castbarShowLatency=true
    SlamFramesDB.castbarScale=0.80
    SlamFramesDB.castbarWidth=360
    SlamFramesDB.castbarStyle=1
    SlamFramesDB.castbarAnchor={x=-18.33375010796635,y=-240.8081150486736}
    self:ApplyPositions()
    if self.ApplySkin then self:ApplySkin(true) end
    if self.UpdateMinimapButtonPosition then self:UpdateMinimapButtonPosition() end
    if self.SetMinimapButtonShown then self:SetMinimapButtonShown(true) end
    if self.castbar and self.LayoutCastBar then self:LayoutCastBar() end
    if self.ApplyBlizzardErrorTextSetting then self:ApplyBlizzardErrorTextSetting() end
    if self.UpdatePlayerEffects then self:UpdatePlayerEffects(true) end
    if self.HideBlizzardFrames then self:HideBlizzardFrames() end
    self:RefreshAll()
    self:UpdateMoveLabels(); if self.RefreshSettings then self:RefreshSettings() end; Print("SlamFrames reset to the default profile.")
end

function SF:ApplyBlizzardErrorTextSetting()
    if not UIErrorsFrame then return end
    if SlamFramesDB and SlamFramesDB.hideBlizzardErrorText then
        if UIErrorsFrame.UnregisterEvent then
            pcall(function() UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE") end)
        end
        if UIErrorsFrame.Clear then pcall(function() UIErrorsFrame:Clear() end) end
    else
        if UIErrorsFrame.RegisterEvent then
            pcall(function() UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE") end)
        end
    end
end

function SF:SetBlizzardErrorTextHidden(value,quiet)
    SlamFramesDB.hideBlizzardErrorText = value and true or false
    self:ApplyBlizzardErrorTextSetting()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet then
        Print("Blizzard red error text "..(SlamFramesDB.hideBlizzardErrorText and "hidden" or "shown")..".")
    end
end

function SF:CreateFrames()
    self:ApplyArtResolutionConfigs()
    local cfgs = self.activeConfigs or C
    self.player=CreateUnitFrame("Player","player","player",cfgs.player or C.player)
    self.target=CreateUnitFrame("Target","target","target",cfgs.target or C.target)
    self.tot=CreateUnitFrame("ToT","tot","targettarget",cfgs.tot or C.tot)
    self.partyFrames={}
    local i
    for i=1,4 do
        self.partyFrames[i]=CreateUnitFrame("Party"..i,"party","party"..i,cfgs.party or C.party)
        self.partyFrames[i].partyIndex=i
    end
    if self.CreatePartyDebuffAlerts then self:CreatePartyDebuffAlerts() end
    -- Raid frames are created lazily by RaidFrames.lua only when Test Frames is active or a live raid exists.
    self:CreateAuras(); self:ApplyPositions(); self:RefreshFrameLayers(); self:UpdateMoveLabels(); self:SetSmoothBars(SlamFramesDB.smoothBars)
end

function SF:RefreshAll() self:UpdatePlayer(); self:UpdateTarget(); self:UpdatePartyFrames(); if self.UpdateRaidFrames then self:UpdateRaidFrames() end; self:UpdateBlizzardPartyFrames(); if self.UpdatePartyDebuffAlerts then self:UpdatePartyDebuffAlerts() end end

local function HandleScale(rest)
    local s,e,first,second=string.find(rest or "","^%s*(%S+)%s*(%S*)%s*$")
    first=first or ""; second=second or ""
    local n=tonumber(first)
    if n then SF:SetFrameScale("player",n,true); SF:SetFrameScale("target",n,true); SF:SetFrameScale("tot",n,true); SF:SetFrameScale("party",n,true); Print("all frame scales set to "..string.format("%.2f",Clamp(n,0.40,3.00))); return end
    local key=NormalizeKey(first); n=tonumber(second)
    if key and n then SF:SetFrameScale(key,n,false); return end
    Print("usage: /sf scale 0.60 OR /sf scale player|target|tot|party 0.60")
end

local function HandleWidth(rest)
    local s,e,first,second=string.find(rest or "","^%s*(%S+)%s*(%S*)%s*$")
    local key=NormalizeKey(first or "")
    local n=tonumber(second)
    if not key or (key~="player" and key~="target" and key~="tot" and key~="party") or not n then
        Print("usage: /sf width player|target|tot|party 0-3 (0=100%, 1=~90%, 2=~80%, 3=~70%)")
        return
    end
    -- Also accept the visible percentage values for convenience.
    if n>=70 then
        if n>=95 then n=0 elseif n>=85 then n=1 elseif n>=75 then n=2 else n=3 end
    end
    SF:SetWidthPreset(key,n,false)
end

function SF:HandleSlash(msg)
    msg=msg or ""
    local s,e,cmd,rest=string.find(msg,"^%s*(%S*)%s*(.-)%s*$")
    cmd=string.lower(cmd or ""); rest=rest or ""
    if cmd=="lock" then self:SetLocked(true)
    elseif cmd=="unlock" then self:SetLocked(false)
    elseif cmd=="reset" then self:Reset(rest)
    elseif cmd=="scale" then HandleScale(rest)
    elseif cmd=="width" or cmd=="barwidth" then HandleWidth(rest)
    elseif cmd=="test" then self.testMode=not self.testMode; SlamFramesDB.testMode=self.testMode; self:RefreshAll(); Print("test mode "..(self.testMode and "on" or "off")..".")
    elseif cmd=="auras" then SlamFramesDB.showAuras=not SlamFramesDB.showAuras; self:UpdateAuras(); if self.RefreshSettings then self:RefreshSettings() end; Print("target auras "..(SlamFramesDB.showAuras and "on" or "off")..".")
    elseif cmd=="health" then if not self:SetHealthTextMode(rest,false) then Print("usage: /sf health percent | amount | both | off") end
    elseif cmd=="tothealth" then if not self:SetToTHealthTextMode(rest,false) then Print("usage: /sf tothealth percent | amount") end
    elseif cmd=="partyhealth" then if not self:SetPartyHealthTextMode(rest,false) then Print("usage: /sf partyhealth percent | amount | off") end
    elseif cmd=="partynamex" then local n=tonumber(rest); if n then self:SetPartyNameOffset(n,false) else Print("usage: /sf partynamex -150 to 150") end
    elseif cmd=="partyspacing" then local n=tonumber(rest); if n then self:SetPartySpacing(n,false) else Print("usage: /sf partyspacing 0-40") end
    elseif cmd=="party" then
        local v=string.lower(rest or "")
        if v=="on" then self:SetPartyFramesEnabled(true,false)
        elseif v=="off" then self:SetPartyFramesEnabled(false,false)
        elseif v=="reset" then self:Reset("party")
        else self:SetPartyFramesEnabled(not SlamFramesDB.showPartyFrames,false) end
    elseif cmd=="partyraid" then
        local v=string.lower(rest or "")
        if v=="show" or v=="off" then self:SetPartyHideInRaid(false,false)
        elseif v=="hide" or v=="on" then self:SetPartyHideInRaid(true,false)
        else Print("usage: /sf partyraid hide | show") end
    elseif cmd=="partypower" then
        local v=string.lower(rest or "")
        if v=="on" then self:SetPartyPowerEnabled(true,false)
        elseif v=="off" then self:SetPartyPowerEnabled(false,false)
        else self:SetPartyPowerEnabled(not SlamFramesDB.showPartyPower,false) end
    elseif cmd=="power" then SlamFramesDB.showPowerNumbers=not SlamFramesDB.showPowerNumbers; self:RefreshAll(); if self.RefreshSettings then self:RefreshSettings() end; Print("power numbers "..(SlamFramesDB.showPowerNumbers and "on" or "off")..".")
    elseif cmd=="selftarget" or cmd=="clickself" then
        local v=string.lower(rest or "")
        if v=="on" then self:SetSelfTargetOnClick(true,false)
        elseif v=="off" then self:SetSelfTargetOnClick(false,false)
        else self:SetSelfTargetOnClick(not SlamFramesDB.selfTargetOnClick,false) end
    elseif cmd=="numbers" then self:SetHealthTextMode((SlamFramesDB.healthTextMode=="off") and "percent" or "off",false)
    elseif cmd=="smooth" then self:SetSmoothBars(not SlamFramesDB.smoothBars); Print("smooth bar movement "..(SlamFramesDB.smoothBars and "on" or "off")..".")
    elseif cmd=="nametext" or cmd=="namescale" then local n=tonumber(rest); if n then self:SetNameTextScale(n,false) else Print("usage: /sf nametext 1.30") end
    elseif cmd=="healthtextscale" then local n=tonumber(rest); if n then self:SetHealthTextScale(n,false) else Print("usage: /sf healthtextscale 1.00") end
    elseif cmd=="powertextscale" or cmd=="resourcetextscale" then local n=tonumber(rest); if n then self:SetPowerTextScale(n,false) else Print("usage: /sf powertextscale 1.00") end
    elseif cmd=="leveltextscale" then local n=tonumber(rest); if n then self:SetLevelTextScale(n,false) else Print("usage: /sf leveltextscale 1.00") end
    elseif cmd=="textscale" then local n=tonumber(rest); if n then self:SetTextScale(n,false) else Print("usage: /sf textscale 1.00 (legacy: sets all text)") end
    elseif cmd=="aurascale" then local n=tonumber(rest); if n then self:SetAuraScale(n,false) else Print("usage: /sf aurascale 1.00") end
    elseif cmd=="aurarowgap" or cmd=="aurarowspacing" then local n=tonumber(rest); if n then self:SetAuraRowSpacing(n,false) else Print("usage: /sf aurarowgap 1.0") end
    elseif cmd=="clickdebug" then
        if self.SetClickCastDebug then self:SetClickCastDebug(not self.clickCastDebug,false)
        else Print("click-cast debug is unavailable.") end
    elseif cmd=="clickdiag" then
        local sw=tostring(SUPERWOW_VERSION or (type(GetSuperWoWVersion)=="function" and GetSuperWoWVersion()) or "?")
        Print("click diag: SuperWoW="..sw.." CastSpellByName="..tostring(type(CastSpellByName)).." SetMouseoverUnit="..tostring(type(SetMouseoverUnit)).." UseContainerItem="..tostring(type(UseContainerItem)))
        local probe=self.target and self.target.sfClickButton or self.player and self.player.sfClickButton
        Print("click diag secure: SetAttribute="..tostring(probe and type(probe.SetAttribute) or "nil").." GetAttribute="..tostring(probe and type(probe.GetAttribute) or "nil").." secureActive="..tostring((self.target and self.target.sfSecureClickActive) or (self.player and self.player.sfSecureClickActive)))
        if probe and type(probe.GetAttribute)=="function" then
            Print("click diag attrs: unit="..tostring(probe:GetAttribute("unit")).." type1="..tostring(probe:GetAttribute("type1")).." type2="..tostring(probe:GetAttribute("type2")).." shift-type1="..tostring(probe:GetAttribute("shift-type1")))
        end
        local mod=(self.GetActiveClickModifier and self:GetActiveClickModifier()) or "?"
        Print("click diag binding: modifier="..tostring(mod).." left="..tostring(self.GetClickBindingText and self:GetClickBindingText(mod=="multi" and "none" or mod,"LeftButton") or "?"))
    elseif cmd=="auradiag" then
        local guid=GetCurrentTargetAuraGuid()
        local np=(type(GetSpellDuration)=="function") and "yes" or "no"
        local pav=(type(GetPlayerAuraDuration)=="function") and "yes" or "no"
        local sw=tostring(SUPERWOW_VERSION or (type(GetSuperWoWVersion)=="function" and GetSuperWoWVersion()) or "?")
        local npv="?"
        if type(GetNampowerVersion)=="function" then
            local a,b,c=GetNampowerVersion()
            if a then npv=tostring(a)..(b and ("."..tostring(b)) or "")..(c and ("."..tostring(c)) or "") end
        end
        local cvar="?"
        if type(GetCVar)=="function" then local ok,v=pcall(GetCVar,"NP_EnableAuraCastEvents"); if ok and v then cvar=tostring(v) end end
        Print("aura diag: target="..tostring(UnitName("target")).." guid="..tostring(guid).." SuperWoW="..sw.." Nampower="..npv.." GetSpellDuration="..np.." GetPlayerAuraDuration="..pav.." NP_AuraEvents="..cvar)
        local s=self.auraTimingStats or {}
        Print("aura diag events: cast="..tostring(s.auraCast or 0).." added="..tostring(s.auraAdded or 0).." removed="..tostring(s.auraRemoved or 0).." supercast="..tostring(s.superCast or 0).." last="..tostring(s.lastEvent))
        local first=ReadTargetAura("buff",1) or ReadTargetAura("debuff",1)
        if first then
            Print("aura diag first: "..tostring(first.name or first.icon).." id="..tostring(first.spellId).." duration="..tostring(first.duration).." left="..string.format("%.1f",tonumber(first.timeLeft) or 0).." source="..tostring(first.timingSource or "raw/none"))
        else
            Print("aura diag first: target has no readable buff/debuff.")
        end
    elseif cmd=="auratimer" then
        local v=string.lower(rest or "")
        if v=="on" then self:SetAuraTimerText(true,false)
        elseif v=="off" then self:SetAuraTimerText(false,false)
        else self:SetAuraTimerText(not SlamFramesDB.auraShowTimerText,false) end
    elseif cmd=="auratimerscale" or cmd=="auratimersize" then
        local n=tonumber(rest)
        if n then self:SetAuraTimerTextScale(n,false) else Print("usage: /sf auratimerscale 1.00") end
    elseif cmd=="portraitzoom" then
        local key,val=string.match(rest or "","^%s*(%S+)%s+(%S+)%s*$")
        val=tonumber(val)
        if not key or not val or not self:SetPortraitZoom(key,val,true) then Print("usage: /sf portraitzoom player|target|tot|party 1.00-1.50")
        else Print(NormalizeKey(key).." portrait zoom set to "..string.format("%.2f",Clamp(val,1.00,1.50))) end
    elseif cmd=="totrelative" then
        self:ResetToTRelative()
    elseif cmd=="ccreset" then
        if self.ResetCCPosition then self:ResetCCPosition() end
    elseif cmd=="ccmove" then
        if self.SetCCMoveMode then self:SetCCMoveMode(not self.ccMoveMode) end
    elseif cmd=="combatglow" then
        local v=string.lower(rest or "")
        if v=="on" then SlamFramesDB.showCombatGlow=true
        elseif v=="off" then SlamFramesDB.showCombatGlow=false
        else
            local n=tonumber(v)
            if n then self:SetCombatGlowIntensity(n,false); return
            else SlamFramesDB.showCombatGlow=not SlamFramesDB.showCombatGlow end
        end
        if self.UpdatePlayerEffects then self:UpdatePlayerEffects(true) end
        if self.RefreshSettings then self:RefreshSettings() end
        Print("combat portrait glow is now "..(SlamFramesDB.showCombatGlow and "ON" or "OFF")..".")
    elseif cmd=="combatglowstrength" or cmd=="combatglowintensity" then
        local n=tonumber(rest)
        if n then self:SetCombatGlowIntensity(n,false) else Print("usage: /sf combatglowstrength 0.50-2.00") end
    elseif cmd=="minimap" then
        local v=string.lower(rest or "")
        if v=="on" then SlamFramesDB.showMinimapButton=true; if self.minimapButton then self.minimapButton:Show() end; Print("minimap button shown.")
        elseif v=="off" then SlamFramesDB.showMinimapButton=false; if self.minimapButton then self.minimapButton:Hide() end; Print("minimap button hidden. Use /sf minimap on to restore it.")
        elseif v=="reset" then SlamFramesDB.minimapAngle=-0.4897411260673095; SlamFramesDB.minimapRadius=80; if self.UpdateMinimapButtonPosition then self:UpdateMinimapButtonPosition() end; Print("minimap button position reset.")
        else Print("usage: /sf minimap on | off | reset") end
        if self.RefreshSettings then self:RefreshSettings() end
    elseif cmd=="castbar" then
        local sub,arg=string.match(rest or "","^%s*(%S*)%s*(.-)%s*$")
        sub=string.lower(sub or ""); arg=arg or ""
        if sub=="on" then if self.SetCastBarEnabled then self:SetCastBarEnabled(true,false) end
        elseif sub=="off" then if self.SetCastBarEnabled then self:SetCastBarEnabled(false,false) end
        elseif sub=="move" then if self.SetCastBarMoveMode then self:SetCastBarMoveMode(not self.castbarMoveMode) end
        elseif sub=="reset" then if self.ResetCastBarPosition then self:ResetCastBarPosition(false) end
        elseif sub=="scale" then local n=tonumber(arg); if n and self.SetCastBarScale then self:SetCastBarScale(n,false) else Print("usage: /sf castbar scale 0.80") end
        elseif sub=="width" then local n=tonumber(arg); if n and self.SetCastBarWidth then self:SetCastBarWidth(n,false) else Print("usage: /sf castbar width 360") end
        elseif sub=="cast" or sub=="test" then if self.PreviewCastBar then self:PreviewCastBar("cast") end
        elseif sub=="channel" then if self.PreviewCastBar then self:PreviewCastBar("channel") end
        elseif sub=="interrupt" then if self.PreviewCastBar then self:PreviewCastBar("interrupt") end
        elseif sub=="fail" then if self.PreviewCastBar then self:PreviewCastBar("fail") end
        elseif sub=="latency" then
            local v=string.lower(arg or "")
            if v=="on" then SlamFramesDB.castbarShowLatency=true elseif v=="off" then SlamFramesDB.castbarShowLatency=false else SlamFramesDB.castbarShowLatency=not SlamFramesDB.castbarShowLatency end
            if self.RefreshSettings then self:RefreshSettings() end
            Print("cast bar latency zone "..(SlamFramesDB.castbarShowLatency and "ON" or "OFF")..".")
        elseif sub=="icon" then
            local v=string.lower(arg or "")
            if v=="on" then SlamFramesDB.castbarShowIcon=true elseif v=="off" then SlamFramesDB.castbarShowIcon=false else SlamFramesDB.castbarShowIcon=not SlamFramesDB.castbarShowIcon end
            if self.LayoutCastBar then self:LayoutCastBar() end
            if self.RefreshSettings then self:RefreshSettings() end
        else Print("castbar: on/off | move | reset | scale 0.80 | width 360 | cast | channel | interrupt | fail | latency on/off | icon on/off") end
    elseif cmd=="skin" then
        local v=string.lower(rest or "")
        if (v=="light" or v=="dark") and self.SetSkin then self:SetSkin(v,false)
        else Print("usage: /sf skin light | dark") end
    elseif cmd=="settings" then if self.ToggleSettings then self:ToggleSettings() end
    elseif cmd=="blizz" then SlamFramesDB.hideBlizzard=not SlamFramesDB.hideBlizzard; Print("hide Blizzard frames is now "..(SlamFramesDB.hideBlizzard and "ON" or "OFF")..". /reload to apply.")
    else Print("commands: /sf settings | skin light/dark | castbar on/off/move/reset/test | unlock | lock | scale [player/target/tot/party] 0.60 | width [player/target/tot/party] 0-3 | portraitzoom [player/target/tot/party] 1.00-1.50 | totrelative | ccmove | ccreset | nametext 1.30 | healthtextscale 1.00 | powertextscale 1.00 | leveltextscale 1.00 | aurascale 1.00 | aurarowgap 1.0 | auratimer on/off | auratimerscale 1.00 | auradiag | combatglow on/off | combatglowstrength 0.50-2.00 | minimap on/off/reset | reset [player/target/tot/party] | health percent/amount/both/off | tothealth percent/amount | party on/off/reset | partypower on/off | partyhealth percent/amount/off | partynamex -150..150 | partyspacing 0-40 | partyraid hide/show | selftarget on/off | power | test | auras | smooth | blizz") end
end

local eventFrame=CreateFrame("Frame","SlamFrames_EventFrame",UIParent)
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("UNIT_LEVEL")
eventFrame:RegisterEvent("UNIT_HEALTH")
eventFrame:RegisterEvent("UNIT_MAXHEALTH")
eventFrame:RegisterEvent("UNIT_MANA")
eventFrame:RegisterEvent("UNIT_MAXMANA")
eventFrame:RegisterEvent("UNIT_RAGE")
eventFrame:RegisterEvent("UNIT_ENERGY")
eventFrame:RegisterEvent("UNIT_DISPLAYPOWER")
eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
eventFrame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("PLAYER_AURAS_CHANGED")
eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
eventFrame:RegisterEvent("PLAYER_ENTER_COMBAT")
eventFrame:RegisterEvent("PLAYER_LEAVE_COMBAT")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
eventFrame:RegisterEvent("SPELLS_CHANGED")

local function RegisterAuraTimingEvent(name)
    local ok=pcall(function() eventFrame:RegisterEvent(name) end)
    SF.auraTimingStats.registered[name]=ok and true or false
end

-- Nampower custom aura events. Registering them is harmless on clients where
-- the DLL/event is absent because old clients reject unknown names inside the
-- protected call. SuperWoW UNIT_CASTEVENT remains a conservative fallback.
local auraTimingEvents={
    "AURA_CAST_ON_SELF","AURA_CAST_ON_OTHER",
    "BUFF_ADDED_SELF","BUFF_REMOVED_SELF","BUFF_ADDED_OTHER","BUFF_REMOVED_OTHER",
    "DEBUFF_ADDED_SELF","DEBUFF_REMOVED_SELF","DEBUFF_ADDED_OTHER","DEBUFF_REMOVED_OTHER",
    "UNIT_CASTEVENT",
}
local auraEventIndex
for auraEventIndex=1,table.getn(auraTimingEvents) do RegisterAuraTimingEvent(auraTimingEvents[auraEventIndex]) end

eventFrame:SetScript("OnEvent",function()
    local ev=event; local u=arg1

    -- Nampower aura application carries exact durationMs and GUID ownership.
    if ev=="AURA_CAST_ON_SELF" or ev=="AURA_CAST_ON_OTHER" then
        SF:HandleNampowerAuraCast(arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9)
        if SF.player then SF:UpdateAuras() end
        return
    elseif ev=="BUFF_ADDED_SELF" or ev=="BUFF_REMOVED_SELF" or ev=="BUFF_ADDED_OTHER" or ev=="BUFF_REMOVED_OTHER"
        or ev=="DEBUFF_ADDED_SELF" or ev=="DEBUFF_REMOVED_SELF" or ev=="DEBUFF_ADDED_OTHER" or ev=="DEBUFF_REMOVED_OTHER" then
        SF:HandleNampowerAuraSlot(ev,arg1,arg2,arg3,arg4,arg5,arg6,arg7)
        if SF.player then SF:UpdateAuras() end
        return
    elseif ev=="UNIT_CASTEVENT" then
        SF:HandleSuperWoWAuraCast(arg1,arg2,arg3,arg4)
        return
    end

    if ev=="VARIABLES_LOADED" then
        DBInit(); SF.testMode=SlamFramesDB.testMode and true or false
        if SF.ApplyBlizzardErrorTextSetting then SF:ApplyBlizzardErrorTextSetting() end
        if type(SetCVar)=="function" then pcall(SetCVar,"NP_EnableAuraCastEvents","1") end
        if not SF.player then SF:CreateFrames() end
        if SF.RefreshDispelCapabilities then SF:RefreshDispelCapabilities() end
        if SF.CreatePlayerEffects then SF:CreatePlayerEffects() end
        if SF.CreateCastBar then SF:CreateCastBar() end
        if SF.CreateSettingsPanel then SF:CreateSettingsPanel() end
        if SF.CreateMinimapButton then SF:CreateMinimapButton() end
        if SF.ApplySkin then SF:ApplySkin(true) end
        SF:HideBlizzardFrames(); SF:RefreshAll()
        Print("v"..C.version.." loaded. Settings profile: "..(SF.activeCharacterProfile or "this character")..". Party click casting is available under the Click Cast settings tab.")
        return
    end
    if not SF.player then return end
    if ev=="PLAYER_ENTERING_WORLD" then SF:HideBlizzardFrames(); if SF.ApplyBlizzardErrorTextSetting then SF:ApplyBlizzardErrorTextSetting() end; SF:RefreshAll(); if SF.RefreshDispelCapabilities then SF:RefreshDispelCapabilities() end; if SF.UpdatePartyDebuffAlerts then SF:UpdatePartyDebuffAlerts() end; if SF.UpdateMinimapButtonIcon then SF:UpdateMinimapButtonIcon() end; if SF.ApplyExternalUISkin then SF:ApplyExternalUISkin() end
    elseif ev=="PARTY_MEMBERS_CHANGED" or ev=="PARTY_LEADER_CHANGED" then
        -- Collapse the roster/name/portrait burst and spread the expensive
        -- initial Party Frame population across several rendered frames.
        if SF.QueuePartyRosterRefresh then SF:QueuePartyRosterRefresh(ev) else SF:UpdatePartyFrames() end
        SF:UpdateBlizzardPartyFrames()
    elseif ev=="RAID_ROSTER_UPDATE" then
        if SF.QueuePartyRosterRefresh then SF:QueuePartyRosterRefresh(ev) else SF:UpdatePartyFrames() end
        if SF.UpdateRaidFrames then SF:UpdateRaidFrames() end
        SF:UpdateBlizzardPartyFrames()
    elseif ev=="SPELLS_CHANGED" then if SF.RefreshDispelCapabilities then SF:RefreshDispelCapabilities() end; if SF.UpdatePartyDebuffAlerts then SF:UpdatePartyDebuffAlerts() end
    elseif ev=="PLAYER_LEVEL_UP" then SF:UpdatePlayer(); SF:UpdateTarget(); SF:UpdatePartyFrames(); if SF.UpdateRaidFrames then SF:UpdateRaidFrames() end
    elseif ev=="UNIT_LEVEL" then
        if u=="player" then SF:UpdatePlayer(); SF:UpdateTarget()
        elseif u=="target" then SF:UpdateTarget()
        elseif u=="targettarget" then SF:UpdateTargetOfTarget()
        elseif u and string.sub(u,1,5)=="party" then
            local pi=tonumber(string.sub(u,6))
            if pi and not SF.partyRosterRefreshPending then SF:UpdatePartyFrame(pi) end
        elseif u and string.sub(u,1,4)=="raid" and SF.UpdateRaidFrame then SF:UpdateRaidFrame(tonumber(string.sub(u,5)) or 1) end
    elseif ev=="PLAYER_TARGET_CHANGED" then SF.lastTargetAuraGuid=GetUnitGuidCompat("target"); SF:UpdateTarget()
    elseif ev=="PLAYER_ENTER_COMBAT" or ev=="PLAYER_REGEN_DISABLED" then
        SF.inCombat=true; if SF.UpdatePlayerEffects then SF:UpdatePlayerEffects(true) end
    elseif ev=="PLAYER_LEAVE_COMBAT" or ev=="PLAYER_REGEN_ENABLED" then
        SF.inCombat=nil; if SF.UpdatePlayerEffects then SF:UpdatePlayerEffects(true) end
    elseif ev=="PLAYER_UPDATE_RESTING" or ev=="PLAYER_AURAS_CHANGED" then if SF.UpdatePlayerEffects then SF:UpdatePlayerEffects(true) end
    elseif u=="player" then SF:UpdatePlayer(); if SF.UpdateMinimapButtonIcon then SF:UpdateMinimapButtonIcon() end; if SF.UpdatePlayerEffects then SF:UpdatePlayerEffects(true) end
    elseif u=="target" then SF:UpdateTarget()
    elseif u=="targettarget" then SF:UpdateTargetOfTarget()
    elseif u and string.sub(u,1,5)=="party" then
        local partyIndex=tonumber(string.sub(u,6))
        if partyIndex and partyIndex>=1 and partyIndex<=4 then
            -- Party resource traffic must never rebuild portraits/names/levels.
            -- Only the affected member's small power bar is queued below.
            if SF.partyRosterRefreshPending then
                -- The queued roster refresh will populate the final unit data.
                -- Ignore the duplicate identity/health/aura burst generated
                -- while party tokens are settling.
            elseif ev=="UNIT_HEALTH" or ev=="UNIT_MAXHEALTH" then
                SF:UpdatePartyFrameHealth(partyIndex)
            elseif ev=="UNIT_AURA" then
                if SF.UpdatePartyDebuffAlerts then SF:UpdatePartyDebuffAlerts(u) end
            elseif ev=="UNIT_NAME_UPDATE" then
                SF:UpdatePartyFrame(partyIndex)
            elseif ev=="UNIT_PORTRAIT_UPDATE" then
                SF:UpdatePartyFrame(partyIndex)
                if SF.QueuePartyPortraitUpdate then SF:QueuePartyPortraitUpdate(partyIndex,true) end
            elseif ev=="UNIT_MANA" or ev=="UNIT_MAXMANA" or ev=="UNIT_RAGE" or ev=="UNIT_ENERGY" or ev=="UNIT_DISPLAYPOWER" then
                -- Resource traffic is intentionally isolated from the expensive
                -- portrait/name/level path. Queue only this member's tiny power
                -- strip, with a short coalescing throttle handled in OnUpdate.
                if SlamFramesDB.showPartyPower and SF.QueuePartyPowerUpdate then SF:QueuePartyPowerUpdate(partyIndex) end
            else
                SF:UpdatePartyFrame(partyIndex)
            end
        end
    elseif u and string.sub(u,1,4)=="raid" and SF.UpdateRaidFrame then
        SF:UpdateRaidFrame(tonumber(string.sub(u,5)) or 1)
    end
end)

local reconcileElapsed=0
eventFrame:SetScript("OnUpdate",function()
    -- Party roster population is intentionally processed outside the normal
    -- 0.20s reconciliation cadence so one member can be populated per frame.
    if SF.ProcessPartyRosterRefresh then SF:ProcessPartyRosterRefresh(arg1 or 0) end
    if SF.ProcessPartyPowerUpdates then SF:ProcessPartyPowerUpdates(arg1 or 0) end
    if SF.ProcessPartyPortraitUpdates then SF:ProcessPartyPortraitUpdates() end

    -- click-cast target restoration must run faster than the normal
    -- 0.20s UI reconciliation cadence.
    if SF.ProcessClickTargetRestore then SF:ProcessClickTargetRestore() end
    reconcileElapsed=reconcileElapsed+(arg1 or 0)
    if reconcileElapsed<0.20 then return end
    reconcileElapsed=0

    -- A unit frame must sit above world/nameplate frames in normal
    -- gameplay, but below managed Blizzard panels while those panels are open.
    -- Reconcile only when the desired strata actually changes.
    if SF.player and SF.GetUnitFrameStrata then
        local wanted=SF:GetUnitFrameStrata()
        if SF.unitFrameStrata~=wanted then
            SF.unitFrameStrata=wanted
            SF:RefreshFrameLayers(SF.topFrameKey)
        end
    end

    -- Blizzard party-frame suppression is reconciled on roster/settings/world
    -- events. Do not force Hide()/SetAlpha() on all four native frames here.
    PruneAuraTimingCache()
    if SF.player and (UnitExists("target") or SF.testMode) then SF:UpdateTargetOfTarget(); SF:UpdateAuras() end
end)

SLASH_SLAMFRAMES1="/slamframes"
SLASH_SLAMFRAMES2="/sf"
SlashCmdList["SLAMFRAMES"]=function(msg) SF:HandleSlash(msg) end
