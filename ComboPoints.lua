-- SlamFrames 3.3 - correct Boss Light active-gem vertical placement.
-- Vanilla/OctoWoW-safe: uses GetComboPoints() first and keeps a tiny fallback
-- poll because PLAYER_COMBO_POINTS / shapeshift events vary across 1.12 forks.

local SF=SlamFrames
if not SF then return end
local C=SlamFrames_Config
local TEX=C.texturePath
local COMBO_VMAX=0.65625 -- 168/256 and 84/128

local function Clamp(v,lo,hi)
    v=tonumber(v) or lo
    if v<lo then return lo end
    if v>hi then return hi end
    return v
end

local function PlayerClassToken()
    if type(UnitClass)~="function" then return nil end
    local _,token=UnitClass("player")
    token=token and string.upper(tostring(token)) or nil
    return token
end

function SF:IsComboPointClass()
    local token=PlayerClassToken()
    return token=="ROGUE" or token=="DRUID"
end

function SF:IsDruidCatForm()
    if PlayerClassToken()~="DRUID" then return false end
    if type(GetShapeshiftFormInfo)~="function" then return false end
    local i
    for i=1,10 do
        local ok,icon,name,active=pcall(GetShapeshiftFormInfo,i)
        if ok and active then
            local probe=string.lower(tostring(icon or "").." "..tostring(name or ""))
            if string.find(probe,"cat",1,true) or string.find(probe,"catform",1,true) then return true end
        end
    end
    return false
end

local function ReadComboPoints()
    if type(GetComboPoints)~="function" then return 0 end
    local ok,v=pcall(GetComboPoints)
    if ok and tonumber(v) then return Clamp(math.floor(tonumber(v)+0.5),0,5) end
    ok,v=pcall(GetComboPoints,"player","target")
    if ok and tonumber(v) then return Clamp(math.floor(tonumber(v)+0.5),0,5) end
    return 0
end

local function ComboVariant()
    local skin=(SlamFramesDB and SlamFramesDB.skin)=="light" and "light" or "dark"
    local style="normal"
    if SlamFramesDB and SlamFramesDB.specialPlayerFrameEnabled then
        if SlamFramesDB.specialPlayerFrameStyle=="boss" then style="boss"
        elseif SlamFramesDB.specialPlayerFrameStyle=="rareelite" then style="rareelite" end
    end
    return style.."_"..skin
end

local function ComboTexture(file)
    local root=(SF.GetTextureRoot and SF:GetTextureRoot()) or TEX
    return root.."Combo\\"..file
end

function SF:CreateComboPointTracker()
    if self.comboTracker or not self.player then return self.comboTracker end
    local c=CreateFrame("Frame","SlamFrames_ComboPoints",self.player)
    c:SetFrameLevel(self.player:GetFrameLevel()+16)
    c:EnableMouse(false)

    c.base=c:CreateTexture(nil,"ARTWORK")
    c.base:SetAllPoints(c)
    c.base:SetTexCoord(0,1,0,COMBO_VMAX)

    c.points={}
    local i
    for i=1,5 do
        local t=c:CreateTexture(nil,"OVERLAY")
        t:SetTexCoord(0,1,0,1)
        c.points[i]=t
    end
    c.lastVariant=nil
    c.lastPoints=-1
    c:Hide()
    self.comboTracker=c
    return c
end

