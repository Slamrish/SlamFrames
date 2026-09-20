-- SlamFrames TEST39 - isolated Vanilla/Octo cast timing ownership for spells, items, bandages, gathering and channels
-- Gold three-slice artwork, spell icon, cast/channel/fail states, latency zone,
-- explicit old-client layout scaling, movement and preview controls.

local SF=SlamFrames
local C=SlamFrames_Config
local TEX=C.texturePath
local CB=C.castbar or {}

local function Clamp(v,lo,hi)
    v=tonumber(v) or lo
    if v<lo then return lo end
    if v>hi then return hi end
    return v
end

local function Round(v) return math.floor((v or 0)+0.5) end

-- OctoWoW can expose old SPELLCAST_* durations differently depending on the
-- source of the cast. Stock 1.12 generally uses milliseconds, while some
-- item/action paths can surface seconds or no usable duration at all. Keep the
-- conversion deliberately tolerant so an 8-second bandage never becomes an
-- 0.008/1.0-second bar.
local function NormalizeSeconds(raw, fallback)
    local n=tonumber(raw)
    if not n or n<=0 then return fallback end
    if n>100 then return n/1000 end
    return n
end

-- Blizzard's own hidden CastingBarFrame still receives the engine's canonical
-- player-cast state even while SlamFrames suppresses its OnShow. This is a
-- valuable fallback for item casts, bandages, gathering and other actions that
-- do not always appear cleanly through C_Spell on old/custom clients.
local function ReadBlizzardCastState()
    local f=CastingBarFrame
    if not f then return nil end
    if not f.casting and not f.channeling then return nil end

    -- Stock Vanilla 1.12 does NOT store a duration in maxValue for ordinary
    -- casts. It stores absolute GetTime()-based timestamps:
    --   casting:  startTime = now, maxValue = startTime + duration
    --   channel:  startTime = now, endTime = startTime + duration
    -- Reading maxValue as a duration is what caused values around 600 seconds
    -- (roughly client uptime) and stationary/instant-looking bars.
    local startTime=tonumber(f.startTime)
    local endTime
    local isChannel=f.channeling and true or false

    if isChannel then
        endTime=tonumber(f.endTime)
        if startTime and (not endTime or endTime<=startTime) then
            local d=NormalizeSeconds(f.duration,nil)
            if d and d>0 then endTime=startTime+d end
        end
    else
        local mv=tonumber(f.maxValue)
        if startTime and mv then
            if mv>startTime then
                -- Native 1.12 absolute end timestamp.
                endTime=mv
            elseif mv>0 then
                -- Defensive compatibility with custom frames that store a
                -- duration instead of an absolute timestamp.
                local d=NormalizeSeconds(mv,nil)
                if d and d>0 then endTime=startTime+d end
            end
        end
    end

    -- If fields were incomplete, inspect the native status-bar bounds. Stock
    -- 1.12 uses absolute [start,end] values; a few custom clients use [0,dur].
    if (not startTime or not endTime or endTime<=startTime) and f.GetMinMaxValues then
        local ok,minv,maxv=pcall(function() return f:GetMinMaxValues() end)
        minv=tonumber(minv); maxv=tonumber(maxv)
        if ok and minv and maxv and maxv>minv then
            if minv>1 then
                startTime=minv; endTime=maxv
            else
                startTime=startTime or GetTime()
                local d=NormalizeSeconds(maxv-minv,nil)
                if d and d>0 then endTime=startTime+d end
            end
        end
    end

    if not startTime or not endTime or endTime<=startTime then return nil end

    local name
    if CastingBarFrameText and CastingBarFrameText.GetText then
        name=CastingBarFrameText:GetText()
    elseif f.Text and f.Text.GetText then
        name=f.Text:GetText()
    end
    local tex
    if CastingBarFrameIcon and CastingBarFrameIcon.GetTexture then
        tex=CastingBarFrameIcon:GetTexture()
    elseif f.Icon and f.Icon.GetTexture then
        tex=f.Icon:GetTexture()
    end
    return name,tex,startTime,endTime,isChannel
end

local CI=SlamFrames_CastIcons
local iconCache={}

local function UsefulCastIcon(tex)
    if CI and CI.UsefulTexture then return CI.UsefulTexture(tex) end
    if type(tex)~="string" or tex=="" then return false end
    return not string.find(string.lower(tex),"questionmark",1,true)
end

local function FindSpellIcon(name,spellID,engineTexture)
    if CI and CI.Resolve then
        local tex=CI:Resolve(name,spellID,engineTexture)
        if tex then
            if name and name~="" then iconCache[name]=tex end
            return tex
        end
    end
    if engineTexture then return engineTexture end
    if not name or name=="" then return "Interface\\Icons\\INV_Misc_QuestionMark" end
    if iconCache[name] then return iconCache[name] end
    if type(GetSpellName)=="function" and type(GetSpellTexture)=="function" then
        local book=BOOKTYPE_SPELL or "spell"
        local i=1
        while i<1200 do
            local n=GetSpellName(i,book)
            if not n then break end
            if n==name then
                local tex=GetSpellTexture(i,book)
                if tex then iconCache[name]=tex; return tex end
            end
            i=i+1
        end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Keep a known-good icon stable for the lifetime of the current cast. Some
-- item channels (notably bandages) expose their real icon at start, then the
-- hidden native cast frame clears it later. Timing reconciliation must never
-- downgrade a real icon to the question-mark fallback.
local function ReconcileCastIcon(cb,name,spellID,engineTexture)
    if not cb then return end
    if cb.castIconLocked and UsefulCastIcon(cb.lastIcon) then return end

    local resolved=FindSpellIcon(name,spellID,engineTexture)
    if UsefulCastIcon(resolved) then
        cb.lastIcon=resolved
        cb.icon:SetTexture(resolved)
        cb.castIconLocked=true
    elseif not UsefulCastIcon(cb.lastIcon) then
        cb.lastIcon="Interface\\Icons\\INV_Misc_QuestionMark"
        cb.icon:SetTexture(cb.lastIcon)
    end
