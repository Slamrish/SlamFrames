-- SlamFrames v0.15.0 - player status effects
-- Resting glow/Zzz, circular adjustable combat glow, and high-priority crowd-control notification with timer.

local SF = SlamFrames
local C = SlamFrames_Config
local TEX = C.texturePath

local function Lower(s)
    if not s then return "" end
    return string.lower(s)
end

local CC_EXACT = {
    ["hammer of justice"] = "STUNNED",
    ["kidney shot"] = "STUNNED",
    ["cheap shot"] = "STUNNED",
    ["bash"] = "STUNNED",
    ["pounce"] = "STUNNED",
    ["war stomp"] = "STUNNED",
    ["concussion blow"] = "STUNNED",
    ["intercept stun"] = "STUNNED",
    ["charge stun"] = "STUNNED",
    ["blackout"] = "STUNNED",
    ["impact"] = "STUNNED",
    ["revenge stun"] = "STUNNED",

    ["fear"] = "FEARED",
    ["psychic scream"] = "FEARED",
    ["howl of terror"] = "FEARED",
    ["intimidating shout"] = "FEARED",
    ["scare beast"] = "FEARED",

    ["polymorph"] = "INCAPACITATED",
    ["sap"] = "INCAPACITATED",
    ["gouge"] = "INCAPACITATED",
    ["repentance"] = "INCAPACITATED",
    ["hibernate"] = "INCAPACITATED",

    ["silence"] = "SILENCED",
    ["spell lock"] = "SILENCED",
    ["counterspell - silenced"] = "SILENCED",
    ["garrote - silence"] = "SILENCED",

    ["frost nova"] = "ROOTED",
    ["entangling roots"] = "ROOTED",
}

local function ClassifyCC(name)
    local n=Lower(name)
    if n=="" then return nil end
    if CC_EXACT[n] then return CC_EXACT[n] end
    if string.find(n,"stun") then return "STUNNED" end
    if string.find(n,"fear") or string.find(n,"terror") then return "FEARED" end
    if string.find(n,"silence") then return "SILENCED" end
    if string.find(n,"root") or string.find(n,"frost nova") then return "ROOTED" end
    if string.find(n,"polymorph") or string.find(n,"sleep") or string.find(n,"sap") then return "INCAPACITATED" end
    return nil
end

local function MakeFont(parent,size)
    local f=parent:CreateFontString(nil,"OVERLAY")
    f:SetFont("Fonts\\FRIZQT__.TTF",size,"OUTLINE")
    f:SetTextColor(1,0.82,0)
    f:SetShadowColor(0,0,0,1); f:SetShadowOffset(1,-1)
    return f
end

local function ScanBuffName(buffIndex)
    if not SF.scanTooltip or not buffIndex then return nil end
    SF.scanTooltip:ClearLines()
    if SF.scanTooltip.SetPlayerBuff then
        local ok=pcall(function() SF.scanTooltip:SetPlayerBuff(buffIndex) end)
        if ok then
            local line=_G["SlamFramesScanTooltipTextLeft1"]
            if line and line.GetText then return line:GetText() end
        end
    end
    return nil
end

local function FindCC()
    if SF.ccTestUntil and GetTime()<SF.ccTestUntil then
        return "STUNNED", "Interface\\Icons\\Spell_Holy_SealOfMight", SF.ccTestUntil-GetTime()
    end

    if type(GetPlayerBuff)~="function" or type(GetPlayerBuffTexture)~="function" then return nil end
    local slot,buffIndex,name,category,texture,timeLeft
    for slot=0,31 do
        buffIndex=GetPlayerBuff(slot,"HARMFUL")
        if not buffIndex or buffIndex<0 then break end
        name=ScanBuffName(buffIndex)
        category=ClassifyCC(name)
        if category then
            texture=GetPlayerBuffTexture(buffIndex)
            if type(GetPlayerBuffTimeLeft)=="function" then timeLeft=GetPlayerBuffTimeLeft(buffIndex) or 0 else timeLeft=0 end
            return category,texture,timeLeft,name
        end
    end
    return nil
end

