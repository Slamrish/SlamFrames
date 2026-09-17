-- SlamFrames 2.0 - masked Rare / Elite / Boss portrait decorations + independent Player/Friendly/Enemy/Rare-Elite name X positions.
-- OctoWoW / Vanilla 1.12-era compatible.
--
-- Two-layer compositor:
--   special BACK artwork -> portrait -> special FRONT bezel/mask -> level badge
--
-- This deliberately avoids modern texture-mask APIs.  The portrait itself
-- occludes any inward decoration from the back layer, while the front bezel
-- slightly overlaps the portrait edge to guarantee a clean circular opening.
--
-- Target orientation: dragon faces LEFT / inward toward target bars.
-- Player orientation: the same artwork is mirrored so the dragon faces RIGHT /
-- inward toward player bars.

local SF=SlamFrames
if not SF then return end

local TEX="Interface\\AddOns\\SlamFrames\\Textures\\"
local WHITE="Interface\\Buttons\\WHITE8X8"
local FONT="Fonts\\FRIZQT__.TTF"

local GOLD={1.00,0.82,0.00}
local GOLD_DIM={0.65,0.48,0.08}
local WHITE_TEXT={0.92,0.92,0.92}
local MUTED={0.66,0.66,0.66}

local STYLE={
    rareelite={
        back="special_rareelite_back.tga",
        front="special_rareelite_front.tga",
        -- Opening center retained from the approved TEST 29 alignment.
        holeX=0.43644,
        holeY=0.45781,
        sizeFactor=1.90,
        -- Player-only name clearance. The mirrored dragon head occupies the
        -- normal left-aligned name area, so shift the name right while this
        -- decoration is active. Authored pixels; LayoutFrame scales it.
        playerNameShift=140,
        playerNameExtraWidth=15,
    },
    boss={
        back="special_boss_back.tga",
        front="special_boss_front.tga",
        holeX=0.44599,
        holeY=0.50436,
        sizeFactor=1.95,
        playerNameShift=145,
        playerNameExtraWidth=15,
    },
}

local function EnsureDefaults()
    SlamFramesDB=SlamFramesDB or {}
    if SlamFramesDB.specialTargetFrames==nil then SlamFramesDB.specialTargetFrames=true end
    if SlamFramesDB.specialPlayerFrameEnabled==nil then SlamFramesDB.specialPlayerFrameEnabled=false end
    if SlamFramesDB.specialPlayerFrameStyle~="rareelite" and SlamFramesDB.specialPlayerFrameStyle~="boss" then
        SlamFramesDB.specialPlayerFrameStyle="rareelite"
    end
    -- User-tunable horizontal offset from the authored safe position. 0 keeps
    -- the TEST 31 clearance; negative moves left, positive moves right.
    if SlamFramesDB.specialPlayerNameOffset==nil then SlamFramesDB.specialPlayerNameOffset=0 end
    SlamFramesDB.specialPlayerNameOffset=math.max(-150,math.min(150,tonumber(SlamFramesDB.specialPlayerNameOffset) or 0))

    -- Target names get independent horizontal tuning for ordinary hostile
    -- targets versus the larger Rare / Elite / Boss portrait decorations.
    -- Zero always means the authored SlamFrames target-name position.
    if SlamFramesDB.targetNameOffsetFriendly==nil then SlamFramesDB.targetNameOffsetFriendly=0 end
    if SlamFramesDB.targetNameOffsetNormal==nil then SlamFramesDB.targetNameOffsetNormal=0 end
    if SlamFramesDB.targetNameOffsetSpecial==nil then SlamFramesDB.targetNameOffsetSpecial=0 end
    SlamFramesDB.targetNameOffsetFriendly=math.max(-150,math.min(150,tonumber(SlamFramesDB.targetNameOffsetFriendly) or 0))
    SlamFramesDB.targetNameOffsetNormal=math.max(-150,math.min(150,tonumber(SlamFramesDB.targetNameOffsetNormal) or 0))
    SlamFramesDB.targetNameOffsetSpecial=math.max(-150,math.min(150,tonumber(SlamFramesDB.targetNameOffsetSpecial) or 0))
end

local function SkinTexture(file)
    EnsureDefaults()
    if SlamFramesDB.skin=="dark" then return TEX.."Dark\\"..file end
    return TEX..file
end

local function UnitSpecialStyle(unit)
    if not unit or not UnitExists(unit) or type(UnitClassification)~="function" then return nil end
    local c=UnitClassification(unit)
    if c=="worldboss" or c=="boss" then return "boss" end
    if c=="rare" or c=="rareelite" or c=="elite" then return "rareelite" end
    return nil
end

local function EnsureDecoration(frame)
    if not frame then return nil end
    if frame.sfSpecialBackFrame and frame.sfSpecialFrontFrame and frame.sfSpecialBackTexture and frame.sfSpecialFrontTexture then
        return frame.sfSpecialBackTexture,frame.sfSpecialFrontTexture
    end

    local back=CreateFrame("Frame",nil,frame)
    back:SetWidth(1); back:SetHeight(1)
    back:EnableMouse(false)
    back:Hide()
    local backTex=back:CreateTexture(nil,"ARTWORK")
    backTex:SetAllPoints(back)
    backTex:SetTexCoord(0,1,0,1)
    backTex:SetBlendMode("BLEND")

    local front=CreateFrame("Frame",nil,frame)
    front:SetWidth(1); front:SetHeight(1)
    front:EnableMouse(false)
    front:Hide()
    local frontTex=front:CreateTexture(nil,"ARTWORK")
    frontTex:SetAllPoints(front)
    frontTex:SetTexCoord(0,1,0,1)
    frontTex:SetBlendMode("BLEND")

    frame.sfSpecialBackFrame=back
    frame.sfSpecialBackTexture=backTex
    frame.sfSpecialFrontFrame=front
    frame.sfSpecialFrontTexture=frontTex
    return backTex,frontTex
