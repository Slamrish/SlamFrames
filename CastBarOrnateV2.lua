-- SlamFrames TEST 18 - rollback to stable cast states + corrected Ornate right boundaries.
-- Shared behavior fixes live in SharedCastBarFixes.lua so all cast-bar styles
-- inherit the same spell-name, interrupt, and recast behavior.
-- OctoWoW / Vanilla 1.12 compatible.

local SF=SlamFrames
local C=SlamFrames_Config
if not SF or not C or not C.castbar then return end
local CB=C.castbar
local TEX=C.texturePath

local function Clamp(v,lo,hi)
    v=tonumber(v) or lo
    if v<lo then return lo end
    if v>hi then return hi end
    return v
end

local function Round(v)
    return math.floor((tonumber(v) or 0)+0.5)
end

local ORNATE={
    frameTexture="castbar2_frame.tga", -- Light/root; Dark lives in Dark\\
    iconBorderTexture="castbar2_icon.tga",
    bodyHeight=58,
    iconSize=78,
    iconInset=12,
    bodyX=64,
    bodyWidthFactor=1.08,
    leftCap=42,
    rightCap=118,
    leftSliceU=0.10,
    rightSliceU=0.76,
    -- TEST 15: align the fill with the visible left edge of the inner track.
    -- 22 left a noticeable dead strip after the icon/bevel; 8 keeps the fill
    -- inside the artwork while letting a new cast begin where the track begins.
    fillLeft=8,
    -- TEST 25: keep the full cast inside the visible Ornate right bevel.
    -- 12 was visually a few pixels too long at the normal in-game scale; 20
    -- preserves the full-width look while ending cleanly inside the artwork.
    fillRight=20,
    -- TEST 27: keep a small failure-only safety inset without leaving a
    -- visible dead strip at the right side of the Ornate track. Normal casts
    -- still use fillRight; red failures stop only slightly earlier.
    failRightInset=8,
    fillBottom=12,
    fillHeight=34,
    nameFont=17,
    timerFont=16,
    nameTextInset=28,
    timerTextInset=32,
    latencyAlpha=0.82,
    latencyEdge=true,
}
CB.styles=CB.styles or {}
CB.styles[2]=ORNATE

local function IsOrnate()
    return SlamFramesDB and tonumber(SlamFramesDB.castbarStyle)==2
end

local function SkinName()
    if SlamFramesDB and SlamFramesDB.skin=="light" then return "light" end
    return "dark"
end

local ORNATE_ASSETS={
    frame="castbar2_frame.tga",
    icon="castbar2_icon.tga",
    fill="castbar2_fill.tga",
    latency="castbar2_latency.tga",
}

-- Match SlamFrames Style 1 skin conventions exactly: the Light artwork lives
-- in the addon root, while Dark artwork with the same filename lives in Dark\.
-- Keeping the filenames identical prevents the two cast-bar styles from
-- developing separate skin-selection rules again.
local function Asset(kind)
    local file=ORNATE_ASSETS[kind]
    if not file then return nil end

    -- Match Style 1's theme behavior: only the decorative metal/frame pieces
    -- change with Light/Dark. The progress fill, dark bar interior treatment,
    -- latency colors, and cast text remain visually identical in both themes.
    if kind=="frame" or kind=="icon" then
        if SkinName()=="dark" then return TEX.."Dark\\"..file end
        return TEX..file
    end

    return TEX..file
end

local function IsGenericCastName(name)
    if SF.IsGenericCastDisplayName then return SF.IsGenericCastDisplayName(name) end
    local low=string.lower(tostring(name or ""))
    return low=="open" or low=="opening" or low=="cast" or low=="casting"
        or low=="channel" or low=="channeling" or low=="spell"
end

local function SafeDisplayName(name)
    if SF.NormalizeCastDisplayName then return SF.NormalizeCastDisplayName(name) end
    if not name or name=="" then return nil end
    local low=string.lower(tostring(name))
    if low=="open" or low=="opening" then return "Using" end
    if IsGenericCastName(name) then return nil end
    return name
end

local function SetSlice(tex,path,u1,u2)
    tex:SetTexture(path)
    tex:SetTexCoord(u1,u2,0,1)
end

