-- SlamFrames TEST 9 enhancements
-- Predictive healing (HealComm-1.0 compatibility) + selectable Ornate cast-bar skin.
-- OctoWoW / Vanilla 1.12-era compatible; intentionally avoids modern Retail APIs.

local SF = SlamFrames
local C = SlamFrames_Config
local Bars = SlamFrames_BarEngine
local TEX = C.texturePath
local CB = C.castbar or {}
local WHITE = "Interface\\Buttons\\WHITE8X8"

if not SF or not C or not Bars then return end

local function Clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function Round(v)
    return math.floor((tonumber(v) or 0) + 0.5)
end

-- ---------------------------------------------------------------------------
-- 1) BAR-ENGINE PREDICTION LAYER
-- ---------------------------------------------------------------------------
--
-- The existing health fill stays on OVERLAY.  The prediction texture sits one
-- draw layer below it and fills from the left edge to current+incoming health.
-- The opaque current-health fill covers the shared region, so only the pale
-- extension beyond current health is visible -- exactly like a modern heal
-- prediction bar without requiring StatusBar APIs that are unreliable on 1.12.

local OriginalBarCreate = Bars.Create
function Bars:Create(parent, rect, texturePath, textureFile)
    local bar = OriginalBarCreate(self, parent, rect, texturePath, textureFile)
    if not bar or bar.sfPredictionPatched then return bar end
    bar.sfPredictionPatched = true

    bar.prediction = bar:CreateTexture(nil, "ARTWORK")
    bar.prediction:SetTexture(texturePath .. textureFile)
    bar.prediction:SetPoint("LEFT", bar, "LEFT", 0, 0)
    bar.prediction:SetTexCoord(0, 1, 0, 1)
    bar.prediction:SetVertexColor(0.76, 1.00, 0.76, 1.00)
    bar.prediction:SetAlpha(0.55)
    bar.prediction:Hide()

    local OriginalSetLayout = bar.SetLayout
    local OriginalUpdateVisual = bar.UpdateVisual

    function bar:UpdatePredictionVisual()
        if not self.prediction then return end
        local incoming = tonumber(self.predictionIncoming) or 0
        local current = tonumber(self.predictionCurrent) or 0
        local maxv = tonumber(self.predictionMax) or tonumber(self.max) or 1
        if not self.predictionEnabled or incoming <= 0 or maxv <= 0 then
            self.prediction:Hide()
            return
        end

        local total = current + incoming
        if total > maxv then total = maxv end
        if total <= current then
            self.prediction:Hide()
            return
        end

        local pct = total / maxv
        if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
        local fullW = self.fullWidth or self:GetWidth() or 1
        local fullH = self.fullHeight or self:GetHeight() or 1

        self.prediction:ClearAllPoints()
        self.prediction:SetPoint("LEFT", self, "LEFT", 0, 0)
        self.prediction:SetHeight(fullH)
        self.prediction:SetWidth(math.max(0.5, fullW * pct))
        self.prediction:SetTexCoord(0, pct, 0, 1)
        self.prediction:SetAlpha(Clamp(self.predictionAlpha or 0.55, 0.15, 0.90))
        self.prediction:Show()
    end

    function bar:SetPrediction(current, incoming, maxv, alpha)
        current = tonumber(current) or 0
        incoming = tonumber(incoming) or 0
        maxv = tonumber(maxv) or tonumber(self.max) or 1
        if maxv <= 0 then maxv = 1 end
        if current < 0 then current = 0 end
        if current > maxv then current = maxv end
        if incoming < 0 then incoming = 0 end

        self.predictionCurrent = current
        self.predictionIncoming = incoming
        self.predictionMax = maxv
        self.predictionAlpha = alpha or self.predictionAlpha or 0.55
        self.predictionEnabled = incoming > 0
        self:UpdatePredictionVisual()
    end

    function bar:ClearPrediction()
        self.predictionEnabled = nil
        self.predictionIncoming = 0
        if self.prediction then self.prediction:Hide() end
    end

    function bar:SetLayout(scale, widthTrim)
        OriginalSetLayout(self, scale, widthTrim)
        if self.prediction then self:UpdatePredictionVisual() end
    end

    function bar:UpdateVisual()
        OriginalUpdateVisual(self)
        if self.prediction then self:UpdatePredictionVisual() end
    end

    return bar
end

-- ---------------------------------------------------------------------------
-- 2) HEALCOMM-DRIVEN PREDICTIVE HEALING
-- ---------------------------------------------------------------------------

