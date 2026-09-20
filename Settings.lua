-- SlamFrames v3.0.0 - stable release settings UI.
-- OctoWoW / 1.12-era compatible: intentionally uses this/arg1 in handlers.

local SF=SlamFrames
local C=SlamFrames_Config
local TEX=C.texturePath
local WHITE="Interface\\Buttons\\WHITE8X8"
local FONT="Fonts\\FRIZQT__.TTF"

local GOLD={1.00,0.82,0.00}
local GOLD_DIM={0.65,0.48,0.08}
local WHITE_TEXT={0.92,0.92,0.92}
local MUTED={0.66,0.66,0.66}

local function RaidCall(method,value)
    local fn=SF and SF[method]
    if fn then
        fn(SF,value,true)
        return true
    end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff3333SlamFrames: raid API unavailable ("..tostring(method)..").|r")
    end
    return false
end

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

local function TintButton(b, selected)
    if not b then return end
    -- Shared UI polish: keep every settings button in the same vivid red
    -- family. Selected buttons are only slightly brighter so state remains
    -- readable without the old brown/dull-red mismatch between sections.
    local normal=b.GetNormalTexture and b:GetNormalTexture() or nil
    local pushed=b.GetPushedTexture and b:GetPushedTexture() or nil
    local disabled=b.GetDisabledTexture and b:GetDisabledTexture() or nil
    local highlight=b.GetHighlightTexture and b:GetHighlightTexture() or nil
    if normal and normal.SetVertexColor then
        if selected then normal:SetVertexColor(0.82,0.15,0.08) else normal:SetVertexColor(0.72,0.12,0.07) end
    end
    if pushed and pushed.SetVertexColor then pushed:SetVertexColor(0.60,0.08,0.05) end
    if disabled and disabled.SetVertexColor then
        if selected then disabled:SetVertexColor(0.82,0.15,0.08) else disabled:SetVertexColor(0.62,0.10,0.06) end
    end
    if highlight and highlight.SetVertexColor then highlight:SetVertexColor(1.00,0.22,0.10) end
    local fs=b.GetFontString and b:GetFontString() or nil
    if fs then fs:SetTextColor(1.00,0.82,0.00) end
end

local function MakeButton(parent,text,w,h)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetWidth(w or 90); b:SetHeight(h or 22); b:SetText(text or "")
    TintButton(b,false)
    return b
end

local function MakeEditBox(parent,w,h)
    local e=CreateFrame("EditBox",nil,parent)
    e:SetWidth(w or 180); e:SetHeight(h or 22)
    e:SetAutoFocus(false)
    e:SetFont(FONT,11,"")
    e:SetTextColor(1.00,1.00,1.00)
    e:SetMaxLetters(80)
    if e.SetTextInsets then e:SetTextInsets(7,7,0,0) end
    if e.SetHighlightColor then e:SetHighlightColor(0.72,0.48,0.08,0.55) end

    -- Do not use InputBoxTemplate here. On the 1.12 client its left/middle/right
    -- texture slices can render inconsistently at custom widths, which produced
    -- dark text in one field and only bracket-like end caps in the others.
    local bg=e:CreateTexture(nil,"BACKGROUND")
    bg:SetTexture(WHITE); bg:SetAllPoints(e); bg:SetVertexColor(0.025,0.025,0.025,0.94)
    e.sfBG=bg
    local function Border(point1,point2,wid,hei)
        local t=e:CreateTexture(nil,"BORDER")
        t:SetTexture(WHITE); t:SetVertexColor(0.38,0.38,0.38,1)
        t:SetPoint(point1,e,point1,0,0)
        if point2 then t:SetPoint(point2,e,point2,0,0) end
        if wid then t:SetWidth(wid) end
        if hei then t:SetHeight(hei) end
        return t
    end
    e.sfTop=Border("TOPLEFT","TOPRIGHT",nil,1)
    e.sfBottom=Border("BOTTOMLEFT","BOTTOMRIGHT",nil,1)
    e.sfLeft=Border("TOPLEFT","BOTTOMLEFT",1,nil)
    e.sfRight=Border("TOPRIGHT","BOTTOMRIGHT",1,nil)
    e:SetScript("OnEscapePressed",function() this:ClearFocus() end)
    return e
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
    box.bg=bg

    local left=box:CreateTexture(nil,"BORDER"); left:SetTexture(WHITE); left:SetVertexColor(0.24,0.20,0.12,1); left:SetPoint("TOPLEFT",box,"TOPLEFT",0,0); left:SetWidth(1); left:SetHeight(h)
    local right=box:CreateTexture(nil,"BORDER"); right:SetTexture(WHITE); right:SetVertexColor(0.24,0.20,0.12,1); right:SetPoint("TOPRIGHT",box,"TOPRIGHT",0,0); right:SetWidth(1); right:SetHeight(h)
    local top=box:CreateTexture(nil,"BORDER"); top:SetTexture(WHITE); top:SetVertexColor(0.55,0.42,0.12,1); top:SetPoint("TOPLEFT",box,"TOPLEFT",0,0); top:SetWidth(w); top:SetHeight(1)
    local bottom=box:CreateTexture(nil,"BORDER"); bottom:SetTexture(WHITE); bottom:SetVertexColor(0.24,0.20,0.12,1); bottom:SetPoint("BOTTOMLEFT",box,"BOTTOMLEFT",0,0); bottom:SetWidth(w); bottom:SetHeight(1)

    box.title=MakeLabel(box,title,13,GOLD)
    box.title:SetPoint("TOPLEFT",box,"TOPLEFT",12,-9)
    MakeLine(box,12,-29,w-24)
    return box
end

local function AddScaleRow(parent,labelText,y,getValue,setter,step)
    local row={}
    row.label=MakeLabel(parent,labelText,11,WHITE_TEXT)
    row.label:SetPoint("TOPLEFT",parent,"TOPLEFT",14,y)
    row.value=MakeLabel(parent,"1.00",11,GOLD)
    row.value:SetPoint("TOPLEFT",parent,"TOPLEFT",114,y)
    row.value:SetWidth(44); row.value:SetJustifyH("CENTER")
    row.minus=MakeButton(parent,"-",30,21); row.minus:SetPoint("TOPLEFT",parent,"TOPLEFT",166,y+4)
    row.minus:SetScript("OnClick",function() setter(getValue()-(step or .05),true) end)
    row.plus=MakeButton(parent,"+",30,21); row.plus:SetPoint("TOPLEFT",parent,"TOPLEFT",204,y+4)
    row.plus:SetScript("OnClick",function() setter(getValue()+(step or .05),true) end)
    row.getValue=getValue
    return row
end

local function AddWidthRow(parent,labelText,y,key)
    local row={key=key}
    row.label=MakeLabel(parent,labelText,11,WHITE_TEXT)
    row.label:SetPoint("TOPLEFT",parent,"TOPLEFT",14,y)
    row.value=MakeLabel(parent,"100%",11,GOLD)
    row.value:SetPoint("TOPLEFT",parent,"TOPLEFT",114,y)
    row.value:SetWidth(44); row.value:SetJustifyH("CENTER")
    row.minus=MakeButton(parent,"-",30,21); row.minus:SetPoint("TOPLEFT",parent,"TOPLEFT",166,y+4)
    -- Minus visually shortens the bar; Plus lengthens it.
    row.minus:SetScript("OnClick",function() SF:SetWidthPreset(key,(SlamFramesDB.widthPresets[key] or 0)+1,true) end)
    row.plus=MakeButton(parent,"+",30,21); row.plus:SetPoint("TOPLEFT",parent,"TOPLEFT",204,y+4)
    row.plus:SetScript("OnClick",function() SF:SetWidthPreset(key,(SlamFramesDB.widthPresets[key] or 0)-1,true) end)
    return row
end

local function Atan2(y,x)
    if math.atan2 then return math.atan2(y,x) end
    if x>0 then return math.atan(y/x) end
    if x<0 and y>=0 then return math.atan(y/x)+math.pi end
    if x<0 and y<0 then return math.atan(y/x)-math.pi end
    if x==0 and y>0 then return math.pi/2 end
    if x==0 and y<0 then return -math.pi/2 end
    return 0
end

function SF:UpdateMinimapButtonPosition()
    local b=self.minimapButton
    if not b or not Minimap then return end
    local a=(SlamFramesDB and SlamFramesDB.minimapAngle) or -0.4897411260673095
    local r=(SlamFramesDB and SlamFramesDB.minimapRadius) or 80
    b:ClearAllPoints()
    b:SetPoint("CENTER",Minimap,"CENTER",math.cos(a)*r,math.sin(a)*r)
end

function SF:SetMinimapButtonShown(v)
    SlamFramesDB.showMinimapButton=v and true or false
    if self.minimapButton then
        if SlamFramesDB.showMinimapButton then self.minimapButton:Show() else self.minimapButton:Hide() end
    end
    if self.RefreshSettings then self:RefreshSettings() end
end

function SF:ResetMinimapButtonPosition()
    SlamFramesDB.minimapAngle=-0.4897411260673095
    SlamFramesDB.minimapRadius=80
    self:UpdateMinimapButtonPosition()
    if self.RefreshSettings then self:RefreshSettings() end
end

function SF:UpdateMinimapButtonIcon()
    local b=self.minimapButton
    if not b or not b.icon then return end
    -- The launcher keeps the exact classic minimap-button shell used by
    -- SlamPlates Advanced, but the center art is SlamFrames-specific: the
    -- player's live portrait. This also makes the project recognizable at a
    -- glance without changing the outer button aesthetic.
    if type(SetPortraitTexture)=="function" then
        local ok=pcall(SetPortraitTexture,b.icon,"player")
        if ok then return end
    end
    b.icon:SetTexture("Interface\\Icons\\Spell_Holy_PowerWordShield")
end

function SF:CreateMinimapButton()
    if self.minimapButton or not Minimap then return end

    -- Match SlamPlates Advanced / classic Vanilla addon-button construction:
    -- 31x31 button, 20x20 center icon, Blizzard tracking border and native
    -- minimap zoom highlight. Only the middle image differs.
    local b=CreateFrame("Button","SlamFramesMinimapButton",Minimap)
    b:SetWidth(31); b:SetHeight(31)
    b:SetFrameStrata("LOW")
    if b.SetToplevel then b:SetToplevel(1) end
    b:RegisterForClicks("LeftButtonUp","RightButtonUp")
    b:RegisterForDrag("LeftButton")
    if b.SetHighlightTexture then b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight") end

    b.icon=b:CreateTexture("SlamFramesMinimapButtonIcon","BACKGROUND")
    b.icon:SetWidth(20); b.icon:SetHeight(20)
    b.icon:SetPoint("TOPLEFT",b,"TOPLEFT",7,-5)
    b.icon:SetTexCoord(0.08,0.92,0.08,0.92)

    b.overlay=b:CreateTexture("SlamFramesMinimapButtonOverlay","OVERLAY")
    b.overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b.overlay:SetWidth(53); b.overlay:SetHeight(53)
    b.overlay:SetPoint("TOPLEFT",b,"TOPLEFT",0,0)

    self.minimapButton=b
    self:UpdateMinimapButtonIcon()

    b:SetScript("OnEnter",function()
        GameTooltip:SetOwner(this,"ANCHOR_LEFT")
        GameTooltip:SetText("SlamFrames",1,0.82,0)
        GameTooltip:AddLine("Left-click: Open settings",1,1,1)
        GameTooltip:AddLine("Right-click: Lock / unlock frames",0.85,0.85,0.85)
        GameTooltip:AddLine("Drag: Move around minimap",0.85,0.85,0.85)
        GameTooltip:AddLine("/sf minimap off  |  /sf minimap on",0.65,0.65,0.65)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)

    b:SetScript("OnClick",function()
        if this.suppressClickUntil and GetTime()<this.suppressClickUntil then return end
        if arg1=="RightButton" then SF:SetLocked(not SlamFramesDB.locked)
        else SF:ToggleSettings() end
    end)

    b:SetScript("OnDragStart",function()
        this.sfDragging=true
        this:SetScript("OnUpdate",function()
            if not this.sfDragging then return end
            local cx,cy=Minimap:GetCenter()
            local x,y=GetCursorPosition()
            local uiScale=UIParent:GetScale()
            if not uiScale or uiScale==0 then uiScale=1 end
            x=x/uiScale; y=y/uiScale
            local a=Atan2(y-cy,x-cx)
            SlamFramesDB.minimapAngle=a
            SF:UpdateMinimapButtonPosition()
        end)
    end)
    b:SetScript("OnDragStop",function()
        this.sfDragging=nil
        this.suppressClickUntil=GetTime()+0.15
        this:SetScript("OnUpdate",nil)
    end)

    self:UpdateMinimapButtonPosition()
    if SlamFramesDB.showMinimapButton then b:Show() else b:Hide() end
end

local function ShowPage(panel,key)
    if not panel or not panel.pages then return end
    local k,page,scroll,slider
    for k,page in pairs(panel.pages) do
        scroll=panel.pageScrolls and panel.pageScrolls[k]
        slider=panel.pageSliders and panel.pageSliders[k]
        if k==key then
            page:Show()
            if scroll then scroll:Show() end
            if slider and slider.sfMaxScroll and slider.sfMaxScroll>0 then slider:Show() end
        else
            page:Hide()
            if scroll then scroll:Hide() end
            if slider then slider:Hide() end
        end
    end
    panel.activeTab=key
    if panel.tabs then
        local i,t
        for i=1,table.getn(panel.tabs) do
            t=panel.tabs[i]
            if t.pageKey==key then t:Disable(); TintButton(t,true) else t:Enable(); TintButton(t,false) end
        end
    end
end

