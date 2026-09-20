-- SlamFrames TEST 26 - canonical cast progress renderer + safe STOP/interrupt arbitration.
-- Inspired by DragonflightUI-Reforged's Turtle/Vanilla cast bar architecture:
-- timing/state produces one normalized 0..1 progress value; the active visual
-- style converts that value into pixels.  This module is intentionally loaded
-- after all style modules so Classic, Ornate, and future styles share the same
-- final geometry/state rules.

local SF=SlamFrames
if not SF then return end

local function Clamp(v,lo,hi)
    v=tonumber(v) or lo
    if v<lo then return lo end
    if v>hi then return hi end
    return v
end

local function IsOrnate(cb)
    if not cb then return false end
    if tonumber(cb.styleNumber)==2 then return true end
    return SlamFramesDB and tonumber(SlamFramesDB.castbarStyle)==2
end

local function TrackWidth(cb,isFailure)
    local w=math.max(0.5,tonumber(cb and cb.innerW) or 0.5)
    if isFailure and IsOrnate(cb) then
        local scale=tonumber(cb.layoutScale) or 1
        local style=cb.style or {}
        local inset=(tonumber(style.failRightInset) or 18)*scale
        w=math.max(0.5,w-inset)
    end
    return w
end

local function ComputeLiveProgress(cb,now)
    if not cb or not cb.startTime or not cb.endTime then return nil,nil,nil end
    local duration=math.max(0.01,(tonumber(cb.endTime) or 0)-(tonumber(cb.startTime) or 0))
    local current
    local pct
    if cb.isChannel then
        current=math.max(0,(tonumber(cb.endTime) or now)-now)
        pct=current/duration
    else
        current=math.max(0,now-(tonumber(cb.startTime) or now))
        pct=current/duration
    end
    pct=Clamp(pct,0,1)
    return pct,current,duration
end

local function Remember(cb,pct,current,duration,isFailure)
    if not cb then return end
    cb.sfCanonicalProgress=Clamp(pct or 0,0,1)
    cb.sfCanonicalCurrent=tonumber(current) or 0
    cb.sfCanonicalDuration=math.max(0.01,tonumber(duration) or 0.01)
    cb.sfCanonicalFailure=isFailure and true or nil
end

local function ClearTerminalState(cb)
    if not cb then return end
    cb.sfPendingSuccess=nil
    cb.sfPendingSuccessAt=nil
    cb.sfTerminalSuccess=nil
    cb.sfTerminalSuccessUntil=nil
    cb.sfCanonicalFailure=nil
end

-- A stop event can arrive just before INTERRUPTED/FAILED on this client.
-- Do not instantly force a yellow 100% bar.  Hold the last live progress for a
-- very short arbitration window; an interrupt/fail cancels it.  If no failure
-- follows, the cast is then finalized at one deterministic 100% boundary.
local TERMINAL_ARBITRATION=0.20

local PreviousStartCastBar=SF.StartCastBar
function SF:StartCastBar(name,texture,startTime,endTime,isChannel,source,spellID)
    local cb=self.castbar
    if cb then
        ClearTerminalState(cb)
        cb.sfCanonicalProgress=0
        cb.sfCanonicalCurrent=0
        cb.sfCanonicalDuration=nil
    end
    PreviousStartCastBar(self,name,texture,startTime,endTime,isChannel,source,spellID)
end

local PreviousFailCastBar=SF.FailCastBar
function SF:FailCastBar(label)
    local cb=self.castbar
    if cb then
        ClearTerminalState(cb)
        cb.sfCanonicalProgress=1
        cb.sfCanonicalCurrent=0
        cb.sfCanonicalFailure=true
    end
    PreviousFailCastBar(self,label)
end

local PreviousClearCastBar=SF.ClearCastBar
function SF:ClearCastBar(immediate)
    local cb=self.castbar
    if immediate or not cb or cb.failure or cb.previewHold or not cb:IsShown() then
        if cb then ClearTerminalState(cb) end
        PreviousClearCastBar(self,immediate)
        return
    end

    -- Non-immediate clear means the cast/channel ended. Capture the final
    -- legitimate live state before the base engine removes cb.active.
    if cb.active and cb.startTime and cb.endTime then
        local pct,current,duration=ComputeLiveProgress(cb,GetTime())
        if pct then Remember(cb,pct,current,duration,false) end
    end

    PreviousClearCastBar(self,false)

    cb=self.castbar
    if not cb then return end
    cb.sfPendingSuccess=true
    cb.sfPendingSuccessAt=GetTime()+TERMINAL_ARBITRATION
    -- Hold alpha/geometry while waiting to see whether INTERRUPTED/FAILED is
    -- delivered immediately after STOP. The shared renderer will not show the
    -- old 1.8/3.0 fallback during this state.
    cb.fadeStart=nil
    cb:SetAlpha(1)
    cb:Show()
end