local HealComm = nil
local AceEvent = nil
local healCommEventRegistered = false

local function TryBindHealComm()
    if HealComm then return true end
    if type(AceLibrary) ~= "function" then return false end

    local ok, lib = pcall(AceLibrary, "HealComm-1.0")
    if not ok or not lib or type(lib.getHeal) ~= "function" then return false end
    HealComm = lib
    SF.HealComm = lib

    local okEvent, ev = pcall(AceLibrary, "AceEvent-2.0")
    if okEvent and ev then AceEvent = ev end

    if AceEvent and not healCommEventRegistered then
        healCommEventRegistered = true
        AceEvent:RegisterEvent("HealComm_Healupdate", function(unitname)
            if SF and SF.HealPredictionUpdateForName then
                SF:HealPredictionUpdateForName(unitname)
            end
        end)
    end
    return true
end

function SF:IsHealCommAvailable()
    return TryBindHealComm()
end

function SF:GetHealPredictionStatus()
    if TryBindHealComm() then return "HealComm-1.0 detected" end
    return "HealComm-1.0 not detected"
end

function SF:GetIncomingHeal(unit)
    if not SlamFramesDB or not SlamFramesDB.healPredictionEnabled then return 0 end
    if not unit or not UnitExists(unit) then return 0 end
    -- HealComm is designed for cooperative healing. Never apply a name-based
    -- prediction to a hostile target; an NPC can theoretically share a name
    -- with a player in HealComm's cache, which would create a false overlay.
    if type(UnitCanAttack) == "function" and UnitCanAttack("player", unit) then return 0 end
    if not TryBindHealComm() then return 0 end

    local name = UnitName(unit)
    if not name or name == "" then return 0 end
    local ok, value = pcall(function() return HealComm:getHeal(name) end)
    if not ok then return 0 end
    value = tonumber(value) or 0
    if value < 0 then value = 0 end
    return value
end

function SF:UpdateHealPredictionForFrame(frame, unit)
    if not frame or not frame.health or not frame.health.SetPrediction then return end
    if not SlamFramesDB or not SlamFramesDB.healPredictionEnabled then
        frame.health:ClearPrediction()
        return
    end
    if not unit or not UnitExists(unit) then
        frame.health:ClearPrediction()
        return
    end

    local cur = UnitHealth(unit) or 0
    local maxv = UnitHealthMax(unit) or 1
    local incoming = self:GetIncomingHeal(unit)
    if incoming > 0 then
        frame.health:SetPrediction(cur, incoming, maxv, SlamFramesDB.healPredictionAlpha or 0.55)
    else
        frame.health:ClearPrediction()
    end
end

function SF:UpdateHealPredictions()
    self:UpdateHealPredictionForFrame(self.player, "player")
    self:UpdateHealPredictionForFrame(self.target, "target")
end

function SF:HealPredictionUpdateForName(unitname)
    if not unitname then
        self:UpdateHealPredictions()
        return
    end
    local playerName = UnitName("player")
    if playerName and unitname == playerName then
        self:UpdateHealPredictionForFrame(self.player, "player")
    end
    if UnitExists("target") then
        local targetName = UnitName("target")
        if targetName and unitname == targetName then
            self:UpdateHealPredictionForFrame(self.target, "target")
        end
    end
end

function SF:SetHealPredictionEnabled(v, quiet)
    SlamFramesDB.healPredictionEnabled = v and true or false
    if SlamFramesDB.healPredictionAlpha == nil then SlamFramesDB.healPredictionAlpha = 0.55 end
    self:UpdateHealPredictions()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then
        if SlamFramesDB.healPredictionEnabled then
            self.Print("predictive healing ON (" .. self:GetHealPredictionStatus() .. ").")
        else
            self.Print("predictive healing OFF.")
        end
    end
end

-- Refresh predictions whenever the normal frame update path runs.
local OriginalUpdatePlayer = SF.UpdatePlayer
if OriginalUpdatePlayer then
    function SF:UpdatePlayer()
        OriginalUpdatePlayer(self)
        self:UpdateHealPredictionForFrame(self.player, "player")
    end
end

local OriginalUpdateTarget = SF.UpdateTarget
if OriginalUpdateTarget then
    function SF:UpdateTarget()
        OriginalUpdateTarget(self)
        self:UpdateHealPredictionForFrame(self.target, "target")
    end
end