local function EnsureSubtext(cb)
    if cb.subtext then return end
    cb.subtext=cb:CreateFontString(nil,"OVERLAY")
    cb.subtext:SetFont("Fonts\\MORPHEUS.TTF",14,"OUTLINE")
    cb.subtext:SetJustifyH("CENTER")
    cb.subtext:SetShadowColor(0,0,0,1)
    cb.subtext:SetShadowOffset(1,-1)
    cb.subtext:SetText("")
    cb.subtext:Hide()
end


local function IsFrameShown(frame)
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

local function CurrentTradeSkillActivity()
    local tradeOpen=IsFrameShown(TradeSkillFrame) or IsFrameShown(CraftFrame)
    if not tradeOpen then return nil end

    local profession=nil
    if type(GetTradeSkillLine)=="function" then
        local ok,name=pcall(GetTradeSkillLine)
        if ok and name and name~="" then profession=name end
    end
    if (not profession or profession=="") and type(GetCraftName)=="function" then
        local ok,name=pcall(GetCraftName)
        if ok and name and name~="" then profession=name end
    end

    local low=string.lower(tostring(profession or ""))
    if string.find(low,"cooking",1,true) then return "Cooking" end
    if string.find(low,"fishing",1,true) then return "Fishing" end
    -- For the rest of the profession windows, the flavor line is deliberately
    -- generic. The actual recipe/item name remains in the main cast-bar label.
    return "Crafting"
end

local function IsTradeSkillCast()
    if C_Spell and type(C_Spell.UnitCastingInfo)=="function" then
        local ok,_,_,_,_,_,isTradeskill=pcall(C_Spell.UnitCastingInfo,"player")
        if ok and isTradeskill then return true end
    end
    return false
end

local function SelectedProfessionRecipeMatches(spellName)
    if not spellName or spellName=="" then return false end
    local wanted=string.lower(tostring(spellName))

    if IsFrameShown(TradeSkillFrame) and type(GetTradeSkillSelectionIndex)=="function" and type(GetTradeSkillInfo)=="function" then
        local okIndex,index=pcall(GetTradeSkillSelectionIndex)
        if okIndex and index and index>0 then
            local okInfo,name=pcall(GetTradeSkillInfo,index)
            if okInfo and name and string.lower(tostring(name))==wanted then return true end
        end
    end

    if IsFrameShown(CraftFrame) and type(GetCraftSelectionIndex)=="function" and type(GetCraftInfo)=="function" then
        local okIndex,index=pcall(GetCraftSelectionIndex)
        if okIndex and index and index>0 then
            local okInfo,name=pcall(GetCraftInfo,index)
            if okInfo and name and string.lower(tostring(name))==wanted then return true end
        end
    end
    return false
end

local function DetectCastActivity(spellName)
    local low=string.lower(tostring(spellName or ""))
    if low=="fishing" or string.find(low,"fishing",1,true) then return "Fishing" end
    if low=="cooking" then return "Cooking" end

    local tradeActivity=CurrentTradeSkillActivity()
    -- Prefer the engine's explicit tradeskill flag. On older clients that do
    -- not expose it, match the active recipe against the current cast name.
    if IsTradeSkillCast() then return tradeActivity or "Crafting" end
    if tradeActivity and SelectedProfessionRecipeMatches(spellName) then return tradeActivity end

    -- Object-use fallback should never inherit the selected unit as a target.
    if low=="using" or low=="open" or low=="opening" then return "Using" end
    return nil
end

function SF:SetCastBarFlavorTextEnabled(v,quiet)
    if not SlamFramesDB then return end
    SlamFramesDB.castbarFlavorTextEnabled=v and true or false
    if self.castbar and self.castbar.subtext then
        if SlamFramesDB.castbarFlavorTextEnabled then
            self:RefreshOrnateCastSubtext()
        else
            self.castbar.subtext:Hide()
        end
    end
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("Ornate flavor text "..(SlamFramesDB.castbarFlavorTextEnabled and "ON" or "OFF")..".") end
end