end

local function IsPlayerSpecialFrame(frame)
    return frame and frame.frameKey=="player"
end

local function ApplyOrientation(frame)
    if not frame then return end
    local mirrored=IsPlayerSpecialFrame(frame)
    local b=frame.sfSpecialBackTexture
    local f=frame.sfSpecialFrontTexture
    if mirrored then
        -- Horizontal mirror: player dragon faces inward toward the bars.
        if b then b:SetTexCoord(1,0,0,1) end
        if f then f:SetTexCoord(1,0,0,1) end
    else
        if b then b:SetTexCoord(0,1,0,1) end
        if f then f:SetTexCoord(0,1,0,1) end
    end
end

function SF:LayoutSpecialPortrait(frame)
    if not frame or not frame.portrait or not frame.sfSpecialPortraitStyle then return end
    local info=STYLE[frame.sfSpecialPortraitStyle]
    if not info then return end
    EnsureDecoration(frame)

    local scale=frame.layoutScale or 1
    local portraitSize=(frame.cfg and frame.cfg.portrait and frame.cfg.portrait.size) or 100
    local size=portraitSize*scale*(info.sizeFactor or 1.90)

    -- The authored frames are asymmetric.  Align using the center of the
    -- transparent portrait opening.  Mirroring the player art mirrors that
    -- opening too, so its X coordinate must be mirrored before calculating
    -- the offset.
    local holeX=info.holeX or 0.5
    if IsPlayerSpecialFrame(frame) then holeX=1-holeX end
    local holeY=info.holeY or 0.5
    local ox=(0.5-holeX)*size
    local oy=(holeY-0.5)*size

    local holders={frame.sfSpecialBackFrame,frame.sfSpecialFrontFrame}
    local i,h
    for i=1,table.getn(holders) do
        h=holders[i]
        h:ClearAllPoints()
        h:SetPoint("CENTER",frame.portrait,"CENTER",ox,oy)
        h:SetWidth(size); h:SetHeight(size)
    end
    ApplyOrientation(frame)
end


local function ApplyPlayerSpecialNameLayout(frame)
    if not frame or frame.frameKey~="player" or not frame.name or not frame.cfg or not frame.cfg.name then return end
    local style=frame.sfSpecialPortraitStyle
    local info=style and STYLE[style] or nil
    if not info then return end

    local scale=frame.layoutScale or 1
    local trim=frame.widthTrim or 0
    local cfg=frame.cfg.name
    -- Start from the style's proven safe clearance, then add the player's
    -- saved adjustment. This keeps 0 as a useful default while still allowing
    -- each UI layout to move the name left or right independently.
    local userOffset=tonumber(SlamFramesDB.specialPlayerNameOffset) or 0
    local shift=(tonumber(info.playerNameShift) or 140)+userOffset
    local extra=tonumber(info.playerNameExtraWidth) or 0

    -- Keep the existing vertical placement/font, but move only the Player
    -- name clear of the mirrored dragon head. Target names are untouched.
    frame.name:ClearAllPoints()
    frame.name:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",(cfg.x+shift)*scale,cfg.y*scale)
    frame.name:SetWidth(math.max(60,(cfg.w-trim-shift+extra))*scale)
    frame.name:SetHeight(math.max(1,frame.name:GetHeight()))
    frame.name:SetJustifyH("LEFT")
end

local function TargetIsHostile()
    if SF.testMode and not UnitExists("target") then return true end
    if not UnitExists("target") then return false end
    if type(UnitCanAttack)=="function" then
        local ok,v=pcall(UnitCanAttack,"player","target")
        if ok then return v and true or false end
    end
    if type(UnitIsFriend)=="function" then
        local ok,v=pcall(UnitIsFriend,"player","target")
        if ok then return not v end
    end
    return true
end

local function ApplyTargetNameLayout(frame)
    if not frame or frame.frameKey~="target" or not frame.name or not frame.cfg or not frame.cfg.name then return end

    local cfg=frame.cfg.name
    local scale=frame.layoutScale or 1
    local trim=frame.widthTrim or 0
    local hostile=TargetIsHostile()
    local offset

    if not hostile then
        -- Friendly/self targets have their own saved position so healers and
        -- support players can tune friendly names without moving enemy names.
        offset=tonumber(SlamFramesDB.targetNameOffsetFriendly) or 0
    else
        -- Pick the hostile slider by the unit's classification, not by whether
        -- the decorative portrait option is enabled. Rare / Elite / Boss names
        -- keep their own tuning even if special target artwork is disabled.
        local special=UnitSpecialStyle("target")~=nil
        offset=special and (tonumber(SlamFramesDB.targetNameOffsetSpecial) or 0)
                       or (tonumber(SlamFramesDB.targetNameOffsetNormal) or 0)
    end

    frame.name:ClearAllPoints()
    frame.name:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",(cfg.x+offset)*scale,cfg.y*scale)
    -- Name X is a pure translation control: preserve the normal text box size
    -- so users can position the label independently without changing its wrap.
    frame.name:SetWidth(math.max(40,cfg.w-trim)*scale)
    frame.name:SetJustifyH("LEFT")