-- ---------------------------------------------------------------------------
-- 3) SELECTABLE CAST-BAR SKINS
-- ---------------------------------------------------------------------------
--
-- Config.lua already contains the parked Style 2 geometry/assets.  The stock
-- CastBar.lua intentionally hard-locks GetStyle() to Style 1, so we replace only
-- the public layout/style methods here and leave all timing/event logic intact.

local function GetCastStyle()
    local styles = CB.styles or {}
    local n = tonumber(SlamFramesDB and SlamFramesDB.castbarStyle) or 1
    n = math.floor(n + 0.5)
    if n ~= 2 or not styles[2] then n = 1 end
    return styles[n] or styles[1] or CB, n
end

local function SetCastSlice(tex, style, u1, u2)
    local file = style.frameTexture or CB.frameTexture or "castbar_frame.tga"
    tex:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(file)) or (TEX .. file))
    tex:SetTexCoord(u1, u2, 0, 1)
end

function SF:LayoutCastBar()
    local cb = self.castbar
    if not cb then return end

    local style, styleNumber = GetCastStyle()
    local scale = Clamp(SlamFramesDB.castbarScale or 0.80, 0.50, 1.60)
    -- The ornate skin has substantially heavier endcaps.  Slightly shorten its
    -- straight body so it matches the compact concept image rather than looking
    -- like Style 1 with larger decorations bolted onto the ends.
    local defaultWidthFactor = (styleNumber == 2) and 0.92 or 1.00
    local widthFactor = style.bodyWidthFactor or defaultWidthFactor
    local bodyW = Clamp(SlamFramesDB.castbarWidth or 360, 260, 540) * scale * widthFactor
    local bodyH = (style.bodyHeight or CB.bodyHeight or 52) * scale
    local iconSize = (style.iconSize or CB.iconSize or 64) * scale
    local showIcon = SlamFramesDB.castbarShowIcon and true or false
    local bodyX = showIcon and ((style.bodyX or CB.bodyX or 52) * scale) or 0
    local totalW = bodyX + bodyW
    local totalH = math.max(iconSize, bodyH)
    local capL = (style.leftCap or CB.leftCap or 26) * scale
    local capR = (style.rightCap or CB.rightCap or 30) * scale
    local uLeft = style.leftSliceU or 0.06
    local uRight = style.rightSliceU or 0.94

    cb.layoutScale = scale
    cb.styleNumber = styleNumber
    cb.style = style
    cb.bodyWidth = bodyW

    SetCastSlice(cb.body.left, style, 0, uLeft)
    SetCastSlice(cb.body.middle, style, uLeft, uRight)
    SetCastSlice(cb.body.right, style, uRight, 1)

    local borderFile = style.iconBorderTexture or "aura_border.tga"
    cb.iconBorder:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(borderFile)) or (TEX .. borderFile))
    cb.latency:SetTexture(TEX .. (style.latencyTexture or CB.latencyTexture or "cast_latency.tga"))
    cb.latency:SetAlpha(style.latencyAlpha or 0.90)
    cb:SetWidth(totalW)
    cb:SetHeight(totalH)

    cb.iconFrame:ClearAllPoints()
    cb.iconFrame:SetPoint("LEFT", cb, "LEFT", 0, 0)
    cb.iconFrame:SetWidth(iconSize)
    cb.iconFrame:SetHeight(iconSize)
    if showIcon then cb.iconFrame:Show() else cb.iconFrame:Hide() end

    local iconInset = (style.iconInset or CB.iconInset or 10) * scale
    cb.icon:ClearAllPoints()
    cb.icon:SetPoint("TOPLEFT", cb.iconFrame, "TOPLEFT", iconInset, -iconInset)
    cb.icon:SetPoint("BOTTOMRIGHT", cb.iconFrame, "BOTTOMRIGHT", -iconInset, iconInset)
    cb.iconBorder:SetAllPoints(cb.iconFrame)

    cb.body:ClearAllPoints()
    cb.body:SetPoint("LEFT", cb, "LEFT", bodyX, 0)
    cb.body:SetWidth(bodyW)
    cb.body:SetHeight(bodyH)

    cb.body.left:ClearAllPoints()
    cb.body.left:SetPoint("LEFT", cb.body, "LEFT", 0, 0)
    cb.body.left:SetWidth(capL)
    cb.body.left:SetHeight(bodyH)

    cb.body.right:ClearAllPoints()
    cb.body.right:SetPoint("RIGHT", cb.body, "RIGHT", 0, 0)
    cb.body.right:SetWidth(capR)
    cb.body.right:SetHeight(bodyH)

    cb.body.middle:ClearAllPoints()
    cb.body.middle:SetPoint("LEFT", cb.body.left, "RIGHT", 0, 0)
    cb.body.middle:SetPoint("RIGHT", cb.body.right, "LEFT", 0, 0)
    cb.body.middle:SetHeight(bodyH)

    local insetL = (style.fillLeft or CB.fillLeft or 14) * scale
    local insetR = (style.fillRight or CB.fillRight or 18) * scale
    local fillBottom = (style.fillBottom or CB.fillBottom or 8) * scale
    local fillH = (style.fillHeight or CB.fillHeight or 15) * scale
    cb.innerX = insetL
    cb.innerW = math.max(20, bodyW - insetL - insetR)
    cb.innerY = fillBottom
    cb.innerH = fillH

    cb.fill:ClearAllPoints()
    cb.fill:SetPoint("BOTTOMLEFT", cb.body, "BOTTOMLEFT", insetL, fillBottom)
    cb.fill:SetHeight(fillH)
    cb.latency:SetHeight(fillH)
    cb.latencyEdge:SetWidth(math.max(1, 2 * scale))
    cb.latencyEdge:SetHeight(fillH)
    cb.spark:SetWidth(math.max(1, 2 * scale))
    cb.spark:SetHeight(fillH + 2 * scale)

    local nameY = (style.textY or CB.textY or 34) * scale
    local nameInset = (style.nameTextInset or style.textInset or CB.textInset or 17) * scale
    local timerInset = (style.timerTextInset or style.textInset or CB.textInset or 17) * scale
    local timerW = 100 * scale

    cb.name:ClearAllPoints()
    cb.name:SetPoint("LEFT", cb.body, "LEFT", nameInset, nameY - bodyH / 2)
    cb.name:SetWidth(math.max(60, bodyW - nameInset - timerInset - timerW))
    cb.name:SetHeight(22 * scale)

    cb.timer:ClearAllPoints()
    cb.timer:SetPoint("RIGHT", cb.body, "RIGHT", -(timerInset + 2 * scale), nameY - bodyH / 2)
    cb.timer:SetWidth(timerW)
    cb.timer:SetHeight(22 * scale)

    cb.name:SetFont("Fonts\\FRIZQT__.TTF", math.max(8, Round((style.nameFont or CB.nameFont or 15) * scale)), "OUTLINE")
    cb.timer:SetFont("Fonts\\FRIZQT__.TTF", math.max(8, Round((style.timerFont or CB.timerFont or 13) * scale)), "OUTLINE")

    cb.moveLabel:ClearAllPoints()
    cb.moveLabel:SetPoint("BOTTOM", cb, "TOP", 0, 4 * scale)
    cb.moveLabel:SetFont("Fonts\\FRIZQT__.TTF", math.max(8, Round(13 * scale)), "OUTLINE")

    self:ApplyCastBarAnchor()
    self:RenderCastBar()
