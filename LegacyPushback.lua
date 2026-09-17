-- SlamFrames TEST 36 - Turtle/Vanilla pushback timing bridge.
-- Based on the same legacy SPELLCAST_START / SPELLCAST_DELAYED timing model
-- used by DragonflightUI-Reforged on Turtle WoW 1.12.
-- Shared behavior: applies to every SlamFrames cast-bar visual style.

local SF=SlamFrames
if not SF then return end

local function Seconds(raw)
    local n=tonumber(raw)
    if not n or n<=0 then return nil end
    -- Turtle/Vanilla SPELLCAST_* timing arguments are milliseconds.
    -- Keep seconds-compatible fallbacks for custom client paths.
    if n>20 then return n/1000 end
    return n
end

local function LockLegacyTiming(cb,startTime,endTime)
    if not cb or not startTime or not endTime or endTime<=startTime then return end
    cb.sfLegacyTiming=true
    cb.sfLegacyStart=startTime
    cb.sfLegacyEnd=endTime
    cb.startTime=startTime
    cb.endTime=endTime

    -- CastBar.lua normally reconciles against C_Spell every ~0.05 sec.
    -- That is useful for most casts, but on Turtle it can immediately erase
    -- SPELLCAST_DELAYED pushback.  While a legacy cast is authoritative, keep
    -- the poll parked until the next cast resets this state.
    cb.nextTimingPoll=GetTime()+3600
    cb.nativeSyncUntil=nil
end

local function ClearLegacyTiming(cb)
    if not cb then return end
    cb.sfLegacyTiming=nil
    cb.sfLegacyStart=nil
    cb.sfLegacyEnd=nil
end

-- New casts always start with a clean timing owner.  The SPELLCAST_START event
-- below will promote ordinary Turtle/Vanilla casts to legacy-authoritative
-- timing when it supplies a real duration.
local PreviousStartCastBar=SF.StartCastBar
function SF:StartCastBar(name,texture,startTime,endTime,isChannel,source,spellID)
    local cb=self.castbar
    if cb then ClearLegacyTiming(cb) end
    PreviousStartCastBar(self,name,texture,startTime,endTime,isChannel,source,spellID)
end

local PreviousClearCastBar=SF.ClearCastBar
function SF:ClearCastBar(immediate)
    local cb=self.castbar
    if cb then ClearLegacyTiming(cb) end
    PreviousClearCastBar(self,immediate)
end

-- Mirror DragonflightUI-Reforged's proven Turtle 1.12 timing semantics:
--   SPELLCAST_START   -> start = now, end = now + duration
--   SPELLCAST_DELAYED -> start += delay, end += delay
-- Moving BOTH timestamps keeps the spell's true duration unchanged while
-- making the visible progress jump backward when pushback occurs.
local PreviousCastBarEvent=SF.CastBarEvent
function SF:CastBarEvent(ev,a1,a2,a3,a4,a5)
    local cb=self.castbar
    local beforeStart=cb and cb.startTime or nil
    local beforeEnd=cb and cb.endTime or nil
    local beforeLegacyStart=cb and cb.sfLegacyStart or nil
    local beforeLegacyEnd=cb and cb.sfLegacyEnd or nil

    PreviousCastBarEvent(self,ev,a1,a2,a3,a4,a5)

    cb=self.castbar
    if not cb then return end

    if ev=="SPELLCAST_START" then
        local duration=Seconds(a2)
        local special=(SF.IsSpecialActionCastTiming and SF.IsSpecialActionCastTiming(a1)) or (cb and cb.sfSpecialActionTiming)
        if duration and duration>0 and duration<60 and cb.active and not cb.isChannel and not special then
            local now=GetTime()
            LockLegacyTiming(cb,now,now+duration)
            if self.RenderCastBar then self:RenderCastBar() end
        end
        return
    end

    if ev=="SPELLCAST_DELAYED" then
        local delay=Seconds(a1) or Seconds(a2)
        local special=cb and cb.sfSpecialActionTiming
        if delay and delay>0 and delay<10 and cb.active and not cb.isChannel and not special then
            -- Use the timing from immediately BEFORE CastBar.lua handled the
            -- event.  Its own handler may query C_Spell; using our pre-event
            -- snapshot prevents that query from swallowing the pushback.
            local s=beforeLegacyStart or beforeStart or cb.startTime
            local e=beforeLegacyEnd or beforeEnd or cb.endTime
            if s and e and e>s then
                LockLegacyTiming(cb,s+delay,e+delay)
                if self.RenderCastBar then self:RenderCastBar() end
            end
        end
        return
    end

    if ev=="SPELLCAST_CHANNEL_START" or ev=="UNIT_SPELLCAST_CHANNEL_START" then
        ClearLegacyTiming(cb)
        return
    end
end

-- CastBar.lua performs a periodic timing reconciliation from C_Spell.  While
-- a legacy Turtle cast owns timing, pin the pushed-back timestamps before the
-- base updater runs and keep its next poll parked.  This is the key difference
-- from TEST 20: the delay can no longer be overwritten 0.05 sec later.
local PreviousUpdateCastBar=SF.UpdateCastBar
function SF:UpdateCastBar(elapsed)
    local cb=self.castbar
    if cb and cb.active and cb.sfLegacyTiming and not cb.isChannel then
        cb.startTime=cb.sfLegacyStart
        cb.endTime=cb.sfLegacyEnd
        cb.nextTimingPoll=GetTime()+3600
        cb.nativeSyncUntil=nil
    end

    PreviousUpdateCastBar(self,elapsed)

    cb=self.castbar
    if cb and cb.active and cb.sfLegacyTiming and not cb.isChannel then
        cb.startTime=cb.sfLegacyStart
        cb.endTime=cb.sfLegacyEnd
        cb.nextTimingPoll=GetTime()+3600
        cb.nativeSyncUntil=nil
    end
end