end

local function ApplySpecialLayering(frame,active)
    if not frame then return end
    local base=frame.sfLayerBase or 10

    if active then
        -- Keep the decorative body over SlamFrames' normal frame art, but put
        -- the actual circular portrait above it.  This makes the portrait act
        -- as a reliable Vanilla-era mask for anything that intrudes inward.
        if frame.sfSpecialBackFrame then
            frame.sfSpecialBackFrame:SetFrameStrata(frame.sfUnitStrata or "MEDIUM")
            frame.sfSpecialBackFrame:SetFrameLevel(base+6)
        end
        if frame.portrait then frame.portrait:SetFrameLevel(base+7) end
        -- Player status effects may still sit on the portrait, but are kept
        -- below the front bezel so the circular edge remains perfectly clean.
        if frame.statusFrame then frame.statusFrame:SetFrameLevel(base+8) end
        if frame.sfSpecialFrontFrame then
            frame.sfSpecialFrontFrame:SetFrameStrata(frame.sfUnitStrata or "MEDIUM")
            frame.sfSpecialFrontFrame:SetFrameLevel(base+9)
        end
        if frame.levelBadge then frame.levelBadge:SetFrameLevel(base+10) end
    end
end

function SF:SetSpecialPortrait(frame,style)
    if not frame then return end
    if style~="rareelite" and style~="boss" then
        local wasActive=frame.sfSpecialPortraitStyle~=nil
        frame.sfSpecialPortraitStyle=nil
        if frame.sfSpecialBackFrame then frame.sfSpecialBackFrame:Hide() end
        if frame.sfSpecialFrontFrame then frame.sfSpecialFrontFrame:Hide() end
        -- Restore the normal SlamFrames layer stack after a special target is
        -- deselected or the player option is switched off.
        if wasActive and self.ApplyFrameLayerBase then
            self:ApplyFrameLayerBase(frame,frame.sfLayerBase or 10)
        end
        -- LayoutText in the core renderer owns the normal name position.
        -- Re-run it only for Player after the decoration is disabled so the
        -- authored left-aligned name returns immediately.
        if wasActive and frame.frameKey=="player" and self.LayoutFrame then
            self:LayoutFrame(frame,"player",frame.layoutScale or 1)
        end
        return
    end

    local info=STYLE[style]
    local backTex,frontTex=EnsureDecoration(frame)
    local changed=frame.sfSpecialPortraitStyle~=style
    frame.sfSpecialPortraitStyle=style
    backTex:SetTexture(SkinTexture(info.back))
    frontTex:SetTexture(SkinTexture(info.front))
    ApplyOrientation(frame)
    self:LayoutSpecialPortrait(frame)
    frame.sfSpecialBackFrame:Show()
    frame.sfSpecialFrontFrame:Show()
    ApplySpecialLayering(frame,true)
    ApplyPlayerSpecialNameLayout(frame)

    -- A skin/style change can replace textures without changing frame state.
    -- Force a visual refresh but leave portrait zoom/health/etc untouched.
    if changed and frame.portrait and frame.unit and UnitExists(frame.unit) then
        frame.portrait:SetUnit(frame.unit)
    end
end

function SF:UpdateSpecialTargetPortrait()
    EnsureDefaults()
    local frame=self.target
    if not frame then return end
    if not SlamFramesDB.specialTargetFrames or (not UnitExists("target") and not self.testMode) then
        self:SetSpecialPortrait(frame,nil)
        return
    end

    local style=nil
    if UnitExists("target") then style=UnitSpecialStyle("target") end
    -- Test Frames remain visually neutral; live classification owns automatic art.
    self:SetSpecialPortrait(frame,style)
end

function SF:UpdateSpecialPlayerPortrait()
    EnsureDefaults()
    local frame=self.player
    if not frame then return end
    if not SlamFramesDB.specialPlayerFrameEnabled then
        self:SetSpecialPortrait(frame,nil)
        return
    end
    self:SetSpecialPortrait(frame,SlamFramesDB.specialPlayerFrameStyle)
end

function SF:UpdateSpecialPortraitFrames()
    self:UpdateSpecialTargetPortrait()
    self:UpdateSpecialPlayerPortrait()
end

function SF:SetSpecialTargetFrames(v,quiet)
    EnsureDefaults()
    SlamFramesDB.specialTargetFrames=v and true or false
    self:UpdateSpecialTargetPortrait()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("special Rare / Elite / Boss target frames "..(SlamFramesDB.specialTargetFrames and "ON" or "OFF")..".") end
end

function SF:SetSpecialPlayerFrameEnabled(v,quiet)
    EnsureDefaults()
    SlamFramesDB.specialPlayerFrameEnabled=v and true or false
    self:UpdateSpecialPlayerPortrait()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("player special portrait frame "..(SlamFramesDB.specialPlayerFrameEnabled and "ON" or "OFF")..".") end