function SF:CreatePlayerEffects()
    if self.effectsCreated or not self.player then return end
    self.effectsCreated=true

    self.scanTooltip=CreateFrame("GameTooltip","SlamFramesScanTooltip",UIParent,"GameTooltipTemplate")
    self.scanTooltip:SetOwner(UIParent,"ANCHOR_NONE")

    local p=self.player
    p.statusFrame=CreateFrame("Frame",nil,p)
    p.statusFrame:SetAllPoints(p)

    -- Additive portrait ring + classic Zzz marks while resting. These live on
    -- a dedicated high frame level so they cannot disappear behind our art.
    p.restGlow=p.statusFrame:CreateTexture(nil,"OVERLAY")
    p.restGlow:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(C.levelBadgeTexture or "level_badge.tga")) or (TEX..(C.levelBadgeTexture or "level_badge.tga")))
    p.restGlow:SetBlendMode("ADD")
    p.restGlow:SetVertexColor(1.0,0.78,0.15)
    p.restGlow:SetAlpha(0); p.restGlow:Hide()

    -- Combat uses the same portrait-ring silhouette in red. It is independent
    -- from the resting effect and can be disabled without touching Zzz/CC.
    p.combatGlow=p.statusFrame:CreateTexture(nil,"OVERLAY")
    p.combatGlow:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(C.levelBadgeTexture or "level_badge.tga")) or (TEX..(C.levelBadgeTexture or "level_badge.tga")))
    p.combatGlow:SetBlendMode("ADD")
    p.combatGlow:SetVertexColor(1.0,0.05,0.02)
    p.combatGlow:SetAlpha(0); p.combatGlow:Hide()

    -- A second, softer action-button halo makes combat state obvious even
    -- against bright scenery. The strength slider drives both its opacity and
    -- its size, so higher settings are visibly stronger rather than merely
    -- hitting the alpha cap on the inner ring.
    p.combatGlowHalo=p.statusFrame:CreateTexture(nil,"OVERLAY")
    -- Purpose-built radial-alpha ring. The old UI-ActionButton-Border texture
    -- contains square-edge bloom, which was visible around our circular portrait.
    p.combatGlowHalo:SetTexture(((SF.GetTextureRoot and SF:GetTextureRoot()) or TEX)..(C.combatGlowTexture or "combat_glow.tga"))
    p.combatGlowHalo:SetBlendMode("ADD")
    p.combatGlowHalo:SetVertexColor(1.0,0.02,0.01)
    p.combatGlowHalo:SetAlpha(0); p.combatGlowHalo:Hide()

    p.restZ1=MakeFont(p.statusFrame,24); p.restZ1:SetText("Z"); p.restZ1:SetTextColor(1.0,0.90,0.30); p.restZ1:Hide()
    p.restZ2=MakeFont(p.statusFrame,19); p.restZ2:SetText("z"); p.restZ2:SetTextColor(1.0,0.90,0.30); p.restZ2:Hide()
    p.restZ3=MakeFont(p.statusFrame,15); p.restZ3:SetText("z"); p.restZ3:SetTextColor(1.0,0.90,0.30); p.restZ3:Hide()

    p.ccGlow=p.statusFrame:CreateTexture(nil,"OVERLAY")
    p.ccGlow:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(C.levelBadgeTexture or "level_badge.tga")) or (TEX..(C.levelBadgeTexture or "level_badge.tga")))
    p.ccGlow:SetBlendMode("ADD")
    p.ccGlow:SetVertexColor(1,0.92,0.35)
    p.ccGlow:SetAlpha(0); p.ccGlow:Hide()

    self.ccAlert=CreateFrame("Frame","SlamFrames_CCAlert",UIParent)
    self.ccAlert:SetFrameStrata("HIGH")
    self.ccAlert.icon=self.ccAlert:CreateTexture(nil,"ARTWORK")
    self.ccAlert.iconBorder=self.ccAlert:CreateTexture(nil,"OVERLAY")
    self.ccAlert.iconBorder:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture("aura_border.tga")) or (TEX.."aura_border.tga"))
    self.ccAlert.label=MakeFont(self.ccAlert,22)
    self.ccAlert.label:SetJustifyH("LEFT")
    self.ccAlert.timer=MakeFont(self.ccAlert,20)
    self.ccAlert.timer:SetTextColor(1,1,1)
    self.ccAlert.timer:SetJustifyH("LEFT")
    self.ccAlert:SetMovable(true)
    self.ccAlert:RegisterForDrag("LeftButton")
    self.ccAlert:EnableMouse(false)
    self.ccAlert:SetScript("OnDragStart",function()
        if not SF.ccMoveMode then return end
        this:StartMoving()
    end)
    self.ccAlert:SetScript("OnDragStop",function()
        if not SF.ccMoveMode then return end
        this:StopMovingOrSizing()
        SF:SaveCCPosition()
    end)
    self.ccAlert:Hide()

    self:RefreshFrameLayers(self.topFrameKey)
    self:LayoutPlayerEffects()
    self:UpdatePlayerEffects(true)
end

