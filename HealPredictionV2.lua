-- SlamFrames Predictive Healing TEST 2
-- Robust HealComm polling + local cast fallback + segment-based prediction rendering.
-- Loaded after Enhancements.lua.

local SF=SlamFrames
if not SF then return end

SF.healPredictionStats=SF.healPredictionStats or {
    polls=0, localStarts=0, hcEvents=0,
    lastSpell=nil, lastTarget=nil,
}
SF.localHealPrediction=SF.localHealPrediction or {}

local function BindHealComm()
    if SF.HealComm and type(SF.HealComm.getHeal)=="function" then return SF.HealComm end
    if not AceLibrary then return nil end
    local ok,lib=pcall(function() return AceLibrary("HealComm-1.0") end)
    if ok and lib and type(lib.getHeal)=="function" then
        SF.HealComm=lib
        return lib
    end
    return nil
end

local function UnitTokenForName(name)
    if not name or name=="" then return nil end
    if UnitName("player")==name then return "player" end
    if UnitExists("target") and UnitName("target")==name then return "target" end
    local i,u
    for i=1,4 do
        u="party"..i
        if UnitExists(u) and UnitName(u)==name then return u end
    end
    for i=1,40 do
        u="raid"..i
        if UnitExists(u) and UnitName(u)==name then return u end
    end
    if AceLibrary then
        local ok,roster=pcall(function() return AceLibrary("RosterLib-2.0") end)
        if ok and roster and type(roster.GetUnitIDFromName)=="function" then
            local ok2,unit=pcall(function() return roster:GetUnitIDFromName(name) end)
            if ok2 and unit then return unit end
        end
    end
    return nil
end

local function FriendlyTargetUnit(hc)
    if hc and hc.SpellCastInfo and hc.SpellCastInfo[3] then
        local u=UnitTokenForName(hc.SpellCastInfo[3])
        if u and UnitExists(u) and (not UnitCanAssist or UnitCanAssist("player",u)) then return u end
    end
    if UnitExists("target") and (not UnitCanAssist or UnitCanAssist("player","target")) then
        if not UnitIsPlayer or UnitIsPlayer("target") then return "target" end
    end
    return "player"
end

local function ResolveSpellNameRank(hc,spellName,spellID)
    local name=spellName
    local rank=nil
    if spellID and type(SpellInfo)=="function" then
        local ok,n,r=pcall(SpellInfo,spellID)
        if ok then name=n or name; rank=r end
    end
    if not rank and hc and hc.SpellCastInfo and hc.SpellCastInfo[1]==name then
        rank=hc.SpellCastInfo[2]
    end
    local rn=tonumber(rank)
    if not rn and type(rank)=="string" then
        local _,_,digits=string.find(rank,"(%d+)")
        rn=tonumber(digits)
    end
    if not rn and hc and hc.Spells and name and hc.Spells[name] then
        local k
        for k in pairs(hc.Spells[name]) do
            local n=tonumber(k)
            if n and (not rn or n>rn) then rn=n end
        end
    end
    return name,rn
end

local function EstimateHeal(hc,unit,spellName,rank)
    if not hc or not hc.Spells or not spellName or not rank then return nil end
    local ranks=hc.Spells[spellName]
    local formula=ranks and ranks[rank]
    if type(formula)~="function" then return nil end

    local bonus=0
    if AceLibrary then
        local ok,itemBonus=pcall(function() return AceLibrary("ItemBonusLib-1.0") end)
        if ok and itemBonus and type(itemBonus.GetBonus)=="function" then
            local ok2,v=pcall(function() return itemBonus:GetBonus("HEAL") end)
            if ok2 then bonus=tonumber(v) or 0 end
        end
    end

    local buffPower,buffMod=0,1
    if type(hc.GetBuffSpellPower)=="function" then
        local ok,a,b=pcall(function() return hc:GetBuffSpellPower() end)
        if ok then buffPower=tonumber(a) or 0; buffMod=tonumber(b) or 1 end
    end

    local targetPower,targetMod=0,1
    if unit and type(hc.GetUnitSpellPower)=="function" then
        local ok,a,b=pcall(function() return hc:GetUnitSpellPower(unit,spellName) end)
        if ok then targetPower=tonumber(a) or 0; targetMod=tonumber(b) or 1 end
    end

    local ok,base=pcall(formula,bonus+buffPower)
    if not ok or not base then return nil end
    local amount=math.floor(((math.floor(tonumber(base) or 0)+targetPower)*buffMod*targetMod)+0.5)
    if amount<0 then amount=0 end
    return amount
