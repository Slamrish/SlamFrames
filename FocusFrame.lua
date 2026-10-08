-- SlamFrames Focus Frame - 3.3
-- Compact portraitless focus health frame for Vanilla / SuperWoW environments.
-- Native "focus" units are used when available. On pure 1.12 clients SlamFrames
-- can emulate a focus by remembering the selected unit name/GUID and resolving it
-- through SuperWoW GUID tokens or known unit tokens.

local SF=SlamFrames
local C=SlamFrames_Config
local Bars=SlamFrames_BarEngine
local TEX=C.texturePath
local WHITE="Interface\\Buttons\\WHITE8X8"

local MASTER_DEFAULTS=SF.MASTER_DEFAULT_PROFILE or {}
local FOCUS_DEFAULTS={
    show=(MASTER_DEFAULTS.showFocusFrame~=false),
    scale=tonumber(MASTER_DEFAULTS.focusScale) or 0.75,
    width=tonumber(MASTER_DEFAULTS.focusWidth) or 220,
    height=tonumber(MASTER_DEFAULTS.focusHeight) or 48,
    healthTextMode=MASTER_DEFAULTS.focusHealthTextMode or "amount",
    nameTextScale=tonumber(MASTER_DEFAULTS.focusNameTextScale) or 1.00,
    healthTextScale=tonumber(MASTER_DEFAULTS.focusHealthTextScale) or 1.00,
    anchor=MASTER_DEFAULTS.focusAnchor,
}

SF.focusState=SF.focusState or {name=nil,guid=nil,token=nil,lastCur=nil,lastMax=nil,lastLevel=nil,source=nil}

local function Clamp(v,lo,hi)
    v=tonumber(v) or lo
    if v<lo then return lo end
    if v>hi then return hi end
    return v
end

local function Round(v) return math.floor((v or 0)+0.5) end

local function SafeUnitExists(unit)
    if not unit or type(UnitExists)~="function" then return false end
    local ok,exists=pcall(UnitExists,unit)
    return ok and exists and true or false
end

local function SafeUnitName(unit)
    if not unit or type(UnitName)~="function" then return nil end
    local ok,name=pcall(UnitName,unit)
    if ok and name and name~="" then return name end
    return nil
end

local function SafeUnitHealth(unit)
    local cur,maxv=0,1
    if type(UnitHealth)=="function" then
        local ok,v=pcall(UnitHealth,unit); if ok and tonumber(v) then cur=tonumber(v) end
    end
    if type(UnitHealthMax)=="function" then
        local ok,v=pcall(UnitHealthMax,unit); if ok and tonumber(v) and tonumber(v)>0 then maxv=tonumber(v) end
    end
    if cur<0 then cur=0 end
    if cur>maxv then cur=maxv end
    return cur,maxv
end

local function SafeUnitLevel(unit)
    if type(UnitLevel)~="function" then return nil end
    local ok,v=pcall(UnitLevel,unit)
    if ok then return tonumber(v) end
    return nil
end

local function GetGuid(unit)
    if SF.GetUnitGuidCompat then
        local ok,g=pcall(SF.GetUnitGuidCompat,unit)
        if ok and g and g~="" then return g end
    end
    if type(UnitGUID)=="function" then
        local ok,g=pcall(UnitGUID,unit)
        if ok and g and g~="" then return g end
    end
    if type(GetUnitGUID)=="function" then
        local ok,g=pcall(GetUnitGUID,unit)
        if ok and g and g~="" then return g end
    end
    return nil
end

local function EnsureFocusDB()
    if type(SlamFramesDB)~="table" then return end
    if SlamFramesDB.showFocusFrame==nil then SlamFramesDB.showFocusFrame=FOCUS_DEFAULTS.show end
    if SlamFramesDB.focusScale==nil then SlamFramesDB.focusScale=FOCUS_DEFAULTS.scale end
    if SlamFramesDB.focusWidth==nil then SlamFramesDB.focusWidth=FOCUS_DEFAULTS.width end
    if SlamFramesDB.focusHeight==nil then SlamFramesDB.focusHeight=FOCUS_DEFAULTS.height end
    if not SlamFramesDB.focusHealthTextMode then SlamFramesDB.focusHealthTextMode=FOCUS_DEFAULTS.healthTextMode end
    if SlamFramesDB.focusNameTextScale==nil then SlamFramesDB.focusNameTextScale=FOCUS_DEFAULTS.nameTextScale end
    if SlamFramesDB.focusHealthTextScale==nil then SlamFramesDB.focusHealthTextScale=FOCUS_DEFAULTS.healthTextScale end
