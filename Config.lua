-- SlamFrames v3.1.0
-- Stable visual geometry + true layout scaling + settings/status pass.

SlamFrames_Config = {
    version = "3.1.0",
    texturePath = "Interface\\AddOns\\SlamFrames\\Textures\\",
    levelBadgeTexture = "level_badge.tga",
    combatGlowTexture = "combat_glow.tga",

    -- All coordinates below are authored at 1.00 layout scale. SlamFrames v0.7
    -- resizes/repositions every child explicitly instead of Frame:SetScale(),
    -- which keeps text, badges, portraits and auras coherent on old clients.
    player = {
        width = 430,
        height = 146,
        frame = "player_frame.tga",
        textureUMax = 0.83984375,
        textureVMax = 0.57031250,

        -- v0.10 variable bar-length renderer. The portrait/left endcap and
        -- right endcap stay pixel-stable; only the straight middle section
        -- compresses. widthStep is authored pixels at 1.00 scale.
        widthSlices = { left = 132, right = 18, step = 30, maxPreset = 3 },

        portrait = {
            x = 61.5, y = 78.0,
            size = 107,
            slices = 56,
            zoom = 1.14, -- v0.10: final tiny zoom-out
            offsetX = 0.00,
            offsetY = 0.005,
        },

        -- Confirmed-good v0.5/v0.6 bar cavities.
        health = { x = 121.0, y = 66.4, w = 297.0, h = 37.8 },
        power  = { x = 121.0, y = 36.6, w = 297.0, h = 18.4 },

        name = {
            x = 113, y = 101.0, w = 292, h = 30,
            font = 22,
            fontPath = "Fonts\\FRIZQT__.TTF",
            flags = "OUTLINE",
            justify = "LEFT",
        },

        levelBadge = {
            x = 103.0, y = 29.0,
            size = 43,
            font = 19,
            fontPath = "Fonts\\FRIZQT__.TTF",
            flags = "OUTLINE",
        },

        healthPercentFont = 15,
        healthValueFont = 11,
        powerFont = 12,
        healthPercentOffset = 6,
        healthValueOffset = -9,
    },

    target = {
        width = 430,
        height = 137,
        frame = "target_frame.tga",
        textureUMax = 0.83984375,
        textureVMax = 0.53515625,

        -- Target portrait/right endcap stays undistorted while the center bar
        -- region shortens in four practical presets: 100/90/80/70%.
        widthSlices = { left = 18, right = 124, step = 30, maxPreset = 3 },

        portrait = {
            x = 370.4, y = 76.0,
            size = 103,
            slices = 56,
            zoom = 1.12, -- v0.10: final tiny zoom-out
            offsetX = 0.00,
            offsetY = 0.005,
        },
        health = { x = 10.5, y = 65.4, w = 302.5, h = 34.0 },
        power  = { x = 10.5, y = 36.3, w = 302.5, h = 18.2 },

        name = {
            x = 10, y = 98.5, w = 302, h = 29,
            font = 21,
            fontPath = "Fonts\\FRIZQT__.TTF",
            flags = "OUTLINE",
            justify = "LEFT",
        },
        levelBadge = {
            x = 329.5, y = 28.0,
            size = 40,
            font = 17,
            fontPath = "Fonts\\FRIZQT__.TTF",
            flags = "OUTLINE",
        },

        healthPercentFont = 15,
        healthValueFont = 11,
        powerFont = 12,
        healthPercentOffset = 6,
        healthValueOffset = -9,

        -- Aura row is laid out relative to the power bar in v0.7. The visible
        -- gold edge (not the transparent texture padding) aligns to health.x.
        aura = { verticalGap = 5.0, startOffset = -8.0 },
    },

    tot = {
        width = 260,
        height = 78,
        frame = "tot_frame.tga",
        textureUMax = 0.50781250,
        textureVMax = 0.60937500,

        -- v0.11 gives target-of-target the same compact width choices as the
        -- player/target frames. The portrait/left end stays fixed while only
        -- the straight bar middle compresses. 18px steps are proportional to
        -- the smaller ToT health cavity (~100/90/80/70%).
        widthSlices = { left = 78, right = 10, step = 18, maxPreset = 3 },

        portrait = {
            x = 38.0, y = 39.3,
            size = 66,
            slices = 44,
            zoom = 1.08,
            offsetX = 0.00,
            offsetY = 0.00,
        },
        health = { x = 74.5, y = 26.6, w = 178.5, h = 20.5 },
        name = {
            x = 73, y = 47.0, w = 178, h = 22,
            font = 16,
            fontPath = "Fonts\\FRIZQT__.TTF",
            flags = "OUTLINE",
            justify = "LEFT",
        },
        levelBadge = {
            x = 61.0, y = 13.5,
            size = 28,
            font = 12,
            fontPath = "Fonts\\FRIZQT__.TTF",
            flags = "OUTLINE",
        },
        healthPercentFont = 10,
        healthValueFont = 7,
        healthPercentOffset = 4,
        healthValueOffset = -5,
    },

    -- Compact Party Frames share the proven ToT artwork and geometry. A thin
    -- party-only resource strip overlays the bottom of the health cavity so
    -- mana/rage/energy can be shown without increasing the frame footprint.
    party = {
        width = 260,
        height = 78,
        frame = "tot_frame.tga",
        textureUMax = 0.50781250,
        textureVMax = 0.60937500,
        widthSlices = { left = 78, right = 10, step = 18, maxPreset = 3 },
        portrait = {
            x = 38.0, y = 39.3,
            size = 66,
            slices = 44,
            zoom = 1.08,
            offsetX = 0.00,
            offsetY = 0.00,
        },
        health = { x = 74.5, y = 26.6, w = 178.5, h = 20.5 },
        -- Party-only resource strip. Keep it as a distinct row immediately
        -- below health; at the default 0.60 party scale this is a compact ~4px
        -- bar and does not increase the outer Party Frame footprint.
        power  = { x = 75.0, y = 19.2, w = 177.5, h = 7.0 },
        name = {
            x = 73, y = 47.0, w = 178, h = 22,
            font = 16,
            fontPath = "Fonts\\FRIZQT__.TTF",
            flags = "OUTLINE",
            justify = "LEFT",
        },
        levelBadge = {
            x = 61.0, y = 13.5,
            size = 28,
            font = 12,
            fontPath = "Fonts\\FRIZQT__.TTF",
            flags = "OUTLINE",
        },
        healthPercentFont = 10,
        healthValueFont = 7,
        powerFont = 7,
        healthPercentOffset = 4,
        healthValueOffset = -5,
    },

    raid = {
        width = 260,
        height = 78,
        frame = "tot_frame.tga",
        textureUMax = 0.50781250,
        textureVMax = 0.60937500,
        widthSlices = { left = 78, right = 10, step = 18, maxPreset = 3 },
        portrait = {
            x = 38.0, y = 39.3,
            size = 66,
            slices = 44,
            zoom = 1.08,
            offsetX = 0.00,
            offsetY = 0.00,
        },
        health = { x = 74.5, y = 26.6, w = 178.5, h = 20.5 },
        name = {
            x = 73, y = 47.0, w = 178, h = 22,
            font = 16,
            fontPath = "Fonts\\FRIZQT__.TTF",
            flags = "OUTLINE",
            justify = "LEFT",
        },
        levelBadge = {
            x = 61.0, y = 13.5,
            size = 28,
            font = 12,
            fontPath = "Fonts\\FRIZQT__.TTF",
            flags = "OUTLINE",
        },
        healthPercentFont = 10,
        healthValueFont = 7,
        healthPercentOffset = 4,
        healthValueOffset = -5,
    },


    castbar = {
        frameTexture = "castbar_frame.tga",
        fillTexture = "cast_fill.tga",
        latencyTexture = "cast_latency.tga",
        failIconTexture = "cast_fail_icon.tga",

        -- Selectable cast-bar skins. Style 1 preserves the clean v0.18 frame.
        -- Style 2 recreates the heavier concept-art ornamentation. Both use
        -- three slices so changing width never stretches decorative endcaps.
        styles = {
            [1] = {
                frameTexture = "castbar_frame.tga",
                iconBorderTexture = "aura_border.tga",
                bodyHeight = 52,
                iconSize = 64,
                iconInset = 10,
                bodyX = 52,
                leftCap = 26,
                rightCap = 30,
                leftSliceU = 0.06,
                rightSliceU = 0.94,
                fillLeft = 14,
                fillRight = 18,
                fillBottom = 8,
                fillHeight = 15,
                textY = 34,
                textInset = 17,
                nameFont = 15,
                timerFont = 13,
            },
            [2] = {
                frameTexture = "castbar_frame_style2.tga",
                iconBorderTexture = "castbar_icon_style2.tga",
                bodyHeight = 60,
                -- Style 2 uses the same width slider as Style 1, but its
                -- ornate body is intentionally shorter so the straight bar
                -- does not overwhelm or run into the decorative endcaps.
                iconSize = 72,
                iconInset = 14,
                bodyX = 58,
                leftCap = 50,
                rightCap = 66,
                leftSliceU = 0.12,
                rightSliceU = 0.86,
                fillLeft = 50,
                fillRight = 68,
                fillBottom = 10,
                fillHeight = 15,
                textY = 39,
                textInset = 29,
                -- Style 2 has heavier left/right ornamentation. Keep the
                -- spell name clear of the left spearwork and pull the timer
                -- inward from the decorated arrowhead.
                nameTextInset = 39,
                timerTextInset = 58,
                nameFont = 15,
                timerFont = 13,
                latencyTexture = "cast_latency_style2.tga",
                latencyAlpha = 1.00,
                latencyEdge = true,
            },
        },

        castColor = {1.00, 0.58, 0.02},
        channelColor = {0.30, 0.90, 0.12},
        failColor = {0.90, 0.08, 0.03},
    },

    aura = {
        size = 40,
        inset = 5,
        -- aura_border.tga has transparent padding. A negative frame gap makes
        -- the *visible* gold borders sit about 1px apart.
        spacing = -5.5,
        visibleLeftPad = 3.45,
        max = 16,
    },

    effects = {
        resting = true,
        cc = true,
        combat = true,
        scanInterval = 0.10,
    },
}