end

local function ResolveDisplayName(name,isChannel)
    if CI and CI.ResolveDisplayName then return CI:ResolveDisplayName(name,isChannel) end
    if name and name~="" and name~="Casting" and name~="Channeling" then return name end
    return isChannel and "Channeling" or "Opening"
end

local function QueryCast()
    if C_Spell and type(C_Spell.UnitCastingInfo)=="function" then
        local name,rank,tex,startMs,endMs,isTradeskill,castID,notInterruptible,spellID,_,delayMs=C_Spell.UnitCastingInfo("player")
        if name and startMs and endMs then
            return name,tex,startMs/1000,endMs/1000,false,spellID,delayMs
        end
    end
    if C_Spell and type(C_Spell.UnitChannelInfo)=="function" then
        local name,rank,tex,startMs,endMs,notInterruptible,castID,spellID=C_Spell.UnitChannelInfo("player")
        if name and startMs and endMs then
            return name,tex,startMs/1000,endMs/1000,true,spellID,0
        end
    end
    return nil
end

-- TEST39: Octo can leave the previous channel visible through C_Spell or the
-- hidden Blizzard CastingBarFrame after a bandage/channel has ended.  Never
-- accept timing merely because a source says "something is casting"; prove
-- that the state belongs to the cast SlamFrames is currently starting/showing.
local function TimingStateFreshForStart(expectedName,expectedChannel,stateName,s,e,stateChannel)
    s=tonumber(s); e=tonumber(e)
    if not s or not e or e<=s then return false end
    local now=GetTime()
    local wantChannel=expectedChannel and true or false
    if (stateChannel and true or false)~=wantChannel then return false end
    -- START events should correspond to a state stamped essentially now.  A
    -- previous 8-second bandage therefore cannot be inherited by the next cast.
    if s<(now-1.50) or s>(now+0.50) or e<=(now-0.05) then return false end
    return true
end

local function TimingStateBelongsToActive(cb,stateName,s,e,stateChannel)
    if not cb or not cb.active then return false end
    s=tonumber(s); e=tonumber(e)
    if not s or not e or e<=s then return false end
    local now=GetTime()
    if e<=(now-0.05) then return false end
    if (stateChannel and true or false)~=(cb.isChannel and true or false) then return false end
    if cb.castStartedAt and s<(cb.castStartedAt-1.50) then return false end
    return true
end

local function ResolveCast(name,rawDuration,isChannel)
    -- Preferred: Octo/ClassicAPI exact unit timing, but only when that timing
    -- belongs to THIS start event.  Octo can retain stale channel information
    -- after bandages; accepting it blindly poisons the following cast.
    local qName,qTex,qStart,qEnd,qChannel,qSpellID=QueryCast()
    if qName and TimingStateFreshForStart(name,isChannel,qName,qStart,qEnd,qChannel) then
        return ResolveDisplayName(qName,qChannel),qTex,qStart,qEnd,qChannel,"api",qSpellID
    end

    -- Fallback: Blizzard's native player cast frame knows about item casts and
    -- other engine actions that may not resolve through C_Spell.  Apply the same
    -- ownership check so a finished channel cannot be recycled by Throw/Hearth.
    local bName,bTex,bStart,bEnd,bChannel=ReadBlizzardCastState()
    if bStart and TimingStateFreshForStart(name,isChannel,bName,bStart,bEnd,bChannel) then
        return ResolveDisplayName(bName or name,bChannel),bTex,bStart,bEnd,bChannel,"blizzard"
    end

    -- Last resort: normalize the legacy event duration. This accepts both the
    -- stock millisecond form (e.g. 8000) and second form (e.g. 8).
    local duration=NormalizeSeconds(rawDuration,1.0)
    if duration and duration>0 then
        local now=GetTime()
        return ResolveDisplayName(name,isChannel),nil,now,now+duration,isChannel and true or false,"legacy"
    end
    return nil
end

local function GetStyle()
    -- Style 2 is intentionally parked for later development. Keep its assets
    -- in the addon, but use only the proven Style 1 runtime layout for now.
    local styles=CB.styles or {}
    return styles[1] or CB,1
end

local function SetSlice(tex,style,u1,u2)
    local file=(style.frameTexture or CB.frameTexture or "castbar_frame.tga")
    tex:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(file)) or (TEX..file))
    tex:SetTexCoord(u1,u2,0,1)
end