end

function SF:SetSpecialPlayerFrameStyle(style,quiet)
    EnsureDefaults()
    style=string.lower(style or "")
    if style=="rare" or style=="elite" or style=="rare/elite" or style=="rare-elite" then style="rareelite" end
    if style~="rareelite" and style~="boss" then return false end
    SlamFramesDB.specialPlayerFrameStyle=style
    self:UpdateSpecialPlayerPortrait()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("player special portrait style: "..(style=="boss" and "Boss" or "Rare / Elite")..".") end
    return true
end

function SF:SetSpecialPlayerNameOffset(value,quiet)
    EnsureDefaults()
    value=tonumber(value) or 0
    -- Five-pixel authored steps are fine enough for 4K placement while still
    -- being easy to control with the old Vanilla slider widget.
    if value>=0 then value=math.floor((value/5)+0.5)*5 else value=math.ceil((value/5)-0.5)*5 end
    if value<-150 then value=-150 elseif value>150 then value=150 end
    SlamFramesDB.specialPlayerNameOffset=value

    local frame=self.player
    if frame and frame.sfSpecialPortraitStyle then
        ApplyPlayerSpecialNameLayout(frame)
    end
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then
        local side=value<0 and "left" or (value>0 and "right" or "default")
        self.Print("special Player name X: "..tostring(value).." ("..side..").")
    end
    return true
end

function SF:SetTargetNameOffsetFriendly(value,quiet)
    EnsureDefaults()
    value=tonumber(value) or 0
    if value>=0 then value=math.floor((value/5)+0.5)*5 else value=math.ceil((value/5)-0.5)*5 end
    if value<-150 then value=-150 elseif value>150 then value=150 end
    SlamFramesDB.targetNameOffsetFriendly=value
    if self.target and UnitExists("target") and not TargetIsHostile() then ApplyTargetNameLayout(self.target) end
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("friendly target name X: "..(value>0 and "+" or "")..tostring(value)..".") end
    return true
end

function SF:SetTargetNameOffsetNormal(value,quiet)
    EnsureDefaults()
    value=tonumber(value) or 0
    if value>=0 then value=math.floor((value/5)+0.5)*5 else value=math.ceil((value/5)-0.5)*5 end
    if value<-150 then value=-150 elseif value>150 then value=150 end
    SlamFramesDB.targetNameOffsetNormal=value
    if self.target and UnitExists("target") and TargetIsHostile() and UnitSpecialStyle("target")==nil then ApplyTargetNameLayout(self.target) end
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("normal enemy name X: "..(value>0 and "+" or "")..tostring(value)..".") end
    return true
end

function SF:SetTargetNameOffsetSpecial(value,quiet)
    EnsureDefaults()
    value=tonumber(value) or 0
    if value>=0 then value=math.floor((value/5)+0.5)*5 else value=math.ceil((value/5)-0.5)*5 end
    if value<-150 then value=-150 elseif value>150 then value=150 end
    SlamFramesDB.targetNameOffsetSpecial=value
    if self.target and UnitExists("target") and TargetIsHostile() and UnitSpecialStyle("target")~=nil then ApplyTargetNameLayout(self.target) end
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("Rare / Elite target name X: "..(value>0 and "+" or "")..tostring(value)..".") end
    return true
end

-- Core hooks ----------------------------------------------------------------
-- Keep this feature isolated from the proven unit-frame renderer.  Only the
-- active special portrait changes the portrait's frame level; disabling it
-- restores SlamFrames' normal layer stack immediately.

local OldUpdatePlayer=SF.UpdatePlayer
if OldUpdatePlayer then
    function SF:UpdatePlayer()
        OldUpdatePlayer(self)
        self:UpdateSpecialPlayerPortrait()
    end
end

local OldUpdateTarget=SF.UpdateTarget
if OldUpdateTarget then
    function SF:UpdateTarget()
        OldUpdateTarget(self)
        self:UpdateSpecialTargetPortrait()
        ApplyTargetNameLayout(self.target)
    end
end

local OldLayoutFrame=SF.LayoutFrame
if OldLayoutFrame then
    function SF:LayoutFrame(frame,key,scale)
        OldLayoutFrame(self,frame,key,scale)
        if frame and frame.sfSpecialPortraitStyle then
            self:LayoutSpecialPortrait(frame)
            ApplySpecialLayering(frame,true)
            ApplyPlayerSpecialNameLayout(frame)
        end
        if frame and frame.frameKey=="target" then ApplyTargetNameLayout(frame) end
    end
end

local OldApplyFrameLayerBase=SF.ApplyFrameLayerBase
if OldApplyFrameLayerBase then
    function SF:ApplyFrameLayerBase(frame,base)
        OldApplyFrameLayerBase(self,frame,base)
        if frame and frame.sfSpecialPortraitStyle then ApplySpecialLayering(frame,true) end
    end
end

local OldRefreshSkinTextures=SF.RefreshSkinTextures
if OldRefreshSkinTextures then
    function SF:RefreshSkinTextures()
        OldRefreshSkinTextures(self)
        self:UpdateSpecialPortraitFrames()
    end
end

-- Settings extension ---------------------------------------------------------
-- Add one scrollable section beneath General without replacing Settings.lua.