end
SF.EnsureFocusDB=EnsureFocusDB

local function FormatNumber(v)
    v=math.floor((tonumber(v) or 0)+0.5)
    local s=tostring(v)
    local sign=""
    if string.sub(s,1,1)=="-" then sign="-"; s=string.sub(s,2) end
    local out=""
    while string.len(s)>3 do
        out=","..string.sub(s,-3)..out
        s=string.sub(s,1,string.len(s)-3)
    end
    return sign..s..out
end

local function FocusDisplayText(cur,maxv)
    local mode=(SlamFramesDB and SlamFramesDB.focusHealthTextMode) or "amount"
    cur=tonumber(cur) or 0; maxv=tonumber(maxv) or 1
    local pct=0; if maxv>0 then pct=math.floor((cur/maxv)*100+0.5) end
    if mode=="percent" then return tostring(pct).."%" end
    if mode=="both" then return FormatNumber(cur).." / "..FormatNumber(maxv).."  ("..tostring(pct).."%)" end
    if mode=="off" then return "" end
    return FormatNumber(cur).." / "..FormatNumber(maxv)
end

-- Constrain long Focus names to the center cavity. Prefer measured font
-- width when available and shorten with an ellipsis when the name is too wide.
local function SetFittedFocusName(fontString,name,maxWidth,fontSize)
    name=tostring(name or "Focus")
    maxWidth=math.max(40,tonumber(maxWidth) or 40)
    fontString:SetText(name)

    if fontString.GetStringWidth then
        local ok,w=pcall(fontString.GetStringWidth,fontString)
        if ok and tonumber(w) and w<=maxWidth then return end
        local keep=string.len(name)
        while keep>1 do
            keep=keep-1
            fontString:SetText(string.sub(name,1,keep).."...")
            local wok,ww=pcall(fontString.GetStringWidth,fontString)
            if wok and tonumber(ww) and ww<=maxWidth then return end
        end
        fontString:SetText("...")
        return
    end

    local avg=math.max(4,(tonumber(fontSize) or 12)*0.58)
    local maxChars=math.floor(maxWidth/avg)
    if maxChars<4 then maxChars=4 end
    if string.len(name)>maxChars then
        fontString:SetText(string.sub(name,1,maxChars-3).."...")
    end
end

local function FocusTexturePath()
    local root=(SF.GetTextureRoot and SF:GetTextureRoot()) or TEX
    local skin=(SlamFramesDB and SlamFramesDB.skin) or "dark"
    if skin=="dark" then return root.."Dark\\focus_frame.tga" end
    return root.."focus_frame.tga"
end

local function CreateFocusArt(parent)
    local art={}
    art.left=parent:CreateTexture(nil,"ARTWORK")
    art.middle=parent:CreateTexture(nil,"ARTWORK")
    art.right=parent:CreateTexture(nil,"ARTWORK")
    art.left:SetTexCoord(0,118/512,0,1)
    art.middle:SetTexCoord(118/512,394/512,0,1)
    art.right:SetTexCoord(394/512,1,0,1)

    function art:SetTexture(path)
        self.left:SetTexture(path); self.middle:SetTexture(path); self.right:SetTexture(path)
    end

    function art:SetLayout(frameW,frameH,scale)
        frameW=tonumber(frameW) or 340; frameH=tonumber(frameH) or 64; scale=scale or 1
        local w=frameW*scale; local h=frameH*scale
        local cap=math.min(w*0.31,h*0.96)
        local mid=math.max(24,w-(cap*2))
        self.left:ClearAllPoints(); self.left:SetPoint("TOPLEFT",parent,"TOPLEFT",0,0); self.left:SetWidth(cap); self.left:SetHeight(h)
        self.right:ClearAllPoints(); self.right:SetPoint("TOPRIGHT",parent,"TOPRIGHT",0,0); self.right:SetWidth(cap); self.right:SetHeight(h)
        self.middle:ClearAllPoints(); self.middle:SetPoint("TOPLEFT",self.left,"TOPRIGHT",0,0); self.middle:SetWidth(mid); self.middle:SetHeight(h)
    end

    art:SetTexture(FocusTexturePath())
    return art
