-- SlamFrames v0.19.16 - Light / Dark skin controller
-- Dark: SlamFrames artwork is recolored to neutral graphite/grey-black metal so
-- it blends into the user's existing dark action-bar/minimap aesthetic.
-- Light: original bright-gold SlamFrames artwork. The native minimap and action-bar
-- artwork receive the same mild warm tint, but action-button outlines, XP/action-bar
-- accent rails, minimap outline rings and addon-button rings stay disabled.

local SF=SlamFrames
local C=SlamFrames_Config
local TEX=C.texturePath

local SKINNED={
    ["player_frame.tga"]=true,
    ["target_frame.tga"]=true,
    ["tot_frame.tga"]=true,
    ["aura_border.tga"]=true,
    ["level_badge.tga"]=true,
    ["castbar_frame.tga"]=true,
}

function SF:GetSkinTexture(file)
    file=file or ""
    local skin=(SlamFramesDB and SlamFramesDB.skin) or "dark"
    if skin=="dark" and SKINNED[file] then
        return TEX.."Dark\\"..file
    end
    return TEX..file
end

local function SetTextureSafe(tex,path)
    if tex and tex.SetTexture then pcall(function() tex:SetTexture(path) end) end
end

local function RefreshUnitFrame(frame)
    if not frame or not frame.cfg then return end
    local path=SF:GetSkinTexture(frame.cfg.frame)
    if frame.art then
        if frame.art.single then SetTextureSafe(frame.art.single,path) end
        if frame.art.left then SetTextureSafe(frame.art.left,path) end
        if frame.art.middle then SetTextureSafe(frame.art.middle,path) end
        if frame.art.right then SetTextureSafe(frame.art.right,path) end
    end
    if frame.levelBadgeTexture then SetTextureSafe(frame.levelBadgeTexture,SF:GetSkinTexture(C.levelBadgeTexture or "level_badge.tga")) end
end

function SF:RefreshSkinTextures()
    RefreshUnitFrame(self.player)
    RefreshUnitFrame(self.target)
    RefreshUnitFrame(self.tot)

    if self.auras then
        local i
        for i=1,table.getn(self.auras) do
            if self.auras[i] and self.auras[i].border then
                SetTextureSafe(self.auras[i].border,self:GetSkinTexture("aura_border.tga"))
            end
        end
    end

    if self.ccAlert and self.ccAlert.iconBorder then
        SetTextureSafe(self.ccAlert.iconBorder,self:GetSkinTexture("aura_border.tga"))
    end

    -- Status-effect rings intentionally follow the selected metal skin while
    -- their vertex colors still communicate resting/combat/CC state.
    if self.player then
        local ring=self:GetSkinTexture(C.levelBadgeTexture or "level_badge.tga")
        if self.player.restGlow then SetTextureSafe(self.player.restGlow,ring) end
        if self.player.combatGlow then SetTextureSafe(self.player.combatGlow,ring) end
        if self.player.ccGlow then SetTextureSafe(self.player.ccGlow,ring) end
    end

    -- CastBar:SetSlice and its icon border are skin-aware; relayout refreshes
    -- those textures without changing saved cast-bar geometry.
    if self.castbar and self.LayoutCastBar then self:LayoutCastBar() end
end

local function AddOverlayToButton(button,index)
    if not button or not button.CreateTexture then return nil end
    if button.SlamFramesLightSkinOverlay then return button.SlamFramesLightSkinOverlay end
    local t=button:CreateTexture(nil,"OVERLAY")
    t:SetTexture(TEX.."aura_border.tga")
    t:SetPoint("TOPLEFT",button,"TOPLEFT",-4,4)
    t:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",4,-4)
    t:SetAlpha(0.95)
    t:Hide()
    button.SlamFramesLightSkinOverlay=t
    return t
end

local function AddRingToFrame(frame,large)
    if not frame or not frame.CreateTexture then return nil end
    if frame.SlamFramesLightSkinRing then return frame.SlamFramesLightSkinRing end
    local t=frame:CreateTexture(nil,"OVERLAY")
    if large then t:SetTexture(TEX.."Light\\minimap_ring.tga")
    else t:SetTexture(TEX.."Light\\minimap_button_ring.tga") end
    t:SetPoint("CENTER",frame,"CENTER",0,0)
    if large then
        local w=(frame.GetWidth and frame:GetWidth()) or 140
        local h=(frame.GetHeight and frame:GetHeight()) or 140
        t:SetWidth(w+30); t:SetHeight(h+30)
    else
        local w=(frame.GetWidth and frame:GetWidth()) or 32
        local h=(frame.GetHeight and frame:GetHeight()) or 32
        t:SetWidth(w+10); t:SetHeight(h+10)
    end
    t:Hide()
    frame.SlamFramesLightSkinRing=t
    return t
end

local ACTION_PREFIXES={
    "ActionButton",
    "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton",
    "MultiBarRightButton",
    "MultiBarLeftButton",
    "BonusActionButton",
}