local function MakeLabel(parent,text,size,color)
    local f=parent:CreateFontString(nil,"OVERLAY")
    f:SetFont(FONT,size or 11,"OUTLINE")
    color=color or GOLD
    f:SetTextColor(color[1],color[2],color[3])
    f:SetText(text or "")
    f:SetJustifyH("LEFT")
    f:SetShadowColor(0,0,0,1); f:SetShadowOffset(1,-1)
    return f
end

local function MakeButton(parent,text,w,h)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetWidth(w or 90); b:SetHeight(h or 22); b:SetText(text or "")
    local fs=b.GetFontString and b:GetFontString() or nil
    if fs then fs:SetTextColor(1.00,0.82,0.00) end
    return b
end

local function MakeLine(parent,x,y,w)
    local t=parent:CreateTexture(nil,"BORDER")
    t:SetTexture(WHITE); t:SetVertexColor(GOLD_DIM[1],GOLD_DIM[2],GOLD_DIM[3],0.85)
    t:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y); t:SetWidth(w); t:SetHeight(1)
    return t
end

local function MakeSection(parent,title,x,y,w,h)
    local box=CreateFrame("Frame",nil,parent)
    box:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    box:SetWidth(w); box:SetHeight(h)
    local bg=box:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints(box); bg:SetTexture(WHITE); bg:SetVertexColor(0.025,0.025,0.025,0.72)
    local left=box:CreateTexture(nil,"BORDER"); left:SetTexture(WHITE); left:SetVertexColor(0.24,0.20,0.12,1); left:SetPoint("TOPLEFT",box,"TOPLEFT",0,0); left:SetWidth(1); left:SetHeight(h)
    local right=box:CreateTexture(nil,"BORDER"); right:SetTexture(WHITE); right:SetVertexColor(0.24,0.20,0.12,1); right:SetPoint("TOPRIGHT",box,"TOPRIGHT",0,0); right:SetWidth(1); right:SetHeight(h)
    local top=box:CreateTexture(nil,"BORDER"); top:SetTexture(WHITE); top:SetVertexColor(0.55,0.42,0.12,1); top:SetPoint("TOPLEFT",box,"TOPLEFT",0,0); top:SetWidth(w); top:SetHeight(1)
    local bottom=box:CreateTexture(nil,"BORDER"); bottom:SetTexture(WHITE); bottom:SetVertexColor(0.24,0.20,0.12,1); bottom:SetPoint("BOTTOMLEFT",box,"BOTTOMLEFT",0,0); bottom:SetWidth(w); bottom:SetHeight(1)
    box.title=MakeLabel(box,title,13,GOLD); box.title:SetPoint("TOPLEFT",box,"TOPLEFT",12,-9)
    MakeLine(box,12,-29,w-24)
    return box
end