end

local function SaveFocusAnchor(frame)
    if not frame or type(SlamFramesDB)~="table" then return end
    local point,relativeTo,relativePoint,x,y=frame:GetPoint(1)
    if not point then return end
    SlamFramesDB.focusAnchor={point=point,relativePoint=relativePoint or point,x=x or 0,y=y or 0}
end

local function ApplyFocusAnchor(frame)
    if not frame then return end
    local a=SlamFramesDB and SlamFramesDB.focusAnchor
    frame:ClearAllPoints()
    if a then
        frame:SetPoint(a.point or "CENTER",UIParent,a.relativePoint or "CENTER",a.x or 0,a.y or 0)
    else
        frame:SetPoint("CENTER",UIParent,"CENTER",0,130)
    end
end

function SF:ResetFocusPosition(quiet)
    EnsureFocusDB()
    local x,y=0,130
    local p=self.player; local t=self.target
    if p and t and p.GetCenter and t.GetCenter then
        local px,py=p:GetCenter(); local tx,ty=t:GetCenter()
        if px and py and tx and ty then x=(px+tx)*0.5; y=(py+ty)*0.5 end
    end
    SlamFramesDB.focusAnchor={point="CENTER",relativePoint="BOTTOMLEFT",x=x,y=y}
    if self.focus then
        self.focus:ClearAllPoints()
        self.focus:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x,y)
    end
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("Focus frame reset between Player and Target.") end
end

function SF:CreateFocusFrame()
    if self.focus then return self.focus end
    EnsureFocusDB()

    local f=CreateFrame("Frame","SlamFrames_Focus",UIParent)
    f.frameKey="focus"; f.unit="focus"; f.layoutScale=1
    f:SetMovable(true); f:EnableMouse(true)
    if f.EnableMouseWheel then f:EnableMouseWheel(true) end
    f:RegisterForDrag("LeftButton")
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end

    local baseLevel=(f.GetFrameLevel and f:GetFrameLevel()) or 1

    -- Keep health below the artwork and all text above both.
    f.barFrame=CreateFrame("Frame",nil,f); f.barFrame:SetAllPoints(f); f.barFrame:SetFrameLevel(baseLevel+1)
    f.health=Bars:Create(f.barFrame,{x=46,y=17,w=248,h=30},TEX,"health_fill.tga")
    f.health:SetSmooth(SlamFramesDB.smoothBars)

    -- the approved Focus artwork has a transparent health cavity.
    -- Unlike the main unit-frame art, that means the world becomes visible
    -- through the empty portion of the bar (most obvious at 0 health).
    -- Give the Focus health bar its own opaque dark backing so empty/dead
    -- health reads the same way as the other SlamFrames health bars.
    f.healthBackdrop=f.health:CreateTexture(nil,"BACKGROUND")
    f.healthBackdrop:SetTexture(WHITE)
    f.healthBackdrop:SetVertexColor(0.025,0.028,0.034,0.98)
    f.healthBackdrop:SetAllPoints(f.health)

    f.artFrame=CreateFrame("Frame",nil,f); f.artFrame:SetAllPoints(f); f.artFrame:SetFrameLevel(baseLevel+2)
    f.art=CreateFocusArt(f.artFrame)

    f.textFrame=CreateFrame("Frame",nil,f); f.textFrame:SetAllPoints(f); f.textFrame:SetFrameLevel(baseLevel+3)
    f.name=f.textFrame:CreateFontString(nil,"OVERLAY")
    f.name:SetFont("Fonts\\FRIZQT__.TTF",16,"OUTLINE")
    f.name:SetTextColor(1.0,0.82,0.0); f.name:SetJustifyH("CENTER")
    f.name:SetShadowColor(0,0,0,1); f.name:SetShadowOffset(1,-1)

    f.healthText=f.textFrame:CreateFontString(nil,"OVERLAY")
    f.healthText:SetFont("Fonts\\FRIZQT__.TTF",13,"OUTLINE")
    f.healthText:SetTextColor(1,1,1); f.healthText:SetJustifyH("CENTER")
    f.healthText:SetShadowColor(0,0,0,1); f.healthText:SetShadowOffset(1,-1)

    f.moveLabel=f.textFrame:CreateFontString(nil,"OVERLAY")
    f.moveLabel:SetFont("Fonts\\FRIZQT__.TTF",11,"OUTLINE")
    f.moveLabel:SetTextColor(1,0.35,0.10); f.moveLabel:SetJustifyH("CENTER")
    f.moveLabel:SetText("FOCUS"); f.moveLabel:Hide()

    f:SetScript("OnMouseDown",function()
        if SF.BringToFront then SF:BringToFront(this) end
    end)
    f:SetScript("OnDragStart",function()
        if SlamFramesDB and not SlamFramesDB.locked then this:StartMoving() end
    end)
    f:SetScript("OnDragStop",function()
        this:StopMovingOrSizing(); SaveFocusAnchor(this)
    end)
    f:SetScript("OnMouseWheel",function()
        if not SlamFramesDB or SlamFramesDB.locked then return end
        local d=arg1 or 0
        local v=(SlamFramesDB.focusScale or FOCUS_DEFAULTS.scale)+(d>0 and 0.05 or -0.05)
        SF:SetFocusScale(v,true)
    end)
    f:SetScript("OnMouseUp",function()
        if not SlamFramesDB or not SlamFramesDB.locked then return end
        if arg1=="LeftButton" then SF:TargetFocusUnit() end
    end)
    f:SetScript("OnEnter",function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(this,"ANCHOR_TOP")
        GameTooltip:SetText("SlamFrames Focus")
        if SlamFramesDB and SlamFramesDB.locked then GameTooltip:AddLine("Left-click: target focus",0.9,0.9,0.9) else GameTooltip:AddLine("Drag to move  |  Mouse wheel to scale",0.9,0.9,0.9) end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)

    self.focus=f
    if not SlamFramesDB.focusAnchor then self:ResetFocusPosition(true) else ApplyFocusAnchor(f) end
    self:LayoutFocusFrame()
    self:UpdateFocusFrame(true)
    return f