function SF:CreateCastBar()
    if self.castbar then return end

    local cb=CreateFrame("Frame","SlamFrames_PlayerCastBar",UIParent)
    cb:SetFrameStrata("HIGH")
    cb:SetFrameLevel(30)
    cb:EnableMouse(false)
    cb:SetMovable(true)
    cb:RegisterForDrag("LeftButton")
    cb:Hide()
    self.castbar=cb

    -- Spell icon and matching SlamFrames aura-style gold border.
    cb.iconFrame=CreateFrame("Frame",nil,cb)
    cb.icon=cb.iconFrame:CreateTexture(nil,"ARTWORK")
    cb.icon:SetTexCoord(.08,.92,.08,.92)
    cb.iconBorder=cb.iconFrame:CreateTexture(nil,"OVERLAY")
    cb.iconBorder:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture("aura_border.tga")) or (TEX.."aura_border.tga"))

    -- Body uses one 512x64 source texture in three slices. The caps retain
    -- their proportions while only the straight middle section stretches.
    cb.body=CreateFrame("Frame",nil,cb)
    cb.body.left=cb.body:CreateTexture(nil,"BACKGROUND")
    cb.body.middle=cb.body:CreateTexture(nil,"BACKGROUND")
    cb.body.right=cb.body:CreateTexture(nil,"BACKGROUND")
    local initialStyle=(CB.styles and CB.styles[1]) or CB
    SetSlice(cb.body.left,initialStyle,0,initialStyle.leftSliceU or 0.06)
    SetSlice(cb.body.middle,initialStyle,initialStyle.leftSliceU or 0.06,initialStyle.rightSliceU or 0.94)
    SetSlice(cb.body.right,initialStyle,initialStyle.rightSliceU or 0.94,1)

    cb.fill=cb.body:CreateTexture(nil,"ARTWORK")
    cb.fill:SetTexture(TEX..(CB.fillTexture or "cast_fill.tga"))
    cb.fill:SetTexCoord(0,1,0,1)

    cb.latency=cb.body:CreateTexture(nil,"OVERLAY")
    cb.latency:SetTexture(TEX..(CB.latencyTexture or "cast_latency.tga"))
    cb.latency:SetTexCoord(0,1,0,1)
    cb.latency:SetAlpha(0.90)

    -- Style 2 can add a bright leading edge so even a narrow latency zone
    -- remains obvious against the amber cast fill.
    cb.latencyEdge=cb.body:CreateTexture(nil,"OVERLAY")
    cb.latencyEdge:SetTexture("Interface\\Buttons\\WHITE8X8")
    cb.latencyEdge:SetVertexColor(1.0,0.16,0.05,1.0)
    cb.latencyEdge:Hide()

    cb.spark=cb.body:CreateTexture(nil,"OVERLAY")
    cb.spark:SetTexture("Interface\\Buttons\\WHITE8X8")
    cb.spark:SetVertexColor(1.0,0.90,0.45,0.90)
    cb.spark:Hide()

    cb.name=cb.body:CreateFontString(nil,"OVERLAY")
    cb.name:SetFont("Fonts\\FRIZQT__.TTF",14,"OUTLINE")
    cb.name:SetTextColor(0.96,0.94,0.90)
    cb.name:SetShadowColor(0,0,0,1); cb.name:SetShadowOffset(1,-1)
    cb.name:SetJustifyH("LEFT")

    cb.timer=cb.body:CreateFontString(nil,"OVERLAY")
    cb.timer:SetFont("Fonts\\FRIZQT__.TTF",13,"OUTLINE")
    cb.timer:SetTextColor(0.96,0.94,0.90)
    cb.timer:SetShadowColor(0,0,0,1); cb.timer:SetShadowOffset(1,-1)
    cb.timer:SetJustifyH("RIGHT")

    cb.moveLabel=cb:CreateFontString(nil,"OVERLAY")
    cb.moveLabel:SetFont("Fonts\\FRIZQT__.TTF",13,"OUTLINE")
    cb.moveLabel:SetTextColor(1.0,0.48,0.18)
    cb.moveLabel:SetText("CAST BAR - DRAG TO MOVE")
    cb.moveLabel:Hide()

    cb:SetScript("OnDragStart",function()
        if not SF.castbarMoveMode then return end
        this:StartMoving()
    end)
    cb:SetScript("OnDragStop",function()
        this:StopMovingOrSizing()
        if not SF.castbarMoveMode then return end
        SF:SaveCastBarPosition()
    end)

    cb:SetScript("OnUpdate",function()
        SF:UpdateCastBar(arg1 or 0)
    end)

    -- ClassicAPI / Octo event set. pcall lets stock 1.12 clients ignore
    -- unknown UNIT_SPELLCAST_* names while retaining legacy SPELLCAST_*.
    local events={
        "UNIT_SPELLCAST_START","UNIT_SPELLCAST_STOP","UNIT_SPELLCAST_FAILED","UNIT_SPELLCAST_INTERRUPTED",
        "UNIT_SPELLCAST_DELAYED","UNIT_SPELLCAST_CHANNEL_START","UNIT_SPELLCAST_CHANNEL_STOP","UNIT_SPELLCAST_CHANNEL_UPDATE",
        "SPELLCAST_START","SPELLCAST_STOP","SPELLCAST_FAILED","SPELLCAST_INTERRUPTED","SPELLCAST_DELAYED",
        "SPELLCAST_CHANNEL_START","SPELLCAST_CHANNEL_STOP","SPELLCAST_CHANNEL_UPDATE","PLAYER_ENTERING_WORLD"
    }
    local i
    for i=1,table.getn(events) do pcall(function() cb:RegisterEvent(events[i]) end) end

    cb:SetScript("OnEvent",function()
        SF:CastBarEvent(event,arg1,arg2,arg3,arg4,arg5)
    end)

    self:LayoutCastBar()
    self:InstallBlizzardCastBarGuard()
end

function SF:InstallBlizzardCastBarGuard()
    if self.castbarBlizzardHooked or not CastingBarFrame then return end
    self.castbarBlizzardHooked=true
    local oldOnShow=CastingBarFrame:GetScript("OnShow")
    CastingBarFrame:SetScript("OnShow",function()
        if SlamFramesDB and SlamFramesDB.showPlayerCastbar and SlamFramesDB.hideBlizzardCastbar then
            this:Hide()
            return
        end
        if oldOnShow then oldOnShow() end
    end)
end