end

local function HealCommTracksPlayer(hc,targetName)
    if not hc or not targetName then return false end
    local playerName=UnitName("player")
    if not playerName then return false end
    if hc.Heals and hc.Heals[targetName] and hc.Heals[targetName][playerName] then return true end
    if hc.Lookup and hc.Lookup[playerName]==targetName then return true end
    return false
end

local function LocalAmountForUnit(unit,hc)
    if not unit or not UnitExists(unit) then return 0 end
    local name=UnitName(unit)
    if not name then return 0 end
    local rec=SF.localHealPrediction[name]
    if not rec then return 0 end
    if not rec.stop or rec.stop<=GetTime() then
        SF.localHealPrediction[name]=nil
        return 0
    end
    if HealCommTracksPlayer(hc,name) then return 0 end
    return tonumber(rec.amount) or 0
end

function SF:StartLocalHealPredictionV2(spellName,rawDuration)
    if not SlamFramesDB or not SlamFramesDB.healPredictionEnabled then return end
    local hc=BindHealComm()
    if not hc or not hc.Spells then return end

    local name=spellName
    local spellID=nil
    local startTime=GetTime()
    local endTime=nil

    if C_Spell and type(C_Spell.UnitCastingInfo)=="function" then
        local ok,n,r,tex,startMs,endMs,isTradeskill,castID,notInterruptible,sid=pcall(C_Spell.UnitCastingInfo,"player")
        if ok and n then
            name=n or name
            spellID=sid
            if tonumber(startMs) and tonumber(endMs) and tonumber(endMs)>tonumber(startMs) then
                startTime=tonumber(startMs)/1000
                endTime=tonumber(endMs)/1000
            end
        end
    end

    local rank
    name,rank=ResolveSpellNameRank(hc,name,spellID)
    if not name or not hc.Spells[name] then return end

    local unit=FriendlyTargetUnit(hc)
    if not unit or not UnitExists(unit) then return end
    if UnitCanAttack and UnitCanAttack("player",unit) then return end

    local targetName=UnitName(unit)
    if not targetName or targetName=="" then return end
    local amount=EstimateHeal(hc,unit,name,rank)
    if not amount or amount<=0 then return end

    if not endTime then
        local d=tonumber(rawDuration)
        if d and d>100 then d=d/1000 end
        if not d or d<=0 then d=2.5 end
        endTime=startTime+d
    end

    SF.localHealPrediction[targetName]={amount=amount,start=startTime,stop=endTime+0.20,spell=name,rank=rank}
    SF.healPredictionStats.localStarts=(SF.healPredictionStats.localStarts or 0)+1
    SF.healPredictionStats.lastSpell=name
    SF.healPredictionStats.lastTarget=targetName
    if SF.UpdateHealPredictions then SF:UpdateHealPredictions() end
end

function SF:ClearLocalHealPredictionV2()
    SF.localHealPrediction={}
    if SF.UpdateHealPredictions then SF:UpdateHealPredictions() end
end

-- Use a true extension segment instead of rendering the entire predicted total
-- behind the existing health fill. This is much less dependent on old-client
-- draw-layer behavior.
local function PatchPredictionSegment(bar)
    if not bar or not bar.prediction or bar.sfPredictionSegmentV2 then return end
    bar.sfPredictionSegmentV2=true
    function bar:UpdatePredictionVisual()
        if not self.prediction then return end
        local incoming=tonumber(self.predictionIncoming) or 0
        local current=tonumber(self.predictionCurrent) or 0
        local maxv=tonumber(self.predictionMax) or tonumber(self.max) or 1
        if not self.predictionEnabled or incoming<=0 or maxv<=0 then
            self.prediction:Hide()
            return
        end
        if current<0 then current=0 elseif current>maxv then current=maxv end
        local total=current+incoming
        if total>maxv then total=maxv end
        if total<=current then self.prediction:Hide(); return end

        local startPct=current/maxv
        local endPct=total/maxv
        local fullW=self.fullWidth or self:GetWidth() or 1
        local fullH=self.fullHeight or self:GetHeight() or 1
        local startX=fullW*startPct
        local width=fullW*(endPct-startPct)
        if width<0.5 then self.prediction:Hide(); return end

        self.prediction:ClearAllPoints()
        self.prediction:SetPoint("LEFT",self,"LEFT",startX,0)
        self.prediction:SetHeight(fullH)
        self.prediction:SetWidth(width)
        self.prediction:SetTexCoord(startPct,endPct,0,1)
        self.prediction:SetVertexColor(0.72,1.00,0.72,1.00)
        self.prediction:SetAlpha(tonumber(self.predictionAlpha) or 0.60)
        self.prediction:Show()
    end
    bar:UpdatePredictionVisual()