end

function SF:LayoutFocusFrame()
    local f=self.focus; if not f then return end
    EnsureFocusDB()
    local scale=Clamp(SlamFramesDB.focusScale,0.40,2.50)
    local fw=Clamp(SlamFramesDB.focusWidth,220,520)
    local fh=Clamp(SlamFramesDB.focusHeight,46,100)
    f.layoutScale=scale
    f:SetScale(1); f:SetWidth(fw*scale); f:SetHeight(fh*scale)
    if f.art then f.art:SetLayout(fw,fh,scale) end

    -- Derive the health bar rectangle from the actual transparent
    -- cavity in the approved Focus artwork instead of approximating it with
    -- generic height multipliers. This matches the same principle used by the
    -- main SlamFrames health bars: the fill occupies the cavity, while the art
    -- sits over it and provides the visible border.
    --
    -- Artwork source is 512x128 and is rendered as three slices:
    --   left  = source x 0..118
    --   middle= source x 118..394
    --   right = source x 394..512
    --
    -- use one canonical health-cavity geometry for BOTH Focus skins.
    -- The Dark Focus bar already fills/drains correctly, so Light now uses the
    -- exact same bar rectangle instead of its older, tighter measurements.
    -- Only the decorative artwork changes between themes; health fill behavior
    -- and backing geometry are now identical.
    local sourceLeft=79
    local sourceRightInset=77
    local sourceTop=31
    local sourceBottom=89

    -- Reproduce the same end-cap width used by CreateFocusArt(), but in
    -- unscaled frame coordinates because StatusBar:SetLayout applies scale.
    local cap=math.min(fw*0.31,fh*0.96)
    local leftInset=cap*(sourceLeft/118)
    local rightInset=cap*(sourceRightInset/118)

    local barY=fh*((128-sourceBottom)/128)
    local barH=fh*((sourceBottom-sourceTop)/128)
    local barW=math.max(50,fw-leftInset-rightInset)

    f.health.baseRect={x=leftInset,y=barY,w=barW,h=barH}
    f.health:SetLayout(scale,0)

    f.name:ClearAllPoints(); f.name:SetPoint("BOTTOM",f,"BOTTOM",0,fh*0.775*scale)
    -- Constrain the name to the same center cavity used by the health bar.
    f.focusNameMaxWidth=math.max(60,barW*scale)
    f.name:SetWidth(f.focusNameMaxWidth); f.name:SetHeight(fh*0.34*scale)
    local nameSize=math.max(8,Round(16*scale*Clamp(SlamFramesDB.focusNameTextScale,0.60,2.00)))
    f.focusNameFontSize=nameSize
    f.name:SetFont("Fonts\\FRIZQT__.TTF",nameSize,"OUTLINE")

    f.healthText:ClearAllPoints(); f.healthText:SetAllPoints(f.health)
    local healthSize=math.max(7,Round(13*scale*Clamp(SlamFramesDB.focusHealthTextScale,0.60,2.00)))
    f.healthText:SetFont("Fonts\\FRIZQT__.TTF",healthSize,"OUTLINE")

    f.moveLabel:ClearAllPoints(); f.moveLabel:SetPoint("TOP",f,"BOTTOM",0,-3)
    f.moveLabel:SetWidth(fw*scale); f.moveLabel:SetHeight(18*scale)
    if self.RefreshFrameLayers then self:RefreshFrameLayers(self.topFrameKey) end