function SF:LayoutCastBar()
    local cb=self.castbar
    if not cb then return end
    local style,styleNumber=GetStyle()
    local scale=Clamp(SlamFramesDB.castbarScale or 0.80,0.50,1.60)
    -- Style-specific body width factor shortens the physical cast-bar body
    -- itself (not the progress fill). Style 1 remains 1.00; Style 2 is more
    -- compact so its straight section sits comfortably between the ornaments.
    local widthFactor=style.bodyWidthFactor or 1.00
    local bodyW=Clamp(SlamFramesDB.castbarWidth or 360,260,540)*scale*widthFactor
    local bodyH=(style.bodyHeight or CB.bodyHeight or 52)*scale
    local iconSize=(style.iconSize or CB.iconSize or 64)*scale
    local showIcon=SlamFramesDB.castbarShowIcon and true or false
    local bodyX=showIcon and ((style.bodyX or CB.bodyX or 52)*scale) or 0
    local totalW=bodyX+bodyW
    local totalH=math.max(iconSize,bodyH)
    local capL=(style.leftCap or CB.leftCap or 26)*scale
    local capR=(style.rightCap or CB.rightCap or 30)*scale
    local uLeft=style.leftSliceU or 0.06
    local uRight=style.rightSliceU or 0.94

    cb.layoutScale=scale
    cb.styleNumber=styleNumber
    cb.style=style
    cb.bodyWidth=bodyW

    SetSlice(cb.body.left,style,0,uLeft)
    SetSlice(cb.body.middle,style,uLeft,uRight)
    SetSlice(cb.body.right,style,uRight,1)
    local borderFile=(style.iconBorderTexture or "aura_border.tga")
    cb.iconBorder:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(borderFile)) or (TEX..borderFile))
    cb.latency:SetTexture(TEX..(style.latencyTexture or CB.latencyTexture or "cast_latency.tga"))
    cb.latency:SetAlpha(style.latencyAlpha or 0.90)
    cb:SetWidth(totalW); cb:SetHeight(totalH)

    cb.iconFrame:ClearAllPoints(); cb.iconFrame:SetPoint("LEFT",cb,"LEFT",0,0)
    cb.iconFrame:SetWidth(iconSize); cb.iconFrame:SetHeight(iconSize)
    if showIcon then cb.iconFrame:Show() else cb.iconFrame:Hide() end
    local iconInset=(style.iconInset or CB.iconInset or 10)*scale
    cb.icon:ClearAllPoints(); cb.icon:SetPoint("TOPLEFT",cb.iconFrame,"TOPLEFT",iconInset,-iconInset)
    cb.icon:SetPoint("BOTTOMRIGHT",cb.iconFrame,"BOTTOMRIGHT",-iconInset,iconInset)
    cb.iconBorder:SetAllPoints(cb.iconFrame)

    cb.body:ClearAllPoints(); cb.body:SetPoint("LEFT",cb,"LEFT",bodyX,0)
    cb.body:SetWidth(bodyW); cb.body:SetHeight(bodyH)

    cb.body.left:ClearAllPoints(); cb.body.left:SetPoint("LEFT",cb.body,"LEFT",0,0); cb.body.left:SetWidth(capL); cb.body.left:SetHeight(bodyH)
    cb.body.right:ClearAllPoints(); cb.body.right:SetPoint("RIGHT",cb.body,"RIGHT",0,0); cb.body.right:SetWidth(capR); cb.body.right:SetHeight(bodyH)
    cb.body.middle:ClearAllPoints(); cb.body.middle:SetPoint("LEFT",cb.body.left,"RIGHT",0,0); cb.body.middle:SetPoint("RIGHT",cb.body.right,"LEFT",0,0); cb.body.middle:SetHeight(bodyH)

    local insetL=(style.fillLeft or CB.fillLeft or 14)*scale
    local insetR=(style.fillRight or CB.fillRight or 18)*scale
    local fillBottom=(style.fillBottom or CB.fillBottom or 8)*scale
    local fillH=(style.fillHeight or CB.fillHeight or 15)*scale
    cb.innerX=insetL
    cb.innerW=math.max(20,bodyW-insetL-insetR)
    cb.innerY=fillBottom
    cb.innerH=fillH

    cb.fill:ClearAllPoints(); cb.fill:SetPoint("BOTTOMLEFT",cb.body,"BOTTOMLEFT",insetL,fillBottom); cb.fill:SetHeight(fillH)
    cb.latency:SetHeight(fillH)
    cb.latencyEdge:SetWidth(math.max(1,2*scale)); cb.latencyEdge:SetHeight(fillH)
    cb.spark:SetWidth(math.max(1,2*scale)); cb.spark:SetHeight(fillH+2*scale)

    local nameY=(style.textY or CB.textY or 34)*scale
    local textInset=(style.textInset or CB.textInset or 17)*scale
    local nameInset=(style.nameTextInset or style.textInset or CB.textInset or 17)*scale
    local timerInset=(style.timerTextInset or style.textInset or CB.textInset or 17)*scale
    local timerW=100*scale
    cb.name:ClearAllPoints(); cb.name:SetPoint("LEFT",cb.body,"LEFT",nameInset,nameY-bodyH/2); cb.name:SetWidth(math.max(60,bodyW-nameInset-timerInset-timerW)); cb.name:SetHeight(22*scale)
    cb.timer:ClearAllPoints(); cb.timer:SetPoint("RIGHT",cb.body,"RIGHT",-(timerInset+2*scale),nameY-bodyH/2); cb.timer:SetWidth(timerW); cb.timer:SetHeight(22*scale)
    cb.name:SetFont("Fonts\\FRIZQT__.TTF",math.max(8,Round((style.nameFont or CB.nameFont or 15)*scale)),"OUTLINE")
    cb.timer:SetFont("Fonts\\FRIZQT__.TTF",math.max(8,Round((style.timerFont or CB.timerFont or 13)*scale)),"OUTLINE")

    cb.moveLabel:ClearAllPoints(); cb.moveLabel:SetPoint("BOTTOM",cb,"TOP",0,4*scale)
    cb.moveLabel:SetFont("Fonts\\FRIZQT__.TTF",math.max(8,Round(13*scale)),"OUTLINE")

    self:ApplyCastBarAnchor()
    self:RenderCastBar()
