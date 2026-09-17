-- SlamFrames TEST 36 - special/repeating action cast timing reconciliation.
-- Shared timing behavior for every cast-bar visual style.
--
-- Ordinary spells keep the proven LegacyPushback path.  Tradeskills and
-- ranged Shoot/Auto Shot are different: on Vanilla/Octo they can be exposed
-- through engine/native casting state that does not behave like a normal
-- pushback-able spell.  For those actions we keep the hidden Blizzard
-- CastingBarFrame timestamps authoritative instead of letting the generic
-- legacy pushback bridge overwrite them.

local SF=SlamFrames
if not SF then return end

local function Lower(v)
    return string.lower(tostring(v or ""))
end

local function FrameShown(frame)
    if not frame then return false end
    if frame.IsVisible then
        local ok,v=pcall(function() return frame:IsVisible() end)
        if ok and v then return true end
    end
    if frame.IsShown then
        local ok,v=pcall(function() return frame:IsShown() end)
        if ok and v then return true end
    end
    return false
end

local function ApiTradeskillActive()
    if C_Spell and type(C_Spell.UnitCastingInfo)=="function" then
        local ok,name,rank,tex,startMs,endMs,isTradeskill=pcall(C_Spell.UnitCastingInfo,"player")
        -- Some compatibility APIs expose boolean flags as 0/1. In Lua, 0 is
        -- truthy, so never use a raw `if isTradeskill` test here.
        local tradeFlag=(isTradeskill==true) or (tonumber(isTradeskill)==1)
        if ok and name and tradeFlag then return true end
    end
    return false
end

local function TradeWindowActive()
    return FrameShown(TradeSkillFrame) or FrameShown(CraftFrame)
end

local function IsShootName(name)
    local n=Lower(name)
    return n=="shoot" or n=="auto shot" or n=="autoshoot"
        or n=="shoot bow" or n=="shoot gun" or n=="shoot crossbow"
end

local function IsSpecialAction(name)
    if IsShootName(name) then return true end
    if ApiTradeskillActive() then return true end
    if TradeWindowActive() then return true end
    return false
end

-- Expose this so the existing LegacyPushback bridge can make the same choice
-- without duplicating profession / Shoot detection.
SF.IsSpecialActionCastTiming=IsSpecialAction

local function NativeCastState()
    local f=CastingBarFrame
    if not f then return nil end

    local isChannel=f.channeling and true or false
    local isCasting=f.casting and true or false
    if not isCasting and not isChannel then return nil end

    local s=tonumber(f.startTime)
    local e
    if isChannel then e=tonumber(f.endTime) else e=tonumber(f.maxValue) end

    -- Defensive fallback for custom clients that only keep usable status-bar
    -- min/max values instead of the stock fields.
    if (not s or not e or e<=s) and f.GetMinMaxValues then
        local ok,minv,maxv=pcall(function() return f:GetMinMaxValues() end)
        minv=tonumber(minv); maxv=tonumber(maxv)
        if ok and minv and maxv and maxv>minv then
            if minv>1 then
                s=minv; e=maxv
            elseif maxv>0 then
                s=GetTime(); e=s+maxv-minv
            end
        end
    end

    if not s or not e or e<=s then return nil end

    local name=nil
    if CastingBarFrameText and CastingBarFrameText.GetText then
        name=CastingBarFrameText:GetText()
    elseif f.Text and f.Text.GetText then
        name=f.Text:GetText()
    end

    return s,e,isChannel,name
end

local function ApiCastState()
    if C_Spell and type(C_Spell.UnitCastingInfo)=="function" then
        local name,rank,tex,startMs,endMs,isTradeskill=C_Spell.UnitCastingInfo("player")
        startMs=tonumber(startMs); endMs=tonumber(endMs)
        if name and startMs and endMs and endMs>startMs then
            return startMs/1000,endMs/1000,false,name,isTradeskill and true or false
        end
    end
    if C_Spell and type(C_Spell.UnitChannelInfo)=="function" then
        local name,rank,tex,startMs,endMs=C_Spell.UnitChannelInfo("player")
        startMs=tonumber(startMs); endMs=tonumber(endMs)
        if name and startMs and endMs and endMs>startMs then
            return startMs/1000,endMs/1000,true,name,false
        end
    end
    return nil
end

local function ClearLegacyOwner(cb)
    if not cb then return end
    cb.sfLegacyTiming=nil
    cb.sfLegacyStart=nil
    cb.sfLegacyEnd=nil
    cb.nativeSyncUntil=nil
    -- Do not let CastBar.lua's normal C_Spell polling replace the special
    -- native timing a frame later.  This field is reset naturally by the next
    -- StartCastBar call when the cast is not special.
    cb.nextTimingPoll=GetTime()+3600
end