end

function SF:SetCastBarStyle(v, quiet)
    local n
    if type(v) == "string" then
        local s = string.lower(v)
        if s == "ornate" or s == "gold" or s == "ornategold" or s == "2" then n = 2
        elseif s == "classic" or s == "standard" or s == "1" then n = 1 end
    else
        n = tonumber(v)
    end
    n = math.floor((tonumber(n) or 1) + 0.5)
    if n ~= 2 or not (CB.styles and CB.styles[2]) then n = 1 end

    SlamFramesDB.castbarStyle = n
    self:LayoutCastBar()
    if self.RefreshSettings then self:RefreshSettings() end
    if not quiet and self.Print then
        self.Print("cast bar skin set to " .. ((n == 2) and "Ornate" or "Classic") .. ".")
    end
    return true
end

function SF:GetCastBarStyleName()
    return (tonumber(SlamFramesDB and SlamFramesDB.castbarStyle) == 2) and "Ornate" or "Classic"
end

-- ---------------------------------------------------------------------------
-- 4) SETTINGS-PANEL INTEGRATION WITHOUT REWRITING Settings.lua
-- ---------------------------------------------------------------------------

local function TintCompatButton(b, selected)
    if not b then return end
    local normal = b.GetNormalTexture and b:GetNormalTexture() or nil
    local pushed = b.GetPushedTexture and b:GetPushedTexture() or nil
    local disabled = b.GetDisabledTexture and b:GetDisabledTexture() or nil
    if normal and normal.SetVertexColor then
        if selected then normal:SetVertexColor(0.72, 0.12, 0.07) else normal:SetVertexColor(0.44, 0.07, 0.05) end
    end
    if pushed and pushed.SetVertexColor then pushed:SetVertexColor(0.72, 0.12, 0.07) end
    if disabled and disabled.SetVertexColor then
        if selected then disabled:SetVertexColor(0.72, 0.12, 0.07) else disabled:SetVertexColor(0.30, 0.05, 0.04) end
    end
    local fs = b.GetFontString and b:GetFontString() or nil
    if fs then fs:SetTextColor(1.00, 0.82, 0.00) end