end

function SF:RefreshFocusSkin()
    if self.focus and self.focus.art then self.focus.art:SetTexture(FocusTexturePath()) end
end

local function ScanFocusName(name)
    if not name or name=="" then return nil end
    local wanted=string.lower(name)
    local tokens={"target","targettarget","mouseover","pet","pettarget"}
    local i
    for i=1,4 do
        table.insert(tokens,"party"..i); table.insert(tokens,"party"..i.."target"); table.insert(tokens,"partypet"..i)
    end
    for i=1,40 do
        table.insert(tokens,"raid"..i); table.insert(tokens,"raid"..i.."target"); table.insert(tokens,"raidpet"..i)
    end
    for i=1,table.getn(tokens) do
        local token=tokens[i]
        if SafeUnitExists(token) then
            local n=SafeUnitName(token)
            if n and string.lower(n)==wanted then return token end
        end
    end
    return nil
end

function SF:ResolveFocusUnit()
    local state=self.focusState or {}

    -- Prefer a real focus token when the client supplies one.
    if SafeUnitExists("focus") then
        local n=SafeUnitName("focus")
        state.name=n or state.name; state.guid=GetGuid("focus") or state.guid; state.token="focus"; state.source="native"
        self.focusState=state
        return "focus"
    end

    -- If a native focus disappeared, do not keep a stale native-only state.
    if state.source=="native" then
        state.name=nil; state.guid=nil; state.token=nil; state.source=nil
    end

    -- Reuse a previously-resolved normal unit token before scanning anything.
    -- This makes normal health updates effectively O(1) while the token is stable.
    if state.token and state.token~="focus" and state.token~=state.guid and SafeUnitExists(state.token) then
        local cachedName=SafeUnitName(state.token)
        if cachedName and state.name and string.lower(cachedName)==string.lower(state.name) then return state.token end
    end

    -- SuperWoW accepts exact GUID strings as unit tokens. This is the most
    -- reliable emulation path because it keeps following the same unit even
    -- after the player changes targets.
    if state.guid and SafeUnitExists(state.guid) then state.token=state.guid; return state.guid end

    if state.name then
        local token=ScanFocusName(state.name)
        if token then
            state.token=token; state.guid=GetGuid(token) or state.guid
            return token
        end
    end
    state.token=nil
    return nil
end

function SF:SetFocusFromUnit(unit,quiet)
    unit=unit or "target"
    if not SafeUnitExists(unit) then
        if not quiet and self.Print then self.Print("No valid unit available to set as focus.") end
        return false
    end
    local name=SafeUnitName(unit)
    if not name then return false end
    self.focusState={name=name,guid=GetGuid(unit),token=unit,lastCur=nil,lastMax=nil,lastLevel=SafeUnitLevel(unit),source="slam"}
    local cur,maxv=SafeUnitHealth(unit); self.focusState.lastCur=cur; self.focusState.lastMax=maxv
    self:UpdateFocusFrame(true)
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("Focus set to "..name..".") end
    return true