end

local OriginalGetIncomingHeal=SF.GetIncomingHeal
function SF:GetIncomingHeal(unit)
    if not SlamFramesDB or not SlamFramesDB.healPredictionEnabled then return 0 end
    if not unit or not UnitExists(unit) then return 0 end
    if UnitCanAttack and UnitCanAttack("player",unit) then return 0 end

    local hc=BindHealComm()
    local total=0
    local name=UnitName(unit)
    if hc and name and name~="" then
        local ok,v=pcall(function() return hc:getHeal(name) end)
        if ok then total=tonumber(v) or 0 end
    end
    if total<0 then total=0 end
    total=total+LocalAmountForUnit(unit,hc)
    return total
end

local OriginalUpdateHealPredictionForFrame=SF.UpdateHealPredictionForFrame
function SF:UpdateHealPredictionForFrame(frame,unit)
    if not frame or not frame.health then return end
    PatchPredictionSegment(frame.health)
    if not frame.health.SetPrediction then return end
    if not SlamFramesDB or not SlamFramesDB.healPredictionEnabled then
        if frame.health.ClearPrediction then frame.health:ClearPrediction() end
        return
    end
    if not unit or not UnitExists(unit) then
        if frame.health.ClearPrediction then frame.health:ClearPrediction() end
        return
    end

    local cur=UnitHealth(unit) or 0
    local maxv=UnitHealthMax(unit) or 1
    local incoming=0
    if SF.healPredictionVisualTestUntil and SF.healPredictionVisualTestUntil>GetTime() then
        incoming=tonumber(SF.healPredictionVisualTestAmount) or math.max(1,math.floor(maxv*0.30))
    else
        incoming=SF:GetIncomingHeal(unit)
    end
    if incoming>0 then frame.health:SetPrediction(cur,incoming,maxv,SlamFramesDB.healPredictionAlpha or 0.60)
    elseif frame.health.ClearPrediction then frame.health:ClearPrediction() end
end

function SF:RunHealPredictionVisualTestV2(amount)
    amount=tonumber(amount) or 2000
    if amount<1 then amount=1 end
    SF.healPredictionVisualTestAmount=amount
    SF.healPredictionVisualTestUntil=GetTime()+8
    if SF.UpdateHealPredictions then SF:UpdateHealPredictions() end
    if SF.Print then
        SF.Print("heal prediction TEST: +"..tostring(math.floor(amount)).." for 8 seconds. The unit must be below full health to show an extension.")
    end
end

function SF:PrintHealPredictionStatusV2()
    local hc=BindHealComm()
    local enabled=SlamFramesDB and SlamFramesDB.healPredictionEnabled and true or false
    local pName=UnitName("player") or "?"
    local pHC=0
    if hc then local ok,v=pcall(function() return hc:getHeal(pName) end); if ok then pHC=tonumber(v) or 0 end end
    local pLocal=LocalAmountForUnit("player",hc)
    local tName=UnitExists("target") and (UnitName("target") or "?") or "-"
    local tHC=0
    if hc and UnitExists("target") then local ok,v=pcall(function() return hc:getHeal(tName) end); if ok then tHC=tonumber(v) or 0 end end
    local tLocal=UnitExists("target") and LocalAmountForUnit("target",hc) or 0
    local pBar=(SF.player and SF.player.health and SF.player.health.SetPrediction) and "yes" or "no"
    local tBar=(SF.target and SF.target.health and SF.target.health.SetPrediction) and "yes" or "no"
    local s=SF.healPredictionStats or {}
    if SF.Print then
        local aceType=type(AceLibrary)
        local aceHas="?"
        if AceLibrary and type(AceLibrary.HasInstance)=="function" then
            local okHas,has=pcall(function() return AceLibrary:HasInstance("HealComm-1.0") end)
            if okHas then aceHas=has and "yes" or "no" end
        end
        SF.Print("healpredict: enabled="..tostring(enabled).." HealComm="..(hc and "yes" or "no").." playerBar="..pBar.." targetBar="..tBar)
        SF.Print("healpredict: AceLibrary="..aceType.." HasHealComm="..aceHas)
        SF.Print("healpredict: player="..pName.." hc="..tostring(math.floor(pHC)).." local="..tostring(math.floor(pLocal)).." target="..tName.." hc="..tostring(math.floor(tHC)).." local="..tostring(math.floor(tLocal)))
        SF.Print("healpredict: polls="..tostring(s.polls or 0).." localStarts="..tostring(s.localStarts or 0).." lastSpell="..tostring(s.lastSpell or "-").." lastTarget="..tostring(s.lastTarget or "-"))
    end