function SF:SetCastBarFlavorTextScale(v,quiet)
    if not SlamFramesDB then return end
    v=Clamp(tonumber(v) or 1.00,0.60,2.00)
    v=math.floor(v*20+0.5)/20
    SlamFramesDB.castbarFlavorTextScale=v
    if self.castbar and self.LayoutCastBar then self:LayoutCastBar() end
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print("Ornate flavor text size set to "..tostring(math.floor(v*100+0.5)).."%.") end
end

local function ResolveCastTarget(spellName)
    -- HealComm has the most reliable friendly-target name for healing casts.
    if SF.HealComm and SF.HealComm.SpellCastInfo and SF.HealComm.SpellCastInfo[3] then
        local hcSpell=SF.HealComm.SpellCastInfo[1]
        if not hcSpell or not spellName or hcSpell==spellName then
            return SF.HealComm.SpellCastInfo[3]
        end
    end
    if UnitExists("target") then
        local n=UnitName("target")
        if n and n~="" then return n end
    end
    return nil
end

function SF:RefreshOrnateCastSubtext(label,targetName,forceState)
    local cb=self.castbar
    if not cb then return end
    EnsureSubtext(cb)
    if not IsOrnate() or not cb:IsShown() then cb.subtext:Hide(); return end
    if SlamFramesDB and SlamFramesDB.castbarFlavorTextEnabled==false then cb.subtext:Hide(); return end

    local state=forceState
    if not state then
        if cb.failure then state="failure"
        elseif cb.isChannel then state="channel"
        else state="cast" end
    end

    local spell=label or cb.sfStableDisplayName or cb.castDisplayName or (cb.name and cb.name:GetText()) or ""
    if IsGenericCastName(spell) then spell=cb.sfStableDisplayName or SafeDisplayName(spell) or "Using" end
    if spell=="" then spell="Using" end
    local txt
    if state=="failure" then
        txt=spell
    else
        -- Profession/activity casts intentionally ignore the currently selected
        -- NPC/player. The recipe/item name stays in the main bar while this
        -- lower line becomes a clean activity label: Cooking/Fishing/Crafting.
        local activity=cb.sfCastActivity or DetectCastActivity(spell)
        if activity then
            cb.sfCastActivity=activity
            cb.sfCastTarget=nil
            txt=activity
        else
            local verb=(state=="channel") and "Channeling" or "Casting"
            local target=targetName or cb.sfCastTarget or ResolveCastTarget(spell)
            cb.sfCastTarget=target
            if target and target~="" then txt=verb.." "..spell.." on "..target.."..."
            else txt=verb.." "..spell.."..." end
        end
    end
    cb.subtext:SetText(txt)
    cb.subtext:Show()
end