local function CandidateBelongsToSpecialCast(cb,s,e,ch,name)
    if not cb or not cb.active then return false end
    s=tonumber(s); e=tonumber(e)
    if not s or not e or e<=s then return false end
    local now=GetTime()
    if e<=(now-0.05) then return false end
    if (ch and true or false)~=(cb.isChannel and true or false) then return false end
    if cb.castStartedAt and s<(cb.castStartedAt-1.50) then return false end

    -- Do not require text equality here. Old-client professions/item actions can
    -- expose a recipe name in one source and a profession/action label in the
    -- other. Freshness + cast/channel type are the reliable ownership signals.
    return true
end

local function ApplySpecialTiming(cb,nameHint)
    if not cb or not cb.active then return false end

    local shown=nameHint or cb.castDisplayName
    if (not shown or shown=="") and cb.name and cb.name.GetText then shown=cb.name:GetText() end

    if not cb.sfSpecialActionTiming and not IsSpecialAction(shown) then return false end
    cb.sfSpecialActionTiming=true
    ClearLegacyOwner(cb)

    -- For Shoot and tradeskills, stock/engine CastingBarFrame state is the
    -- first choice because that is what the Vanilla client itself uses to draw
    -- the cast.  C_Spell is retained only as a fallback if the native frame has
    -- not stamped its timestamps yet.
    local s,e,ch,nativeName=NativeCastState()
    local source="native-special"
    if not CandidateBelongsToSpecialCast(cb,s,e,ch,nativeName) then
        s,e,ch,nativeName=ApiCastState()
        source="api-special-fallback"
    end

    if not CandidateBelongsToSpecialCast(cb,s,e,ch,nativeName) then return false end

    cb.startTime=s
    cb.endTime=e
    cb.isChannel=ch and true or false
    cb.castSource=source

    -- Keep the real recipe/action label that the rest of SlamFrames already
    -- resolved.  Only use the native text if our label is still generic/empty.
    if (not cb.castDisplayName or cb.castDisplayName=="" or cb.castDisplayName=="Casting")
        and nativeName and nativeName~="" then
        cb.castDisplayName=nativeName
        if cb.name then cb.name:SetText(nativeName) end
    end

    return true
end

local PreviousStartCastBar=SF.StartCastBar
function SF:StartCastBar(name,texture,startTime,endTime,isChannel,source,spellID)
    PreviousStartCastBar(self,name,texture,startTime,endTime,isChannel,source,spellID)
    local cb=self.castbar
    if not cb then return end

    cb.sfSpecialActionTiming=IsSpecialAction(name) and true or nil
    if cb.sfSpecialActionTiming then
        ApplySpecialTiming(cb,name)
        if self.RenderCastBar then self:RenderCastBar() end
    else
        -- A normal spell should be free to use the existing C_Spell / legacy
        -- pushback machinery immediately.
        cb.nextTimingPoll=nil
    end
end

-- LegacyPushback.lua is already loaded before this file.  It can temporarily
-- claim SPELLCAST_START during the inner handler, so reconcile once more after
-- the complete event chain returns.
local PreviousCastBarEvent=SF.CastBarEvent
function SF:CastBarEvent(ev,a1,a2,a3,a4,a5)
    PreviousCastBarEvent(self,ev,a1,a2,a3,a4,a5)

    local cb=self.castbar
    if not cb then return end

    if ev=="SPELLCAST_START" or ev=="UNIT_SPELLCAST_START" then
        local hint=(ev=="SPELLCAST_START") and a1 or a4
        if cb.active and (cb.sfSpecialActionTiming or IsSpecialAction(hint)) then
            cb.sfSpecialActionTiming=true
            ApplySpecialTiming(cb,hint)
            if self.RenderCastBar then self:RenderCastBar() end
        end
    elseif ev=="SPELLCAST_DELAYED" or ev=="UNIT_SPELLCAST_DELAYED" then
        if cb.active and cb.sfSpecialActionTiming then
            -- These actions are not normal pushback-able spell casts.  Refresh
            -- from native timing instead of applying the generic delay bridge.
            ApplySpecialTiming(cb,cb.castDisplayName)
            if self.RenderCastBar then self:RenderCastBar() end
        end
    end
end

-- Re-assert special-action timing immediately before and after the existing
-- update chain.  The pre-pass prevents an incorrect shorter duration from
-- expiring the bar; the post-pass guarantees the canonical renderer sees the
-- same native timestamps.  Both Classic and Ornate styles therefore inherit
-- this correction automatically.
local PreviousUpdateCastBar=SF.UpdateCastBar
function SF:UpdateCastBar(elapsed)
    local cb=self.castbar
    if cb and cb.active and cb.sfSpecialActionTiming then
        ApplySpecialTiming(cb,cb.castDisplayName)
    end

    PreviousUpdateCastBar(self,elapsed)

    cb=self.castbar
    if cb and cb.active and cb.sfSpecialActionTiming then
        if ApplySpecialTiming(cb,cb.castDisplayName) and self.RenderCastBar then
            self:RenderCastBar()
        end
    end
end