end

function SF:ApplyCastBarAnchor()
    local cb=self.castbar
    if not cb then return end
    cb:ClearAllPoints()
    local a=SlamFramesDB.castbarAnchor
    if a and a.x and a.y then
        cb:SetPoint("CENTER",UIParent,"CENTER",a.x,a.y)
    elseif self.player then
        cb:SetPoint("TOP",self.player,"BOTTOM",0,-8)
    else
        cb:SetPoint("CENTER",UIParent,"CENTER",0,-180)
    end
end

function SF:SaveCastBarPosition()
    local cb=self.castbar
    if not cb then return end
    local cx,cy=cb:GetCenter(); local ux,uy=UIParent:GetCenter()
    if not cx or not ux then return end
    SlamFramesDB.castbarAnchor={x=cx-ux,y=cy-uy}
    self:ApplyCastBarAnchor()
    if self.RefreshSettings then self:RefreshSettings() end
end

function SF:ResetCastBarPosition(quiet)
    SlamFramesDB.castbarAnchor=nil
    self:ApplyCastBarAnchor()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("cast bar reset beneath the Player frame.") end
end

function SF:SetCastBarScale(v,quiet)
    SlamFramesDB.castbarScale=Clamp(v,0.50,1.60)
    self:LayoutCastBar()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("cast bar scale set to "..string.format("%.2f",SlamFramesDB.castbarScale)..".") end
end

function SF:SetCastBarWidth(v,quiet)
    SlamFramesDB.castbarWidth=Round(Clamp(v,260,540)/10)*10
    self:LayoutCastBar()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("cast bar width set to "..tostring(SlamFramesDB.castbarWidth)..".") end
end

function SF:SetCastBarStyle(v,quiet)
    SlamFramesDB.castbarStyle=1
    self:LayoutCastBar()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("cast bar uses the standard SlamFrames style.") end
end

function SF:SetCastBarEnabled(v,quiet)
    SlamFramesDB.showPlayerCastbar=v and true or false
    if not SlamFramesDB.showPlayerCastbar and self.castbar then self:ClearCastBar(true) end
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("player cast bar is now "..(SlamFramesDB.showPlayerCastbar and "ON" or "OFF")..".") end
end

function SF:SetCastBarMoveMode(v)
    self.castbarMoveMode=v and true or false
    if not self.castbar then return end
    self.castbar:EnableMouse(self.castbarMoveMode)
    if self.castbarMoveMode then
        self.castbar.moveLabel:Show()
        self:PreviewCastBar("move")
        if self.Print then self.Print("cast bar move mode enabled. Drag the bar, then press Done Moving.") end
    else
        self.castbar.moveLabel:Hide()
        self.castbar.previewHold=nil
        self:ClearCastBar(true)
        if self.Print then self.Print("cast bar move mode disabled.") end
    end
    if self.RefreshSettings then self:RefreshSettings() end
end

function SF:StartCastBar(name,texture,startTime,endTime,isChannel,source,spellID)
    if not SlamFramesDB.showPlayerCastbar or not self.castbar then return end
    local cb=self.castbar
    -- Every START is a hard ownership boundary.  No timing owner/poll state from
    -- a previous bandage, channel, tradeskill or pushed-back spell may survive.
    cb.sfSpecialActionTiming=nil
    cb.sfLegacyTiming=nil; cb.sfLegacyStart=nil; cb.sfLegacyEnd=nil
    cb.nextTimingPoll=nil
    cb.castStartedAt=GetTime()
    cb.active=true; cb.isChannel=isChannel and true or false
    cb.castSource=source or "unknown"
    cb.nativeSyncUntil=(source=="legacy") and (GetTime()+0.35) or nil
    cb.startTime=startTime or GetTime(); cb.endTime=endTime or (cb.startTime+1)
    cb.failureUntil=nil; cb.fadeStart=nil; cb.alpha=1
    name=ResolveDisplayName(name,isChannel)
    cb.castDisplayName=name
    cb.name:SetText(name)
    cb.lastIcon=FindSpellIcon(name,spellID,texture)
    cb.icon:SetTexture(cb.lastIcon)
    cb.castIconLocked=UsefulCastIcon(cb.lastIcon) and true or nil
    cb:Show(); cb:SetAlpha(1)
    if CastingBarFrame and SlamFramesDB.hideBlizzardCastbar then CastingBarFrame:Hide() end
    self:RenderCastBar()
end

function SF:RefreshCastBarFromAPI(expectedName,expectedChannel)
    local name,tex,startTime,endTime,isChannel,spellID=QueryCast()
    if name then
        if expectedChannel~=nil and not TimingStateFreshForStart(expectedName,expectedChannel,name,startTime,endTime,isChannel) then
            return false
        end
        self:StartCastBar(name,tex,startTime,endTime,isChannel,"api",spellID)
        return true
    end
    return false
end