local PreviousLayoutCastBar=SF.LayoutCastBar
function SF:LayoutCastBar()
    local cb=self.castbar
    if not cb then return end
    EnsureSubtext(cb)

    if not IsOrnate() then
        -- Style 2 changes the live fill texture, so explicitly restore Style 1
        -- before handing layout back to the existing proven implementation.
        if cb.fill then cb.fill:SetTexture(TEX..(CB.fillTexture or "cast_fill.tga")) end
        if cb.name then cb.name:SetTextColor(0.96,0.94,0.90) end
        if cb.timer then cb.timer:SetTextColor(0.96,0.94,0.90) end
        cb.subtext:SetText(""); cb.subtext:Hide()
        return PreviousLayoutCastBar(self)
    end

    local style=ORNATE
    local scale=Clamp(SlamFramesDB.castbarScale or 0.80,0.50,1.60)
    local bodyW=Clamp(SlamFramesDB.castbarWidth or 360,260,540)*scale*(style.bodyWidthFactor or 1.00)
    local bodyH=style.bodyHeight*scale
    local iconSize=style.iconSize*scale
    local showIcon=SlamFramesDB.castbarShowIcon and true or false
    local bodyX=showIcon and (style.bodyX*scale) or 0
    local totalW=bodyX+bodyW
    local totalH=math.max(iconSize,bodyH)
    local capL=style.leftCap*scale
    local capR=style.rightCap*scale
    local uLeft=style.leftSliceU
    local uRight=style.rightSliceU

    cb.layoutScale=scale
    cb.styleNumber=2
    cb.style=style
    cb.bodyWidth=bodyW

    local framePath=Asset("frame")
    SetSlice(cb.body.left,framePath,0,uLeft)
    SetSlice(cb.body.middle,framePath,uLeft,uRight)
    SetSlice(cb.body.right,framePath,uRight,1)
    cb.iconBorder:SetTexture(Asset("icon"))
    cb.fill:SetTexture(Asset("fill")); cb.fill:SetTexCoord(0,1,0,1)
    cb.latency:SetTexture(Asset("latency")); cb.latency:SetAlpha(style.latencyAlpha)

    cb:SetWidth(totalW); cb:SetHeight(totalH)

    cb.iconFrame:ClearAllPoints(); cb.iconFrame:SetPoint("LEFT",cb,"LEFT",0,0)
    cb.iconFrame:SetWidth(iconSize); cb.iconFrame:SetHeight(iconSize)
    if showIcon then cb.iconFrame:Show() else cb.iconFrame:Hide() end
    local iconInset=style.iconInset*scale
    cb.icon:ClearAllPoints(); cb.icon:SetPoint("TOPLEFT",cb.iconFrame,"TOPLEFT",iconInset,-iconInset)
    cb.icon:SetPoint("BOTTOMRIGHT",cb.iconFrame,"BOTTOMRIGHT",-iconInset,iconInset)
    cb.iconBorder:SetAllPoints(cb.iconFrame)

    cb.body:ClearAllPoints(); cb.body:SetPoint("LEFT",cb,"LEFT",bodyX,0)
    cb.body:SetWidth(bodyW); cb.body:SetHeight(bodyH)
    cb.body.left:ClearAllPoints(); cb.body.left:SetPoint("LEFT",cb.body,"LEFT",0,0); cb.body.left:SetWidth(capL); cb.body.left:SetHeight(bodyH)
    cb.body.right:ClearAllPoints(); cb.body.right:SetPoint("RIGHT",cb.body,"RIGHT",0,0); cb.body.right:SetWidth(capR); cb.body.right:SetHeight(bodyH)
    cb.body.middle:ClearAllPoints(); cb.body.middle:SetPoint("LEFT",cb.body.left,"RIGHT",0,0); cb.body.middle:SetPoint("RIGHT",cb.body.right,"LEFT",0,0); cb.body.middle:SetHeight(bodyH)

    local insetL=style.fillLeft*scale
    local insetR=style.fillRight*scale
    local fillBottom=style.fillBottom*scale
    local fillH=style.fillHeight*scale
    cb.innerX=insetL
    cb.innerW=math.max(20,bodyW-insetL-insetR)
    cb.innerY=fillBottom
    cb.innerH=fillH

    cb.fill:ClearAllPoints(); cb.fill:SetPoint("BOTTOMLEFT",cb.body,"BOTTOMLEFT",insetL,fillBottom); cb.fill:SetHeight(fillH)
    cb.latency:SetHeight(fillH)
    cb.latencyEdge:SetWidth(math.max(1,2*scale)); cb.latencyEdge:SetHeight(fillH)
    cb.spark:SetWidth(math.max(1,2*scale)); cb.spark:SetHeight(fillH+3*scale)
    cb.spark:SetVertexColor(1.00,0.92,0.56,1.00)

    -- Text sits vertically centered inside the tall filled track. The timer is
    -- anchored inside the large fixed right cap, matching the approved mockup.
    local nameInset=style.nameTextInset*scale
    local timerInset=style.timerTextInset*scale
    local timerW=96*scale
    cb.name:ClearAllPoints(); cb.name:SetPoint("LEFT",cb.body,"LEFT",nameInset,0)
    cb.name:SetWidth(math.max(60,bodyW-nameInset-capR-(12*scale))); cb.name:SetHeight(28*scale)
    cb.timer:ClearAllPoints(); cb.timer:SetPoint("RIGHT",cb.body,"RIGHT",-timerInset,0)
    cb.timer:SetWidth(timerW); cb.timer:SetHeight(28*scale)
    cb.name:SetFont("Fonts\\FRIZQT__.TTF",math.max(9,Round(style.nameFont*scale)),"OUTLINE")
    cb.timer:SetFont("Fonts\\FRIZQT__.TTF",math.max(9,Round(style.timerFont*scale)),"OUTLINE")

    -- Style 1 keeps its cast fill/text treatment when the metal skin changes.
    -- Ornate now behaves the same way: Light/Dark only swaps the decorative
    -- frame, while the bar text stays the same readable warm-white color.
    cb.name:SetTextColor(0.98,0.95,0.86)
    cb.timer:SetTextColor(0.98,0.95,0.86)
    -- Cast description must stay readable against the 3D world, not just the
    -- selected UI skin. Use pure white in both themes with the existing black
    -- outline/shadow rather than tinting it blue/grey or brown.
    cb.subtext:SetTextColor(1.00,1.00,1.00)

    local flavorScale=Clamp((SlamFramesDB and SlamFramesDB.castbarFlavorTextScale) or 1.00,0.60,2.00)
    cb.subtext:ClearAllPoints(); cb.subtext:SetPoint("TOP",cb.body,"BOTTOM",0,-7*scale)
    cb.subtext:SetWidth(math.max(160,totalW)); cb.subtext:SetHeight(math.max(24*scale,28*scale*flavorScale))
    cb.subtext:SetFont("Fonts\\MORPHEUS.TTF",math.max(8,Round(14*scale*flavorScale)),"OUTLINE")

    cb.moveLabel:ClearAllPoints(); cb.moveLabel:SetPoint("BOTTOM",cb,"TOP",0,5*scale)
    cb.moveLabel:SetFont("Fonts\\FRIZQT__.TTF",math.max(8,Round(13*scale)),"OUTLINE")

    self:ApplyCastBarAnchor()
    self:RenderCastBar()
    if cb:IsShown() then self:RefreshOrnateCastSubtext() else cb.subtext:Hide() end