end

local function MakeCompatButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(w or 90)
    b:SetHeight(h or 22)
    b:SetText(text or "")
    TintCompatButton(b, false)
    return b
end

local function MakeCompatLabel(parent,text,size,r,g,b)
    local f=parent:CreateFontString(nil,"OVERLAY")
    f:SetFont("Fonts\\FRIZQT__.TTF",size or 10,"OUTLINE")
    f:SetTextColor(r or .92,g or .92,b or .92)
    f:SetText(text or "")
    f:SetJustifyH("LEFT")
    f:SetShadowColor(0,0,0,1); f:SetShadowOffset(1,-1)
    return f
end

local function MakeCompatSection(parent,title,x,y,w,h)
    local box=CreateFrame("Frame",nil,parent)
    box:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    box:SetWidth(w); box:SetHeight(h)
    local bg=box:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(box); bg:SetTexture(WHITE); bg:SetVertexColor(.025,.025,.025,.72)
    local top=box:CreateTexture(nil,"BORDER"); top:SetTexture(WHITE); top:SetVertexColor(.55,.42,.12,1); top:SetPoint("TOPLEFT",box,"TOPLEFT",0,0); top:SetWidth(w); top:SetHeight(1)
    local bottom=box:CreateTexture(nil,"BORDER"); bottom:SetTexture(WHITE); bottom:SetVertexColor(.24,.20,.12,1); bottom:SetPoint("BOTTOMLEFT",box,"BOTTOMLEFT",0,0); bottom:SetWidth(w); bottom:SetHeight(1)
    local left=box:CreateTexture(nil,"BORDER"); left:SetTexture(WHITE); left:SetVertexColor(.24,.20,.12,1); left:SetPoint("TOPLEFT",box,"TOPLEFT",0,0); left:SetWidth(1); left:SetHeight(h)
    local right=box:CreateTexture(nil,"BORDER"); right:SetTexture(WHITE); right:SetVertexColor(.24,.20,.12,1); right:SetPoint("TOPRIGHT",box,"TOPRIGHT",0,0); right:SetWidth(1); right:SetHeight(h)
    box.title=MakeCompatLabel(box,title,13,1.00,.82,0.00); box.title:SetPoint("TOPLEFT",box,"TOPLEFT",12,-9)
    local line=box:CreateTexture(nil,"BORDER"); line:SetTexture(WHITE); line:SetVertexColor(.65,.48,.08,.85); line:SetPoint("TOPLEFT",box,"TOPLEFT",12,-29); line:SetWidth(w-24); line:SetHeight(1)
    return box
end