end

function SF:SetFocusByName(name,quiet)
    name=tostring(name or "")
    if name=="" then return self:SetFocusFromUnit("target",quiet) end
    local token=ScanFocusName(name)
    if token then return self:SetFocusFromUnit(token,quiet) end
    self.focusState={name=name,guid=nil,token=nil,lastCur=0,lastMax=1,lastLevel=nil,source="slam"}
    self:UpdateFocusFrame(true)
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("Focus remembered as "..name.."; live health appears when the unit is resolvable.") end
    return true
end

function SF:ClearFocus(quiet)
    self.focusState={name=nil,guid=nil,token=nil,lastCur=nil,lastMax=nil,lastLevel=nil,source=nil}
    if self.focus then self.focus:Hide() end
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("Focus cleared.") end
end

function SF:TargetFocusUnit()
    local token=self:ResolveFocusUnit()
    if token and type(TargetUnit)=="function" then
        local ok=pcall(TargetUnit,token); if ok then return true end
    end
    local name=self.focusState and self.focusState.name
    if name and type(TargetByName)=="function" then pcall(TargetByName,name,true); return true end
    return false
end

function SF:UpdateFocusFrame(force)
    local f=self.focus; if not f then return end
    EnsureFocusDB()
    if not SlamFramesDB.showFocusFrame then f:Hide(); return end

    if self.testMode then
        SetFittedFocusName(f.name,"Rogar",f.focusNameMaxWidth or 120,f.focusNameFontSize)
        f.health:SetFillColor(1,1,1,1); f.health:SetValue(2947,2947,true)
        f.healthText:SetText(FocusDisplayText(2947,2947)); f:SetAlpha(1); f:Show(); return
    end

    local token=self:ResolveFocusUnit()
    local state=self.focusState or {}
    if not token and not state.name then f:Hide(); return end

    local cur,maxv,name
    if token then
        cur,maxv=SafeUnitHealth(token); name=SafeUnitName(token) or state.name or "Focus"
        state.name=name; state.guid=GetGuid(token) or state.guid; state.lastCur=cur; state.lastMax=maxv; state.lastLevel=SafeUnitLevel(token)
        f.health:SetFillColor(1,1,1,1); f:SetAlpha(1)
    else
        cur=state.lastCur or 0; maxv=state.lastMax or 1; name=state.name or "Focus"
        f.health:SetFillColor(0.45,0.45,0.45,1); f:SetAlpha(0.72)
    end
    self.focusState=state
    SetFittedFocusName(f.name,name,f.focusNameMaxWidth or 120,f.focusNameFontSize)
    f.health:SetValue(cur,maxv,force and true or false)
    f.healthText:SetText(FocusDisplayText(cur,maxv))
    f:Show()
end

function SF:SetFocusEnabled(v,quiet)
    EnsureFocusDB(); SlamFramesDB.showFocusFrame=v and true or false
    self:UpdateFocusFrame(true); if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("Focus frame "..(SlamFramesDB.showFocusFrame and "enabled" or "disabled")..".") end
end

function SF:SetFocusScale(v,quiet)
    EnsureFocusDB(); SlamFramesDB.focusScale=Clamp(v,0.40,2.50); self:LayoutFocusFrame(); self:UpdateFocusFrame(true)
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("Focus scale set to "..string.format("%.2f",SlamFramesDB.focusScale)..".") end
end

function SF:SetFocusWidth(v,quiet)
    EnsureFocusDB(); SlamFramesDB.focusWidth=Round(Clamp(v,220,520)); self:LayoutFocusFrame(); self:UpdateFocusFrame(true)
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("Focus width set to "..tostring(SlamFramesDB.focusWidth)..".") end
end

function SF:SetFocusHeight(v,quiet)
    EnsureFocusDB(); SlamFramesDB.focusHeight=Round(Clamp(v,46,100)); self:LayoutFocusFrame(); self:UpdateFocusFrame(true)
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("Focus height set to "..tostring(SlamFramesDB.focusHeight)..".") end
end

function SF:SetFocusHealthTextMode(mode,quiet)
    mode=string.lower(tostring(mode or "amount"))
    if mode~="percent" and mode~="amount" and mode~="both" and mode~="off" then return false end
    SlamFramesDB.focusHealthTextMode=mode; self:UpdateFocusFrame(true); if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("Focus health text: "..mode..".") end
    return true