local PreviousRenderCastBar=SF.RenderCastBar
function SF:RenderCastBar()
    PreviousRenderCastBar(self)

    local cb=self.castbar
    if not cb or not cb:IsShown() or not cb.fill then return end
    local now=GetTime()
    local pct,current,duration,isFailure

    if cb.failure then
        pct=1
        current=0
        duration=cb.sfCanonicalDuration or 1
        isFailure=true
        Remember(cb,pct,current,duration,true)
    elseif cb.previewHold then
        pct=Clamp(cb.previewPct or 0.55,0,1)
        duration=math.max(0.01,tonumber(cb.previewDuration) or 3)
        current=duration*pct
        Remember(cb,pct,current,duration,false)
    elseif cb.active and cb.startTime and cb.endTime then
        pct,current,duration=ComputeLiveProgress(cb,now)
        if pct then Remember(cb,pct,current,duration,false) end
    elseif cb.sfPendingSuccess then
        pct=Clamp(cb.sfCanonicalProgress or 0,0,1)
        current=tonumber(cb.sfCanonicalCurrent) or 0
        duration=math.max(0.01,tonumber(cb.sfCanonicalDuration) or 1)
    elseif cb.sfTerminalSuccess then
        pct=1
        duration=math.max(0.01,tonumber(cb.sfCanonicalDuration) or 1)
        current=duration
        Remember(cb,pct,current,duration,false)
    elseif cb.fadeStart and cb.sfCanonicalProgress~=nil then
        -- Failure fade or another presentation-only fade: preserve the last
        -- canonical geometry. Never let a fallback timer/width recalculate it.
        pct=Clamp(cb.sfCanonicalProgress,0,1)
        current=tonumber(cb.sfCanonicalCurrent) or 0
        duration=math.max(0.01,tonumber(cb.sfCanonicalDuration) or 1)
        isFailure=cb.sfCanonicalFailure and true or false
    else
        return
    end

    local trackW=TrackWidth(cb,isFailure or cb.failure)
    local fillW=math.max(0.5,trackW*Clamp(pct,0,1))

    -- One and only one final width calculation for every style/state.
    cb.fill:ClearAllPoints()
    cb.fill:SetPoint("BOTTOMLEFT",cb.body,"BOTTOMLEFT",cb.innerX or 0,cb.innerY or 0)
    cb.fill:SetHeight(cb.innerH or 1)
    cb.fill:SetWidth(fillW)
    cb.fill:SetTexCoord(0,Clamp(pct,0,1),0,1)
    cb.fill:Show()

    -- Timer derives from the same canonical timing state as the fill.
    if SlamFramesDB.castbarShowTimer and not cb.failure then
        cb.timer:SetText(string.format("%.1f / %.1f",math.max(0,current or 0),duration or 0))
    elseif cb.failure then
        cb.timer:SetText("")
    end

    -- Spark is also derived from the exact same track and progress, preventing
    -- it from appearing a few pixels ahead/behind the fill after transitions.
    if (cb.active or cb.previewHold) and not cb.failure then
        local sx=(cb.innerX or 0)+math.max(0,math.min(trackW,trackW*Clamp(pct,0,1)))
        cb.spark:ClearAllPoints()
        cb.spark:SetPoint("BOTTOMLEFT",cb.body,"BOTTOMLEFT",sx,(cb.innerY or 0)-1)
        cb.spark:Show()
    else
        cb.spark:Hide()
    end
end

local PreviousUpdateCastBar=SF.UpdateCastBar
function SF:UpdateCastBar(elapsed)
    local cb=self.castbar
    local now=GetTime()

    -- Keep the short STOP-vs-INTERRUPT arbitration state visible and stable.
    if cb and cb.sfPendingSuccess then
        cb.fadeStart=nil
        cb:SetAlpha(1)
        cb:Show()
        if now>=cb.sfPendingSuccessAt then
            cb.sfPendingSuccess=nil
            cb.sfPendingSuccessAt=nil
            cb.sfTerminalSuccess=true
            cb.sfTerminalSuccessUntil=now+0.28
            cb.sfCanonicalProgress=1
            cb.sfCanonicalCurrent=cb.sfCanonicalDuration or 0
            cb.fadeStart=now
        end
    end

    local wasActive=cb and cb.active and true or false
    local oldEnd=cb and cb.endTime or nil

    PreviousUpdateCastBar(self,elapsed)

    cb=self.castbar
    if not cb then return end
    now=GetTime()

    -- The base updater can naturally expire a cast at endTime even if a STOP
    -- event was not observed. Convert that path into the same arbitration flow
    -- so terminal geometry is deterministic too.
    if wasActive and oldEnd and now>=oldEnd and not cb.active and cb.fadeStart
        and not cb.failure and not cb.sfPendingSuccess and not cb.sfTerminalSuccess then
        cb.sfPendingSuccess=true
        cb.sfPendingSuccessAt=now+TERMINAL_ARBITRATION
        cb.fadeStart=nil
        cb:SetAlpha(1)
        cb:Show()
    end

    if cb.sfPendingSuccess then
        cb.fadeStart=nil
        cb:SetAlpha(1)
        cb:Show()
        self:RenderCastBar()
        return
    end

    if cb.sfTerminalSuccess then
        if cb.sfTerminalSuccessUntil and now>=cb.sfTerminalSuccessUntil then
            cb.sfTerminalSuccess=nil
            cb.sfTerminalSuccessUntil=nil
        elseif cb:IsShown() then
            self:RenderCastBar()
        end
    end
end

-- TEST 26: never infer an interrupt from SPELLCAST_STOP alone.
-- OctoWoW can deliver a normal successful STOP before the local visual timing
-- has reached 100%, especially with pushback/latency.  ClearCastBar() already
-- places STOP into the neutral sfPendingSuccess arbitration state above.  A
-- genuine SPELLCAST_INTERRUPTED / FAILED event owns the red failure state; if
-- none arrives within TERMINAL_ARBITRATION, the pending cast becomes a normal
-- successful completion.  This avoids both false interrupts and the old yellow
-- full-bar flash that occurred before real interrupt events.