local OriginalCreateSettingsPanel = SF.CreateSettingsPanel
if OriginalCreateSettingsPanel then
    function SF:CreateSettingsPanel()
        OriginalCreateSettingsPanel(self)
        local f = self.settings
        if not f then return end

        -- The General -> Interaction section already has an empty right-hand
        -- slot on row 2, so predictive healing fits without enlarging the page.
        if f.generalInteraction and not f.generalInteraction.healPrediction then
            local b = MakeCompatButton(f.generalInteraction, "Heal Prediction: ON", 205, 24)
            b:SetPoint("TOPRIGHT", f.generalInteraction, "TOPRIGHT", -14, -78)
            b:SetScript("OnClick", function()
                SF:SetHealPredictionEnabled(not SlamFramesDB.healPredictionEnabled, true)
                SF:RefreshSettings()
            end)
            b:SetScript("OnEnter", function()
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:SetText("Predictive Healing", 1.0, 0.82, 0.0)
                GameTooltip:AddLine("Shows incoming HealComm healing as a pale green extension on Player and Target health bars.", 1, 1, 1, true)
                GameTooltip:AddLine(SF:GetHealPredictionStatus(), 0.70, 0.90, 0.70, true)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            f.generalInteraction.healPrediction = b
        end

        -- Cast Bar has an unused right-hand slot opposite Latency Zone.  Use it
        -- as a one-click skin selector: Classic <-> Ornate.
        if f.castbarMain and not f.castbarMain.style then
            local b = MakeCompatButton(f.castbarMain, "Cast Skin: Classic", 205, 24)
            b:SetPoint("TOPRIGHT", f.castbarMain, "TOPRIGHT", -14, -113)
            b:SetScript("OnClick", function()
                SF:SetCastBarStyle((tonumber(SlamFramesDB.castbarStyle) == 2) and 1 or 2, true)
                SF:RefreshSettings()
                if SF.PreviewCastBar then SF:PreviewCastBar("cast") end
            end)
            b:SetScript("OnEnter", function()
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:SetText("Cast Bar Skin", 1.0, 0.82, 0.0)
                GameTooltip:AddLine("Classic = current SlamFrames cast bar.", 1, 1, 1, true)
                GameTooltip:AddLine("Ornate = the heavier gold concept-art skin.", 1, 1, 1, true)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            f.castbarMain.style = b
        end

        -- Ornate-only flavor-text controls. The cast-bar tab previously ended
        -- exactly at the viewport height, so extend it and enable scrolling for
        -- this additional section rather than crowding the existing controls.
        if f.pages and f.pages.castbar and not f.castbarFlavor then
            local page=f.pages.castbar
            local flavor=MakeCompatSection(page,"Ornate Flavor Text",0,-556,504,178)
            flavor.toggle=MakeCompatButton(flavor,"Flavor Text: ON",205,24)
            flavor.toggle:SetPoint("TOPLEFT",flavor,"TOPLEFT",14,-43)
            flavor.toggle:SetScript("OnClick",function()
                SF:SetCastBarFlavorTextEnabled(not SlamFramesDB.castbarFlavorTextEnabled,true)
                SF:RefreshSettings()
                if SF.castbar and SF.castbar:IsShown() and SF.RefreshOrnateCastSubtext then SF:RefreshOrnateCastSubtext() end
            end)

            flavor.help=MakeCompatLabel(flavor,"Cooking, Fishing and profession crafts use a clean activity label and never append your selected target.",9,.66,.66,.66)
            flavor.help:SetPoint("TOPLEFT",flavor,"TOPLEFT",14,-76); flavor.help:SetWidth(470); flavor.help:SetJustifyH("LEFT")

            flavor.sizeLabel=MakeCompatLabel(flavor,"Flavor Text Size",10,.92,.92,.92)
            flavor.sizeLabel:SetPoint("TOPLEFT",flavor,"TOPLEFT",14,-108)
            flavor.sizeValue=MakeCompatLabel(flavor,"100%",10,1.00,.82,0.00)
            flavor.sizeValue:SetPoint("TOPRIGHT",flavor,"TOPRIGHT",-14,-108); flavor.sizeValue:SetWidth(54); flavor.sizeValue:SetJustifyH("RIGHT")

            flavor.slider=CreateFrame("Slider",nil,flavor)
            flavor.slider:SetOrientation("HORIZONTAL"); flavor.slider:SetPoint("TOPLEFT",flavor,"TOPLEFT",14,-132); flavor.slider:SetWidth(460); flavor.slider:SetHeight(16)
            flavor.slider:SetMinMaxValues(.60,2.00); if flavor.slider.SetValueStep then flavor.slider:SetValueStep(.05) end
            flavor.track=flavor.slider:CreateTexture(nil,"BACKGROUND"); flavor.track:SetTexture(WHITE); flavor.track:SetVertexColor(.22,.18,.10,1); flavor.track:SetPoint("LEFT",flavor.slider,"LEFT",0,0); flavor.track:SetPoint("RIGHT",flavor.slider,"RIGHT",0,0); flavor.track:SetHeight(5)
            flavor.fill=flavor.slider:CreateTexture(nil,"BORDER"); flavor.fill:SetTexture(WHITE); flavor.fill:SetVertexColor(.78,.56,.06,1); flavor.fill:SetPoint("LEFT",flavor.slider,"LEFT",0,0); flavor.fill:SetHeight(3)
            flavor.thumb=flavor.slider:CreateTexture(nil,"OVERLAY"); flavor.thumb:SetTexture((SF.GetSkinTexture and SF:GetSkinTexture(C.levelBadgeTexture or "level_badge.tga")) or (TEX..(C.levelBadgeTexture or "level_badge.tga"))); flavor.thumb:SetWidth(18); flavor.thumb:SetHeight(18); flavor.slider:SetThumbTexture(flavor.thumb)
            flavor.slider:SetScript("OnValueChanged",function()
                if flavor.suppress then return end
                local v=math.floor(this:GetValue()*20+.5)/20
                SF:SetCastBarFlavorTextScale(v,true)
                flavor.sizeValue:SetText(tostring(math.floor(v*100+.5)).."%")
                flavor.fill:SetWidth(math.max(1,this:GetWidth()*((v-.60)/1.40)))
            end)

            f.castbarFlavor=flavor
            page:SetHeight(744)
            if f.pageSliders and f.pageSliders.castbar then
                local slider=f.pageSliders.castbar
                local maxScroll=196
                slider.sfMaxScroll=maxScroll
                slider:SetMinMaxValues(0,maxScroll)
                slider:SetValue(maxScroll)
            end
            if f.pageScrolls and f.pageScrolls.castbar and f.pageScrolls.castbar.EnableMouseWheel then
                f.pageScrolls.castbar:EnableMouseWheel(true)
            end
        end

        if self.RefreshSettings then self:RefreshSettings() end
    end
end

local OriginalRefreshSettings = SF.RefreshSettings
if OriginalRefreshSettings then
    function SF:RefreshSettings()
        OriginalRefreshSettings(self)
        local f = self.settings
        if not f then return end
        if f.generalInteraction and f.generalInteraction.healPrediction then
            local enabled = SlamFramesDB.healPredictionEnabled and true or false
            f.generalInteraction.healPrediction:SetText("Heal Prediction: " .. (enabled and "ON" or "OFF"))
            TintCompatButton(f.generalInteraction.healPrediction, enabled)
        end
        if f.castbarMain and f.castbarMain.style then
            local ornate = tonumber(SlamFramesDB.castbarStyle) == 2
            f.castbarMain.style:SetText("Cast Skin: " .. (ornate and "Ornate" or "Classic"))
            TintCompatButton(f.castbarMain.style, ornate)
        end
        if f.castbarFlavor then
            local enabled=(SlamFramesDB.castbarFlavorTextEnabled~=false)
            f.castbarFlavor.toggle:SetText("Flavor Text: "..(enabled and "ON" or "OFF"))
            TintCompatButton(f.castbarFlavor.toggle,enabled)
            local v=tonumber(SlamFramesDB.castbarFlavorTextScale) or 1.00
            if v<.60 then v=.60 elseif v>2.00 then v=2.00 end
            f.castbarFlavor.suppress=true
            f.castbarFlavor.slider:SetValue(v)
            f.castbarFlavor.suppress=nil
            f.castbarFlavor.sizeValue:SetText(tostring(math.floor(v*100+.5)).."%")
            f.castbarFlavor.fill:SetWidth(math.max(1,f.castbarFlavor.slider:GetWidth()*((v-.60)/1.40)))
        end
    end
end

-- ---------------------------------------------------------------------------
-- 5) SLASH-COMMAND COMPATIBILITY
-- ---------------------------------------------------------------------------

local OriginalHandleSlash = SF.HandleSlash
if OriginalHandleSlash then
    function SF:HandleSlash(msg)
        msg = msg or ""
        local _, _, cmd, rest = string.find(msg, "^%s*(%S*)%s*(.-)%s*$")
        cmd = string.lower(cmd or "")
        rest = rest or ""

        if cmd == "healpredict" or cmd == "healprediction" then
            local v = string.lower(rest or "")
            if v == "on" then self:SetHealPredictionEnabled(true, false)
            elseif v == "off" then self:SetHealPredictionEnabled(false, false)
            elseif v == "status" then
                if self.Print then self.Print("predictive healing " .. (SlamFramesDB.healPredictionEnabled and "ON" or "OFF") .. "; " .. self:GetHealPredictionStatus() .. ".") end
            else
                self:SetHealPredictionEnabled(not SlamFramesDB.healPredictionEnabled, false)
            end
            return
        end

        if cmd == "castbar" then
            local sub, arg = string.match(rest or "", "^%s*(%S*)%s*(.-)%s*$")
            sub = string.lower(sub or "")
            if sub == "flavor" or sub == "flavour" then
                local choice=string.lower(arg or "")
                if choice=="on" then self:SetCastBarFlavorTextEnabled(true,false)
                elseif choice=="off" then self:SetCastBarFlavorTextEnabled(false,false)
                else self:SetCastBarFlavorTextEnabled(not SlamFramesDB.castbarFlavorTextEnabled,false) end
                return
            elseif sub == "flavorscale" or sub == "flavourscale" or sub == "flavorsize" then
                local n=tonumber(arg)
                if n then self:SetCastBarFlavorTextScale(n,false)
                elseif self.Print then self.Print("usage: /sf castbar flavorscale 0.60-2.00") end
                return
            elseif sub == "style" or sub == "skin" then
                local choice = string.lower(arg or "")
                if choice == "" then
                    self:SetCastBarStyle((tonumber(SlamFramesDB.castbarStyle) == 2) and 1 or 2, false)
                elseif choice == "1" or choice == "classic" or choice == "standard" then
                    self:SetCastBarStyle(1, false)
                elseif choice == "2" or choice == "ornate" or choice == "gold" or choice == "ornate gold" then
                    self:SetCastBarStyle(2, false)
                elseif self.Print then
                    self.Print("usage: /sf castbar style 1|2  (Classic | Ornate)")
                end
                return
            end
        end

        return OriginalHandleSlash(self, msg)
    end
end

-- ---------------------------------------------------------------------------
-- 6) INITIALIZATION / SAVED-VARIABLE COMPATIBILITY
-- ---------------------------------------------------------------------------
-- SlamFrames 1.0 currently migrates every saved castbarStyle back to 1 during
-- DBInit.  Capture the SavedVariables value at ADDON_LOADED, then restore it on
-- the first PLAYER_ENTERING_WORLD after DBInit has completed.