function SF:CreateSpecialPortraitSettings()
    if not self.settings or self.settings.sfSpecialPortraitSection then return end
    local f=self.settings
    local g=f.pages and f.pages.general
    if not g then return end

    -- General originally fits exactly in its 548px viewport. Add space for the
    -- new section and activate the existing gold scrollbar/mouse wheel.
    local newHeight=940
    g:SetHeight(newHeight)
    local scroll=f.pageScrolls and f.pageScrolls.general
    local slider=f.pageSliders and f.pageSliders.general
    local maxScroll=newHeight-548
    if slider then
        slider:SetMinMaxValues(0,maxScroll)
        slider.sfMaxScroll=maxScroll
        slider:SetValue(maxScroll)
    end
    if scroll and scroll.EnableMouseWheel then scroll:EnableMouseWheel(true) end

    local s=MakeSection(g,"Special portrait frames",0,-556,504,371)
    f.sfSpecialPortraitSection=s

    s.target=MakeButton(s,"",220,24); s.target:SetPoint("TOPLEFT",s,"TOPLEFT",14,-43)
    s.target:SetScript("OnClick",function() SF:SetSpecialTargetFrames(not SlamFramesDB.specialTargetFrames,true) end)

    s.player=MakeButton(s,"",220,24); s.player:SetPoint("TOPRIGHT",s,"TOPRIGHT",-14,-43)
    s.player:SetScript("OnClick",function() SF:SetSpecialPlayerFrameEnabled(not SlamFramesDB.specialPlayerFrameEnabled,true) end)

    s.styleLabel=MakeLabel(s,"Player decoration",11,WHITE_TEXT); s.styleLabel:SetPoint("TOPLEFT",s,"TOPLEFT",14,-82)
    s.rare=MakeButton(s,"Rare / Elite",128,24); s.rare:SetPoint("TOPLEFT",s,"TOPLEFT",150,-78)
    s.rare:SetScript("OnClick",function() SF:SetSpecialPlayerFrameStyle("rareelite",true) end)
    s.boss=MakeButton(s,"Boss",128,24); s.boss:SetPoint("LEFT",s.rare,"RIGHT",10,0)
    s.boss:SetScript("OnClick",function() SF:SetSpecialPlayerFrameStyle("boss",true) end)

    s.nameXLabel=MakeLabel(s,"Player name X",11,WHITE_TEXT); s.nameXLabel:SetPoint("TOPLEFT",s,"TOPLEFT",14,-118)
    s.nameXValue=MakeLabel(s,"0",11,GOLD); s.nameXValue:SetPoint("TOPLEFT",s,"TOPLEFT",116,-118); s.nameXValue:SetWidth(42); s.nameXValue:SetJustifyH("CENTER")
    s.nameXSlider=CreateFrame("Slider",nil,s)
    s.nameXSlider:SetOrientation("HORIZONTAL")
    s.nameXSlider:SetPoint("TOPLEFT",s,"TOPLEFT",166,-114)
    s.nameXSlider:SetWidth(318); s.nameXSlider:SetHeight(18)
    s.nameXSlider:SetMinMaxValues(-150,150)
    if s.nameXSlider.SetValueStep then s.nameXSlider:SetValueStep(5) end
    local nameTrack=s.nameXSlider:CreateTexture(nil,"BACKGROUND")
    nameTrack:SetTexture(WHITE); nameTrack:SetVertexColor(0.22,0.18,0.10,1)
    nameTrack:SetPoint("LEFT",s.nameXSlider,"LEFT",0,0); nameTrack:SetPoint("RIGHT",s.nameXSlider,"RIGHT",0,0); nameTrack:SetHeight(5)
    local nameCenter=s.nameXSlider:CreateTexture(nil,"BORDER")
    nameCenter:SetTexture(WHITE); nameCenter:SetVertexColor(GOLD_DIM[1],GOLD_DIM[2],GOLD_DIM[3],1)
    nameCenter:SetPoint("CENTER",s.nameXSlider,"CENTER",0,0); nameCenter:SetWidth(2); nameCenter:SetHeight(11)
    local nameThumb=s.nameXSlider:CreateTexture(nil,"OVERLAY")
    nameThumb:SetTexture(WHITE); nameThumb:SetVertexColor(0.78,0.56,0.10,1)
    nameThumb:SetWidth(10); nameThumb:SetHeight(18); s.nameXSlider:SetThumbTexture(nameThumb)
    s.nameXSlider:SetScript("OnValueChanged",function()
        if s.nameXSuppress then return end
        SF:SetSpecialPlayerNameOffset(this:GetValue(),true)
    end)

    s.friendlyNameXLabel=MakeLabel(s,"Friendly name X",11,WHITE_TEXT); s.friendlyNameXLabel:SetPoint("TOPLEFT",s,"TOPLEFT",14,-153)
    s.friendlyNameXValue=MakeLabel(s,"0",11,GOLD); s.friendlyNameXValue:SetPoint("TOPLEFT",s,"TOPLEFT",116,-153); s.friendlyNameXValue:SetWidth(42); s.friendlyNameXValue:SetJustifyH("CENTER")
    s.friendlyNameXSlider=CreateFrame("Slider",nil,s)
    s.friendlyNameXSlider:SetOrientation("HORIZONTAL")
    s.friendlyNameXSlider:SetPoint("TOPLEFT",s,"TOPLEFT",166,-149)
    s.friendlyNameXSlider:SetWidth(318); s.friendlyNameXSlider:SetHeight(18)
    s.friendlyNameXSlider:SetMinMaxValues(-150,150)
    if s.friendlyNameXSlider.SetValueStep then s.friendlyNameXSlider:SetValueStep(5) end
    local friendlyTrack=s.friendlyNameXSlider:CreateTexture(nil,"BACKGROUND")
    friendlyTrack:SetTexture(WHITE); friendlyTrack:SetVertexColor(0.22,0.18,0.10,1)
    friendlyTrack:SetPoint("LEFT",s.friendlyNameXSlider,"LEFT",0,0); friendlyTrack:SetPoint("RIGHT",s.friendlyNameXSlider,"RIGHT",0,0); friendlyTrack:SetHeight(5)
    local friendlyCenter=s.friendlyNameXSlider:CreateTexture(nil,"BORDER")
    friendlyCenter:SetTexture(WHITE); friendlyCenter:SetVertexColor(GOLD_DIM[1],GOLD_DIM[2],GOLD_DIM[3],1)
    friendlyCenter:SetPoint("CENTER",s.friendlyNameXSlider,"CENTER",0,0); friendlyCenter:SetWidth(2); friendlyCenter:SetHeight(11)
    local friendlyThumb=s.friendlyNameXSlider:CreateTexture(nil,"OVERLAY")
    friendlyThumb:SetTexture(WHITE); friendlyThumb:SetVertexColor(0.78,0.56,0.10,1)
    friendlyThumb:SetWidth(10); friendlyThumb:SetHeight(18); s.friendlyNameXSlider:SetThumbTexture(friendlyThumb)
    s.friendlyNameXSlider:SetScript("OnValueChanged",function()
        if s.friendlyNameXSuppress then return end
        SF:SetTargetNameOffsetFriendly(this:GetValue(),true)
    end)

    s.normalNameXLabel=MakeLabel(s,"Enemy name X",11,WHITE_TEXT); s.normalNameXLabel:SetPoint("TOPLEFT",s,"TOPLEFT",14,-188)
    s.normalNameXValue=MakeLabel(s,"0",11,GOLD); s.normalNameXValue:SetPoint("TOPLEFT",s,"TOPLEFT",116,-188); s.normalNameXValue:SetWidth(42); s.normalNameXValue:SetJustifyH("CENTER")
    s.normalNameXSlider=CreateFrame("Slider",nil,s)
    s.normalNameXSlider:SetOrientation("HORIZONTAL")
    s.normalNameXSlider:SetPoint("TOPLEFT",s,"TOPLEFT",166,-184)
    s.normalNameXSlider:SetWidth(318); s.normalNameXSlider:SetHeight(18)
    s.normalNameXSlider:SetMinMaxValues(-150,150)
    if s.normalNameXSlider.SetValueStep then s.normalNameXSlider:SetValueStep(5) end
    local normalTrack=s.normalNameXSlider:CreateTexture(nil,"BACKGROUND")
    normalTrack:SetTexture(WHITE); normalTrack:SetVertexColor(0.22,0.18,0.10,1)
    normalTrack:SetPoint("LEFT",s.normalNameXSlider,"LEFT",0,0); normalTrack:SetPoint("RIGHT",s.normalNameXSlider,"RIGHT",0,0); normalTrack:SetHeight(5)
    local normalCenter=s.normalNameXSlider:CreateTexture(nil,"BORDER")
    normalCenter:SetTexture(WHITE); normalCenter:SetVertexColor(GOLD_DIM[1],GOLD_DIM[2],GOLD_DIM[3],1)
    normalCenter:SetPoint("CENTER",s.normalNameXSlider,"CENTER",0,0); normalCenter:SetWidth(2); normalCenter:SetHeight(11)
    local normalThumb=s.normalNameXSlider:CreateTexture(nil,"OVERLAY")
    normalThumb:SetTexture(WHITE); normalThumb:SetVertexColor(0.78,0.56,0.10,1)
    normalThumb:SetWidth(10); normalThumb:SetHeight(18); s.normalNameXSlider:SetThumbTexture(normalThumb)
    s.normalNameXSlider:SetScript("OnValueChanged",function()
        if s.normalNameXSuppress then return end
        SF:SetTargetNameOffsetNormal(this:GetValue(),true)
    end)

    s.specialNameXLabel=MakeLabel(s,"Rare / Elite name X",11,WHITE_TEXT); s.specialNameXLabel:SetPoint("TOPLEFT",s,"TOPLEFT",14,-223)
    s.specialNameXValue=MakeLabel(s,"0",11,GOLD); s.specialNameXValue:SetPoint("TOPLEFT",s,"TOPLEFT",116,-223); s.specialNameXValue:SetWidth(42); s.specialNameXValue:SetJustifyH("CENTER")
    s.specialNameXSlider=CreateFrame("Slider",nil,s)
    s.specialNameXSlider:SetOrientation("HORIZONTAL")
    s.specialNameXSlider:SetPoint("TOPLEFT",s,"TOPLEFT",166,-219)
    s.specialNameXSlider:SetWidth(318); s.specialNameXSlider:SetHeight(18)
    s.specialNameXSlider:SetMinMaxValues(-150,150)
    if s.specialNameXSlider.SetValueStep then s.specialNameXSlider:SetValueStep(5) end
    local specialTrack=s.specialNameXSlider:CreateTexture(nil,"BACKGROUND")
    specialTrack:SetTexture(WHITE); specialTrack:SetVertexColor(0.22,0.18,0.10,1)
    specialTrack:SetPoint("LEFT",s.specialNameXSlider,"LEFT",0,0); specialTrack:SetPoint("RIGHT",s.specialNameXSlider,"RIGHT",0,0); specialTrack:SetHeight(5)
    local specialCenter=s.specialNameXSlider:CreateTexture(nil,"BORDER")
    specialCenter:SetTexture(WHITE); specialCenter:SetVertexColor(GOLD_DIM[1],GOLD_DIM[2],GOLD_DIM[3],1)
    specialCenter:SetPoint("CENTER",s.specialNameXSlider,"CENTER",0,0); specialCenter:SetWidth(2); specialCenter:SetHeight(11)
    local specialThumb=s.specialNameXSlider:CreateTexture(nil,"OVERLAY")
    specialThumb:SetTexture(WHITE); specialThumb:SetVertexColor(0.78,0.56,0.10,1)
    specialThumb:SetWidth(10); specialThumb:SetHeight(18); s.specialNameXSlider:SetThumbTexture(specialThumb)
    s.specialNameXSlider:SetScript("OnValueChanged",function()
        if s.specialNameXSuppress then return end
        SF:SetTargetNameOffsetSpecial(this:GetValue(),true)
    end)

    s.hint1=MakeLabel(s,"Name X sliders: 0 = default; negative moves left, positive moves right.",10,MUTED); s.hint1:SetPoint("TOPLEFT",s,"TOPLEFT",14,-260)
    s.hint2=MakeLabel(s,"Friendly name X affects friendly targets; Enemy name X affects normal hostile targets.",9,MUTED); s.hint2:SetPoint("TOPLEFT",s,"TOPLEFT",14,-283)
    s.hint3=MakeLabel(s,"Rare / Elite name X also covers Boss targets. Player name X remains independent.",9,MUTED); s.hint3:SetPoint("TOPLEFT",s,"TOPLEFT",14,-304)
    s.hint4=MakeLabel(s,"Targets auto-select special art. Player art mirrors inward; theme follows Light/Dark.",9,MUTED); s.hint4:SetPoint("TOPLEFT",s,"TOPLEFT",14,-325)
