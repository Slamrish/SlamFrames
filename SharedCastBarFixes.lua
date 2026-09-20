-- SlamFrames TEST 22 - stable shared cast-bar behavior + no live fallback timer.
-- This file intentionally contains ONLY behavior that every cast-bar style
-- should inherit.  Style-specific artwork/layout belongs in the style module.
-- OctoWoW / Vanilla 1.12 compatible.

local SF=SlamFrames
if not SF then return end

local function Lower(v)
    return string.lower(tostring(v or ""))
end

local function IsGenericCastName(name)
    local n=Lower(name)
    return n=="open" or n=="opening" or n=="cast" or n=="casting"
        or n=="channel" or n=="channeling" or n=="spell"
end

local function NormalizeCastName(name)
    if not name or name=="" then return nil end
    local n=Lower(name)
    -- Object / quest interactions should never leak the engine's old
    -- "Open" / "Opening" wording into SlamFrames.
    if n=="open" or n=="opening" then return "Using" end
    if IsGenericCastName(name) then return nil end
    return name
end

SF.IsGenericCastDisplayName=IsGenericCastName
SF.NormalizeCastDisplayName=NormalizeCastName

-- A new cast always owns the bar immediately.  Clear any transient failure
-- presentation before the base engine starts the new spell.  This fixes the
-- old interrupt -> immediate recast case for EVERY cast-bar style.
local PreviousStartCastBar=SF.StartCastBar
function SF:StartCastBar(name,texture,startTime,endTime,isChannel,source,spellID)
    local cb=self.castbar
    if cb then
        cb.failure=nil
        cb.failureUntil=nil
        cb.fadeStart=nil
        cb.previewHold=nil
        cb:SetAlpha(1)
    end

    PreviousStartCastBar(self,name,texture,startTime,endTime,isChannel,source,spellID)

    cb=self.castbar
    if not cb then return end

    local safe=NormalizeCastName(name)
    if safe then
        cb.sfStableDisplayName=safe
        cb.castDisplayName=safe
        if cb.name then cb.name:SetText(safe) end
    elseif Lower(name)=="open" or Lower(name)=="opening" then
        cb.sfStableDisplayName="Using"
        cb.castDisplayName="Using"
        if cb.name then cb.name:SetText("Using") end
    end
end

-- CastBar.lua periodically reconciles against Blizzard/C_Spell state.  Old
-- clients can briefly return generic names such as "Opening" after a real
-- spell has already started.  Run this correction after the base renderer so
-- every current/future visual style keeps the last trustworthy spell name.
local PreviousRenderCastBar=SF.RenderCastBar
function SF:RenderCastBar()
    local cb=self.castbar

    -- CastBar.lua has a harmless preview-oriented fallback of 1.8 / 3.0
    -- whenever the frame is visible but no active cast/failure/preview state
    -- exists.  During a REAL cast fade this briefly leaked onto screen and
    -- looked like the spell had randomly become a 3-second cast.
    --
    -- A fade is presentation-only: preserve the exact last rendered state and
    -- let UpdateCastBar change alpha.  Do not recalculate fill or timer values.
    -- This also keeps the red INTERRUPTED/FAILED presentation intact through
    -- its fade instead of letting the orange 1.8 / 3.0 placeholder flash in.
    if cb and cb:IsShown() and cb.fadeStart and not cb.active and not cb.failure and not cb.previewHold then
        if cb.latency then cb.latency:Hide() end
        if cb.latencyEdge then cb.latencyEdge:Hide() end
        if cb.spark then cb.spark:Hide() end
        return
    end

    PreviousRenderCastBar(self)
    cb=self.castbar
    if not cb or not cb:IsShown() or not cb.name then return end
    if cb.failure then return end

    local shown=cb.name:GetText()
    if IsGenericCastName(shown) then
        if cb.sfStableDisplayName then
            cb.name:SetText(cb.sfStableDisplayName)
            cb.castDisplayName=cb.sfStableDisplayName
        elseif Lower(shown)=="open" or Lower(shown)=="opening" then
            cb.name:SetText("Using")
            cb.castDisplayName="Using"
            cb.sfStableDisplayName="Using"
        end
    elseif shown and shown~="" then
        local safe=NormalizeCastName(shown)
        if safe then cb.sfStableDisplayName=safe end
    end
end

-- Clear the locked label when the cast is truly cleared.  Style-specific
-- modules may keep their own target/subtext state separately.
local PreviousClearCastBar=SF.ClearCastBar
function SF:ClearCastBar(immediate)
    PreviousClearCastBar(self,immediate)
    if self.castbar then self.castbar.sfStableDisplayName=nil end
end