local savedCastbarStyle = nil
local styleRestored = false
local init = CreateFrame("Frame", "SlamFrames_EnhancementsInit", UIParent)
init:RegisterEvent("ADDON_LOADED")
init:RegisterEvent("VARIABLES_LOADED")
init:RegisterEvent("PLAYER_ENTERING_WORLD")
init:RegisterEvent("PLAYER_TARGET_CHANGED")
init:SetScript("OnEvent", function()
    local ev = event
    if ev == "ADDON_LOADED" then
        if arg1 == "SlamFrames" and SlamFramesDB then
            local n = tonumber(SlamFramesDB.castbarStyle)
            if n == 1 or n == 2 then savedCastbarStyle = n end
        end
        return
    end

    if ev == "VARIABLES_LOADED" then
        if SlamFramesDB then
            if SlamFramesDB.healPredictionEnabled == nil then SlamFramesDB.healPredictionEnabled = true end
            if SlamFramesDB.healPredictionAlpha == nil then SlamFramesDB.healPredictionAlpha = 0.55 end
            if SlamFramesDB.castbarFlavorTextEnabled == nil then SlamFramesDB.castbarFlavorTextEnabled = true end
            if SlamFramesDB.castbarFlavorTextScale == nil then SlamFramesDB.castbarFlavorTextScale = 1.00 end
        end
        TryBindHealComm()
        return
    end

    if ev == "PLAYER_ENTERING_WORLD" then
        if SlamFramesDB then
            if SlamFramesDB.healPredictionEnabled == nil then SlamFramesDB.healPredictionEnabled = true end
            if SlamFramesDB.healPredictionAlpha == nil then SlamFramesDB.healPredictionAlpha = 0.55 end
            if SlamFramesDB.castbarFlavorTextEnabled == nil then SlamFramesDB.castbarFlavorTextEnabled = true end
            if SlamFramesDB.castbarFlavorTextScale == nil then SlamFramesDB.castbarFlavorTextScale = 1.00 end
            if not styleRestored then
                styleRestored = true
                if savedCastbarStyle == 2 and CB.styles and CB.styles[2] then
                    SlamFramesDB.castbarStyle = 2
                else
                    SlamFramesDB.castbarStyle = 1
                end
                if SF.castbar then SF:LayoutCastBar() end
            end
        end
        TryBindHealComm()
        if SF.UpdateHealPredictions then SF:UpdateHealPredictions() end
        if SF.RefreshSettings then SF:RefreshSettings() end
        return
    end

    if ev == "PLAYER_TARGET_CHANGED" then
        if SF.UpdateHealPredictionForFrame then SF:UpdateHealPredictionForFrame(SF.target, "target") end
    end
end)