end

function SF:RefreshSpecialPortraitSettings()
    EnsureDefaults()
    local f=self.settings
    local s=f and f.sfSpecialPortraitSection
    if not s then return end
    s.target:SetText("Target Special Frames: "..(SlamFramesDB.specialTargetFrames and "ON" or "OFF"))
    s.player:SetText("Player Special Frame: "..(SlamFramesDB.specialPlayerFrameEnabled and "ON" or "OFF"))
    local rareSelected=SlamFramesDB.specialPlayerFrameStyle=="rareelite"
    s.rare:SetText((rareSelected and "[x] " or "").."Rare / Elite")
    s.boss:SetText((not rareSelected and "[x] " or "").."Boss")
    if s.nameXSlider then
        local v=tonumber(SlamFramesDB.specialPlayerNameOffset) or 0
        s.nameXSuppress=true
        s.nameXSlider:SetValue(v)
        s.nameXSuppress=nil
        if s.nameXValue then s.nameXValue:SetText((v>0 and "+" or "")..tostring(v)) end
    end
    if s.friendlyNameXSlider then
        local v=tonumber(SlamFramesDB.targetNameOffsetFriendly) or 0
        s.friendlyNameXSuppress=true
        s.friendlyNameXSlider:SetValue(v)
        s.friendlyNameXSuppress=nil
        if s.friendlyNameXValue then s.friendlyNameXValue:SetText((v>0 and "+" or "")..tostring(v)) end
    end
    if s.normalNameXSlider then
        local v=tonumber(SlamFramesDB.targetNameOffsetNormal) or 0
        s.normalNameXSuppress=true
        s.normalNameXSlider:SetValue(v)
        s.normalNameXSuppress=nil
        if s.normalNameXValue then s.normalNameXValue:SetText((v>0 and "+" or "")..tostring(v)) end
    end
    if s.specialNameXSlider then
        local v=tonumber(SlamFramesDB.targetNameOffsetSpecial) or 0
        s.specialNameXSuppress=true
        s.specialNameXSlider:SetValue(v)
        s.specialNameXSuppress=nil
        if s.specialNameXValue then s.specialNameXValue:SetText((v>0 and "+" or "")..tostring(v)) end
    end