end

function SF:SetFocusNameTextScale(v,quiet)
    EnsureFocusDB(); SlamFramesDB.focusNameTextScale=Clamp(v,0.60,2.00); self:LayoutFocusFrame(); self:UpdateFocusFrame(true)
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("Focus name text scale set to "..string.format("%.2f",SlamFramesDB.focusNameTextScale)..".") end
end

function SF:SetFocusHealthTextScale(v,quiet)
    EnsureFocusDB(); SlamFramesDB.focusHealthTextScale=Clamp(v,0.60,2.00); self:LayoutFocusFrame(); self:UpdateFocusFrame(true)
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("Focus health text scale set to "..string.format("%.2f",SlamFramesDB.focusHealthTextScale)..".") end
end

function SF:ResetFocusSettings(quiet)
    EnsureFocusDB()
    SlamFramesDB.showFocusFrame=FOCUS_DEFAULTS.show
    SlamFramesDB.focusScale=FOCUS_DEFAULTS.scale
    SlamFramesDB.focusWidth=FOCUS_DEFAULTS.width
    SlamFramesDB.focusHeight=FOCUS_DEFAULTS.height
    SlamFramesDB.focusHealthTextMode=FOCUS_DEFAULTS.healthTextMode
    SlamFramesDB.focusNameTextScale=FOCUS_DEFAULTS.nameTextScale
    SlamFramesDB.focusHealthTextScale=FOCUS_DEFAULTS.healthTextScale
    if FOCUS_DEFAULTS.anchor then
        SlamFramesDB.focusAnchor={
            point=FOCUS_DEFAULTS.anchor.point or "TOPLEFT",
            relativePoint=FOCUS_DEFAULTS.anchor.relativePoint or FOCUS_DEFAULTS.anchor.point or "TOPLEFT",
            x=FOCUS_DEFAULTS.anchor.x or 0,
            y=FOCUS_DEFAULTS.anchor.y or 0,
        }
        if self.focus then ApplyFocusAnchor(self.focus) end
    else
        SlamFramesDB.focusAnchor=nil
        self:ResetFocusPosition(true)
    end
    self:LayoutFocusFrame(); self:UpdateFocusFrame(true)
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("Focus frame reset to default.") end
end

function SF:UpdateFocusMoveState()
    local f=self.focus; if not f then return end
    local unlocked=SlamFramesDB and not SlamFramesDB.locked
    if unlocked then f.moveLabel:SetText("FOCUS  "..string.format("%.2f",SlamFramesDB.focusScale or FOCUS_DEFAULTS.scale).."x"); f.moveLabel:Show() else f.moveLabel:Hide() end
end

-- Core hooks ---------------------------------------------------------------
local OldCreateFrames=SF.CreateFrames
SF.CreateFrames=function(self)
    OldCreateFrames(self)
    EnsureFocusDB()
    self:CreateFocusFrame()
end

local OldRefreshAll=SF.RefreshAll
SF.RefreshAll=function(self)
    OldRefreshAll(self)
    if self.focus then self:UpdateFocusFrame() end
end

local OldRefreshLayers=SF.RefreshFrameLayers
SF.RefreshFrameLayers=function(self,topKey)
    OldRefreshLayers(self,topKey)
    if self.focus and self.ApplyFrameLayerBase then self:ApplyFrameLayerBase(self.focus,(topKey=="focus") and 90 or 48) end
end

local OldMoveLabels=SF.UpdateMoveLabels
SF.UpdateMoveLabels=function(self)
    OldMoveLabels(self)
    self:UpdateFocusMoveState()
end

local OldSmooth=SF.SetSmoothBars
SF.SetSmoothBars=function(self,enabled)
    OldSmooth(self,enabled)
    if self.focus and self.focus.health then self.focus.health:SetSmooth(SlamFramesDB.smoothBars) end
end