local LIGHT_TINT_NAMES={
    -- Keep the subtle warm coloration on the native minimap border.
    "MinimapBorder",

    -- Light mode also gives the native action-bar artwork the same gentle
    -- warm/gold cast. These are vertex tints only: no yellow icon frames and
    -- no extra top/bottom rails are drawn.
    "MainMenuBarTexture0","MainMenuBarTexture1","MainMenuBarTexture2","MainMenuBarTexture3",
    "MainMenuBarLeftEndCap","MainMenuBarRightEndCap",
    "BonusActionBarTexture0","BonusActionBarTexture1",
}

local function ApplyNamedTint(show)
    if not SF.skinOriginalVertex then SF.skinOriginalVertex={} end
    local i,obj,r,g,b,a
    for i=1,table.getn(LIGHT_TINT_NAMES) do
        obj=_G and _G[LIGHT_TINT_NAMES[i]]
        if obj and obj.SetVertexColor then
            if not SF.skinOriginalVertex[obj] then
                if obj.GetVertexColor then
                    local ok,rr,gg,bb,aa=pcall(function() return obj:GetVertexColor() end)
                    if ok then SF.skinOriginalVertex[obj]={rr or 1,gg or 1,bb or 1,aa or 1} else SF.skinOriginalVertex[obj]={1,1,1,1} end
                else
                    SF.skinOriginalVertex[obj]={1,1,1,1}
                end
            end
            if show then
                pcall(function() obj:SetVertexColor(1.00,0.88,0.48,1.00) end)
            else
                local c=SF.skinOriginalVertex[obj]
                pcall(function() obj:SetVertexColor(c[1],c[2],c[3],c[4]) end)
            end
        end
    end
end

local MINIMAP_BUTTONS={
    "MinimapZoomIn",
    "MinimapZoomOut",
    "MiniMapTrackingButton",
    "MiniMapBattlefieldFrame",
    "MiniMapMailFrame",
    "GameTimeFrame",
    "SlamFramesMinimapButton",
}

function SF:CreateExternalSkinOverlays()
    if not self.skinActionOverlays then self.skinActionOverlays={} end
    if not self.skinMinimapOverlays then self.skinMinimapOverlays={} end

    local p,i,name,b,o
    for p=1,table.getn(ACTION_PREFIXES) do
        for i=1,12 do
            name=ACTION_PREFIXES[p]..i
            b=_G and _G[name]
            if b then
                o=AddOverlayToButton(b,i)
                if o and not b.SlamFramesLightSkinTracked then
                    self.skinActionOverlays[table.getn(self.skinActionOverlays)+1]=o
                    b.SlamFramesLightSkinTracked=true
                end
            end
        end
    end

    -- Stance and pet buttons are also part of the action-bar visual cluster.
    for i=1,10 do
        b=_G and _G["ShapeshiftButton"..i]
        if b then
            o=AddOverlayToButton(b,i)
            if o and not b.SlamFramesLightSkinTracked then self.skinActionOverlays[table.getn(self.skinActionOverlays)+1]=o; b.SlamFramesLightSkinTracked=true end
        end
        b=_G and _G["PetActionButton"..i]
        if b then
            o=AddOverlayToButton(b,i)
            if o and not b.SlamFramesLightSkinTracked then self.skinActionOverlays[table.getn(self.skinActionOverlays)+1]=o; b.SlamFramesLightSkinTracked=true end
        end
    end

    -- v0.19.16: do not draw any extra rings around the minimap or its buttons.
    -- The light skin now relies only on a subtle vertex tint of the native
    -- MinimapBorder, which avoids the hard outline around both the map and the
    -- SlamFrames launcher icon.
    if self.skinMinimapOverlays then
        local j
        for j=1,table.getn(self.skinMinimapOverlays) do self.skinMinimapOverlays[j]:Hide() end
    end

    -- v0.19.16: no extra top/bottom action-bar rails. The broad native
    -- action-bar vertex tint is handled separately by ApplyNamedTint so the
    -- bar keeps its Light-theme coloration without hard yellow lines.
    if self.skinMainBarAccent then self.skinMainBarAccent:Hide() end
end

function SF:ApplyExternalUISkin()
    self:CreateExternalSkinOverlays()
    local show=(SlamFramesDB and SlamFramesDB.skin=="light") and true or false
    local i
    -- Light skin keeps action-button icon overlays disabled. The action bar
    -- itself is colored only through the native-art vertex tint below.
    if self.skinActionOverlays then
        for i=1,table.getn(self.skinActionOverlays) do
            self.skinActionOverlays[i]:Hide()
        end
    end
    if self.skinMinimapOverlays then
        for i=1,table.getn(self.skinMinimapOverlays) do
            self.skinMinimapOverlays[i]:Hide()
        end
    end
    if self.skinMainBarAccent then self.skinMainBarAccent:Hide() end
    ApplyNamedTint(show)
end

function SF:ApplySkin(quiet)
    if not SlamFramesDB then return end
    if SlamFramesDB.skin~="light" and SlamFramesDB.skin~="dark" then SlamFramesDB.skin="dark" end
    self:RefreshSkinTextures()
    self:ApplyExternalUISkin()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then self.Print((SlamFramesDB.skin=="light" and "Light" or "Dark").." skin applied.") end
end

function SF:SetSkin(name,quiet)
    name=string.lower(name or "")
    if name~="light" and name~="dark" then return false end
    SlamFramesDB.skin=name
    self:ApplySkin(quiet)
    return true
end