end

-- Keep the approved descriptive line synchronized with real casts.
-- SharedCastBarFixes.lua already owns failure reset + stable spell-name state.
local PreviousStartCastBar=SF.StartCastBar
function SF:StartCastBar(name,texture,startTime,endTime,isChannel,source,spellID)
    PreviousStartCastBar(self,name,texture,startTime,endTime,isChannel,source,spellID)
    local cb=self.castbar
    if not cb or not IsOrnate() then return end
    local safe=cb.sfStableDisplayName or SafeDisplayName(name) or "Using"
    cb.sfCastActivity=DetectCastActivity(safe)
    if cb.sfCastActivity then cb.sfCastTarget=nil else cb.sfCastTarget=ResolveCastTarget(safe) end
    self:RefreshOrnateCastSubtext(safe,cb.sfCastTarget,isChannel and "channel" or "cast")
end

local PreviousFailCastBar=SF.FailCastBar
function SF:FailCastBar(label)
    PreviousFailCastBar(self,label)
    if self.castbar and IsOrnate() then
        self:RefreshOrnateCastSubtext(label or "INTERRUPTED",nil,"failure")
    end
end

local PreviousClearCastBar=SF.ClearCastBar
function SF:ClearCastBar(immediate)
    PreviousClearCastBar(self,immediate)
    if self.castbar then
        self.castbar.sfCastTarget=nil
        self.castbar.sfCastActivity=nil
        if immediate and self.castbar.subtext then self.castbar.subtext:Hide() end
    end
end