end

-- Wrap the existing slash handler from Enhancements.lua.
local PreviousHandleSlash=SF.HandleSlash
function SF:HandleSlash(msg)
    msg=msg or ""
    local _,_,cmd,rest=string.find(msg,"^%s*(%S*)%s*(.-)%s*$")
    cmd=string.lower(cmd or "")
    rest=rest or ""
    if cmd=="healpredict" or cmd=="healprediction" then
        local _,_,sub,arg=string.find(rest,"^%s*(%S*)%s*(.-)%s*$")
        sub=string.lower(sub or "")
        if sub=="status" then SF:PrintHealPredictionStatusV2(); return end
        if sub=="test" then SF:RunHealPredictionVisualTestV2(tonumber(arg) or 2000); return end
    end
    return PreviousHandleSlash(self,msg)
end

-- Poll HealComm directly every 0.10s and listen for player cast starts. This
-- avoids depending on the old HealComm frontend event bridge alone.
local pollElapsed=0
local runtime=CreateFrame("Frame","SlamFrames_HealPredictionV2Runtime",UIParent)
runtime:RegisterEvent("SPELLCAST_START")
runtime:RegisterEvent("SPELLCAST_STOP")
runtime:RegisterEvent("SPELLCAST_INTERRUPTED")
runtime:RegisterEvent("SPELLCAST_FAILED")
pcall(function() runtime:RegisterEvent("UNIT_SPELLCAST_START") end)
pcall(function() runtime:RegisterEvent("UNIT_SPELLCAST_STOP") end)
pcall(function() runtime:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED") end)
pcall(function() runtime:RegisterEvent("UNIT_SPELLCAST_FAILED") end)

runtime:SetScript("OnEvent",function()
    local ev=event
    if ev=="SPELLCAST_START" then
        SF:StartLocalHealPredictionV2(arg1,arg2)
    elseif ev=="UNIT_SPELLCAST_START" then
        if arg1=="player" then SF:StartLocalHealPredictionV2(arg4,nil) end
    elseif ev=="SPELLCAST_STOP" or ev=="SPELLCAST_INTERRUPTED" or ev=="SPELLCAST_FAILED"
        or ev=="UNIT_SPELLCAST_STOP" or ev=="UNIT_SPELLCAST_INTERRUPTED" or ev=="UNIT_SPELLCAST_FAILED" then
        if not string.find(ev,"^UNIT_") or arg1=="player" then SF:ClearLocalHealPredictionV2() end
    end
end)

runtime:SetScript("OnUpdate",function()
    pollElapsed=pollElapsed+(arg1 or 0)
    if pollElapsed<0.10 then return end
    pollElapsed=0

    if SF.healPredictionVisualTestUntil and SF.healPredictionVisualTestUntil<=GetTime() then
        SF.healPredictionVisualTestUntil=nil
        SF.healPredictionVisualTestAmount=nil
    end

    local name,rec
    for name,rec in pairs(SF.localHealPrediction) do
        if not rec or not rec.stop or rec.stop<=GetTime() then SF.localHealPrediction[name]=nil end
    end

    if SlamFramesDB and SlamFramesDB.healPredictionEnabled and SF.player then
        SF.healPredictionStats.polls=(SF.healPredictionStats.polls or 0)+1
        BindHealComm()
        if SF.UpdateHealPredictions then SF:UpdateHealPredictions() end
    end
end)

-- Patch already-created health bars immediately if VARIABLES_LOADED ran first.
if SF.player and SF.player.health then PatchPredictionSegment(SF.player.health) end
if SF.target and SF.target.health then PatchPredictionSegment(SF.target.health) end
if SF.UpdateHealPredictions then SF:UpdateHealPredictions() end