function SF:LayoutComboPointTracker()
    local c=self:CreateComboPointTracker()
    local p=self.player
    if not c or not p or not p.cfg then return end
    local cfg=p.cfg
    local playerScale=p.layoutScale or (SlamFramesDB.scales and SlamFramesDB.scales.player) or .60
    local trim=p.widthTrim or 0
    local healthW=math.max(80,(cfg.health.w or 297)-trim)
    local userScale=Clamp(SlamFramesDB.comboPointScale or 1.00,.65,1.50)

    -- Follow Player bar length and Player scale automatically.  The tracker is
    -- centered on the live health/resource cavity, not on the portrait frame,
    -- so all existing bar-width presets stay aligned.
    local authoredW=healthW+20
    local authoredH=authoredW/3.05
    local w=authoredW*playerScale*userScale
    local h=authoredH*playerScale*userScale
    local centerX=(cfg.health.x+(healthW*.5))*playerScale + (tonumber(SlamFramesDB.comboPointXOffset) or 0)*playerScale
    local topY=((cfg.power and cfg.power.y) or 36.6)*playerScale + (tonumber(SlamFramesDB.comboPointYOffset) or 0)*playerScale
    local centerY=topY-(h*.5)

    c:ClearAllPoints()
    c:SetPoint("CENTER",p,"BOTTOMLEFT",centerX,centerY)
    c:SetWidth(w); c:SetHeight(h)

    -- each approved art variant has slightly different socket centers.
    -- Use measurements from the actual source art instead of one shared table.
    -- The small table is used by both native 1080 and 4K Compatible mode.
    local variant=ComboVariant()
    local mode=(SF.GetArtResolution and SF:GetArtResolution()) or "4k"
    local small=(mode=="1080" or mode=="4kcompat")
    local layouts4k={
        boss_dark={xs={88/512,172/512,256/512,339/512,424/512},y=86/168,size=0.100},
        -- Boss Light's original Y coordinate put the lit gem ~12 source
        -- pixels below the artwork socket center. Use measured Light artwork
        -- placement while retaining the approved active-fill size and palette.
        boss_light={xs={91/512,172/512,252/512,332/512,413/512},y=91/168,size=0.100},
        -- Normal Light is geometry-locked to Normal Dark. Both themes
        -- use the exact same socket centers, circumference and active-point size;
        -- only the texture palette changes when the skin is switched.
        normal_dark={xs={88/512,172/512,256/512,339/512,424/512},y=86/168,size=0.100},
        normal_light={xs={88/512,172/512,256/512,339/512,424/512},y=86/168,size=0.100},
        rareelite_dark={xs={88/512,172/512,256/512,339/512,424/512},y=86/168,size=0.100},
        -- Keep the measured Light Rare/Elite socket centers while matching
        -- Dark's fill size.
        rareelite_light={xs={92/512,172/512,251/512,331/512,406/512},ys={95/168,93/168,91/168,93/168,95/168},size=0.100},
    }
    local layoutsSmall={
        boss_dark={xs={44/256,86/256,128/256,170/256,212/256},y=43/84,size=0.100},
        boss_light={xs={46/256,86/256,126/256,166/256,206/256},y=46/84,size=0.100},
        normal_dark={xs={44/256,86/256,128/256,170/256,212/256},y=43/84,size=0.100},
        normal_light={xs={44/256,86/256,128/256,170/256,212/256},y=43/84,size=0.100},
        rareelite_dark={xs={44/256,86/256,128/256,170/256,212/256},y=43/84,size=0.100},
        rareelite_light={xs={46/256,86/256,127/256,167/256,206/256},ys={46/84,44/84,44/84,46/84,46/84},size=0.100},
    }
    local L=(small and layoutsSmall[variant]) or layouts4k[variant] or layouts4k.normal_dark
    local gemSize=w*L.size
    local i
    for i=1,5 do
        local t=c.points[i]
        t:ClearAllPoints()
        local ly=(L.ys and L.ys[i]) or L.y
        t:SetPoint("CENTER",c,"BOTTOMLEFT",w*L.xs[i],h*ly)
        t:SetWidth(gemSize); t:SetHeight(gemSize)
    end
end

function SF:UpdateComboPointTracker(force)
    local c=self:CreateComboPointTracker()
    if not c then return end

    if not SlamFramesDB or SlamFramesDB.showComboPoints==false or not self:IsComboPointClass() then
        c:Hide(); return
    end
    if PlayerClassToken()=="DRUID" and SlamFramesDB.comboDruidHideOutsideCat~=false and not self:IsDruidCatForm() then
        c:Hide(); return
    end

    local variant=ComboVariant()
    local count=(self.testMode and 3) or ReadComboPoints()
    if force or c.lastVariant~=variant then
        c.lastVariant=variant
        c.base:SetTexture(ComboTexture("combo_"..variant..".tga"))
        local i
        for i=1,5 do
            c.points[i]:SetTexture(ComboTexture("combo_"..variant.."_active.tga"))
            c.points[i]:Hide()
        end
        c.lastPoints=-1
    end
    if force or c.lastPoints~=count then
        local i
        for i=1,5 do
            if i<=count then
                c.points[i]:Show()
            else
                c.points[i]:Hide()
            end
        end
        c.lastPoints=count
    end
    self:LayoutComboPointTracker()
    c:Show()
end

function SF:SetComboPointsEnabled(v,quiet)
    SlamFramesDB.showComboPoints=v and true or false
    self:UpdateComboPointTracker(true)
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("combo-point tracker "..(SlamFramesDB.showComboPoints and "ON" or "OFF")..".") end
end

function SF:SetComboDruidHideOutsideCat(v,quiet)
    SlamFramesDB.comboDruidHideOutsideCat=v and true or false
    self:UpdateComboPointTracker(true)
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("Druid combo tracker outside Cat Form: "..(SlamFramesDB.comboDruidHideOutsideCat and "HIDDEN" or "SHOWN")..".") end
end

function SF:SetComboPointScale(v,quiet)
    SlamFramesDB.comboPointScale=Clamp(v,0.65,1.50)
    self:LayoutComboPointTracker(); self:UpdateComboPointTracker(true)
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("combo tracker scale: "..string.format("%.2f",SlamFramesDB.comboPointScale).."x.") end
end