function SF:FailCastBar(label)
    local cb=self.castbar
    if not cb or not SlamFramesDB.showPlayerCastbar then return end
    cb.active=nil; cb.previewHold=nil; cb.isChannel=nil
    cb.sfSpecialActionTiming=nil
    cb.sfLegacyTiming=nil; cb.sfLegacyStart=nil; cb.sfLegacyEnd=nil
    cb.nextTimingPoll=nil; cb.nativeSyncUntil=nil; cb.castStartedAt=nil
    cb.failureUntil=GetTime()+0.75; cb.fadeStart=nil
    cb.name:SetText(label or "INTERRUPTED")
    cb.timer:SetText("")
    if label=="FAILED" then
        -- Dedicated failure art: never degrade to a question mark.
        cb.icon:SetTexture(TEX..(CB.failIconTexture or "cast_fail_icon.tga"))
    elseif label=="INTERRUPTED" then
        -- Dedicated stock Vanilla interrupt art for cancelled/interrupted casts.
        cb.icon:SetTexture("Interface\Icons\Ability_Kick")
    else
        local fallback=(CI and CI.DatabaseTexture and CI:DatabaseTexture(label)) or nil
        cb.icon:SetTexture((UsefulCastIcon(fallback) and fallback) or (UsefulCastIcon(cb.lastIcon) and cb.lastIcon) or "Interface\Icons\Spell_Shadow_CurseOfTounges")
    end
    cb.failure=true
    cb:Show(); cb:SetAlpha(1)
    self:RenderCastBar()
end

function SF:ClearCastBar(immediate)
    local cb=self.castbar
    if not cb then return end
    cb.active=nil; cb.previewHold=nil; cb.failure=nil; cb.failureUntil=nil
    cb.isChannel=nil
    cb.castSource=nil; cb.nativeSyncUntil=nil; cb.castIconLocked=nil
    cb.sfSpecialActionTiming=nil
    cb.sfLegacyTiming=nil; cb.sfLegacyStart=nil; cb.sfLegacyEnd=nil
    cb.nextTimingPoll=nil; cb.castStartedAt=nil
    cb.spark:Hide(); cb.latency:Hide(); cb.latencyEdge:Hide()
    if immediate then cb.fadeStart=nil; cb:Hide(); cb:SetAlpha(0)
    else cb.fadeStart=GetTime(); cb:SetAlpha(1) end
end

function SF:RenderCastBar()
    local cb=self.castbar
    if not cb or not cb:IsShown() then return end
    local now=GetTime()
    local pct=.55
    local duration=3
    local current=1.8

    if cb.failure then
        pct=1
    elseif cb.previewHold then
        pct=cb.previewPct or .55; duration=cb.previewDuration or 3; current=duration*pct
    elseif cb.active and cb.startTime and cb.endTime then
        duration=math.max(.01,cb.endTime-cb.startTime)
        if cb.isChannel then current=math.max(0,cb.endTime-now); pct=current/duration
        else current=math.max(0,now-cb.startTime); pct=current/duration end
        if pct<0 then pct=0 elseif pct>1 then pct=1 end
    end

    local color
    if cb.failure then color=CB.failColor or {0.90,0.08,0.03}
    elseif cb.isChannel then color=CB.channelColor or {0.30,0.90,0.12}
    else color=CB.castColor or {1.00,0.58,0.02} end
    cb.fill:SetVertexColor(color[1],color[2],color[3],1)

    local fillW=math.max(.5,cb.innerW*pct)
    cb.fill:SetWidth(fillW); cb.fill:SetTexCoord(0,pct,0,1); cb.fill:Show()

    if SlamFramesDB.castbarShowTimer and not cb.failure then
        cb.timer:SetText(string.format("%.1f / %.1f",current,duration))
    else cb.timer:SetText("") end

    if SlamFramesDB.castbarShowLatency and not cb.failure and not cb.previewHold then
        local lag=0
        if type(GetNetStats)=="function" then local _,_,l=GetNetStats(); lag=(tonumber(l) or 0)/1000 end
        local lw=math.min(cb.innerW*0.45,cb.innerW*(lag/math.max(.01,duration)))
        if lw>=1 then
            cb.latency:Show(); cb.latency:ClearAllPoints(); cb.latency:SetWidth(lw)
            cb.latencyEdge:Hide()
            if cb.isChannel then
                cb.latency:SetPoint("BOTTOMLEFT",cb.body,"BOTTOMLEFT",cb.innerX,cb.innerY)
                if cb.style and cb.style.latencyEdge then
                    cb.latencyEdge:Show(); cb.latencyEdge:ClearAllPoints()
                    cb.latencyEdge:SetPoint("BOTTOMLEFT",cb.latency,"BOTTOMRIGHT",0,0)
                end
            else
                cb.latency:SetPoint("BOTTOMRIGHT",cb.body,"BOTTOMRIGHT",-(cb.bodyWidth-cb.innerX-cb.innerW),cb.innerY)
                if cb.style and cb.style.latencyEdge then
                    cb.latencyEdge:Show(); cb.latencyEdge:ClearAllPoints()
                    cb.latencyEdge:SetPoint("BOTTOMRIGHT",cb.latency,"BOTTOMLEFT",0,0)
                end
            end
        else cb.latency:Hide(); cb.latencyEdge:Hide() end
    elseif cb.previewHold and SlamFramesDB.castbarShowLatency then
        local lw=math.max(1,cb.innerW*.14)
        cb.latency:Show(); cb.latency:ClearAllPoints(); cb.latency:SetWidth(lw)
        cb.latency:SetPoint("BOTTOMRIGHT",cb.body,"BOTTOMRIGHT",-(cb.bodyWidth-cb.innerX-cb.innerW),cb.innerY)
        if cb.style and cb.style.latencyEdge then
            cb.latencyEdge:Show(); cb.latencyEdge:ClearAllPoints()
            cb.latencyEdge:SetPoint("BOTTOMRIGHT",cb.latency,"BOTTOMLEFT",0,0)
        else cb.latencyEdge:Hide() end
    else cb.latency:Hide(); cb.latencyEdge:Hide() end

    if cb.active or cb.previewHold then
        cb.spark:Show(); cb.spark:ClearAllPoints()
        local sx=cb.innerX+math.min(cb.innerW,math.max(0,cb.innerW*pct))
        cb.spark:SetPoint("BOTTOMLEFT",cb.body,"BOTTOMLEFT",sx,cb.innerY-1)
    else cb.spark:Hide() end