end

local OldCreateSettingsPanel=SF.CreateSettingsPanel
if OldCreateSettingsPanel then
    function SF:CreateSettingsPanel()
        OldCreateSettingsPanel(self)
        self:CreateSpecialPortraitSettings()
        self:RefreshSpecialPortraitSettings()
    end
end

local OldRefreshSettings=SF.RefreshSettings
if OldRefreshSettings then
    function SF:RefreshSettings()
        OldRefreshSettings(self)
        self:CreateSpecialPortraitSettings()
        self:RefreshSpecialPortraitSettings()
    end
end

-- Optional slash shortcuts. Settings remain the primary control surface.
local OldHandleSlash=SF.HandleSlash
if OldHandleSlash then
    function SF:HandleSlash(msg)
        msg=msg or ""
        local cmd,rest=string.match(msg,"^(%S+)%s*(.-)$")
        cmd=string.lower(cmd or "")
        rest=string.lower(rest or "")
        if cmd=="specialtarget" then
            if rest=="on" then self:SetSpecialTargetFrames(true,false)
            elseif rest=="off" then self:SetSpecialTargetFrames(false,false)
            else if self.Print then self.Print("usage: /sf specialtarget on | off") end end
            return
        elseif cmd=="specialplayer" then
            if rest=="on" then self:SetSpecialPlayerFrameEnabled(true,false)
            elseif rest=="off" then self:SetSpecialPlayerFrameEnabled(false,false)
            else if self.Print then self.Print("usage: /sf specialplayer on | off") end end
            return
        elseif cmd=="specialstyle" then
            if rest=="rare" or rest=="elite" or rest=="rareelite" or rest=="rare-elite" then self:SetSpecialPlayerFrameStyle("rareelite",false)
            elseif rest=="boss" then self:SetSpecialPlayerFrameStyle("boss",false)
            else if self.Print then self.Print("usage: /sf specialstyle rare | boss") end end
            return
        elseif cmd=="specialnamex" then
            local v=tonumber(rest)
            if v then self:SetSpecialPlayerNameOffset(v,false)
            else if self.Print then self.Print("usage: /sf specialnamex -150 .. 150") end end
            return
        elseif cmd=="friendlynamex" then
            local v=tonumber(rest)
            if v then self:SetTargetNameOffsetFriendly(v,false)
            else if self.Print then self.Print("usage: /sf friendlynamex -150 .. 150") end end
            return
        elseif cmd=="enemynamex" then
            local v=tonumber(rest)
            if v then self:SetTargetNameOffsetNormal(v,false)
            else if self.Print then self.Print("usage: /sf enemynamex -150 .. 150") end end
            return
        elseif cmd=="rareelitenamex" then
            local v=tonumber(rest)
            if v then self:SetTargetNameOffsetSpecial(v,false)
            else if self.Print then self.Print("usage: /sf rareelitenamex -150 .. 150") end end
            return
        end
        OldHandleSlash(self,msg)
    end
end

-- Make the new defaults/state available immediately after loading.
EnsureDefaults()
if SF.player or SF.target then SF:UpdateSpecialPortraitFrames() end