function SF:SetComboPointOffset(axis,v,quiet)
    v=Clamp(math.floor((tonumber(v) or 0)+0.5),-100,100)
    if axis=="x" then SlamFramesDB.comboPointXOffset=v else SlamFramesDB.comboPointYOffset=v end
    self:LayoutComboPointTracker()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("combo tracker "..string.upper(axis).." offset: "..tostring(v)..".") end
end

function SF:ResetComboPointLayout(quiet)
    SlamFramesDB.comboPointScale=1.00
    SlamFramesDB.comboPointXOffset=0
    SlamFramesDB.comboPointYOffset=0
    SlamFramesDB.targetComboPointScale=1.50
    self:LayoutComboPointTracker(); self:UpdateComboPointTracker(true)
    self:LayoutTargetComboPointFrame(); self:UpdateTargetComboPointFrame(true)
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("combo tracker layout reset.") end
end

-- ---------------------------------------------------------------------------
-- Target combo points
--
-- Vanilla's ComboFrame is a separate UIParent child anchored to Blizzard's
-- TargetFrame.  Because SlamFrames replaces/hides Blizzard's target frame, the
-- original arc can appear detached in world-space.  earlier builds permanently
-- suppresses that native floating frame and recreates its five stock 1.12
-- combo-point sprites around the SlamFrames target portrait instead.
-- ---------------------------------------------------------------------------

local function GetNativeComboFrame()
    if type(getglobal)=="function" then return getglobal("ComboFrame") end
    return ComboFrame
end

function SF:SuppressNativeComboFrame()
    local f=GetNativeComboFrame()
    if not f then return nil end

    if not f.sfSlamFramesSuppressed then
        if f.UnregisterEvent then
            pcall(function() f:UnregisterEvent("PLAYER_TARGET_CHANGED") end)
            pcall(function() f:UnregisterEvent("PLAYER_COMBO_POINTS") end)
            pcall(function() f:UnregisterEvent("UNIT_COMBO_POINTS") end)
        end
        -- Some 1.12 forks restore the native handler after reloads.  Clear the
        -- event script as a second line of defense so it cannot reappear at
        -- Blizzard's old TargetFrame anchor.
        if f.SetScript then pcall(function() f:SetScript("OnEvent",nil) end) end
        f.sfSlamFramesSuppressed=true
    end

    if f.SetAlpha then f:SetAlpha(0) end
    if f.Hide then f:Hide() end
    return f
end


local function TargetComboTheme()
    return (SlamFramesDB and SlamFramesDB.skin)=="light" and "light" or "dark"
end

local function TargetComboTexture(file)
    local root=(SF.GetTextureRoot and SF:GetTextureRoot()) or TEX
    return root.."TargetCombo\\"..file
end

function SF:CreateTargetComboPointArc()
    if self.targetComboArc or not self.target then return self.targetComboArc end

    local host=CreateFrame("Frame","SlamFrames_TargetComboArc",self.target)
    host:SetAllPoints(self.target)
    host:SetFrameLevel(self.target:GetFrameLevel()+30)
    host:EnableMouse(false)
    host.points={}
    host.lastCount=-1
    host.lastTheme=nil

    local i
    for i=1,5 do
        local p=CreateFrame("Frame","SlamFrames_TargetComboPoint"..i,host)
        p:EnableMouse(false)

        p.base=p:CreateTexture(nil,"ARTWORK")
        p.base:SetAllPoints(p)

        p.active=p:CreateTexture(nil,"OVERLAY")
        p.active:SetAllPoints(p)
        p.active:SetBlendMode("ADD")
        p.active:Hide()

        p:Show()
        host.points[i]=p
    end

    host:Hide()
    self.targetComboArc=host
    return host
end

function SF:LayoutTargetComboPointFrame()
    local host=self:CreateTargetComboPointArc()
    local target=self.target
    if not host or not target or not target.cfg or not target.cfg.portrait then return end

    local cfg=target.cfg
    local p=cfg.portrait
    local scale=target.layoutScale or (SlamFramesDB.scales and SlamFramesDB.scales.target) or .60
    local trim=target.widthTrim or 0
    local userScale=Clamp(SlamFramesDB.targetComboPointScale or 1.50,0.75,2.00)

    -- keep the custom art, but stop shrinking the *whole five-point
    -- texture* into one portrait-sized box. Each approved socket is now its
    -- own element. This lets the circles stay readable while the arc itself
    -- keeps the compact Vanilla-style placement around the target portrait.
    local cx=(p.x-trim)*scale
    local cy=p.y*scale
    local portraitSize=(p.size or 103)*scale

    local pointSize=21*scale*userScale
    local radius=(portraitSize*0.50)+(pointSize*0.62)

    -- One canonical geometry for both skins. Angles run across the upper/right
    -- portrait edge, matching the original target-combo location without
    -- colliding with the Target-of-Target frame below.
    local angles={118,94,70,46,22}
    local pi=3.141592653589793

    host:ClearAllPoints()
    host:SetAllPoints(target)
    host:SetFrameLevel(target:GetFrameLevel()+30)

    local i,a,r,x,y,pt
    for i=1,5 do
        a=angles[i]*pi/180
        x=cx+(math.cos(a)*radius)
        y=cy+(math.sin(a)*radius)
        pt=host.points[i]
        pt:ClearAllPoints()
        pt:SetPoint("CENTER",target,"BOTTOMLEFT",x,y)
        pt:SetWidth(pointSize)
        pt:SetHeight(pointSize)
    end