local OldReset=SF.Reset
SF.Reset=function(self,key)
    local raw=string.lower(tostring(key or ""))
    if raw=="focus" or raw=="f" then self:ResetFocusSettings(false); return end
    OldReset(self,key)
    if raw=="" then
        -- Core Reset All already restored the complete master profile, including
        -- the authored Focus geometry/anchor. Only rebuild the live Focus frame.
        if self.focus then ApplyFocusAnchor(self.focus); self:LayoutFocusFrame(); self:UpdateFocusFrame(true) end
    end
end

local OldSlash=SF.HandleSlash
SF.HandleSlash=function(self,msg)
    msg=msg or ""
    local _,_,cmd,rest=string.find(msg,"^%s*(%S*)%s*(.-)%s*$")
    cmd=string.lower(cmd or ""); rest=rest or ""
    if cmd=="focus" then
        if string.lower(rest)=="clear" then self:ClearFocus(false)
        elseif rest~="" then self:SetFocusByName(rest,false)
        else self:SetFocusFromUnit("target",false) end
        return
    elseif cmd=="clearfocus" then self:ClearFocus(false); return
    elseif cmd=="focuswidth" then local v=tonumber(rest); if v then self:SetFocusWidth(v,false) end; return
    elseif cmd=="focusheight" then local v=tonumber(rest); if v then self:SetFocusHeight(v,false) end; return
    elseif cmd=="focusscale" then local v=tonumber(rest); if v then self:SetFocusScale(v,false) end; return
    end
    OldSlash(self,msg)
end

SLASH_SLAMFOCUS1="/sfocus"
SlashCmdList["SLAMFOCUS"]=function(msg)
    msg=msg or ""
    if string.lower(msg)=="clear" then SF:ClearFocus(false)
    elseif msg~="" then SF:SetFocusByName(msg,false)
    else SF:SetFocusFromUnit("target",false) end
end
SLASH_SLAMCLEARFOCUS1="/sfclearfocus"
SlashCmdList["SLAMCLEARFOCUS"]=function() SF:ClearFocus(false) end

-- Claim the familiar /focus and /clearfocus commands only when the client or
-- another addon has not already supplied them. This keeps native/other focus
-- implementations intact while giving pure Vanilla users the expected command.
if not SLASH_FOCUS1 and not SlashCmdList["FOCUS"] then
    SLASH_SLAMFOCUS_NATIVE1="/focus"
    SlashCmdList["SLAMFOCUS_NATIVE"]=function(msg)
        msg=msg or ""
        if msg~="" then SF:SetFocusByName(msg,false) else SF:SetFocusFromUnit("target",false) end
    end
end
if not SLASH_CLEARFOCUS1 and not SlashCmdList["CLEARFOCUS"] then
    SLASH_SLAMCLEARFOCUS_NATIVE1="/clearfocus"
    SlashCmdList["SLAMCLEARFOCUS_NATIVE"]=function() SF:ClearFocus(false) end
end

-- Lightweight focus reconciliation. SuperWoW custom GUID units do not always
-- emit the stock UNIT_* events, so poll only this one tiny frame at 5 Hz.
local focusEvents=CreateFrame("Frame","SlamFramesFocusEventFrame",UIParent)
pcall(function() focusEvents:RegisterEvent("PLAYER_FOCUS_CHANGED") end)
focusEvents:RegisterEvent("PLAYER_TARGET_CHANGED")
focusEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
focusEvents:RegisterEvent("UNIT_HEALTH")
focusEvents:RegisterEvent("UNIT_MAXHEALTH")
focusEvents:RegisterEvent("UNIT_NAME_UPDATE")
focusEvents:SetScript("OnEvent",function()
    if not SF.focus then return end
    local ev=event
    if ev=="UNIT_HEALTH" or ev=="UNIT_MAXHEALTH" or ev=="UNIT_NAME_UPDATE" then
        local state=SF.focusState or {}
        local u=arg1
        if u and (u==state.token or u==state.guid or u=="focus") then SF:UpdateFocusFrame(true) end
        return
    end
    SF:UpdateFocusFrame(true)
end)
focusEvents.elapsed=0
focusEvents:SetScript("OnUpdate",function()
    this.elapsed=(this.elapsed or 0)+(arg1 or 0)
    if this.elapsed<0.40 then return end
    this.elapsed=0
    if SF.focus and (SF.focus:IsShown() or (SlamFramesDB and SlamFramesDB.showFocusFrame)) then SF:UpdateFocusFrame(false) end
end)