end

function SF:UpdateCastBar(elapsed)
    local cb=self.castbar
    if not cb or not cb:IsShown() then return end
    local now=GetTime()

    -- A legacy event may arrive before Blizzard's own CastingBarFrame has
    -- finished stamping the real item/action duration. Reconcile for a few
    -- frames so bandages, gathering, item uses and other unusual casts pick up
    -- the engine's actual timing instead of keeping a guessed 1-second bar.
    if cb.active and cb.nativeSyncUntil and now<=cb.nativeSyncUntil then
        local n,tex,s,e,ch=ReadBlizzardCastState()
        if TimingStateBelongsToActive(cb,n,s,e,ch) then
            cb.startTime=s; cb.endTime=e; cb.isChannel=ch and true or false
            cb.castSource="blizzard"
            cb.nativeSyncUntil=nil
            local display=ResolveDisplayName(n,cb.isChannel)
            if display and display~="" then cb.castDisplayName=display; cb.name:SetText(display) end
            ReconcileCastIcon(cb,display,nil,tex)
        end
    end

    -- While a cast is active, prefer exact C_Spell timing whenever it becomes
    -- available. This also corrects delayed/pushed-back casts without relying
    -- on the legacy event argument format.
    if cb.active and (not cb.nextTimingPoll or now>=cb.nextTimingPoll) then
        cb.nextTimingPoll=now+0.05
        local n,tex,s,e,ch,spellID=QueryCast()
        if n and TimingStateBelongsToActive(cb,n,s,e,ch) then
            cb.startTime=s; cb.endTime=e; cb.isChannel=ch and true or false
            cb.castSource="api"
            local display=ResolveDisplayName(n,cb.isChannel)
            if display and display~="" then cb.castDisplayName=display; cb.name:SetText(display) end
            ReconcileCastIcon(cb,display,spellID,tex)
        else
            local bn,btex,bs,be,bch=ReadBlizzardCastState()
            if TimingStateBelongsToActive(cb,bn,bs,be,bch) then
                cb.startTime=bs; cb.endTime=be; cb.isChannel=bch and true or false
                cb.castSource="blizzard"
                local display=ResolveDisplayName(bn,cb.isChannel)
                if display and display~="" then cb.castDisplayName=display; cb.name:SetText(display) end
                ReconcileCastIcon(cb,display,nil,btex)
            end
        end
    end

    if cb.failureUntil then
        if now>=cb.failureUntil then cb.failureUntil=nil; cb.failure=nil; cb.fadeStart=now end
    elseif cb.active and cb.endTime and now>=cb.endTime then
        cb.active=nil; cb.fadeStart=now
    end

    if cb.fadeStart and not cb.previewHold and not self.castbarMoveMode then
        local a=1-((now-cb.fadeStart)/0.28)
        if a<=0 then cb.fadeStart=nil; cb:Hide(); cb:SetAlpha(0); return end
        cb:SetAlpha(a)
    else cb:SetAlpha(1) end

    self:RenderCastBar()
end

function SF:PreviewCastBar(kind)
    if not self.castbar then return end
    local cb=self.castbar
    cb.failure=nil; cb.failureUntil=nil; cb.fadeStart=nil; cb.active=nil
    cb.previewHold=(kind=="move") and true or nil
    cb.previewDuration=3.0; cb.previewPct=.60
    if kind=="channel" then
        cb.isChannel=true; cb.name:SetText("Drain Life"); cb.icon:SetTexture("Interface\\Icons\\Spell_Shadow_LifeDrain02")
        cb.startTime=GetTime(); cb.endTime=cb.startTime+5.0; cb.active=true
    elseif kind=="interrupt" then
        cb.icon:SetTexture("Interface\\Icons\\Spell_Fire_FlameBolt"); cb.lastIcon="Interface\\Icons\\Spell_Fire_FlameBolt"; self:FailCastBar("INTERRUPTED"); return
    elseif kind=="fail" then
        self:FailCastBar("FAILED"); return
    else
        cb.isChannel=nil; cb.name:SetText(kind=="move" and "SlamFrames Cast Bar" or "Fireball"); cb.icon:SetTexture("Interface\\Icons\\Spell_Fire_FlameBolt")
        if kind~="move" then cb.startTime=GetTime(); cb.endTime=cb.startTime+3.0; cb.active=true end
    end
    cb:Show(); cb:SetAlpha(1); self:RenderCastBar()
end