end

function SF:UpdateTargetComboPointFrame(force)
    self:SuppressNativeComboFrame()

    local host=self:CreateTargetComboPointArc()
    if not host then return end

    local enabled=SlamFramesDB and SlamFramesDB.showTargetComboPoints~=false
    -- mirror the Player combo tracker behavior in Test Mode.
    -- Rogues/Druids should be able to preview and adjust the Target combo arc
    -- even when there is no live target, so Test Frames always supplies a
    -- three-point preview while the Target Combo setting is enabled.
    local comboClass=self:IsComboPointClass()
    local preview=self.testMode and comboClass
    local usable=enabled and comboClass and self.target and (preview or UnitExists("target"))
    local count=usable and (preview and 3 or ReadComboPoints()) or 0

    if not usable or count<=0 then
        host.lastCount=0
        host:Hide()
        return
    end

    local theme=TargetComboTheme()
    if force or host.lastTheme~=theme then
        local baseTex=TargetComboTexture("target_combo_socket_"..theme..".tga")
        local activeTex=TargetComboTexture("target_combo_socket_"..theme.."_active.tga")
        local i
        for i=1,5 do
            host.points[i].base:SetTexture(baseTex)
            host.points[i].active:SetTexture(activeTex)
            host.points[i].active:Hide()
        end
        host.lastTheme=theme
        host.lastCount=-1
    end

    self:LayoutTargetComboPointFrame()

    if force or host.lastCount~=count then
        local i
        for i=1,5 do
            host.points[i]:Show()
            if i<=count then host.points[i].active:Show() else host.points[i].active:Hide() end
        end
        host.lastCount=count
    end

    host:Show()
end

function SF:SetTargetComboPointScale(v,quiet)
    v=Clamp(tonumber(v) or 1.50,0.75,2.00)
    v=math.floor(v*20+0.5)/20
    SlamFramesDB.targetComboPointScale=v
    self:LayoutTargetComboPointFrame()
    self:UpdateTargetComboPointFrame(true)
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then
        self.Print("Target combo scale: "..tostring(math.floor(v*100+0.5)).."%.")
    end
end

function SF:SetTargetComboPointsEnabled(v,quiet)
    SlamFramesDB.showTargetComboPoints=v and true or false
    self:SuppressNativeComboFrame()
    self:UpdateTargetComboPointFrame(true)
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then
        self.Print("Target combo points "..(SlamFramesDB.showTargetComboPoints and "ON" or "OFF")..".")
    end
end

local ev=CreateFrame("Frame",nil,UIParent)
local function SafeRegister(name)
    pcall(function() ev:RegisterEvent(name) end)
end
SafeRegister("PLAYER_ENTERING_WORLD")
SafeRegister("PLAYER_COMBO_POINTS")
SafeRegister("UNIT_COMBO_POINTS")
SafeRegister("PLAYER_TARGET_CHANGED")
SafeRegister("UPDATE_SHAPESHIFT_FORM")
SafeRegister("UPDATE_SHAPESHIFT_FORMS")
SafeRegister("PLAYER_AURAS_CHANGED")
ev:SetScript("OnEvent",function()
    if SF and SF.UpdateComboPointTracker then SF:UpdateComboPointTracker(true) end
    if SF and SF.UpdateTargetComboPointFrame then SF:UpdateTargetComboPointFrame(true) end
end)

-- Extremely light compatibility fallback for forks that do not expose all of
-- the original combo/shapeshift events. Five textures are only changed when
-- the count/theme actually changes.
local elapsed=0
ev:SetScript("OnUpdate",function()
    elapsed=elapsed+(arg1 or 0)
    if elapsed<0.15 then return end
    elapsed=0
    if SF and SF.UpdateComboPointTracker then SF:UpdateComboPointTracker(false) end
    if SF and SF.UpdateTargetComboPointFrame then SF:UpdateTargetComboPointFrame(false) end
end)
