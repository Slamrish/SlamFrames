-- SlamFrames TEST 28 - stacked/self aura duration refresh reconciliation.
-- OctoWoW / Vanilla 1.12-era compatible.
--
-- Nampower exposes BUFF_UPDATE_DURATION_SELF / DEBUFF_UPDATE_DURATION_SELF
-- specifically when an existing aura has its duration refreshed. SlamFrames'
-- original aura-slot path intentionally preserves a known-good start time when
-- BUFF_ADDED follows AURA_CAST, but that same rule can leave stack-refreshing
-- auras (for example Zeal) counting down from the old application.
--
-- This module updates the existing exact-GUID + spellId cache record in place
-- when Nampower reports a duration refresh. It also watches stack-increase
-- events as a fallback and queries GetPlayerAuraDuration when available.

local SF=SlamFrames
if not SF then return end

SF.auraTimingCache=SF.auraTimingCache or {}
SF.auraRefreshFix=SF.auraRefreshFix or {}
local Fix=SF.auraRefreshFix
Fix.pendingRefresh=nil
Fix.lastSelfGuid=Fix.lastSelfGuid or nil

local function NormalizeSpellId(id)
    id=tonumber(id)
    if not id then return nil end
    if id < -1 then id=id+65536 end
    if id<=0 then return nil end
    return id
end

local function GetPlayerGuid()
    if type(UnitGUID)=="function" then
        local ok,guid=pcall(UnitGUID,"player")
        if ok and guid and guid~="" then
            Fix.lastSelfGuid=guid
            return guid
        end
    end
    return Fix.lastSelfGuid
end

local function QueueAuraRefresh()
    Fix.pendingRefresh=0.03
end

local function RefreshCachedTimer(guid,spellId,duration,auraSlot,source)
    guid=guid or GetPlayerGuid()
    spellId=NormalizeSpellId(spellId)
    duration=tonumber(duration)
    auraSlot=tonumber(auraSlot)
    if not guid or not spellId or not duration or duration<=0 then return false end

    local states=SF.auraTimingCache[guid]
    if type(states)~="table" then
        states={}
        SF.auraTimingCache[guid]=states
    end

    local rec=states[spellId]
    if type(rec)~="table" then rec={} end

    local now=GetTime()
    rec.spellId=spellId
    rec.duration=duration
    rec.start=now
    rec.stop=now+duration
    if auraSlot then rec.auraSlot=auraSlot end
    if not rec.kind and auraSlot then
        if auraSlot<32 then rec.kind="buff" else rec.kind="debuff" end
    end
    rec.source=source or rec.source or "nampower-duration-refresh"
    rec.lastSource=source or "nampower-duration-refresh"
    rec.updated=now
    states[spellId]=rec

    if SF.auraTimingStats then
        SF.auraTimingStats.lastEvent=source or "AURA_DURATION_REFRESH"
        SF.auraTimingStats.lastSource=source or "nampower-duration-refresh"
        SF.auraTimingStats.durationRefresh=(SF.auraTimingStats.durationRefresh or 0)+1
    end

    QueueAuraRefresh()
    return true
end

-- Ask Nampower for the authoritative remaining duration of a raw player aura
-- slot. This is safe for stack modifications: if the server did not actually
-- refresh the duration, we preserve the same expiration by using the remaining
-- value rather than blindly resetting to the aura's full base duration.
local function RefreshFromAuraSlot(guid,expectedSpellId,auraSlot,source)
    if type(GetPlayerAuraDuration)~="function" then return false end
    auraSlot=tonumber(auraSlot)
    if not auraSlot then return false end

    local ok,spellId,remainingMs,expirationMs=pcall(GetPlayerAuraDuration,auraSlot)
    if not ok then return false end
    spellId=NormalizeSpellId(spellId) or NormalizeSpellId(expectedSpellId)
    remainingMs=tonumber(remainingMs)
    if not spellId or not remainingMs or remainingMs<=0 then return false end
    return RefreshCachedTimer(guid,spellId,remainingMs/1000,auraSlot,source)
end

local f=CreateFrame("Frame","SlamFramesAuraRefreshFixFrame")
Fix.frame=f

local events={
    "PLAYER_ENTERING_WORLD",
    "BUFF_UPDATE_DURATION_SELF",
    "DEBUFF_UPDATE_DURATION_SELF",
    -- Stack increases are reported as *_ADDED_* with state=2 in current
    -- Nampower. Use them only as a fallback query; the duration-update event
    -- remains the preferred source of truth.
    "BUFF_ADDED_SELF",
    "DEBUFF_ADDED_SELF",
}
local i
for i=1,table.getn(events) do
    pcall(function() f:RegisterEvent(events[i]) end)
end

f:SetScript("OnEvent",function()
    local ev=event
    if ev=="PLAYER_ENTERING_WORLD" then
        GetPlayerGuid()
        return
    end

    if ev=="BUFF_UPDATE_DURATION_SELF" or ev=="DEBUFF_UPDATE_DURATION_SELF" then
        -- Nampower signature:
        -- arg1 auraSlot (raw 0-based), arg2 durationMs,
        -- arg3 expirationTimeMs, arg4 spellId.
        local auraSlot=tonumber(arg1)
        local durationMs=tonumber(arg2)
        local spellId=NormalizeSpellId(arg4)
        if spellId and durationMs and durationMs>0 then
            RefreshCachedTimer(GetPlayerGuid(),spellId,durationMs/1000,auraSlot,"nampower-duration-refresh")
        elseif auraSlot then
            -- Newly added auras can report spellId=0 because this event fires
            -- before the unit field is populated. Let the normal SlamFrames
            -- application path handle those, but try the slot on the next
            -- stack/update path if possible.
            RefreshFromAuraSlot(GetPlayerGuid(),nil,auraSlot,"nampower-duration-slot")
        end
        return
    end

    if ev=="BUFF_ADDED_SELF" or ev=="DEBUFF_ADDED_SELF" then
        -- Nampower aura state signature:
        -- arg1 guid, arg2 luaSlot, arg3 spellId, arg4 stackCount,
        -- arg5 auraLevel, arg6 raw auraSlot, arg7 state
        -- state=2 means the existing aura was modified; on *_ADDED_* this is
        -- specifically a stack increase.
        local guid=arg1
        if guid and guid~="" then Fix.lastSelfGuid=guid end
        local state=tonumber(arg7)
        if state==2 then
            RefreshFromAuraSlot(guid,NormalizeSpellId(arg3),tonumber(arg6),"nampower-stack-refresh")
        end
    end
end)

-- Delay the visible aura rebuild by a few hundredths of a second because
-- BUFF_UPDATE_DURATION_SELF can arrive just before the refreshed aura fields
-- themselves are committed. This keeps stack count and timer visually in sync.
f:SetScript("OnUpdate",function()
    if not Fix.pendingRefresh then return end
    Fix.pendingRefresh=Fix.pendingRefresh-(arg1 or 0)
    if Fix.pendingRefresh>0 then return end
    Fix.pendingRefresh=nil
    if SF.UpdateAuras then SF:UpdateAuras() end
end)