function SF:CreateSettingsPanel()
    if self.settings then return end

    local f=CreateFrame("Frame","SlamFramesSettings",UIParent)
    f:SetWidth(540); f:SetHeight(740); f:SetPoint("CENTER",UIParent,"CENTER",0,0)
    f:SetFrameStrata("DIALOG"); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function() this:StartMoving() end)
    f:SetScript("OnDragStop",function() this:StopMovingOrSizing() end)
    if f.SetBackdrop then
        f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
    end

    -- Slim gold inner border gives the dark SlamPlates-style settings shell a
    -- SlamFrames identity while retaining the same high-contrast layout.
    local borderTop=f:CreateTexture(nil,"BORDER"); borderTop:SetTexture(WHITE); borderTop:SetVertexColor(0.78,0.56,0.10,0.9); borderTop:SetPoint("TOPLEFT",f,"TOPLEFT",10,-10); borderTop:SetWidth(520); borderTop:SetHeight(1)
    local borderBottom=f:CreateTexture(nil,"BORDER"); borderBottom:SetTexture(WHITE); borderBottom:SetVertexColor(0.78,0.56,0.10,0.9); borderBottom:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",10,10); borderBottom:SetWidth(520); borderBottom:SetHeight(1)

    f:Hide(); self.settings=f

    local title=MakeLabel(f,"SlamFrames",20,GOLD); title:SetPoint("TOPLEFT",f,"TOPLEFT",24,-20)
    local subtitle=MakeLabel(f,"UNIT FRAMES",12,WHITE_TEXT); subtitle:SetPoint("LEFT",title,"RIGHT",14,0)
    local version=MakeLabel(f,"v"..(C.version or ""),10,MUTED); version:SetPoint("TOPLEFT",title,"BOTTOMLEFT",2,-2)
    local close=MakeButton(f,"X",30,25); close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-20,-18); close:SetScript("OnClick",function() f:Hide() end)

    f.tabs={}
    local tabData={{"General","general"},{"Layout","layout"},{"Party","party"},{"Raid","raid"},{"Click Cast","clickcast"},{"Effects","effects"},{"Cast Bar","castbar"}}
    local i
    for i=1,table.getn(tabData) do
        local t=MakeButton(f,tabData[i][1],78,28)
        t.pageKey=tabData[i][2]
        t:SetWidth(68); t:SetPoint("TOPLEFT",f,"TOPLEFT",24+(i-1)*70,-64)
        t:SetScript("OnClick",function() ShowPage(f,this.pageKey) end)
        f.tabs[i]=t
    end

    -- Scrollable tab viewport. The footer stays fixed, so long pages can grow
    -- without covering Reset All / Test Frames / Close. Only tabs whose
    -- content exceeds the viewport show a scrollbar; mouse wheel works too.
    f.pages={}
    f.pageScrolls={}
    f.pageSliders={}
    local pageKeys={"general","layout","party","raid","clickcast","effects","castbar"}
    local pageHeights={general=548,layout=672,party=548,raid=950,clickcast=836,effects=548,castbar=650}
    local viewportHeight=548
    for i=1,table.getn(pageKeys) do
        local key=pageKeys[i]
        local scroll=CreateFrame("ScrollFrame",nil,f)
        scroll:SetPoint("TOPLEFT",f,"TOPLEFT",18,-104)
        scroll:SetWidth(504); scroll:SetHeight(viewportHeight)
        scroll:Hide()

        local p=CreateFrame("Frame",nil,scroll)
        p:SetWidth(504); p:SetHeight(pageHeights[key] or viewportHeight)
        scroll:SetScrollChild(p)
        p:Hide()

        local maxScroll=math.max(0,(pageHeights[key] or viewportHeight)-viewportHeight)
        local slider=CreateFrame("Slider",nil,f)
        slider:SetOrientation("VERTICAL")
        slider:SetPoint("TOPLEFT",scroll,"TOPRIGHT",5,-4)
        slider:SetWidth(10); slider:SetHeight(viewportHeight-8)
        slider:SetMinMaxValues(0,maxScroll)
        if slider.SetValueStep then slider:SetValueStep(20) end
        -- Vertical sliders place their maximum at the top. Invert the value
        -- so the thumb behaves like a normal scrollbar: top = page top.
        slider:SetValue(maxScroll)
        slider.sfMaxScroll=maxScroll
        slider.sfScroll=scroll

        local track=slider:CreateTexture(nil,"BACKGROUND")
        track:SetTexture(WHITE); track:SetVertexColor(0.18,0.16,0.12,0.85)
        track:SetPoint("TOP",slider,"TOP",0,0); track:SetPoint("BOTTOM",slider,"BOTTOM",0,0); track:SetWidth(3)
        local thumb=slider:CreateTexture(nil,"OVERLAY")
        thumb:SetTexture(WHITE); thumb:SetVertexColor(0.78,0.56,0.10,0.95)
        thumb:SetWidth(8); thumb:SetHeight(34)
        slider:SetThumbTexture(thumb)
        slider:SetScript("OnValueChanged",function()
            if this.sfScroll then
                this.sfScroll:SetVerticalScroll((this.sfMaxScroll or 0)-this:GetValue())
            end
        end)
        slider:Hide()

        if scroll.EnableMouseWheel then
            scroll:EnableMouseWheel(maxScroll>0)
            scroll.sfSlider=slider
            scroll:SetScript("OnMouseWheel",function()
                local s=this.sfSlider
                if not s or not s.sfMaxScroll or s.sfMaxScroll<=0 then return end
                local delta=arg1 or 0
                local offset=s.sfMaxScroll-s:GetValue()
                offset=offset-(delta*42)
                if offset<0 then offset=0 elseif offset>s.sfMaxScroll then offset=s.sfMaxScroll end
                s:SetValue(s.sfMaxScroll-offset)
            end)
        end

        f.pages[key]=p
        f.pageScrolls[key]=scroll
        f.pageSliders[key]=slider
    end

    -- GENERAL ---------------------------------------------------------------
    local g=f.pages.general
    local display=MakeSection(g,"Display",0,0,504,246)
    local hl=MakeLabel(display,"Player / Target health",11,WHITE_TEXT); hl:SetPoint("TOPLEFT",display,"TOPLEFT",14,-43)
    display.healthButtons={}
    local modes={{"%","percent"},{"Amount","amount"},{"Both","both"},{"Off","off"}}
    local x=150
    for i=1,table.getn(modes) do
        local b=MakeButton(display,modes[i][1],72,22); b.mode=modes[i][2]; b:SetPoint("TOPLEFT",display,"TOPLEFT",x,-39)
        b:SetScript("OnClick",function() SF:SetHealthTextMode(this.mode,true); SF:RefreshSettings() end)
        display.healthButtons[i]=b; x=x+80
    end

    local thl=MakeLabel(display,"Target of Target health",11,WHITE_TEXT); thl:SetPoint("TOPLEFT",display,"TOPLEFT",14,-78)
    display.totHealthButtons={}
    local tmodes={{"%","percent"},{"Amount","amount"}}
    x=150
    for i=1,table.getn(tmodes) do
        local b=MakeButton(display,tmodes[i][1],96,22); b.mode=tmodes[i][2]; b:SetPoint("TOPLEFT",display,"TOPLEFT",x,-74)
        b:SetScript("OnClick",function() SF:SetToTHealthTextMode(this.mode,true); SF:RefreshSettings() end)
        display.totHealthButtons[i]=b; x=x+106
    end

    display.power=MakeButton(display,"",205,24); display.power:SetPoint("TOPLEFT",display,"TOPLEFT",14,-116)
    display.power:SetScript("OnClick",function() SlamFramesDB.showPowerNumbers=not SlamFramesDB.showPowerNumbers; SF:RefreshAll(); SF:RefreshSettings() end)
    display.auras=MakeButton(display,"",205,24); display.auras:SetPoint("TOPRIGHT",display,"TOPRIGHT",-14,-116)
    display.auras:SetScript("OnClick",function() SlamFramesDB.showAuras=not SlamFramesDB.showAuras; SF:UpdateAuras(); SF:RefreshSettings() end)
    local hint=MakeLabel(display,"ToT health format is independent. Text sizes remain under Layout.",10,MUTED); hint:SetPoint("TOPLEFT",display,"TOPLEFT",14,-150)
    display.skinLabel=MakeLabel(display,"Skin",11,WHITE_TEXT); display.skinLabel:SetPoint("TOPLEFT",display,"TOPLEFT",14,-178)
    display.skinButtons={}
    display.skinButtons[1]=MakeButton(display,"Light",96,22); display.skinButtons[1].skin="light"; display.skinButtons[1]:SetPoint("TOPLEFT",display,"TOPLEFT",150,-174); display.skinButtons[1]:SetScript("OnClick",function() SF:SetSkin(this.skin,true); SF:RefreshSettings() end)
    display.skinButtons[2]=MakeButton(display,"Dark",96,22); display.skinButtons[2].skin="dark"; display.skinButtons[2]:SetPoint("LEFT",display.skinButtons[1],"RIGHT",10,0); display.skinButtons[2]:SetScript("OnClick",function() SF:SetSkin(this.skin,true); SF:RefreshSettings() end)
    display.resolutionLabel=MakeLabel(display,"Art resolution",11,WHITE_TEXT); display.resolutionLabel:SetPoint("TOPLEFT",display,"TOPLEFT",14,-210)
    display.resolutionButtons={}
    display.resolutionButtons[1]=MakeButton(display,"4K",96,22); display.resolutionButtons[1].res="4k"; display.resolutionButtons[1]:SetPoint("TOPLEFT",display,"TOPLEFT",150,-206); display.resolutionButtons[1]:SetScript("OnClick",function() SF:SetArtResolution(this.res,true); if SF.PromptArtResolutionReload then SF:PromptArtResolutionReload(this.res) end; SF:RefreshSettings() end)
    display.resolutionButtons[2]=MakeButton(display,"1080",96,22); display.resolutionButtons[2].res="1080"; display.resolutionButtons[2]:SetPoint("LEFT",display.resolutionButtons[1],"RIGHT",10,0); display.resolutionButtons[2]:SetScript("OnClick",function() SF:SetArtResolution(this.res,true); if SF.PromptArtResolutionReload then SF:PromptArtResolutionReload(this.res) end; SF:RefreshSettings() end)

    local interaction=MakeSection(g,"Interaction",0,-258,504,158)
    interaction.lock=MakeButton(interaction,"",205,24); interaction.lock:SetPoint("TOPLEFT",interaction,"TOPLEFT",14,-43); interaction.lock:SetScript("OnClick",function() SF:SetLocked(not SlamFramesDB.locked) end)
    interaction.smooth=MakeButton(interaction,"",205,24); interaction.smooth:SetPoint("TOPRIGHT",interaction,"TOPRIGHT",-14,-43); interaction.smooth:SetScript("OnClick",function() SF:SetSmoothBars(not SlamFramesDB.smoothBars) end)
    interaction.selfTarget=MakeButton(interaction,"",205,24); interaction.selfTarget:SetPoint("TOPLEFT",interaction,"TOPLEFT",14,-78); interaction.selfTarget:SetScript("OnClick",function() SF:SetSelfTargetOnClick(not SlamFramesDB.selfTargetOnClick,true) end)
    local ih=MakeLabel(interaction,"When ON, left-click Player while locked selects yourself and hides redundant ToT.",10,MUTED); ih:SetPoint("TOPLEFT",interaction,"TOPLEFT",14,-113)
    local ih2=MakeLabel(interaction,"Right-click unit frames still opens the normal WoW unit menu.",9,MUTED); ih2:SetPoint("TOPLEFT",interaction,"TOPLEFT",14,-133)

    local minimap=MakeSection(g,"Minimap launcher",0,-428,504,154)
    minimap.toggle=MakeButton(minimap,"",205,24); minimap.toggle:SetPoint("TOPLEFT",minimap,"TOPLEFT",14,-43); minimap.toggle:SetScript("OnClick",function() SF:SetMinimapButtonShown(not SlamFramesDB.showMinimapButton) end)
    minimap.reset=MakeButton(minimap,"Reset Icon Position",205,24); minimap.reset:SetPoint("TOPRIGHT",minimap,"TOPRIGHT",-14,-43); minimap.reset:SetScript("OnClick",function() SF:ResetMinimapButtonPosition() end)
    local mh1=MakeLabel(minimap,"Left-click icon: settings    Right-click: lock/unlock    Drag: reposition",10,WHITE_TEXT); mh1:SetPoint("TOPLEFT",minimap,"TOPLEFT",14,-82)
    local mh2=MakeLabel(minimap,"Classic SlamPlates Advanced shell; center uses your live player portrait.",10,MUTED); mh2:SetPoint("TOPLEFT",minimap,"TOPLEFT",14,-104)
    local mh3=MakeLabel(minimap,"If hidden, restore it with  /sf minimap on",9,MUTED); mh3:SetPoint("TOPLEFT",minimap,"TOPLEFT",14,-126)

    -- LAYOUT ----------------------------------------------------------------
    local l=f.pages.layout
    local frameScale=MakeSection(l,"Frame scale",0,0,246,154)
    f.scaleRows={}
    local keys={"player","target","tot"}
    local labels={"Player","Target","Target of Target"}
    for i=1,3 do
        local key=keys[i]
        f.scaleRows[i]=AddScaleRow(frameScale,labels[i],-43-(i-1)*33,function() return SlamFramesDB.scales[key] or .60 end,function(v,q) SF:SetFrameScale(key,v,q) end,.05)
    end

    local barLength=MakeSection(l,"Bar length",258,0,246,154)
    f.playerWidthRow=AddWidthRow(barLength,"Player",-43,"player")
    f.targetWidthRow=AddWidthRow(barLength,"Target",-76,"target")
    f.totWidthRow=AddWidthRow(barLength,"Target of Target",-109,"tot")

    local zoomSection=MakeSection(l,"Portrait zoom",0,-166,504,132)
    f.portraitZoomRows={}
    local zkeys={"player","target","tot"}
    local zlabels={"Player","Target","Target of Target"}
    local zx={14,174,334}
    for i=1,3 do
        local key=zkeys[i]
        local cell=CreateFrame("Frame",nil,zoomSection)
        cell:SetPoint("TOPLEFT",zoomSection,"TOPLEFT",zx[i],-38); cell:SetWidth(150); cell:SetHeight(80)
        local label=MakeLabel(cell,zlabels[i],10,WHITE_TEXT); label:SetPoint("TOPLEFT",cell,"TOPLEFT",0,0)
        local value=MakeLabel(cell,"1.00",10,GOLD); value:SetPoint("TOPRIGHT",cell,"TOPRIGHT",0,0); value:SetWidth(38); value:SetJustifyH("RIGHT")
        local slider=CreateFrame("Slider",nil,cell)
        slider:SetOrientation("HORIZONTAL"); slider:SetPoint("TOPLEFT",cell,"TOPLEFT",0,-26); slider:SetWidth(145); slider:SetHeight(18)
        slider:SetMinMaxValues(1.00,1.50); if slider.SetValueStep then slider:SetValueStep(.01) end
        local track=slider:CreateTexture(nil,"BACKGROUND"); track:SetTexture(WHITE); track:SetVertexColor(0.22,0.18,0.10,1); track:SetPoint("LEFT",slider,"LEFT",0,0); track:SetPoint("RIGHT",slider,"RIGHT",0,0); track:SetHeight(5)
        local fill=slider:CreateTexture(nil,"BORDER"); fill:SetTexture(WHITE); fill:SetVertexColor(0.78,0.56,0.06,1); fill:SetPoint("LEFT",slider,"LEFT",0,0); fill:SetHeight(3)
        local thumb=slider:CreateTexture(nil,"OVERLAY"); thumb:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(C.levelBadgeTexture or "level_badge.tga")) or (TEX..(C.levelBadgeTexture or "level_badge.tga"))); thumb:SetWidth(18); thumb:SetHeight(18); slider:SetThumbTexture(thumb)
        local row={key=key,label=label,value=value,slider=slider,fill=fill}
        slider:SetScript("OnValueChanged",function()
            if row.suppress then return end
            local v=this:GetValue()
            SF:SetPortraitZoom(row.key,v,true)
            row.value:SetText(string.format("%.2f",v))
            row.fill:SetWidth(math.max(1,this:GetWidth()*((v-1.00)/0.50)))
        end)
        f.portraitZoomRows[i]=row
    end
    local zh=MakeLabel(zoomSection,"1.00 = full portrait     1.50 = maximum crop / zoom",9,MUTED); zh:SetPoint("BOTTOMLEFT",zoomSection,"BOTTOMLEFT",14,9)

    local textSection=MakeSection(l,"Text size",0,-310,246,224)
    f.nameScaleRow=AddScaleRow(textSection,"Name",-43,function() return SlamFramesDB.nameTextScale or 1.30 end,function(v,q) SF:SetNameTextScale(v,q) end,.05)
    f.healthScaleRow=AddScaleRow(textSection,"Health",-76,function() return SlamFramesDB.healthTextScale or 1.00 end,function(v,q) SF:SetHealthTextScale(v,q) end,.05)
    f.powerScaleRow=AddScaleRow(textSection,"Resource",-109,function() return SlamFramesDB.powerTextScale or 1.00 end,function(v,q) SF:SetPowerTextScale(v,q) end,.05)
    f.levelScaleRow=AddScaleRow(textSection,"Level",-142,function() return SlamFramesDB.levelTextScale or 1.00 end,function(v,q) SF:SetLevelTextScale(v,q) end,.05)
    local th=MakeLabel(textSection,"Each category scales independently.",10,MUTED); th:SetPoint("TOPLEFT",textSection,"TOPLEFT",14,-184)

    local auraSection=MakeSection(l,"Target aura icons",258,-310,246,252)
    f.auraScaleRow=AddScaleRow(auraSection,"Icon size",-43,function() return SlamFramesDB.auraScale or 1.00 end,function(v,q) SF:SetAuraScale(v,q) end,.10)

    auraSection.rowGapLabel=MakeLabel(auraSection,"Row spacing",10,WHITE_TEXT); auraSection.rowGapLabel:SetPoint("TOPLEFT",auraSection,"TOPLEFT",14,-82)
    auraSection.rowGapValue=MakeLabel(auraSection,"2.0",10,GOLD); auraSection.rowGapValue:SetPoint("TOPRIGHT",auraSection,"TOPRIGHT",-14,-82); auraSection.rowGapValue:SetWidth(42); auraSection.rowGapValue:SetJustifyH("RIGHT")
    auraSection.rowGapSlider=CreateFrame("Slider",nil,auraSection)
    auraSection.rowGapSlider:SetOrientation("HORIZONTAL"); auraSection.rowGapSlider:SetPoint("TOPLEFT",auraSection,"TOPLEFT",14,-103); auraSection.rowGapSlider:SetWidth(216); auraSection.rowGapSlider:SetHeight(16)
    auraSection.rowGapSlider:SetMinMaxValues(0.00,12.00); if auraSection.rowGapSlider.SetValueStep then auraSection.rowGapSlider:SetValueStep(.50) end
    auraSection.rowGapTrack=auraSection.rowGapSlider:CreateTexture(nil,"BACKGROUND"); auraSection.rowGapTrack:SetTexture(WHITE); auraSection.rowGapTrack:SetVertexColor(0.22,0.18,0.10,1); auraSection.rowGapTrack:SetPoint("LEFT",auraSection.rowGapSlider,"LEFT",0,0); auraSection.rowGapTrack:SetPoint("RIGHT",auraSection.rowGapSlider,"RIGHT",0,0); auraSection.rowGapTrack:SetHeight(5)
    auraSection.rowGapFill=auraSection.rowGapSlider:CreateTexture(nil,"BORDER"); auraSection.rowGapFill:SetTexture(WHITE); auraSection.rowGapFill:SetVertexColor(0.78,0.56,0.06,1); auraSection.rowGapFill:SetPoint("LEFT",auraSection.rowGapSlider,"LEFT",0,0); auraSection.rowGapFill:SetHeight(3)
    auraSection.rowGapThumb=auraSection.rowGapSlider:CreateTexture(nil,"OVERLAY"); auraSection.rowGapThumb:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(C.levelBadgeTexture or "level_badge.tga")) or (TEX..(C.levelBadgeTexture or "level_badge.tga"))); auraSection.rowGapThumb:SetWidth(18); auraSection.rowGapThumb:SetHeight(18); auraSection.rowGapSlider:SetThumbTexture(auraSection.rowGapThumb)
    auraSection.rowGapSlider:SetScript("OnValueChanged",function()
        if auraSection.rowGapSuppress then return end
        local v=math.floor(this:GetValue()*2+0.5)/2
        SF:SetAuraRowSpacing(v,true)
        auraSection.rowGapValue:SetText(string.format("%.1f",v))
        auraSection.rowGapFill:SetWidth(math.max(1,this:GetWidth()*(v/12.00)))
    end)
    auraSection.timer=MakeButton(auraSection,"",216,22); auraSection.timer:SetPoint("TOPLEFT",auraSection,"TOPLEFT",14,-137)
    auraSection.timer:SetScript("OnClick",function() SF:SetAuraTimerText(not SlamFramesDB.auraShowTimerText,true); SF:RefreshSettings() end)

    auraSection.timerScaleLabel=MakeLabel(auraSection,"Timer size",10,WHITE_TEXT); auraSection.timerScaleLabel:SetPoint("TOPLEFT",auraSection,"TOPLEFT",14,-174)
    auraSection.timerScaleValue=MakeLabel(auraSection,"100%",10,GOLD); auraSection.timerScaleValue:SetPoint("TOPRIGHT",auraSection,"TOPRIGHT",-14,-174); auraSection.timerScaleValue:SetWidth(48); auraSection.timerScaleValue:SetJustifyH("RIGHT")
    auraSection.timerScaleSlider=CreateFrame("Slider",nil,auraSection)
    auraSection.timerScaleSlider:SetOrientation("HORIZONTAL"); auraSection.timerScaleSlider:SetPoint("TOPLEFT",auraSection,"TOPLEFT",14,-195); auraSection.timerScaleSlider:SetWidth(216); auraSection.timerScaleSlider:SetHeight(16)
    auraSection.timerScaleSlider:SetMinMaxValues(0.50,2.00); if auraSection.timerScaleSlider.SetValueStep then auraSection.timerScaleSlider:SetValueStep(.05) end
    auraSection.timerScaleTrack=auraSection.timerScaleSlider:CreateTexture(nil,"BACKGROUND"); auraSection.timerScaleTrack:SetTexture(WHITE); auraSection.timerScaleTrack:SetVertexColor(0.22,0.18,0.10,1); auraSection.timerScaleTrack:SetPoint("LEFT",auraSection.timerScaleSlider,"LEFT",0,0); auraSection.timerScaleTrack:SetPoint("RIGHT",auraSection.timerScaleSlider,"RIGHT",0,0); auraSection.timerScaleTrack:SetHeight(5)
    auraSection.timerScaleFill=auraSection.timerScaleSlider:CreateTexture(nil,"BORDER"); auraSection.timerScaleFill:SetTexture(WHITE); auraSection.timerScaleFill:SetVertexColor(0.78,0.56,0.06,1); auraSection.timerScaleFill:SetPoint("LEFT",auraSection.timerScaleSlider,"LEFT",0,0); auraSection.timerScaleFill:SetHeight(3)
    auraSection.timerScaleThumb=auraSection.timerScaleSlider:CreateTexture(nil,"OVERLAY"); auraSection.timerScaleThumb:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(C.levelBadgeTexture or "level_badge.tga")) or (TEX..(C.levelBadgeTexture or "level_badge.tga"))); auraSection.timerScaleThumb:SetWidth(18); auraSection.timerScaleThumb:SetHeight(18); auraSection.timerScaleSlider:SetThumbTexture(auraSection.timerScaleThumb)
    auraSection.timerScaleSlider:SetScript("OnValueChanged",function()
        if auraSection.timerScaleSuppress then return end
        local v=math.floor(this:GetValue()*20+0.5)/20
        SF:SetAuraTimerTextScale(v,true)
        auraSection.timerScaleValue:SetText(tostring(math.floor(v*100+0.5)).."%")
        auraSection.timerScaleFill:SetWidth(math.max(1,this:GetWidth()*((v-0.50)/1.50)))
    end)
    local auraHelp=MakeLabel(auraSection,"Timer shows the remaining aura duration as a centered number. Adjust its size above.",9,MUTED); auraHelp:SetPoint("TOPLEFT",auraSection,"TOPLEFT",14,-224); auraHelp:SetWidth(216); auraHelp:SetJustifyH("LEFT")

    local relationSection=MakeSection(l,"Relative placement",258,-574,246,110)
    relationSection.totReset=MakeButton(relationSection,"Reset ToT Under Target",214,24); relationSection.totReset:SetPoint("TOPLEFT",relationSection,"TOPLEFT",14,-42); relationSection.totReset:SetScript("OnClick",function() SF:ResetToTRelative() end)
    local rhelp=MakeLabel(relationSection,"Reattaches ToT beneath the target health bar.",9,MUTED); rhelp:SetPoint("TOPLEFT",relationSection,"TOPLEFT",14,-76)

    -- PARTY -----------------------------------------------------------------
    local ppage=f.pages.party

    local pmain=MakeSection(ppage,"Party Frames",0,0,504,126)
    pmain.toggle=MakeButton(pmain,"",220,24); pmain.toggle:SetPoint("TOPLEFT",pmain,"TOPLEFT",14,-43)
    pmain.toggle:SetScript("OnClick",function() SF:SetPartyFramesEnabled(not SlamFramesDB.showPartyFrames,true); SF:RefreshSettings() end)
    pmain.raid=MakeButton(pmain,"",220,24); pmain.raid:SetPoint("TOPRIGHT",pmain,"TOPRIGHT",-14,-43)
    pmain.raid:SetScript("OnClick",function() SF:SetPartyHideInRaid(not SlamFramesDB.partyHideInRaid,true); SF:RefreshSettings() end)
    local ph1=MakeLabel(pmain,"When enabled, SlamFrames replaces Blizzard party1-party4 frames automatically.",10,WHITE_TEXT); ph1:SetPoint("TOPLEFT",pmain,"TOPLEFT",14,-79)
    local ph2=MakeLabel(pmain,"Uses the compact Target-of-Target frame style for a clean four-member stack.",9,MUTED); ph2:SetPoint("TOPLEFT",pmain,"TOPLEFT",14,-99)

    local psize=MakeSection(ppage,"Size & Position",0,-138,246,190)
    f.partyScaleRow=AddScaleRow(psize,"Scale",-43,function() return SlamFramesDB.scales.party or .60 end,function(v,q) SF:SetFrameScale("party",v,q) end,.05)
    f.partyWidthRow=AddWidthRow(psize,"Bar length",-76,"party")
    psize.reset=MakeButton(psize,"Reset Party Position",216,24); psize.reset:SetPoint("TOPLEFT",psize,"TOPLEFT",14,-112); psize.reset:SetScript("OnClick",function() SF:ResetPartyPosition() end)
    local psh=MakeLabel(psize,"Unlock frames, then drag any party member to move the entire group.",9,MUTED); psh:SetPoint("TOPLEFT",psize,"TOPLEFT",14,-149); psh:SetWidth(216)

    local pvisual=MakeSection(ppage,"Portrait & Spacing",258,-138,246,190)
    pvisual.zoomLabel=MakeLabel(pvisual,"Portrait zoom",10,WHITE_TEXT); pvisual.zoomLabel:SetPoint("TOPLEFT",pvisual,"TOPLEFT",14,-43)
    pvisual.zoomValue=MakeLabel(pvisual,"1.08",10,GOLD); pvisual.zoomValue:SetPoint("TOPRIGHT",pvisual,"TOPRIGHT",-14,-43); pvisual.zoomValue:SetWidth(44); pvisual.zoomValue:SetJustifyH("RIGHT")
    pvisual.zoomSlider=CreateFrame("Slider",nil,pvisual); pvisual.zoomSlider:SetOrientation("HORIZONTAL"); pvisual.zoomSlider:SetPoint("TOPLEFT",pvisual,"TOPLEFT",14,-65); pvisual.zoomSlider:SetWidth(216); pvisual.zoomSlider:SetHeight(16)
    pvisual.zoomSlider:SetMinMaxValues(1.00,1.50); if pvisual.zoomSlider.SetValueStep then pvisual.zoomSlider:SetValueStep(.01) end
    pvisual.zoomTrack=pvisual.zoomSlider:CreateTexture(nil,"BACKGROUND"); pvisual.zoomTrack:SetTexture(WHITE); pvisual.zoomTrack:SetVertexColor(0.22,0.18,0.10,1); pvisual.zoomTrack:SetPoint("LEFT",pvisual.zoomSlider,"LEFT",0,0); pvisual.zoomTrack:SetPoint("RIGHT",pvisual.zoomSlider,"RIGHT",0,0); pvisual.zoomTrack:SetHeight(5)
    pvisual.zoomFill=pvisual.zoomSlider:CreateTexture(nil,"BORDER"); pvisual.zoomFill:SetTexture(WHITE); pvisual.zoomFill:SetVertexColor(0.78,0.56,0.06,1); pvisual.zoomFill:SetPoint("LEFT",pvisual.zoomSlider,"LEFT",0,0); pvisual.zoomFill:SetHeight(3)
    pvisual.zoomThumb=pvisual.zoomSlider:CreateTexture(nil,"OVERLAY"); pvisual.zoomThumb:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(C.levelBadgeTexture or "level_badge.tga")) or (TEX..(C.levelBadgeTexture or "level_badge.tga"))); pvisual.zoomThumb:SetWidth(18); pvisual.zoomThumb:SetHeight(18); pvisual.zoomSlider:SetThumbTexture(pvisual.zoomThumb)
    pvisual.zoomSlider:SetScript("OnValueChanged",function()
        if pvisual.zoomSuppress then return end
        local v=math.floor(this:GetValue()*100+0.5)/100
        SF:SetPortraitZoom("party",v,true); pvisual.zoomValue:SetText(string.format("%.2f",v)); pvisual.zoomFill:SetWidth(math.max(1,this:GetWidth()*((v-1.00)/0.50)))
    end)

    pvisual.spacingLabel=MakeLabel(pvisual,"Vertical spacing",10,WHITE_TEXT); pvisual.spacingLabel:SetPoint("TOPLEFT",pvisual,"TOPLEFT",14,-103)
    pvisual.spacingValue=MakeLabel(pvisual,"8",10,GOLD); pvisual.spacingValue:SetPoint("TOPRIGHT",pvisual,"TOPRIGHT",-14,-103); pvisual.spacingValue:SetWidth(44); pvisual.spacingValue:SetJustifyH("RIGHT")
    pvisual.spacingSlider=CreateFrame("Slider",nil,pvisual); pvisual.spacingSlider:SetOrientation("HORIZONTAL"); pvisual.spacingSlider:SetPoint("TOPLEFT",pvisual,"TOPLEFT",14,-125); pvisual.spacingSlider:SetWidth(216); pvisual.spacingSlider:SetHeight(16)
    pvisual.spacingSlider:SetMinMaxValues(0,40); if pvisual.spacingSlider.SetValueStep then pvisual.spacingSlider:SetValueStep(1) end
    pvisual.spacingTrack=pvisual.spacingSlider:CreateTexture(nil,"BACKGROUND"); pvisual.spacingTrack:SetTexture(WHITE); pvisual.spacingTrack:SetVertexColor(0.22,0.18,0.10,1); pvisual.spacingTrack:SetPoint("LEFT",pvisual.spacingSlider,"LEFT",0,0); pvisual.spacingTrack:SetPoint("RIGHT",pvisual.spacingSlider,"RIGHT",0,0); pvisual.spacingTrack:SetHeight(5)
    pvisual.spacingFill=pvisual.spacingSlider:CreateTexture(nil,"BORDER"); pvisual.spacingFill:SetTexture(WHITE); pvisual.spacingFill:SetVertexColor(0.78,0.56,0.06,1); pvisual.spacingFill:SetPoint("LEFT",pvisual.spacingSlider,"LEFT",0,0); pvisual.spacingFill:SetHeight(3)
    pvisual.spacingThumb=pvisual.spacingSlider:CreateTexture(nil,"OVERLAY"); pvisual.spacingThumb:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(C.levelBadgeTexture or "level_badge.tga")) or (TEX..(C.levelBadgeTexture or "level_badge.tga"))); pvisual.spacingThumb:SetWidth(18); pvisual.spacingThumb:SetHeight(18); pvisual.spacingSlider:SetThumbTexture(pvisual.spacingThumb)
    pvisual.spacingSlider:SetScript("OnValueChanged",function()
        if pvisual.spacingSuppress then return end
        local v=math.floor(this:GetValue()+0.5)
        SF:SetPartySpacing(v,true); pvisual.spacingValue:SetText(tostring(v)); pvisual.spacingFill:SetWidth(math.max(1,this:GetWidth()*(v/40)))
    end)

    local ptext=MakeSection(ppage,"Party Text",0,-340,504,202)
    local phealth=MakeLabel(ptext,"Health format",11,WHITE_TEXT); phealth:SetPoint("TOPLEFT",ptext,"TOPLEFT",14,-43)
    ptext.healthButtons={}
    local pmodes={{"%","percent"},{"Amount","amount"},{"Off","off"}}
    local px=150
    for i=1,table.getn(pmodes) do
        local b=MakeButton(ptext,pmodes[i][1],88,22); b.mode=pmodes[i][2]; b:SetPoint("TOPLEFT",ptext,"TOPLEFT",px,-39)
        b:SetScript("OnClick",function() SF:SetPartyHealthTextMode(this.mode,true); SF:RefreshSettings() end)
        ptext.healthButtons[i]=b; px=px+96
    end
    ptext.nameLabel=MakeLabel(ptext,"Name X",10,WHITE_TEXT); ptext.nameLabel:SetPoint("TOPLEFT",ptext,"TOPLEFT",14,-86)
    ptext.nameValue=MakeLabel(ptext,"0",10,GOLD); ptext.nameValue:SetPoint("TOPRIGHT",ptext,"TOPRIGHT",-14,-86); ptext.nameValue:SetWidth(52); ptext.nameValue:SetJustifyH("RIGHT")
    ptext.nameSlider=CreateFrame("Slider",nil,ptext); ptext.nameSlider:SetOrientation("HORIZONTAL"); ptext.nameSlider:SetPoint("TOPLEFT",ptext,"TOPLEFT",14,-108); ptext.nameSlider:SetWidth(476); ptext.nameSlider:SetHeight(16)
    ptext.nameSlider:SetMinMaxValues(-150,150); if ptext.nameSlider.SetValueStep then ptext.nameSlider:SetValueStep(5) end
    ptext.nameTrack=ptext.nameSlider:CreateTexture(nil,"BACKGROUND"); ptext.nameTrack:SetTexture(WHITE); ptext.nameTrack:SetVertexColor(0.22,0.18,0.10,1); ptext.nameTrack:SetPoint("LEFT",ptext.nameSlider,"LEFT",0,0); ptext.nameTrack:SetPoint("RIGHT",ptext.nameSlider,"RIGHT",0,0); ptext.nameTrack:SetHeight(5)
    ptext.nameFill=ptext.nameSlider:CreateTexture(nil,"BORDER"); ptext.nameFill:SetTexture(WHITE); ptext.nameFill:SetVertexColor(0.78,0.56,0.06,1); ptext.nameFill:SetPoint("LEFT",ptext.nameSlider,"LEFT",0,0); ptext.nameFill:SetHeight(3)
    ptext.nameThumb=ptext.nameSlider:CreateTexture(nil,"OVERLAY"); ptext.nameThumb:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(C.levelBadgeTexture or "level_badge.tga")) or (TEX..(C.levelBadgeTexture or "level_badge.tga"))); ptext.nameThumb:SetWidth(18); ptext.nameThumb:SetHeight(18); ptext.nameSlider:SetThumbTexture(ptext.nameThumb)
    ptext.nameSlider:SetScript("OnValueChanged",function()
        if ptext.nameSuppress then return end
        local v=math.floor((this:GetValue()+2.5)/5)*5
        SF:SetPartyNameOffset(v,true); ptext.nameValue:SetText(tostring(v)); ptext.nameFill:SetWidth(math.max(1,this:GetWidth()*((v+150)/300)))
    end)
    local pth1=MakeLabel(ptext,"Name X moves all four party names together (-150 to +150).",10,WHITE_TEXT); pth1:SetPoint("TOPLEFT",ptext,"TOPLEFT",14,-145)
    local pth2=MakeLabel(ptext,"Global Name / Health text sizes on the Layout tab also apply to party frames.",9,MUTED); pth2:SetPoint("TOPLEFT",ptext,"TOPLEFT",14,-168)

    f.partyMain=pmain; f.partySize=psize; f.partyVisual=pvisual; f.partyText=ptext


    -- RAID -----------------------------------------------------------------
    local rpage=f.pages.raid
    local rmain=MakeSection(rpage,"Raid Frames",0,0,504,166)
    rmain.toggle=MakeButton(rmain,"",206,24); rmain.toggle:SetPoint("TOPLEFT",rmain,"TOPLEFT",14,-43); rmain.toggle:SetScript("OnClick",function() RaidCall("SetRaidFramesEnabled",not SlamFramesDB.showRaidFrames); SF:RefreshSettings() end)
    rmain.headers=MakeButton(rmain,"",252,24); rmain.headers:SetPoint("TOPRIGHT",rmain,"TOPRIGHT",-14,-43); rmain.headers:SetScript("OnClick",function() RaidCall("SetRaidGroupHeaders",not SlamFramesDB.raidShowGroupHeaders); SF:RefreshSettings() end)
    rmain.compact=MakeButton(rmain,"",206,24); rmain.compact:SetPoint("TOPLEFT",rmain,"TOPLEFT",14,-77); rmain.compact:SetScript("OnClick",function() RaidCall("SetRaidCompactMode",not SlamFramesDB.raidCompactMode); SF:RefreshSettings() end)
    rmain.layout=MakeButton(rmain,"",252,24); rmain.layout:SetPoint("TOPRIGHT",rmain,"TOPRIGHT",-14,-77); rmain.layout:SetScript("OnClick",function() local current=SlamFramesDB.raidGroupsPerRow or 8; local n=8; if current==8 then n=4 elseif current==4 then n=2 else n=8 end; RaidCall("SetRaidGroupsPerRow",n); SF:RefreshSettings() end)
    local rh1=MakeLabel(rmain,"Compact Mode is the healing layout: no portraits or level badges, just fast health-first cells.",10,WHITE_TEXT); rh1:SetPoint("TOPLEFT",rmain,"TOPLEFT",14,-112); rh1:SetWidth(476)
    local rh2=MakeLabel(rmain,"It keeps SlamFrames health bars, click casting and sizing, and now follows the selected Light / Dark skin.",9,MUTED); rh2:SetPoint("TOPLEFT",rmain,"TOPLEFT",14,-135); rh2:SetWidth(476)

    local rsize=MakeSection(rpage,"Size & Position",0,-178,246,254)
    f.raidScaleRow=AddScaleRow(rsize,"Scale",-43,function() return SlamFramesDB.scales.raid or .60 end,function(v,q) SF:SetFrameScale("raid",v,q) end,.05)
    f.raidWidthRow=AddWidthRow(rsize,"Bar length",-76,"raid")
    rsize.reset=MakeButton(rsize,"Reset Raid Position",216,24); rsize.reset:SetPoint("TOPLEFT",rsize,"TOPLEFT",14,-112); rsize.reset:SetScript("OnClick",function() SF:ResetRaidPosition() end)

    rsize.opacityLabel=MakeLabel(rsize,"Raid opacity",10,WHITE_TEXT); rsize.opacityLabel:SetPoint("TOPLEFT",rsize,"TOPLEFT",14,-151)
    rsize.opacityValue=MakeLabel(rsize,"100%",10,GOLD); rsize.opacityValue:SetPoint("TOPRIGHT",rsize,"TOPRIGHT",-14,-151); rsize.opacityValue:SetWidth(44); rsize.opacityValue:SetJustifyH("RIGHT")
    rsize.opacitySlider=CreateFrame("Slider",nil,rsize); rsize.opacitySlider:SetOrientation("HORIZONTAL"); rsize.opacitySlider:SetPoint("TOPLEFT",rsize,"TOPLEFT",14,-173); rsize.opacitySlider:SetWidth(216); rsize.opacitySlider:SetHeight(16); rsize.opacitySlider:SetMinMaxValues(20,100); if rsize.opacitySlider.SetValueStep then rsize.opacitySlider:SetValueStep(5) end
    local rot=rsize.opacitySlider:CreateTexture(nil,"BACKGROUND"); rot:SetTexture(WHITE); rot:SetVertexColor(.22,.18,.10,1); rot:SetPoint("LEFT",rsize.opacitySlider,"LEFT",0,0); rot:SetPoint("RIGHT",rsize.opacitySlider,"RIGHT",0,0); rot:SetHeight(5)
    local roth=rsize.opacitySlider:CreateTexture(nil,"OVERLAY"); roth:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(C.levelBadgeTexture or "level_badge.tga")) or (TEX..(C.levelBadgeTexture or "level_badge.tga"))); roth:SetWidth(18); roth:SetHeight(18); rsize.opacitySlider:SetThumbTexture(roth)
    rsize.opacitySlider:SetScript("OnValueChanged",function() if rsize.opacitySuppress then return end; local v=math.floor((this:GetValue()+2.5)/5)*5; if v<20 then v=20 elseif v>100 then v=100 end; rsize.opacityValue:SetText(tostring(v).."%"); RaidCall("SetRaidOpacity",v/100) end)

    local rsh=MakeLabel(rsize,"Unlock + drag moves the grid. Opacity changes visuals only; click targets stay active.",9,MUTED); rsh:SetPoint("TOPLEFT",rsize,"TOPLEFT",14,-211); rsh:SetWidth(216)

    local rvisual=MakeSection(rpage,"Layout",258,-178,246,310)
    local function RaidMiniSlider(parent,label,y,minv,maxv,getter,setter)
        local lab=MakeLabel(parent,label,10,WHITE_TEXT); lab:SetPoint("TOPLEFT",parent,"TOPLEFT",14,y)
        local val=MakeLabel(parent,tostring(getter()),10,GOLD); val:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-14,y); val:SetWidth(44); val:SetJustifyH("RIGHT")
        local sl=CreateFrame("Slider",nil,parent); sl:SetOrientation("HORIZONTAL"); sl:SetPoint("TOPLEFT",parent,"TOPLEFT",14,y-22); sl:SetWidth(216); sl:SetHeight(16); sl:SetMinMaxValues(minv,maxv); if sl.SetValueStep then sl:SetValueStep(1) end
        local tr=sl:CreateTexture(nil,"BACKGROUND"); tr:SetTexture(WHITE); tr:SetVertexColor(.22,.18,.10,1); tr:SetPoint("LEFT",sl,"LEFT",0,0); tr:SetPoint("RIGHT",sl,"RIGHT",0,0); tr:SetHeight(5)
        local th=sl:CreateTexture(nil,"OVERLAY"); th:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(C.levelBadgeTexture or "level_badge.tga")) or (TEX..(C.levelBadgeTexture or "level_badge.tga"))); th:SetWidth(18); th:SetHeight(18); sl:SetThumbTexture(th)
        sl:SetValue(getter()); sl:SetScript("OnValueChanged",function() local v=math.floor(this:GetValue()+.5); val:SetText(tostring(v)); setter(v,true) end)
        return {slider=sl,value=val,getValue=getter}
    end
    f.raidSpacingRow=RaidMiniSlider(rvisual,"Member spacing",-43,0,40,function() return SlamFramesDB.raidSpacing or 4 end,function(v,q) RaidCall("SetRaidSpacing",v) end)
    f.raidGroupSpacingRow=RaidMiniSlider(rvisual,"Group X spacing",-103,0,40,function() return SlamFramesDB.raidGroupSpacing or 10 end,function(v,q) RaidCall("SetRaidGroupSpacing",v) end)
    f.raidGroupRowSpacingRow=RaidMiniSlider(rvisual,"Group row spacing",-163,0,80,function() return SlamFramesDB.raidGroupRowSpacing or 36 end,function(v,q) RaidCall("SetRaidGroupRowSpacing",v) end)
    rvisual.zoomLabel=MakeLabel(rvisual,"Portrait zoom (Standard)",10,WHITE_TEXT); rvisual.zoomLabel:SetPoint("TOPLEFT",rvisual,"TOPLEFT",14,-223)
    rvisual.zoomValue=MakeLabel(rvisual,"1.08",10,GOLD); rvisual.zoomValue:SetPoint("TOPRIGHT",rvisual,"TOPRIGHT",-14,-223); rvisual.zoomValue:SetWidth(44); rvisual.zoomValue:SetJustifyH("RIGHT")
    rvisual.zoomSlider=CreateFrame("Slider",nil,rvisual); rvisual.zoomSlider:SetOrientation("HORIZONTAL"); rvisual.zoomSlider:SetPoint("TOPLEFT",rvisual,"TOPLEFT",14,-245); rvisual.zoomSlider:SetWidth(216); rvisual.zoomSlider:SetHeight(16); rvisual.zoomSlider:SetMinMaxValues(1.00,1.50); if rvisual.zoomSlider.SetValueStep then rvisual.zoomSlider:SetValueStep(.01) end
    local rzt=rvisual.zoomSlider:CreateTexture(nil,"BACKGROUND"); rzt:SetTexture(WHITE); rzt:SetVertexColor(.22,.18,.10,1); rzt:SetPoint("LEFT",rvisual.zoomSlider,"LEFT",0,0); rzt:SetPoint("RIGHT",rvisual.zoomSlider,"RIGHT",0,0); rzt:SetHeight(5)
    local rzth=rvisual.zoomSlider:CreateTexture(nil,"OVERLAY"); rzth:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(C.levelBadgeTexture or "level_badge.tga")) or (TEX..(C.levelBadgeTexture or "level_badge.tga"))); rzth:SetWidth(18); rzth:SetHeight(18); rvisual.zoomSlider:SetThumbTexture(rzth)
    rvisual.zoomSlider:SetScript("OnValueChanged",function() if rvisual.zoomSuppress then return end; local v=math.floor(this:GetValue()*100+.5)/100; rvisual.zoomValue:SetText(string.format("%.2f",v)); SF:SetPortraitZoom("raid",v,true) end)
    f.raidVisual=rvisual

    local rtext=MakeSection(rpage,"Raid Text & Preview",0,-500,504,420)
    local rl=MakeLabel(rtext,"Health format",11,WHITE_TEXT); rl:SetPoint("TOPLEFT",rtext,"TOPLEFT",14,-43)
    rtext.healthButtons={}
    local rmodes={{"%","percent"},{"Amount","amount"},{"Off","off"}}; local rx=150
    for i=1,table.getn(rmodes) do local b=MakeButton(rtext,rmodes[i][1],88,22); b.mode=rmodes[i][2]; b:SetPoint("TOPLEFT",rtext,"TOPLEFT",rx,-39); b:SetScript("OnClick",function() RaidCall("SetRaidHealthTextMode",this.mode); SF:RefreshSettings() end); rtext.healthButtons[i]=b; rx=rx+96 end

    local nlab=MakeLabel(rtext,"Name X",10,WHITE_TEXT); nlab:SetPoint("TOPLEFT",rtext,"TOPLEFT",14,-84)
    rtext.nameValue=MakeLabel(rtext,"0",10,GOLD); rtext.nameValue:SetPoint("TOPRIGHT",rtext,"TOPRIGHT",-14,-84); rtext.nameValue:SetWidth(52); rtext.nameValue:SetJustifyH("RIGHT")
    rtext.nameSlider=CreateFrame("Slider",nil,rtext); rtext.nameSlider:SetOrientation("HORIZONTAL"); rtext.nameSlider:SetPoint("TOPLEFT",rtext,"TOPLEFT",14,-106); rtext.nameSlider:SetWidth(476); rtext.nameSlider:SetHeight(16); rtext.nameSlider:SetMinMaxValues(-150,150); if rtext.nameSlider.SetValueStep then rtext.nameSlider:SetValueStep(5) end
    local nt=rtext.nameSlider:CreateTexture(nil,"BACKGROUND"); nt:SetTexture(WHITE); nt:SetVertexColor(.22,.18,.10,1); nt:SetPoint("LEFT",rtext.nameSlider,"LEFT",0,0); nt:SetPoint("RIGHT",rtext.nameSlider,"RIGHT",0,0); nt:SetHeight(5)
    local nth=rtext.nameSlider:CreateTexture(nil,"OVERLAY"); nth:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(C.levelBadgeTexture or "level_badge.tga")) or (TEX..(C.levelBadgeTexture or "level_badge.tga"))); nth:SetWidth(18); nth:SetHeight(18); rtext.nameSlider:SetThumbTexture(nth)
    rtext.nameSlider:SetScript("OnValueChanged",function() if rtext.nameSuppress then return end; local v=math.floor((this:GetValue()+2.5)/5)*5; rtext.nameValue:SetText(tostring(v)); RaidCall("SetRaidNameOffset",v) end)

    rtext.classNames=MakeButton(rtext,"",220,22); rtext.classNames:SetPoint("TOPLEFT",rtext,"TOPLEFT",14,-143); rtext.classNames:SetScript("OnClick",function() RaidCall("SetRaidClassColoredNames",not SlamFramesDB.raidClassColoredNames); SF:RefreshSettings() end)
    local classHint=MakeLabel(rtext,"Uses each raid member's class color for the name; SlamFrames gold remains available as the neutral option.",9,MUTED); classHint:SetPoint("TOPLEFT",rtext,"TOPLEFT",246,-145); classHint:SetWidth(244)

    local pl=MakeLabel(rtext,"Test Frames raid size",10,WHITE_TEXT); pl:SetPoint("TOPLEFT",rtext,"TOPLEFT",14,-184)
    rtext.previewButtons={}; local sizes={5,10,15,20,40}; rx=14
    for i=1,5 do local b=MakeButton(rtext,tostring(sizes[i]),72,22); b.previewSize=sizes[i]; b:SetPoint("TOPLEFT",rtext,"TOPLEFT",rx,-207); b:SetScript("OnClick",function() RaidCall("SetRaidPreviewSize",this.previewSize); SF:RefreshSettings() end); rtext.previewButtons[i]=b; rx=rx+82 end

    rtext.debuffPreview=MakeButton(rtext,"",220,22); rtext.debuffPreview:SetPoint("TOPLEFT",rtext,"TOPLEFT",14,-243); rtext.debuffPreview:SetScript("OnClick",function() RaidCall("SetRaidPreviewDebuffs",not SlamFramesDB.raidPreviewDebuffs); SF:RefreshSettings() end)
    rtext.mainTankPreview=MakeButton(rtext,"",220,22); rtext.mainTankPreview:SetPoint("TOPRIGHT",rtext,"TOPRIGHT",-14,-243); rtext.mainTankPreview:SetScript("OnClick",function() RaidCall("SetRaidPreviewMainTanks",not SlamFramesDB.raidPreviewMainTanks); SF:RefreshSettings() end)

    local gLabel=MakeLabel(rtext,"Debuff glow size",10,WHITE_TEXT); gLabel:SetPoint("TOPLEFT",rtext,"TOPLEFT",14,-282)
    rtext.debuffGlowValue=MakeLabel(rtext,"2",10,GOLD); rtext.debuffGlowValue:SetPoint("TOPRIGHT",rtext,"TOPRIGHT",-14,-282); rtext.debuffGlowValue:SetWidth(44); rtext.debuffGlowValue:SetJustifyH("RIGHT")
    rtext.debuffGlowSlider=CreateFrame("Slider",nil,rtext); rtext.debuffGlowSlider:SetOrientation("HORIZONTAL"); rtext.debuffGlowSlider:SetPoint("TOPLEFT",rtext,"TOPLEFT",14,-304); rtext.debuffGlowSlider:SetWidth(476); rtext.debuffGlowSlider:SetHeight(16); rtext.debuffGlowSlider:SetMinMaxValues(1,8); if rtext.debuffGlowSlider.SetValueStep then rtext.debuffGlowSlider:SetValueStep(1) end
    local dgt=rtext.debuffGlowSlider:CreateTexture(nil,"BACKGROUND"); dgt:SetTexture(WHITE); dgt:SetVertexColor(.22,.18,.10,1); dgt:SetPoint("LEFT",rtext.debuffGlowSlider,"LEFT",0,0); dgt:SetPoint("RIGHT",rtext.debuffGlowSlider,"RIGHT",0,0); dgt:SetHeight(5)
    local dgth=rtext.debuffGlowSlider:CreateTexture(nil,"OVERLAY"); dgth:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(C.levelBadgeTexture or "level_badge.tga")) or (TEX..(C.levelBadgeTexture or "level_badge.tga"))); dgth:SetWidth(18); dgth:SetHeight(18); rtext.debuffGlowSlider:SetThumbTexture(dgth)
    rtext.debuffGlowSlider:SetScript("OnValueChanged",function() if rtext.debuffGlowSuppress then return end; local v=math.floor(this:GetValue()+.5); rtext.debuffGlowValue:SetText(tostring(v)); RaidCall("SetRaidDebuffGlowSize",v) end)

    local rr=MakeLabel(rtext,"Test Debuffs shows Magic, Curse, Poison and Disease. Glow Size expands the colored alert around the frame.",9,MUTED); rr:SetPoint("TOPLEFT",rtext,"TOPLEFT",14,-341); rr:SetWidth(476)
    local rr2=MakeLabel(rtext,"Test Main Tanks marks two preview members with the new steel-blue Main Tank frame treatment.",9,MUTED); rr2:SetPoint("TOPLEFT",rtext,"TOPLEFT",14,-363); rr2:SetWidth(476)
    local rr3=MakeLabel(rtext,"Live Main Tank styling follows the raid roster's Main Tank assignment; preview controls remain Test Frames only.",9,MUTED); rr3:SetPoint("TOPLEFT",rtext,"TOPLEFT",14,-385); rr3:SetWidth(476)
    f.raidMain=rmain; f.raidSize=rsize; f.raidText=rtext

    -- CLICK CASTING ---------------------------------------------------------
    local cpage=f.pages.clickcast
    local cmain=MakeSection(cpage,"Click Casting",0,0,504,178)
    cmain.toggle=MakeButton(cmain,"",206,24); cmain.toggle:SetPoint("TOPLEFT",cmain,"TOPLEFT",14,-43)
    cmain.toggle:SetScript("OnClick",function() SF:SetClickCastingEnabled(not SlamFramesDB.clickCastingEnabled,true); SF:RefreshSettings() end)
    cmain.normal=MakeButton(cmain,"",252,24); cmain.normal:SetPoint("TOPLEFT",cmain,"TOPLEFT",238,-43)
    cmain.normal:SetScript("OnClick",function() SF:SetClickCastingApplyNormal(not SlamFramesDB.clickCastingApplyNormal,true); SF:RefreshSettings() end)
    cmain.tooltip=MakeButton(cmain,"",206,24); cmain.tooltip:SetPoint("TOPLEFT",cmain,"TOPLEFT",14,-77)
    cmain.tooltip:SetScript("OnClick",function() SF:SetClickCastingTooltip(not SlamFramesDB.clickCastingTooltip,true); SF:RefreshSettings() end)
    local cwarn=MakeLabel(cmain,"Party and Raid frames always participate when Click Casting is ON.",10,WHITE_TEXT); cwarn:SetPoint("TOPLEFT",cmain,"TOPLEFT",14,-113); cwarn:SetWidth(476)
    local ch=MakeLabel(cmain,"Player / Target / ToT remain completely normal unless the optional toggle above is enabled.",9,MUTED); ch:SetPoint("TOPLEFT",cmain,"TOPLEFT",14,-137); ch:SetWidth(476)

    local binds=MakeSection(cpage,"Mouse Bindings",0,-190,504,322)
    local bh=MakeLabel(binds,"Choose None, Shift, Ctrl, or Alt. Leave a click NORMAL, or override only the clicks you want.",10,WHITE_TEXT); bh:SetPoint("TOPLEFT",binds,"TOPLEFT",14,-43); bh:SetWidth(476)
    local ml=MakeLabel(binds,"Edit bindings for:",9,MUTED); ml:SetPoint("TOPLEFT",binds,"TOPLEFT",14,-72)
    binds.modifierButtons={}
    local modDefs={{"None","none"},{"Shift","shift"},{"Ctrl","ctrl"},{"Alt","alt"}}
    local mx=112
    for i=1,table.getn(modDefs) do
        local mb=MakeButton(binds,modDefs[i][1],82,22)
        mb.modifierKey=modDefs[i][2]
        mb:SetPoint("TOPLEFT",binds,"TOPLEFT",mx+(i-1)*91,-66)
        mb:SetScript("OnClick",function() f.clickBindingModifier=this.modifierKey; SF:RefreshSettings() end)
        binds.modifierButtons[i]=mb
    end
    local col1=MakeLabel(binds,"Button",9,MUTED); col1:SetPoint("TOPLEFT",binds,"TOPLEFT",14,-105)
    local col2=MakeLabel(binds,"Function",9,MUTED); col2:SetPoint("TOPLEFT",binds,"TOPLEFT",112,-105)
    local col3=MakeLabel(binds,"Spell / Item Name",9,MUTED); col3:SetPoint("TOPLEFT",binds,"TOPLEFT",256,-105)
    binds.rows={}
    local bindDefs={{"Left Click","LeftButton"},{"Right Click","RightButton"},{"Middle Click","MiddleButton"}}
    local by=-126
    for i=1,table.getn(bindDefs) do
        local row={}
        row.buttonKey=bindDefs[i][2]
        row.label=MakeLabel(binds,bindDefs[i][1],10,WHITE_TEXT); row.label:SetPoint("TOPLEFT",binds,"TOPLEFT",14,by-4)
        row.action=MakeButton(binds,"",132,22); row.action:SetPoint("TOPLEFT",binds,"TOPLEFT",108,by)
        row.action.buttonKey=row.buttonKey
        row.action:SetScript("OnClick",function()
            local mod=f.clickBindingModifier or "none"
            SF:CycleClickBindingAction(mod,this.buttonKey,true)
            SF:RefreshSettings()
        end)
        row.spell=MakeEditBox(binds,232,22); row.spell:SetPoint("TOPLEFT",binds,"TOPLEFT",248,by)
        row.spell.buttonKey=row.buttonKey
        row.spell:SetScript("OnEnterPressed",function()
            local mod=this.modifierKey or f.clickBindingModifier or "none"
            SF:SetClickSpell(mod,this.buttonKey,this:GetText(),true)
            this:ClearFocus(); SF:RefreshSettings()
        end)
        row.spell:SetScript("OnEditFocusLost",function()
            local mod=this.modifierKey or f.clickBindingModifier or "none"
            SF:SetClickSpell(mod,this.buttonKey,this:GetText(),true)
        end)
        binds.rows[i]=row
        by=by-48
    end
    local bhelp1=MakeLabel(binds,"NORMAL preserves the frame's existing behavior. Party Left = target, Party Right = menu, Middle = no action.",9,MUTED); bhelp1:SetPoint("TOPLEFT",binds,"TOPLEFT",14,-270); bhelp1:SetWidth(476)
    local bhelp2=MakeLabel(binds,"Use Item is the /use equivalent. Enter an item name (or /use Item Name). Cast Spell and Use Item activate the field above.",9,MUTED); bhelp2:SetPoint("TOPLEFT",binds,"TOPLEFT",14,-289); bhelp2:SetWidth(476)

    local deb=MakeSection(cpage,"Party Debuff Alerts",0,-524,504,284)
    deb.toggle=MakeButton(deb,"",206,24); deb.toggle:SetPoint("TOPLEFT",deb,"TOPLEFT",14,-43)
    deb.toggle:SetScript("OnClick",function() SF:SetPartyDebuffAlerts(not SlamFramesDB.partyDebuffAlerts,true); SF:RefreshSettings() end)
    deb.filter=MakeButton(deb,"",252,24); deb.filter:SetPoint("TOPLEFT",deb,"TOPLEFT",238,-43)
    deb.filter:SetScript("OnClick",function() SF:SetPartyDebuffOnlyDispellable(not SlamFramesDB.partyDebuffOnlyDispellable,true); SF:RefreshSettings() end)
    deb.message=MakeButton(deb,"",206,24); deb.message:SetPoint("TOPLEFT",deb,"TOPLEFT",14,-79)
    deb.message:SetScript("OnClick",function() SF:SetPartyDebuffMessage(not SlamFramesDB.partyDebuffMessage,true); SF:RefreshSettings() end)
    deb.sound=MakeButton(deb,"",206,24); deb.sound:SetPoint("TOPLEFT",deb,"TOPLEFT",238,-79)
    deb.sound:SetScript("OnClick",function() SF:SetPartyDebuffSound(not SlamFramesDB.partyDebuffSound,true); SF:RefreshSettings() end)
    local d1=MakeLabel(deb,"Debuffed party frames receive a colored border and debuff icon. New debuffs can also produce a screen message and sound.",10,WHITE_TEXT); d1:SetPoint("TOPLEFT",deb,"TOPLEFT",14,-121); d1:SetWidth(476)
    local d2=MakeLabel(deb,"Type colors: Magic blue, Curse purple, Disease amber, Poison green. Unknown debuff types use red.",9,MUTED); d2:SetPoint("TOPLEFT",deb,"TOPLEFT",14,-157); d2:SetWidth(476)
    local d3=MakeLabel(deb,"Dispellable mode scans your learned spellbook (Cleanse, Purify, Dispel Magic, Cure/Abolish, Remove Curse) instead of assuming class abilities.",9,MUTED); d3:SetPoint("TOPLEFT",deb,"TOPLEFT",14,-190); d3:SetWidth(476)
    local d4=MakeLabel(deb,"Alerts are event-driven from UNIT_AURA / group changes; there is no continuous full-party aura polling loop.",9,MUTED); d4:SetPoint("TOPLEFT",deb,"TOPLEFT",14,-230); d4:SetWidth(476)

    f.clickBindingModifier="none"
    f.clickMain=cmain; f.clickBindings=binds; f.clickDebuffs=deb

    -- EFFECTS ---------------------------------------------------------------
    local e=f.pages.effects
    local rest=MakeSection(e,"Resting / Inn",0,0,504,118)
    rest.toggle=MakeButton(rest,"",215,24); rest.toggle:SetPoint("TOPLEFT",rest,"TOPLEFT",14,-43); rest.toggle:SetScript("OnClick",function() SlamFramesDB.showRestingEffect=not SlamFramesDB.showRestingEffect; SF:UpdatePlayerEffects(true); SF:RefreshSettings() end)
    local rh1=MakeLabel(rest,"Gold portrait pulse + Z z z while resting. Level badge always renders above the glow.",10,WHITE_TEXT); rh1:SetPoint("TOPLEFT",rest,"TOPLEFT",14,-82)

    local combat=MakeSection(e,"Combat notification",0,-130,504,112)
    combat.toggle=MakeButton(combat,"",205,24); combat.toggle:SetPoint("TOPLEFT",combat,"TOPLEFT",14,-43); combat.toggle:SetScript("OnClick",function() SlamFramesDB.showCombatGlow=not SlamFramesDB.showCombatGlow; SF:UpdatePlayerEffects(true); SF:RefreshSettings() end)

    combat.intensityLabel=MakeLabel(combat,"Glow Strength",10,WHITE_TEXT); combat.intensityLabel:SetPoint("TOPLEFT",combat,"TOPLEFT",244,-40)
    combat.intensityValue=MakeLabel(combat,"115%",10,GOLD); combat.intensityValue:SetPoint("TOPRIGHT",combat,"TOPRIGHT",-16,-40); combat.intensityValue:SetWidth(48); combat.intensityValue:SetJustifyH("RIGHT")
    combat.intensitySlider=CreateFrame("Slider",nil,combat)
    combat.intensitySlider:SetOrientation("HORIZONTAL"); combat.intensitySlider:SetPoint("TOPLEFT",combat,"TOPLEFT",244,-61); combat.intensitySlider:SetWidth(244); combat.intensitySlider:SetHeight(16)
    combat.intensitySlider:SetMinMaxValues(0.50,2.00); if combat.intensitySlider.SetValueStep then combat.intensitySlider:SetValueStep(.05) end
    combat.intensityTrack=combat.intensitySlider:CreateTexture(nil,"BACKGROUND"); combat.intensityTrack:SetTexture(WHITE); combat.intensityTrack:SetVertexColor(0.22,0.18,0.10,1); combat.intensityTrack:SetPoint("LEFT",combat.intensitySlider,"LEFT",0,0); combat.intensityTrack:SetPoint("RIGHT",combat.intensitySlider,"RIGHT",0,0); combat.intensityTrack:SetHeight(5)
    combat.intensityFill=combat.intensitySlider:CreateTexture(nil,"BORDER"); combat.intensityFill:SetTexture(WHITE); combat.intensityFill:SetVertexColor(0.82,0.08,0.03,1); combat.intensityFill:SetPoint("LEFT",combat.intensitySlider,"LEFT",0,0); combat.intensityFill:SetHeight(3)
    combat.intensityThumb=combat.intensitySlider:CreateTexture(nil,"OVERLAY"); combat.intensityThumb:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(C.levelBadgeTexture or "level_badge.tga")) or (TEX..(C.levelBadgeTexture or "level_badge.tga"))); combat.intensityThumb:SetVertexColor(1.0,0.18,0.10); combat.intensityThumb:SetWidth(17); combat.intensityThumb:SetHeight(17); combat.intensitySlider:SetThumbTexture(combat.intensityThumb)
    combat.intensitySlider:SetScript("OnValueChanged",function()
        if combat.intensitySuppress then return end
        local v=this:GetValue()
        SF:SetCombatGlowIntensity(v,true)
        combat.intensityValue:SetText(tostring(math.floor(v*100+0.5)).."%")
        combat.intensityFill:SetWidth(math.max(1,this:GetWidth()*((v-0.50)/1.50)))
    end)

    local cb1=MakeLabel(combat,"Red combat ring + outer halo. Strength adjusts brightness and halo spread.",10,WHITE_TEXT); cb1:SetPoint("TOPLEFT",combat,"TOPLEFT",14,-86)

    local cc=MakeSection(e,"Crowd control alerts",0,-254,504,196)
    cc.toggle=MakeButton(cc,"",215,24); cc.toggle:SetPoint("TOPLEFT",cc,"TOPLEFT",14,-43); cc.toggle:SetScript("OnClick",function() SlamFramesDB.showCCEffect=not SlamFramesDB.showCCEffect; SF:UpdatePlayerEffects(true); SF:RefreshSettings() end)
    cc.preview=MakeButton(cc,"Preview CC",150,24); cc.preview:SetPoint("TOPRIGHT",cc,"TOPRIGHT",-14,-43); cc.preview:SetScript("OnClick",function() SF:PreviewCC(4) end)
    cc.move=MakeButton(cc,"Move CC Alert",215,24); cc.move:SetPoint("TOPLEFT",cc,"TOPLEFT",14,-79); cc.move:SetScript("OnClick",function() SF:SetCCMoveMode(not SF.ccMoveMode) end)
    cc.reset=MakeButton(cc,"Reset CC Position",215,24); cc.reset:SetPoint("TOPRIGHT",cc,"TOPRIGHT",-14,-79); cc.reset:SetScript("OnClick",function() SF:ResetCCPosition() end)
    local ch1=MakeLabel(cc,"Move mode keeps a test alert visible so you can drag it anywhere.",10,WHITE_TEXT); ch1:SetPoint("TOPLEFT",cc,"TOPLEFT",14,-121)
    local ch2=MakeLabel(cc,"Reset anchors it above the player health bar and follows frame scaling.",10,WHITE_TEXT); ch2:SetPoint("TOPLEFT",cc,"TOPLEFT",14,-141)
    local ch3=MakeLabel(cc,"Live timers depend on what OctoWoW exposes for the active debuff.",10,MUTED); ch3:SetPoint("TOPLEFT",cc,"TOPLEFT",14,-163)

    local notes=MakeSection(e,"Compatibility",0,-462,504,76)
    local n1=MakeLabel(notes,"Effects are visual-only and do not change combat state or protected actions.",10,WHITE_TEXT); n1:SetPoint("TOPLEFT",notes,"TOPLEFT",14,-43)


    -- CAST BAR --------------------------------------------------------------
    local cpage=f.pages.castbar
    local cmain=MakeSection(cpage,"Player Cast Bar",0,0,504,156)
    cmain.toggle=MakeButton(cmain,"",205,24); cmain.toggle:SetPoint("TOPLEFT",cmain,"TOPLEFT",14,-43)
    cmain.toggle:SetScript("OnClick",function() SF:SetCastBarEnabled(not SlamFramesDB.showPlayerCastbar,true); SF:RefreshSettings() end)
    cmain.blizz=MakeButton(cmain,"",205,24); cmain.blizz:SetPoint("TOPRIGHT",cmain,"TOPRIGHT",-14,-43)
    cmain.blizz:SetScript("OnClick",function() SlamFramesDB.hideBlizzardCastbar=not SlamFramesDB.hideBlizzardCastbar; SF:RefreshSettings() end)
    cmain.icon=MakeButton(cmain,"",205,24); cmain.icon:SetPoint("TOPLEFT",cmain,"TOPLEFT",14,-78)
    cmain.icon:SetScript("OnClick",function() SlamFramesDB.castbarShowIcon=not SlamFramesDB.castbarShowIcon; SF:LayoutCastBar(); SF:RefreshSettings() end)
    cmain.timer=MakeButton(cmain,"",205,24); cmain.timer:SetPoint("TOPRIGHT",cmain,"TOPRIGHT",-14,-78)
    cmain.timer:SetScript("OnClick",function() SlamFramesDB.castbarShowTimer=not SlamFramesDB.castbarShowTimer; if SF.castbar then SF:RenderCastBar() end; SF:RefreshSettings() end)
    cmain.latency=MakeButton(cmain,"",205,24); cmain.latency:SetPoint("TOPLEFT",cmain,"TOPLEFT",14,-113)
    cmain.latency:SetScript("OnClick",function() SlamFramesDB.castbarShowLatency=not SlamFramesDB.castbarShowLatency; if SF.castbar then SF:RenderCastBar() end; SF:RefreshSettings() end)

    local cerrors=MakeSection(cpage,"Blizzard Error Text",0,-168,504,104)
    cerrors.toggle=MakeButton(cerrors,"",205,24); cerrors.toggle:SetPoint("TOPLEFT",cerrors,"TOPLEFT",14,-43)
    cerrors.toggle:SetScript("OnClick",function() SF:SetBlizzardErrorTextHidden(not SlamFramesDB.hideBlizzardErrorText,true); SF:RefreshSettings() end)
    local ceh1=MakeLabel(cerrors,"Hides the red failed-cast / ability error text shown near the top of the screen.",10,WHITE_TEXT); ceh1:SetPoint("TOPLEFT",cerrors,"TOPLEFT",234,-42); ceh1:SetWidth(254)
    local ceh2=MakeLabel(cerrors,"SlamFrames cast-bar Interrupted / Failed feedback remains active.",9,MUTED); ceh2:SetPoint("TOPLEFT",cerrors,"TOPLEFT",234,-66); ceh2:SetWidth(254)

    local clayout=MakeSection(cpage,"Cast Bar Layout",0,-284,504,196)
    f.castbarScaleRow=AddScaleRow(clayout,"Scale",-43,function() return SlamFramesDB.castbarScale or .80 end,function(v,q) SF:SetCastBarScale(v,q) end,.05)

    clayout.widthLabel=MakeLabel(clayout,"Width",11,WHITE_TEXT); clayout.widthLabel:SetPoint("TOPLEFT",clayout,"TOPLEFT",270,-43)
    clayout.widthValue=MakeLabel(clayout,"360",11,GOLD); clayout.widthValue:SetPoint("TOPRIGHT",clayout,"TOPRIGHT",-16,-43); clayout.widthValue:SetWidth(48); clayout.widthValue:SetJustifyH("RIGHT")
    clayout.widthSlider=CreateFrame("Slider",nil,clayout)
    clayout.widthSlider:SetOrientation("HORIZONTAL"); clayout.widthSlider:SetPoint("TOPLEFT",clayout,"TOPLEFT",270,-66); clayout.widthSlider:SetWidth(218); clayout.widthSlider:SetHeight(16)
    clayout.widthSlider:SetMinMaxValues(260,540); if clayout.widthSlider.SetValueStep then clayout.widthSlider:SetValueStep(10) end
    clayout.widthTrack=clayout.widthSlider:CreateTexture(nil,"BACKGROUND"); clayout.widthTrack:SetTexture(WHITE); clayout.widthTrack:SetVertexColor(0.22,0.18,0.10,1); clayout.widthTrack:SetPoint("LEFT",clayout.widthSlider,"LEFT",0,0); clayout.widthTrack:SetPoint("RIGHT",clayout.widthSlider,"RIGHT",0,0); clayout.widthTrack:SetHeight(5)
    clayout.widthFill=clayout.widthSlider:CreateTexture(nil,"BORDER"); clayout.widthFill:SetTexture(WHITE); clayout.widthFill:SetVertexColor(0.78,0.56,0.06,1); clayout.widthFill:SetPoint("LEFT",clayout.widthSlider,"LEFT",0,0); clayout.widthFill:SetHeight(3)
    clayout.widthThumb=clayout.widthSlider:CreateTexture(nil,"OVERLAY"); clayout.widthThumb:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(C.levelBadgeTexture or "level_badge.tga")) or (TEX..(C.levelBadgeTexture or "level_badge.tga"))); clayout.widthThumb:SetWidth(18); clayout.widthThumb:SetHeight(18); clayout.widthSlider:SetThumbTexture(clayout.widthThumb)
    clayout.widthSlider:SetScript("OnValueChanged",function()
        if clayout.widthSuppress then return end
        local v=math.floor((this:GetValue()+5)/10)*10
        SF:SetCastBarWidth(v,true)
        clayout.widthValue:SetText(tostring(v))
        clayout.widthFill:SetWidth(math.max(1,this:GetWidth()*((v-260)/280)))
    end)

    clayout.move=MakeButton(clayout,"Move Cast Bar",205,24); clayout.move:SetPoint("TOPLEFT",clayout,"TOPLEFT",14,-104)
    clayout.move:SetScript("OnClick",function() SF:SetCastBarMoveMode(not SF.castbarMoveMode) end)
    clayout.reset=MakeButton(clayout,"Reset Position",205,24); clayout.reset:SetPoint("TOPRIGHT",clayout,"TOPRIGHT",-14,-104)
    clayout.reset:SetScript("OnClick",function() SF:ResetCastBarPosition(false) end)
    local clh1=MakeLabel(clayout,"Reset attaches the cast bar beneath Player. Move mode shows a draggable preview.",10,MUTED); clh1:SetPoint("TOPLEFT",clayout,"TOPLEFT",14,-145)
    local clh2=MakeLabel(clayout,"Width changes use three-slice artwork, so the gold beveled ends never stretch.",9,MUTED); clh2:SetPoint("TOPLEFT",clayout,"TOPLEFT",14,-166)

    local cpreview=MakeSection(cpage,"Preview States",0,-492,504,140)
    cpreview.cast=MakeButton(cpreview,"Cast",108,26); cpreview.cast:SetPoint("TOPLEFT",cpreview,"TOPLEFT",14,-43); cpreview.cast:SetScript("OnClick",function() SF:PreviewCastBar("cast") end)
    cpreview.channel=MakeButton(cpreview,"Channel",108,26); cpreview.channel:SetPoint("LEFT",cpreview.cast,"RIGHT",8,0); cpreview.channel:SetScript("OnClick",function() SF:PreviewCastBar("channel") end)
    cpreview.interrupt=MakeButton(cpreview,"Interrupted",108,26); cpreview.interrupt:SetPoint("LEFT",cpreview.channel,"RIGHT",8,0); cpreview.interrupt:SetScript("OnClick",function() SF:PreviewCastBar("interrupt") end)
    cpreview.failed=MakeButton(cpreview,"Failed",108,26); cpreview.failed:SetPoint("LEFT",cpreview.interrupt,"RIGHT",8,0); cpreview.failed:SetScript("OnClick",function() SF:PreviewCastBar("fail") end)
    local cph1=MakeLabel(cpreview,"The latency region is calculated from GetNetStats() for live casts.",10,WHITE_TEXT); cph1:SetPoint("TOPLEFT",cpreview,"TOPLEFT",14,-86)
    local cph2=MakeLabel(cpreview,"Pure instant spells do not create a cast window; very short timed casts do.",9,MUTED); cph2:SetPoint("TOPLEFT",cpreview,"TOPLEFT",14,-108)

    f.castbarMain=cmain; f.castbarErrors=cerrors; f.castbarLayout=clayout; f.castbarPreview=cpreview

    -- Persistent footer -----------------------------------------------------
    f.reset=MakeButton(f,"Reset All",120,26); f.reset:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",24,24); f.reset:SetScript("OnClick",function() SF:Reset() end)
    f.test=MakeButton(f,"Test Frames",120,26); f.test:SetPoint("BOTTOM",f,"BOTTOM",0,24); f.test:SetScript("OnClick",function() SF.testMode=not SF.testMode; SlamFramesDB.testMode=SF.testMode; SF:RefreshAll(); SF:RefreshSettings() end)
    f.done=MakeButton(f,"Close",120,26); f.done:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-24,24); f.done:SetScript("OnClick",function() f:Hide() end)

    f.generalDisplay=display; f.generalInteraction=interaction; f.generalMinimap=minimap
    f.layoutAuraSection=auraSection
    f.effectsRest=rest; f.effectsCombat=combat; f.effectsCC=cc

    ShowPage(f,"general")
    self:RefreshSettings()