function SF:LayoutPlayerEffects()
    if not self.effectsCreated or not self.player then return end
    local p=self.player
    local cfg=p.cfg
    local s=p.layoutScale or 1
    local ts=1.00
    local ps=cfg.portrait.size*s
    local px=cfg.portrait.x*s
    local py=cfg.portrait.y*s

    local glowSize=ps*1.17
    p.restGlow:ClearAllPoints(); p.restGlow:SetPoint("CENTER",p,"BOTTOMLEFT",px,py); p.restGlow:SetWidth(glowSize); p.restGlow:SetHeight(glowSize)
    p.combatGlow:ClearAllPoints(); p.combatGlow:SetPoint("CENTER",p,"BOTTOMLEFT",px,py); p.combatGlow:SetWidth(glowSize); p.combatGlow:SetHeight(glowSize)
    p.combatGlowHalo:ClearAllPoints(); p.combatGlowHalo:SetPoint("CENTER",p,"BOTTOMLEFT",px,py); p.combatGlowHalo:SetWidth(ps*1.45); p.combatGlowHalo:SetHeight(ps*1.45)
    p.ccGlow:ClearAllPoints(); p.ccGlow:SetPoint("CENTER",p,"BOTTOMLEFT",px,py); p.ccGlow:SetWidth(glowSize); p.ccGlow:SetHeight(glowSize)

    -- Keep all three Z's inside the portrait, rising diagonally toward the
    -- portrait's upper-right like the stock resting treatment.
    local zScale=s*ts
    p.restZ1:ClearAllPoints(); p.restZ1:SetPoint("CENTER",p,"BOTTOMLEFT",px+ps*0.20,py+ps*0.18)
    p.restZ2:ClearAllPoints(); p.restZ2:SetPoint("CENTER",p,"BOTTOMLEFT",px+ps*0.31,py+ps*0.29)
    p.restZ3:ClearAllPoints(); p.restZ3:SetPoint("CENTER",p,"BOTTOMLEFT",px+ps*0.39,py+ps*0.39)
    p.restZ1:SetFont("Fonts\\FRIZQT__.TTF",math.max(8,math.floor(24*zScale+0.5)),"OUTLINE")
    p.restZ2:SetFont("Fonts\\FRIZQT__.TTF",math.max(7,math.floor(19*zScale+0.5)),"OUTLINE")
    p.restZ3:SetFont("Fonts\\FRIZQT__.TTF",math.max(6,math.floor(15*zScale+0.5)),"OUTLINE")

    local a=self.ccAlert
    local icon=46*s
    a:SetWidth(210*s); a:SetHeight(58*s)
    a:ClearAllPoints()
    if SlamFramesDB.ccAnchor and SlamFramesDB.ccAnchor.x and SlamFramesDB.ccAnchor.y then
        a:SetPoint("CENTER",p.health,"CENTER",SlamFramesDB.ccAnchor.x*s,SlamFramesDB.ccAnchor.y*s)
    else
        a:SetPoint("BOTTOM",p.health,"TOP",0,8*s)
    end
    a.icon:ClearAllPoints(); a.icon:SetPoint("LEFT",a,"LEFT",0,0); a.icon:SetWidth(icon); a.icon:SetHeight(icon)
    a.icon:SetTexCoord(0,1,0,1)
    a.iconBorder:ClearAllPoints(); a.iconBorder:SetPoint("CENTER",a.icon,"CENTER",0,0); a.iconBorder:SetWidth(icon+10*s); a.iconBorder:SetHeight(icon+10*s)
    a.label:ClearAllPoints(); a.label:SetPoint("TOPLEFT",a,"TOPLEFT",58*s,-2*s); a.label:SetWidth(150*s); a.label:SetHeight(30*s*ts)
    a.label:SetFont("Fonts\\FRIZQT__.TTF",math.max(8,math.floor(22*s*ts+0.5)),"OUTLINE")
    a.timer:ClearAllPoints(); a.timer:SetPoint("BOTTOMLEFT",a,"BOTTOMLEFT",58*s,2*s); a.timer:SetWidth(120*s); a.timer:SetHeight(26*s*ts)
    a.timer:SetFont("Fonts\\FRIZQT__.TTF",math.max(8,math.floor(20*s*ts+0.5)),"OUTLINE")
    self:RefreshFrameLayers(self.topFrameKey)
end

function SF:SaveCCPosition()
    if not self.ccAlert or not self.player or not self.player.health then return end
    local ax,ay=self.ccAlert:GetCenter()
    local hx,hy=self.player.health:GetCenter()
    if not ax or not hx then return end
    local scale=self.player.layoutScale or 1
    if scale==0 then scale=1 end
    SlamFramesDB.ccAnchor={x=(ax-hx)/scale,y=(ay-hy)/scale}
    self:LayoutPlayerEffects()
    if self.RefreshSettings then self:RefreshSettings() end
end

function SF:ResetCCPosition()
    SlamFramesDB.ccAnchor=nil
    self:LayoutPlayerEffects()
    if self.RefreshSettings then self:RefreshSettings() end
    if self.Print then self.Print("CC notification reset above the player health bar.") end
end