-- Style 2 reconciliation ------------------------------------------------------
-- The stock renderer is shared with Style 1.  After it performs timing/math,
-- clamp Style 2's failure fill to the visible inner track and replace the
-- stretched latency texture with a single clean marker that can never leave
-- the frame artwork.
local PreviousRenderCastBar=SF.RenderCastBar
function SF:RenderCastBar()
    PreviousRenderCastBar(self)
    local cb=self.castbar
    if not cb or not IsOrnate() or not cb:IsShown() then return end
    local scale=cb.layoutScale or 1

    -- INTERRUPTED/FAILED intentionally render as a full bar, but Style 2's
    -- outer frame has a beveled right lip.  Keep that full-state animation
    -- inside the lip rather than allowing the fill to touch/cover the artwork.
    if cb.failure and cb.fill then
        -- Normal casts intentionally run almost the full usable track. Failure
        -- states use their own tighter end point because the solid red full-bar
        -- animation reads wider and can visually cover the ornate right bevel.
        local failureRightPad=(ORNATE.failRightInset or 18)*scale
        local failureW=math.max(0.5,(cb.innerW or 1)-failureRightPad)
        cb.fill:SetWidth(failureW)
        cb.fill:SetTexCoord(0,1,0,1)

        -- Failure has no moving cast edge. Explicitly suppress the spark and
        -- latency marker so neither can survive a state transition and appear
        -- outside the fail-specific boundary.
        if cb.spark then cb.spark:Hide() end
        if cb.latency then cb.latency:Hide() end
        if cb.latencyEdge then cb.latencyEdge:Hide() end
    end

    -- Style 1's latency region is a stretched texture.  On the ornate artwork
    -- that reads as stray orange stripes and can overlap the bevel.  Style 2
    -- uses one narrow marker at the START of the latency window, entirely
    -- inside the progress track.
    if cb.latency then cb.latency:Hide() end
    if cb.latencyEdge then
        cb.latencyEdge:Hide()
        if SlamFramesDB.castbarShowLatency and not cb.failure then
            local duration=nil
            if cb.active and cb.startTime and cb.endTime then
                duration=math.max(.01,cb.endTime-cb.startTime)
            elseif cb.previewHold then
                duration=cb.previewDuration or 3
            end
            if duration then
                local lw=0
                if cb.previewHold then
                    lw=math.max(1,(cb.innerW or 1)*.14)
                elseif type(GetNetStats)=="function" then
                    local _,_,lagMs=GetNetStats()
                    local lag=(tonumber(lagMs) or 0)/1000
                    lw=math.min((cb.innerW or 1)*.45,(cb.innerW or 1)*(lag/duration))
                end
                if lw>=1 then
                    local rightSafe=4*scale
                    local x
                    if cb.isChannel then
                        x=(cb.innerX or 0)+math.min((cb.innerW or 1)-rightSafe,lw)
                    else
                        x=(cb.innerX or 0)+math.max(0,(cb.innerW or 1)-lw-rightSafe)
                    end
                    cb.latencyEdge:ClearAllPoints()
                    cb.latencyEdge:SetPoint("BOTTOMLEFT",cb.body,"BOTTOMLEFT",x,(cb.innerY or 0)+(2*scale))
                    cb.latencyEdge:SetWidth(math.max(1,2*scale))
                    cb.latencyEdge:SetHeight(math.max(1,(cb.innerH or 1)-(4*scale)))
                    cb.latencyEdge:SetVertexColor(1.00,0.20,0.04,0.95)
                    cb.latencyEdge:Show()
                end
            end
        end
    end
end

local PreviousPreviewCastBar=SF.PreviewCastBar
function SF:PreviewCastBar(kind)
    PreviousPreviewCastBar(self,kind)
    if not IsOrnate() or not self.castbar then return end
    local cb=self.castbar
    if kind=="cast" or kind=="move" then
        -- Reference preview uses the exact visual language that was approved;
        -- live casts immediately replace these values with real spell data.
        cb.name:SetText("Flash Heal")
        cb.castDisplayName="Flash Heal"
        cb.sfStableDisplayName="Flash Heal"
        cb.icon:SetTexture("Interface\\Icons\\Spell_Holy_FlashHeal")
        cb.sfCastActivity=nil
        cb.sfCastTarget="Gorath"
        self:RefreshOrnateCastSubtext("Flash Heal","Gorath","cast")
    elseif kind=="channel" then
        self:RefreshOrnateCastSubtext("Drain Life",ResolveCastTarget("Drain Life"),"channel")
    end
    self:RenderCastBar()
end

-- Skin.lua already relayouts the cast bar when the global skin changes.  Keep
-- one final safety hook here as well so Style 2 is refreshed immediately after
-- an in-settings Light/Dark click even on older OctoWoW clients/addon load
-- orders where RefreshSkinTextures is delayed.
if SF.SetSkin and not SF._ornateSkinRefreshHooked then
    SF._ornateSkinRefreshHooked=true
    local PreviousSetSkin=SF.SetSkin
    function SF:SetSkin(name,quiet)
        local ok=PreviousSetSkin(self,name,quiet)
        if ok and self.castbar and self.LayoutCastBar then self:LayoutCastBar() end
        return ok
    end
end