function SF:CastBarEvent(ev,a1,a2,a3,a4,a5)
    if not self.castbar then return end
    if ev=="PLAYER_ENTERING_WORLD" then
        if not self.castbarMoveMode then self:ClearCastBar(true) end
        return
    end

    -- Unit-specific events are preferred, but never globally disable legacy
    -- events: item casts such as bandages can travel through a different event
    -- path on OctoWoW than ordinary spellbook casts.
    if string.find(ev or "","^UNIT_SPELLCAST_") then
        if a1~="player" then return end
        if ev=="UNIT_SPELLCAST_START" or ev=="UNIT_SPELLCAST_CHANNEL_START" then
            local eventIsChannel=(ev=="UNIT_SPELLCAST_CHANNEL_START")
            local eventName=a4
            if not self:RefreshCastBarFromAPI(eventName,eventIsChannel) then
                local name=eventName
                local eventSpellID=a3
                local rn,rt,rs,re,rc,source,resolvedSpellID=ResolveCast(name,nil,ev=="UNIT_SPELLCAST_CHANNEL_START")
                local sid=resolvedSpellID or eventSpellID
                if rn then self:StartCastBar(rn,FindSpellIcon(rn,sid,rt),rs,re,rc,source,sid) end
            end
        elseif ev=="UNIT_SPELLCAST_DELAYED" or ev=="UNIT_SPELLCAST_CHANNEL_UPDATE" then
            local name,tex,startTime,endTime,isChannel,spellID=QueryCast()
            if name and TimingStateBelongsToActive(self.castbar,name,startTime,endTime,isChannel) then
                self.castbar.startTime=startTime; self.castbar.endTime=endTime; self.castbar.isChannel=isChannel and true or false
                self.castbar.castSource="api"
                ReconcileCastIcon(self.castbar,name,spellID,tex)
            else
                local nativeName,_,s,e,ch=ReadBlizzardCastState()
                if TimingStateBelongsToActive(self.castbar,nativeName,s,e,ch) then
                    self.castbar.startTime=s; self.castbar.endTime=e; self.castbar.isChannel=ch and true or false
                end
            end
        elseif ev=="UNIT_SPELLCAST_INTERRUPTED" then self:FailCastBar("INTERRUPTED")
        elseif ev=="UNIT_SPELLCAST_FAILED" then self:FailCastBar("FAILED")
        elseif ev=="UNIT_SPELLCAST_STOP" or ev=="UNIT_SPELLCAST_CHANNEL_STOP" then self:ClearCastBar(false) end
        return
    end

    -- Legacy events remain an active fallback for non-spellbook casts. Resolve
    -- from C_Spell first, then Blizzard's hidden native cast frame, then the
    -- event duration with seconds/milliseconds auto-detection.
    if ev=="SPELLCAST_START" then
        -- Vanilla signature: arg1 = spell name, arg2 = duration in ms.
        local name=a1
        local rn,rt,rs,re,rc,source,spellID=ResolveCast(name,a2,false)
        if rn then self:StartCastBar(rn,FindSpellIcon(rn,spellID,rt),rs,re,rc,source,spellID) end
    elseif ev=="SPELLCAST_CHANNEL_START" then
        -- Vanilla channel signature is reversed:
        -- arg1 = duration in ms, arg2 = spell name.
        -- Bandages use this path on old clients, so treating arg1 as the name
        -- made them use a bogus fallback duration and appear nearly instant.
        local name=a2
        local rn,rt,rs,re,rc,source,spellID=ResolveCast(name,a1,true)
        if rn then self:StartCastBar(rn,FindSpellIcon(rn,spellID,rt),rs,re,true,source,spellID) end
    elseif ev=="SPELLCAST_INTERRUPTED" then self:FailCastBar("INTERRUPTED")
    elseif ev=="SPELLCAST_FAILED" then self:FailCastBar("FAILED")
    elseif ev=="SPELLCAST_CHANNEL_STOP" then
        self:ClearCastBar(false)
    elseif ev=="SPELLCAST_STOP" then
        -- Vanilla can emit SPELLCAST_STOP around a channeled action as well.
        -- Do not kill an active bandage/channel; CHANNEL_STOP owns that state.
        if not (self.castbar.active and self.castbar.isChannel) then self:ClearCastBar(false) end
    elseif ev=="SPELLCAST_DELAYED" then
        local delay=NormalizeSeconds(tonumber(a1) or tonumber(a2),nil)
        local name,tex,startTime,endTime,isChannel,spellID=QueryCast()
        if name and TimingStateBelongsToActive(self.castbar,name,startTime,endTime,isChannel) then
            self.castbar.startTime=startTime; self.castbar.endTime=endTime; self.castbar.isChannel=isChannel and true or false
            ReconcileCastIcon(self.castbar,name,spellID,tex)
        else
            local n,nt,ns,ne,nc=ReadBlizzardCastState()
            if TimingStateBelongsToActive(self.castbar,n,ns,ne,nc) then
                self.castbar.startTime=ns; self.castbar.endTime=ne; self.castbar.isChannel=nc and true or false
                local display=ResolveDisplayName(n,self.castbar.isChannel)
                if display and display~="" then self.castbar.castDisplayName=display; self.castbar.name:SetText(display) end
                ReconcileCastIcon(self.castbar,display,nil,nt)
            elseif delay and self.castbar.active then
                self.castbar.endTime=self.castbar.endTime+delay
            end
        end
    elseif ev=="SPELLCAST_CHANNEL_UPDATE" then
        local qn,qtex,qs,qe,qch,qspellID=QueryCast()
        if qn and TimingStateBelongsToActive(self.castbar,qn,qs,qe,qch) then
            self.castbar.startTime=qs; self.castbar.endTime=qe; self.castbar.isChannel=true
            local qdisplay=ResolveDisplayName(qn,true)
            if qdisplay and qdisplay~="" then self.castbar.castDisplayName=qdisplay; self.castbar.name:SetText(qdisplay) end
            ReconcileCastIcon(self.castbar,qdisplay,qspellID,qtex)
        else
            local n,tex,s,e,ch=ReadBlizzardCastState()
            if TimingStateBelongsToActive(self.castbar,n,s,e,ch) then
                self.castbar.startTime=s; self.castbar.endTime=e; self.castbar.isChannel=true
                local display=ResolveDisplayName(n,true)
                if display and display~="" then self.castbar.castDisplayName=display; self.castbar.name:SetText(display) end
                ReconcileCastIcon(self.castbar,display,nil,tex)
            elseif self.castbar.active and self.castbar.isChannel then
                -- Vanilla arg1 is remaining channel duration in ms. Preserve
                -- the original total duration while moving the end time.
                local remain=NormalizeSeconds(a1,nil)
                if remain then
                    local total=math.max(.01,self.castbar.endTime-self.castbar.startTime)
                    self.castbar.endTime=GetTime()+remain
                    self.castbar.startTime=self.castbar.endTime-total
                end
            else
                self:RenderCastBar()
            end
        end
    end
end