function SF:SetCCMoveMode(enabled)
    self.ccMoveMode=enabled and true or false
    if not self.ccAlert then return end
    self.ccAlert:EnableMouse(self.ccMoveMode)
    if self.ccMoveMode then
        self.ccTestUntil=GetTime()+3600
        self:UpdatePlayerEffects(true)
        if self.Print then self.Print("CC move mode enabled. Drag the CC alert, then press Done Moving CC.") end
    else
        self.ccTestUntil=nil
        self:UpdatePlayerEffects(true)
        if self.Print then self.Print("CC move mode disabled.") end
    end
    if self.RefreshSettings then self:RefreshSettings() end
end

function SF:UpdatePlayerEffects(force)
    if not self.effectsCreated or not self.player then return end
    local now=GetTime()
    local resting=false
    if type(IsResting)=="function" then resting=IsResting() and true or false end

    if SlamFramesDB.showRestingEffect and resting then
        self.player.restGlow:Show(); self.player.restZ1:Show(); self.player.restZ2:Show(); self.player.restZ3:Show()
        local wave=0.5+0.5*math.sin(now*3.2)
        local pulse=0.30+0.40*wave
        self.player.restGlow:SetAlpha(pulse)
        self.player.restZ1:SetAlpha(0.75+0.25*wave)
        self.player.restZ2:SetAlpha(0.60+0.35*(0.5+0.5*math.sin(now*3.2+0.8)))
        self.player.restZ3:SetAlpha(0.45+0.45*(0.5+0.5*math.sin(now*3.2+1.6)))
        self.player.portrait:SetAlpha(0.82)
    else
        self.player.restGlow:Hide(); self.player.restZ1:Hide(); self.player.restZ2:Hide(); self.player.restZ3:Hide()
        self.player.portrait:SetAlpha(1)
    end

    local inCombat=self.inCombat and true or false
    if type(UnitAffectingCombat)=="function" then
        local ok,result=pcall(UnitAffectingCombat,"player")
        if ok and result then inCombat=true elseif ok then inCombat=false end
    end
    if SlamFramesDB.showCombatGlow and inCombat then
        self.player.combatGlow:Show()
        self.player.combatGlowHalo:Show()
        local combatWave=0.5+0.5*math.sin(now*4.6)
        local intensity=tonumber(SlamFramesDB.combatGlowIntensity) or 1.30
        if intensity<0.50 then intensity=0.50 elseif intensity>2.00 then intensity=2.00 end

        -- Inner ring: bright, tight pulse. Outer halo: broader red bloom.
        -- Strength affects alpha *and* halo radius so the control remains
        -- visually meaningful even after the inner additive ring reaches 1.0.
        local combatAlpha=(0.45+0.45*combatWave)*intensity
        if combatAlpha>1 then combatAlpha=1 end
        self.player.combatGlow:SetAlpha(combatAlpha)

        local haloAlpha=(0.12+0.30*combatWave)*intensity
        if haloAlpha>0.95 then haloAlpha=0.95 end
        self.player.combatGlowHalo:SetAlpha(haloAlpha)

        local cfg=self.player.cfg
        local scale=self.player.layoutScale or 1
        local ps=cfg.portrait.size*scale
        local normalized=(intensity-0.50)/1.50
        local haloSize=ps*(1.40+0.28*normalized)
        self.player.combatGlowHalo:SetWidth(haloSize)
        self.player.combatGlowHalo:SetHeight(haloSize)
    else
        self.player.combatGlow:Hide()
        self.player.combatGlowHalo:Hide()
    end

    local category,texture,timeLeft=FindCC()
    if (SlamFramesDB.showCCEffect or self.ccMoveMode) and category then
        self.player.ccGlow:Show()
        self.player.ccGlow:SetAlpha(0.35+0.40*(0.5+0.5*math.sin(now*5.0)))
        self.ccAlert.label:SetText(category)
        self.ccAlert.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        if timeLeft and timeLeft>0 then self.ccAlert.timer:SetText(string.format("%.1fs",timeLeft)) else self.ccAlert.timer:SetText("") end
        self.ccAlert:Show()
    else
        self.player.ccGlow:Hide(); self.ccAlert:Hide()
    end
end

function SF:PreviewCC(seconds)
    self.ccTestUntil=GetTime()+(seconds or 4)
    self:UpdatePlayerEffects(true)
end

local effectsUpdater=CreateFrame("Frame","SlamFrames_EffectsUpdater",UIParent)
local elapsed=0
effectsUpdater:SetScript("OnUpdate",function()
    if not SF.effectsCreated then return end
    elapsed=elapsed+(arg1 or 0)
    local interval=(C.effects and C.effects.scanInterval) or 0.10
    if elapsed<interval then return end
    elapsed=0
    SF:UpdatePlayerEffects(false)
end)