end

function SF:RefreshSettings()
    local f=self.settings; if not f then return end
    local i,b

    if f.generalDisplay then
        for i=1,table.getn(f.generalDisplay.healthButtons or {}) do
            b=f.generalDisplay.healthButtons[i]
            if b.mode==(SlamFramesDB.healthTextMode or "percent") then b:Disable(); TintButton(b,true) else b:Enable(); TintButton(b,false) end
        end
        for i=1,table.getn(f.generalDisplay.totHealthButtons or {}) do
            b=f.generalDisplay.totHealthButtons[i]
            if b.mode==(SlamFramesDB.totHealthTextMode or "percent") then b:Disable(); TintButton(b,true) else b:Enable(); TintButton(b,false) end
        end
        f.generalDisplay.power:SetText("Resource numbers: "..(SlamFramesDB.showPowerNumbers and "ON" or "OFF"))
        f.generalDisplay.auras:SetText("Target auras: "..(SlamFramesDB.showAuras and "ON" or "OFF"))
        if f.generalDisplay.skinButtons then
            for i=1,table.getn(f.generalDisplay.skinButtons) do
                b=f.generalDisplay.skinButtons[i]
                if b.skin==(SlamFramesDB.skin or "dark") then b:Disable(); TintButton(b,true) else b:Enable(); TintButton(b,false) end
            end
        end
        if f.generalDisplay.resolutionButtons then
            for i=1,table.getn(f.generalDisplay.resolutionButtons) do
                b=f.generalDisplay.resolutionButtons[i]
                if b.res==(SlamFramesDB.artResolution or "4k") then b:Disable(); TintButton(b,true) else b:Enable(); TintButton(b,false) end
            end
        end
    end

    if f.generalInteraction then
        f.generalInteraction.lock:SetText(SlamFramesDB.locked and "Unlock Frames" or "Lock Frames")
        f.generalInteraction.smooth:SetText("Smooth Bars: "..(SlamFramesDB.smoothBars and "ON" or "OFF"))
        if f.generalInteraction.selfTarget then f.generalInteraction.selfTarget:SetText("Click Player = Self: "..(SlamFramesDB.selfTargetOnClick and "ON" or "OFF")) end
    end

    if f.generalMinimap then
        f.generalMinimap.toggle:SetText("Minimap Icon: "..(SlamFramesDB.showMinimapButton and "ON" or "OFF"))
    end

    for i=1,table.getn(f.scaleRows or {}) do
        if f.scaleRows[i] and f.scaleRows[i].value and f.scaleRows[i].getValue then
            f.scaleRows[i].value:SetText(string.format("%.2f",f.scaleRows[i].getValue()))
        end
    end

    if f.playerWidthRow then f.playerWidthRow.value:SetText(tostring(SF.WidthPercent("player",C.player)).."%") end
    if f.targetWidthRow then f.targetWidthRow.value:SetText(tostring(SF.WidthPercent("target",C.target)).."%") end
    if f.totWidthRow then f.totWidthRow.value:SetText(tostring(SF.WidthPercent("tot",C.tot)).."%") end

    for i=1,table.getn(f.portraitZoomRows or {}) do
        local row=f.portraitZoomRows[i]
        local v=(SlamFramesDB.portraitZooms and SlamFramesDB.portraitZooms[row.key]) or 1.00
        row.suppress=true; row.slider:SetValue(v); row.suppress=nil
        row.value:SetText(string.format("%.2f",v))
        row.fill:SetWidth(math.max(1,row.slider:GetWidth()*((v-1.00)/0.50)))
    end

    local rows={f.nameScaleRow,f.healthScaleRow,f.powerScaleRow,f.levelScaleRow,f.auraScaleRow}
    for i=1,table.getn(rows) do
        if rows[i] and rows[i].value and rows[i].getValue then rows[i].value:SetText(string.format("%.2f",rows[i].getValue())) end
    end

    if f.layoutAuraSection and f.layoutAuraSection.rowGapSlider then
        local v=tonumber(SlamFramesDB.auraRowSpacing) or 1.00
        f.layoutAuraSection.rowGapSuppress=true
        f.layoutAuraSection.rowGapSlider:SetValue(v)
        f.layoutAuraSection.rowGapSuppress=nil
        f.layoutAuraSection.rowGapValue:SetText(string.format("%.1f",v))
        f.layoutAuraSection.rowGapFill:SetWidth(math.max(1,f.layoutAuraSection.rowGapSlider:GetWidth()*(v/12.00)))
    end
    if f.layoutAuraSection then
        if f.layoutAuraSection.timer then f.layoutAuraSection.timer:SetText("Timer: "..(SlamFramesDB.auraShowTimerText and "ON" or "OFF")) end
        if f.layoutAuraSection.timerScaleSlider then
            local v=tonumber(SlamFramesDB.auraTimerTextScale) or 1.00
            if v<0.50 then v=0.50 elseif v>2.00 then v=2.00 end
            f.layoutAuraSection.timerScaleSuppress=true
            f.layoutAuraSection.timerScaleSlider:SetValue(v)
            f.layoutAuraSection.timerScaleSuppress=nil
            f.layoutAuraSection.timerScaleValue:SetText(tostring(math.floor(v*100+0.5)).."%")
            f.layoutAuraSection.timerScaleFill:SetWidth(math.max(1,f.layoutAuraSection.timerScaleSlider:GetWidth()*((v-0.50)/1.50)))
        end
    end

    if f.partyMain then
        f.partyMain.toggle:SetText("Party Frames: "..(SlamFramesDB.showPartyFrames and "ON" or "OFF"))
        f.partyMain.raid:SetText("Hide in Raid: "..(SlamFramesDB.partyHideInRaid and "ON" or "OFF"))
    end
    if f.partyScaleRow and f.partyScaleRow.value then f.partyScaleRow.value:SetText(string.format("%.2f",SlamFramesDB.scales.party or .60)) end
    if f.partyWidthRow then f.partyWidthRow.value:SetText(tostring(SF.WidthPercent("party",C.party)).."%") end
    if f.partyVisual then
        local z=(SlamFramesDB.portraitZooms and SlamFramesDB.portraitZooms.party) or 1.08
        f.partyVisual.zoomSuppress=true; f.partyVisual.zoomSlider:SetValue(z); f.partyVisual.zoomSuppress=nil
        f.partyVisual.zoomValue:SetText(string.format("%.2f",z)); f.partyVisual.zoomFill:SetWidth(math.max(1,f.partyVisual.zoomSlider:GetWidth()*((z-1.00)/0.50)))
        local sp=tonumber(SlamFramesDB.partySpacing) or 8
        f.partyVisual.spacingSuppress=true; f.partyVisual.spacingSlider:SetValue(sp); f.partyVisual.spacingSuppress=nil
        f.partyVisual.spacingValue:SetText(tostring(math.floor(sp+0.5))); f.partyVisual.spacingFill:SetWidth(math.max(1,f.partyVisual.spacingSlider:GetWidth()*(sp/40)))
    end
    if f.partyText then
        for i=1,table.getn(f.partyText.healthButtons or {}) do
            b=f.partyText.healthButtons[i]
            if b.mode==(SlamFramesDB.partyHealthTextMode or "percent") then b:Disable(); TintButton(b,true) else b:Enable(); TintButton(b,false) end
        end
        local nx=tonumber(SlamFramesDB.partyNameOffset) or 0
        f.partyText.nameSuppress=true; f.partyText.nameSlider:SetValue(nx); f.partyText.nameSuppress=nil
        f.partyText.nameValue:SetText(tostring(nx)); f.partyText.nameFill:SetWidth(math.max(1,f.partyText.nameSlider:GetWidth()*((nx+150)/300)))
    end


    if f.raidMain then
        f.raidMain.toggle:SetText("Raid Frames: "..(SlamFramesDB.showRaidFrames and "ON" or "OFF"))
        f.raidMain.headers:SetText("Group Headers: "..(SlamFramesDB.raidShowGroupHeaders and "ON" or "OFF"))
        if f.raidMain.compact then f.raidMain.compact:SetText("Compact Mode: "..(SlamFramesDB.raidCompactMode and "ON" or "OFF")) end
        if f.raidMain.layout then
            local gl=SlamFramesDB.raidGroupsPerRow or 8
            local glText="8 Across"
            if gl==4 then glText="4 + 4" elseif gl==2 then glText="2 Across" end
            f.raidMain.layout:SetText("Group Layout: "..glText)
        end
    end
    if f.raidScaleRow and f.raidScaleRow.value then f.raidScaleRow.value:SetText(string.format("%.2f",SlamFramesDB.scales.raid or .60)) end
    if f.raidWidthRow then f.raidWidthRow.value:SetText(tostring(SF.WidthPercent("raid",C.raid)).."%") end
    if f.raidSize and f.raidSize.opacitySlider then
        local ov=math.floor(((tonumber(SlamFramesDB.raidOpacity) or 1.00)*100)+0.5)
        ov=math.floor((ov+2.5)/5)*5; if ov<20 then ov=20 elseif ov>100 then ov=100 end
        f.raidSize.opacitySuppress=true; f.raidSize.opacitySlider:SetValue(ov); f.raidSize.opacitySuppress=nil
        f.raidSize.opacityValue:SetText(tostring(ov).."%")
    end
    if f.raidVisual and f.raidVisual.zoomSlider then local z=(SlamFramesDB.portraitZooms and SlamFramesDB.portraitZooms.raid) or 1.08; f.raidVisual.zoomSuppress=true; f.raidVisual.zoomSlider:SetValue(z); f.raidVisual.zoomSuppress=nil; f.raidVisual.zoomValue:SetText(string.format("%.2f",z)) end
    if f.raidText then
        for i=1,table.getn(f.raidText.healthButtons or {}) do b=f.raidText.healthButtons[i]; if b.mode==(SlamFramesDB.raidHealthTextMode or "percent") then b:Disable(); TintButton(b,true) else b:Enable(); TintButton(b,false) end end
        local nx=tonumber(SlamFramesDB.raidNameOffset) or 0; f.raidText.nameSuppress=true; f.raidText.nameSlider:SetValue(nx); f.raidText.nameSuppress=nil; f.raidText.nameValue:SetText(tostring(nx))
        if f.raidText.classNames then f.raidText.classNames:SetText("Class-colored Names: "..(SlamFramesDB.raidClassColoredNames and "ON" or "OFF")) end
        for i=1,table.getn(f.raidText.previewButtons or {}) do b=f.raidText.previewButtons[i]; if b.previewSize==(SlamFramesDB.raidPreviewSize or 20) then b:Disable(); TintButton(b,true) else b:Enable(); TintButton(b,false) end end
        if f.raidText.debuffPreview then f.raidText.debuffPreview:SetText("Test Debuffs: "..(SlamFramesDB.raidPreviewDebuffs and "ON" or "OFF")) end
        if f.raidText.mainTankPreview then f.raidText.mainTankPreview:SetText("Test Main Tanks: "..(SlamFramesDB.raidPreviewMainTanks and "ON" or "OFF")) end
        if f.raidText.debuffGlowSlider then
            local gv=tonumber(SlamFramesDB.raidDebuffGlowSize) or 2
            f.raidText.debuffGlowSuppress=true; f.raidText.debuffGlowSlider:SetValue(gv); f.raidText.debuffGlowSuppress=nil
            f.raidText.debuffGlowValue:SetText(tostring(math.floor(gv+.5)))
        end
    end

    if f.clickMain then
        f.clickMain.toggle:SetText("Click Casting: "..(SlamFramesDB.clickCastingEnabled and "ON" or "OFF"))
        f.clickMain.normal:SetText("Also Player / Target / ToT: "..(SlamFramesDB.clickCastingApplyNormal and "ON" or "OFF"))
        f.clickMain.tooltip:SetText("Binding Tooltip: "..(SlamFramesDB.clickCastingTooltip and "ON" or "OFF"))
    end
    if f.clickBindings and f.clickBindings.rows then
        local mod=f.clickBindingModifier or "none"
        if f.clickBindings.modifierButtons then
            for i=1,table.getn(f.clickBindings.modifierButtons) do
                local mb=f.clickBindings.modifierButtons[i]
                if mb.modifierKey==mod then mb:Disable(); TintButton(mb,true) else mb:Enable(); TintButton(mb,false) end
            end
        end
        for i=1,table.getn(f.clickBindings.rows) do
            local row=f.clickBindings.rows[i]
            local bind=SF:GetClickBinding(mod,row.buttonKey)
            if bind then
                local action=bind.action or "normal"
                local labels={normal="Normal",spell="Cast Spell",item="Use Item",target="Target Unit",menu="Unit Menu",none="Disabled"}
                row.action:SetText(labels[action] or "Normal")
                if action~="normal" then TintButton(row.action,true) else TintButton(row.action,false) end
                row.spell.modifierKey=mod
                local fieldActive=(action=="spell" or action=="item")
                row.spell:EnableMouse(fieldActive and true or false)
                row.spell:SetAlpha(fieldActive and 1.00 or 0.38)
                if fieldActive then row.spell:SetTextColor(1.00,1.00,1.00) else row.spell:SetTextColor(0.66,0.66,0.66) end
                if row.spell.sfBG then
                    if fieldActive then row.spell.sfBG:SetVertexColor(0.025,0.025,0.025,0.94)
                    else row.spell.sfBG:SetVertexColor(0.025,0.025,0.025,0.55) end
                end
                if not (row.spell.HasFocus and row.spell:HasFocus()) then
                    if fieldActive then row.spell:SetText(bind.spell or "") else row.spell:SetText("") end
                end
            end
        end
    end
    if f.clickDebuffs then
        f.clickDebuffs.toggle:SetText("Visual Alerts: "..(SlamFramesDB.partyDebuffAlerts and "ON" or "OFF"))
        f.clickDebuffs.filter:SetText(SlamFramesDB.partyDebuffOnlyDispellable and "Filter: DISPELLABLE BY ME" or "Filter: ALL DEBUFFS")
        f.clickDebuffs.message:SetText("Screen Message: "..(SlamFramesDB.partyDebuffMessage and "ON" or "OFF"))
        f.clickDebuffs.sound:SetText("Alert Sound: "..(SlamFramesDB.partyDebuffSound and "ON" or "OFF"))
    end

    if f.effectsRest then f.effectsRest.toggle:SetText("Resting FX: "..(SlamFramesDB.showRestingEffect and "ON" or "OFF")) end
    if f.effectsCombat then
        f.effectsCombat.toggle:SetText("Combat Glow: "..(SlamFramesDB.showCombatGlow and "ON" or "OFF"))
        local v=tonumber(SlamFramesDB.combatGlowIntensity) or 1.30
        if v<0.50 then v=0.50 elseif v>2.00 then v=2.00 end
        if f.effectsCombat.intensitySlider then
            f.effectsCombat.intensitySuppress=true
            f.effectsCombat.intensitySlider:SetValue(v)
            f.effectsCombat.intensitySuppress=nil
            f.effectsCombat.intensityValue:SetText(tostring(math.floor(v*100+0.5)).."%")
            f.effectsCombat.intensityFill:SetWidth(math.max(1,f.effectsCombat.intensitySlider:GetWidth()*((v-0.50)/1.50)))
        end
    end
    if f.effectsCC then
        f.effectsCC.toggle:SetText("CC Alerts: "..(SlamFramesDB.showCCEffect and "ON" or "OFF"))
        if f.effectsCC.move then f.effectsCC.move:SetText(SF.ccMoveMode and "Done Moving CC" or "Move CC Alert") end
    end

    if f.castbarMain then
        f.castbarMain.toggle:SetText("Player Cast Bar: "..(SlamFramesDB.showPlayerCastbar and "ON" or "OFF"))
        f.castbarMain.blizz:SetText("Hide Blizzard Bar: "..(SlamFramesDB.hideBlizzardCastbar and "ON" or "OFF"))
        f.castbarMain.icon:SetText("Spell Icon: "..(SlamFramesDB.castbarShowIcon and "ON" or "OFF"))
        f.castbarMain.timer:SetText("Timer: "..(SlamFramesDB.castbarShowTimer and "ON" or "OFF"))
        f.castbarMain.latency:SetText("Latency Zone: "..(SlamFramesDB.castbarShowLatency and "ON" or "OFF"))
    end
    if f.castbarErrors and f.castbarErrors.toggle then
        f.castbarErrors.toggle:SetText("Red Error Text: "..(SlamFramesDB.hideBlizzardErrorText and "HIDDEN" or "SHOWN"))
    end
    if f.castbarScaleRow and f.castbarScaleRow.value then f.castbarScaleRow.value:SetText(string.format("%.2f",SlamFramesDB.castbarScale or .80)) end
    if f.castbarLayout then
        local w=tonumber(SlamFramesDB.castbarWidth) or 360
        f.castbarLayout.widthSuppress=true
        f.castbarLayout.widthSlider:SetValue(w)
        f.castbarLayout.widthSuppress=nil
        f.castbarLayout.widthValue:SetText(tostring(w))
        f.castbarLayout.widthFill:SetWidth(math.max(1,f.castbarLayout.widthSlider:GetWidth()*((w-260)/280)))
        f.castbarLayout.move:SetText(SF.castbarMoveMode and "Done Moving" or "Move Cast Bar")
    end
    if f.test then f.test:SetText(SF.testMode and "Hide Test" or "Test Frames") end
end

function SF:ToggleSettings()
    if not self.settings then self:CreateSettingsPanel() end
    if self.settings:IsShown() then self.settings:Hide()
    else self:RefreshSettings(); self.settings:Show() end
end
