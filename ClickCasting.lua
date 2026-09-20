-- SlamFrames TEST50 - real Button OnClick dispatch + SuperWoW direct-unit click casting.
-- Designed for OctoWoW / Vanilla 1.12-era APIs.
-- Click casting is implemented natively in SlamFrames. HealBotBlue and Puppeteer
-- were used as behavioral/reference sources for Vanilla click-targeting concepts.

SlamFrames = SlamFrames or {}
local SF = SlamFrames

local BOOK = BOOKTYPE_SPELL or "spell"
local BUTTON_LABELS = {LeftButton="Left",RightButton="Right",MiddleButton="Middle"}
local MODIFIER_LABELS = {none="No Modifier",shift="Shift",ctrl="Ctrl",alt="Alt",multi="Multiple Modifiers"}
local ACTION_LABELS = {normal="Normal",spell="Cast Spell",item="Use Item",target="Target Unit",menu="Unit Menu",none="Disabled"}
local ACTION_ORDER = {normal="spell",spell="item",item="target",target="menu",menu="none",none="normal"}
local DEBUFF_COLORS = {
    Magic   = {0.20,0.55,1.00},
    Curse   = {0.68,0.30,0.92},
    Disease = {0.72,0.48,0.16},
    Poison  = {0.22,0.82,0.25},
    Other   = {0.92,0.18,0.18},
}

local function Print(msg)
    if SF.Print then SF.Print(msg)
    elseif DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("SlamFrames: "..msg) end
end

local function Trim(s)
    s=tostring(s or "")
    s=string.gsub(s,"^%s+","")
    s=string.gsub(s,"%s+$","")
    return s
end

local function ValidAction(v)
    return v=="normal" or v=="spell" or v=="item" or v=="target" or v=="menu" or v=="none"
end

local function NewBinding(action,spell)
    local b={}
    b.action=ValidAction(action) and action or "normal"
    b.spell=Trim(spell)
    return b
end

local function MigrateLegacyBinding(src,defaultBase)
    if type(src)~="table" then return NewBinding("normal","") end
    if ValidAction(src.action) then return NewBinding(src.action,src.spell) end
    if src.mode=="spell" then return NewBinding("spell",src.spell) end
    if src.mode=="base" then
        local base=src.base
        -- TEST46 shipped Target/Menu/None as the initial party-frame defaults.
        -- Convert those untouched defaults to NORMAL so TEST48's UI reflects
        -- the simpler "leave it alone unless I override it" model.
        if base==defaultBase then return NewBinding("normal",src.spell) end
        if base=="target" or base=="menu" or base=="none" then return NewBinding(base,src.spell) end
    end
    return NewBinding("normal",src.spell)
end

local function EnsureModifierSet(set)
    if type(set)~="table" then set={} end
    if type(set.LeftButton)~="table" then set.LeftButton=NewBinding("normal","")
    else set.LeftButton=NewBinding(set.LeftButton.action,set.LeftButton.spell) end
    if type(set.RightButton)~="table" then set.RightButton=NewBinding("normal","")
    else set.RightButton=NewBinding(set.RightButton.action,set.RightButton.spell) end
    if type(set.MiddleButton)~="table" then set.MiddleButton=NewBinding("normal","")
    else set.MiddleButton=NewBinding(set.MiddleButton.action,set.MiddleButton.spell) end
    return set
end

function SF:InitClickCastingDB()
    if not SlamFramesDB then return end
    if SlamFramesDB.clickCastingEnabled==nil then SlamFramesDB.clickCastingEnabled=false end
    if SlamFramesDB.clickCastingApplyNormal==nil then SlamFramesDB.clickCastingApplyNormal=false end
    if SlamFramesDB.clickCastingTooltip==nil then SlamFramesDB.clickCastingTooltip=true end
    if SlamFramesDB.partyDebuffAlerts==nil then SlamFramesDB.partyDebuffAlerts=true end
    if SlamFramesDB.partyDebuffOnlyDispellable==nil then SlamFramesDB.partyDebuffOnlyDispellable=true end
    if SlamFramesDB.partyDebuffMessage==nil then SlamFramesDB.partyDebuffMessage=true end
    if SlamFramesDB.partyDebuffSound==nil then SlamFramesDB.partyDebuffSound=false end

    if type(SlamFramesDB.clickBindingSets)~="table" then
        SlamFramesDB.clickBindingSets={}
        -- Migrate TEST46's flat bindings into the no-modifier layer.
        local legacy=type(SlamFramesDB.clickBindings)=="table" and SlamFramesDB.clickBindings or {}
        SlamFramesDB.clickBindingSets.none={
            LeftButton=MigrateLegacyBinding(legacy.LeftButton,"target"),
            RightButton=MigrateLegacyBinding(legacy.RightButton,"menu"),
            MiddleButton=MigrateLegacyBinding(legacy.MiddleButton,"none"),
        }
    end
    SlamFramesDB.clickBindingSets.none=EnsureModifierSet(SlamFramesDB.clickBindingSets.none)
    SlamFramesDB.clickBindingSets.shift=EnsureModifierSet(SlamFramesDB.clickBindingSets.shift)
    SlamFramesDB.clickBindingSets.ctrl=EnsureModifierSet(SlamFramesDB.clickBindingSets.ctrl)
    SlamFramesDB.clickBindingSets.alt=EnsureModifierSet(SlamFramesDB.clickBindingSets.alt)
end

function SF:GetClickBinding(modifier,button)
    -- Backward-compatible helper form: GetClickBinding("LeftButton")
    if button==nil then button=modifier; modifier="none" end
    modifier=modifier or "none"
    if not SlamFramesDB or type(SlamFramesDB.clickBindingSets)~="table" then return nil end
    local set=SlamFramesDB.clickBindingSets[modifier]
    return set and set[button] or nil
end

function SF:GetActiveClickModifier()
    local shift=type(IsShiftKeyDown)=="function" and IsShiftKeyDown() and true or false
    local ctrl=type(IsControlKeyDown)=="function" and IsControlKeyDown() and true or false
    local alt=type(IsAltKeyDown)=="function" and IsAltKeyDown() and true or false
    local count=(shift and 1 or 0)+(ctrl and 1 or 0)+(alt and 1 or 0)
    if count>1 then return "multi" end
    if shift then return "shift" end
    if ctrl then return "ctrl" end
    if alt then return "alt" end
    return "none"
end

local function SuspendAutoSelfCast()
    if type(GetCVar)~="function" or type(SetCVar)~="function" then return nil,false end
    local ok,value=pcall(GetCVar,"autoSelfCast")
    if not ok then return nil,false end
    pcall(SetCVar,"autoSelfCast","0")
    return value,true
end

local function RestoreAutoSelfCast(value,changed)
    if changed and type(SetCVar)=="function" and value~=nil then pcall(SetCVar,"autoSelfCast",value) end
end

function SF:SetClickCastingEnabled(v,quiet)
    SlamFramesDB.clickCastingEnabled=v and true or false
    if not quiet then Print("click casting "..(SlamFramesDB.clickCastingEnabled and "ON" or "OFF")) end
    if self.RefreshSettings then self:RefreshSettings() end
end

function SF:SetClickCastingApplyNormal(v,quiet)
    SlamFramesDB.clickCastingApplyNormal=v and true or false
    if not quiet then Print("click casting on Player/Target/ToT "..(SlamFramesDB.clickCastingApplyNormal and "ON" or "OFF")) end
    if self.RefreshSettings then self:RefreshSettings() end
end

function SF:SetClickCastingTooltip(v,quiet)
    SlamFramesDB.clickCastingTooltip=v and true or false
    if not quiet then Print("click binding tooltips "..(SlamFramesDB.clickCastingTooltip and "ON" or "OFF")) end
    if self.RefreshSettings then self:RefreshSettings() end
end

function SF:SetClickBindingAction(modifier,button,action,quiet)
    local b=self:GetClickBinding(modifier,button); if not b or not ValidAction(action) then return end
    b.action=action
    if not quiet then Print((MODIFIER_LABELS[modifier] or modifier).." + "..(BUTTON_LABELS[button] or button)..": "..(ACTION_LABELS[action] or action)) end
    if self.RefreshSettings then self:RefreshSettings() end
end

function SF:CycleClickBindingAction(modifier,button,quiet)
    local b=self:GetClickBinding(modifier,button); if not b then return end
    self:SetClickBindingAction(modifier,button,ACTION_ORDER[b.action] or "normal",quiet)
end

function SF:SetClickSpell(modifier,button,spell,quiet)
    -- Backward-compatible helper form: SetClickSpell(button,spell,quiet)
    if button=="LeftButton" or button=="RightButton" or button=="MiddleButton" then
        -- New signature already in use.
    elseif modifier=="LeftButton" or modifier=="RightButton" or modifier=="MiddleButton" then
        quiet=spell; spell=button; button=modifier; modifier="none"
    end
    local b=self:GetClickBinding(modifier,button); if not b then return end
    b.spell=Trim(spell)
    if not quiet then
        if b.spell=="" then Print((MODIFIER_LABELS[modifier] or modifier).." + "..(BUTTON_LABELS[button] or button).." spell cleared")
        else Print((MODIFIER_LABELS[modifier] or modifier).." + "..(BUTTON_LABELS[button] or button).." spell: "..b.spell) end
    end
    if self.RefreshSettings then self:RefreshSettings() end
end

local function FindSpellId(pattern)
    pattern=Trim(pattern)
    if pattern=="" then return nil end
    local wanted=string.lower(pattern)
    local exact=nil
    local latestBase=nil
    local i=1
    while true do
        local name,rank=GetSpellName(i,BOOK)
        if not name then break end
        local full=name
        if rank and rank~="" then full=name.." ("..rank..")" end
        if string.lower(full)==wanted or string.lower(name.."("..(rank or "")..")")==wanted then
            exact=i; break
        end
        if string.lower(name)==wanted then latestBase=i end
        i=i+1
    end
    return exact or latestBase
end


local function HasSuperWoWDirectUnitCast()
    -- SuperWoW extends CastSpellByName(spell, unit). Prefer this path because
    -- it is exactly what current Vanilla healer-frame projects use to avoid
    -- target swapping for friendly click casts.
    if type(CastSpellByName)~="function" then return false end
    if SUPERWOW_VERSION then return true end
    if type(GetSuperWoWVersion)=="function" then return true end
    -- OctoWoW builds can expose SuperWoW functionality without a version
    -- global. SetMouseoverUnit is another SuperWoW API and is a safe marker.
    if type(SetMouseoverUnit)=="function" then return true end
    return false
end

local function QuietTargetUnit(unit)
    if not unit or not UnitExists(unit) or type(TargetUnit)~="function" then return end
    local oldPlaySound=PlaySound
    if oldPlaySound then PlaySound=function() end end
    TargetUnit(unit)
    if oldPlaySound then PlaySound=oldPlaySound end
end

local function RestoreImmediateTarget(hadTarget)
    local oldPlaySound=PlaySound
    if oldPlaySound then PlaySound=function() end end
    if hadTarget then
        if type(TargetLastTarget)=="function" then TargetLastTarget() end
    elseif type(ClearTarget)=="function" then
        ClearTarget()
    end
    if oldPlaySound then PlaySound=oldPlaySound end
end

function SF:SetClickCastDebug(v,quiet)
    self.clickCastDebug=v and true or false
    if not quiet then Print("click-cast debug "..(self.clickCastDebug and "ON" or "OFF")) end
end

local function ClickDebug(msg)
    if SF.clickCastDebug then Print("CLICKDBG: "..tostring(msg)) end
end

function SF:ProcessClickTargetRestore()
    local p=self.clickTargetRestorePending
    if not p then return end
    if GetTime() < (p.restoreAt or 0) then return end
    self.clickTargetRestorePending=nil

    -- If the player manually changed target during the tiny casting window,
    -- respect that choice instead of snapping them back somewhere else.
    if p.tempUnit and type(UnitIsUnit)=="function" and UnitExists("target") then
        local ok,same=pcall(UnitIsUnit,"target",p.tempUnit)
        if ok and not same then return end
    end

    local oldPlaySound=PlaySound
    local noSound=function() end
    if oldPlaySound then PlaySound=noSound end
    if not p.hadTarget then
        if type(ClearTarget)=="function" then ClearTarget() end
    elseif p.wasEnemy and type(TargetLastEnemy)=="function" then
        TargetLastEnemy()
    elseif type(TargetLastTarget)=="function" then
        TargetLastTarget()
    elseif p.oldName and type(TargetByName)=="function" then
        TargetByName(p.oldName)
    end
    if oldPlaySound then PlaySound=oldPlaySound end
end

local function CaptureClickTargetOrigin(unit)
    -- Rapid click-casts can happen before the prior 0.10s restore fires.
    -- Preserve the ORIGINAL target rather than treating the temporary heal
    -- target as the new origin.
    local pending=SF.clickTargetRestorePending
    if pending then
        return pending.hadTarget,pending.wasEnemy,pending.oldName,false
    end

    local hadTarget=UnitExists("target") and true or false
    local wasEnemy=false
    local oldName=nil
    if hadTarget then
        oldName=UnitName("target")
        if type(UnitCanAttack)=="function" then wasEnemy=UnitCanAttack("player","target") and true or false end
    end

    local same=false
    if hadTarget and unit and UnitExists(unit) then
        if type(UnitIsUnit)=="function" then
            local ok,v=pcall(UnitIsUnit,"target",unit)
            if ok then same=v and true or false end
        elseif oldName and UnitName(unit)==oldName then
            same=true
        end
    end
    return hadTarget,wasEnemy,oldName,same
end

local function TargetForClickCast(unit)
    if not unit or not UnitExists(unit) then return false end
    if type(UnitIsUnit)=="function" and UnitExists("target") then
        local ok,same=pcall(UnitIsUnit,"target",unit)
        if ok and same then return true end
    end
    if type(TargetUnit)=="function" then
        TargetUnit(unit)
        return true
    end
    return false
end

local function ScheduleClickTargetRestore(hadTarget,wasEnemy,oldName,sameAsOriginal,unit)
    if sameAsOriginal then
        SF.clickTargetRestorePending=nil
        return
    end
    SF.clickTargetRestorePending={
        hadTarget=hadTarget,
        wasEnemy=wasEnemy,
        oldName=oldName,
        tempUnit=unit,
        restoreAt=GetTime()+0.10,
    }
end

function SF:CastClickSpell(spell,unit)
    spell=Trim(spell)
    if spell=="" or not unit or not UnitExists(unit) then
        ClickDebug("spell rejected: empty spell or invalid unit "..tostring(unit))
        return false
    end

    local id=FindSpellId(spell)
    if not id then
        Print("click cast spell not found: "..spell)
        return false
    end

    -- TEST50: use the same execution model as current Vanilla healer frames.
    -- On SuperWoW, CastSpellByName accepts the unit token as its second
    -- argument, so no temporary target is required at all.
    if HasSuperWoWDirectUnitCast() then
        ClickDebug("CastSpellByName direct: "..spell.." -> "..unit)
        local ok,err=pcall(CastSpellByName,spell,unit)
        if not ok then
            Print("click cast error: "..tostring(err))
            return false
        end
        return true
    end

    -- Pure 1.12 fallback: Puppeteer/HealersMate-style temporary targeting.
    -- Target before invoking CastSpellByName, then restore immediately after
    -- the cast call has been dispatched from the hardware OnClick event.
    local hadTarget=UnitExists("target") and true or false
    local same=false
    if hadTarget and type(UnitIsUnit)=="function" then
        local ok,v=pcall(UnitIsUnit,"target",unit)
        if ok then same=v and true or false end
    end

    if not same then QuietTargetUnit(unit) end
    ClickDebug("CastSpellByName fallback: "..spell.." -> "..unit)
    local ok,err=pcall(CastSpellByName,spell)
    if not ok then
        if not same then RestoreImmediateTarget(hadTarget) end
        Print("click cast error: "..tostring(err))
        return false
    end

    if type(SpellIsTargeting)=="function" and SpellIsTargeting() and type(SpellTargetUnit)=="function" then
        SpellTargetUnit(unit)
        if type(SpellStopTargeting)=="function" and SpellIsTargeting() then SpellStopTargeting() end
    end
    if not same then RestoreImmediateTarget(hadTarget) end
    return true
end


local function NormalizeUseItemPattern(pattern)
    pattern=Trim(pattern)
    if pattern=="" then return "" end
    -- Accept either the plain item name or the familiar macro form:
    -- /use Major Healing Potion
    pattern=string.gsub(pattern,"^/[Uu][Ss][Ee]%s+","")
    pattern=string.gsub(pattern,"^%s+","")
    pattern=string.gsub(pattern,"%s+$","")
    if string.sub(pattern,1,1)=='"' and string.sub(pattern,-1)=='"' and string.len(pattern)>1 then
        pattern=string.sub(pattern,2,-2)
    end
    return pattern
end

local function ItemNameFromLink(link)
    if type(link)~="string" then return nil end
    local _,_,name=string.find(link,"%[(.-)%]")
    return name
end

local function FindBagItem(itemName)
    if not itemName or itemName=="" then return nil,nil end
    local wanted=string.lower(itemName)
    local maxBag=NUM_BAG_FRAMES or 4
    local bag=0
    while bag<=maxBag do
        local slots=GetContainerNumSlots and GetContainerNumSlots(bag) or 0
        local slot=1
        while slot<=slots do
            local link=GetContainerItemLink and GetContainerItemLink(bag,slot) or nil
            local name=ItemNameFromLink(link)
            if name and string.lower(name)==wanted then return bag,slot end
            slot=slot+1
        end
        bag=bag+1
    end
    return nil,nil
end

local function FindEquippedItemSlot(itemName)
    if not itemName or itemName=="" or type(GetInventoryItemLink)~="function" then return nil end
    local wanted=string.lower(itemName)
    local slot=1
    while slot<=19 do
        local link=GetInventoryItemLink("player",slot)
        local name=ItemNameFromLink(link)
        if name and string.lower(name)==wanted then return slot end
        slot=slot+1
    end
    return nil
end

function SF:UseClickItem(pattern,unit)
    local itemName=NormalizeUseItemPattern(pattern)
    if itemName=="" then return false end

    -- Permit /use 13 style inventory-slot bindings in addition to item names.
    local numericSlot=tonumber(itemName)
    local bag,slot=nil,nil
    local invSlot=nil
    if numericSlot and numericSlot>=1 and numericSlot<=19 and math.floor(numericSlot)==numericSlot then
        invSlot=numericSlot
    else
        bag,slot=FindBagItem(itemName)
        if not bag then invSlot=FindEquippedItemSlot(itemName) end
    end

    if not bag and invSlot==nil then
        Print("click use item not found: "..itemName)
        return false
    end

    -- Items do not have a SuperWoW direct-unit overload. Match Puppeteer's
    -- proven Vanilla path: temporarily target the clicked unit, use the item,
    -- resolve a targeting cursor if one appears, then restore the old target.
    local hadTarget=UnitExists("target") and true or false
    local same=false
    if hadTarget and unit and UnitExists(unit) and type(UnitIsUnit)=="function" then
        local ok,v=pcall(UnitIsUnit,"target",unit)
        if ok then same=v and true or false end
    end
    if unit and UnitExists(unit) and not same then QuietTargetUnit(unit) end

    if bag then
        ClickDebug("UseContainerItem "..tostring(bag)..","..tostring(slot).." ["..itemName.."]")
        UseContainerItem(bag,slot)
    elseif type(UseInventoryItem)=="function" then
        ClickDebug("UseInventoryItem "..tostring(invSlot).." ["..itemName.."]")
        UseInventoryItem(invSlot)
    end

    if unit and UnitExists(unit) and type(SpellIsTargeting)=="function" and SpellIsTargeting() and type(SpellTargetUnit)=="function" then
        SpellTargetUnit(unit)
        if type(SpellStopTargeting)=="function" and SpellIsTargeting() then SpellStopTargeting() end
    end

    if not same then RestoreImmediateTarget(hadTarget) end
    return true
end


function SF:TargetClickUnit(frame)
    if not frame or not frame.unit or not UnitExists(frame.unit) then return true end
    if type(TargetUnit)=="function" then
        TargetUnit(frame.unit)
        if self.UpdateTarget then self:UpdateTarget() end
    end
    return true
end

function SF:RunNormalFrameClick(frame,button)
    if not frame then return true end
    if button=="RightButton" then
        if self.UnitMenuForFrame then self:UnitMenuForFrame(frame) end
        return true
    elseif button=="LeftButton" then
        -- Preserve SlamFrames' existing behavior exactly when a binding is
        -- set to NORMAL: party left-click targets; Player left-click targets
        -- self only when the existing Self Target option is enabled; Target
        -- and ToT left-click remain unchanged/no-op.
        if frame.frameKey=="party" or frame.frameKey=="raid" then return self:TargetClickUnit(frame) end
        if frame.frameKey=="player" and SlamFramesDB.selfTargetOnClick then return self:TargetClickUnit(frame) end
        return true
    end
    -- Middle click has no stock SlamFrames action.
    return true
end

function SF:RunClickAction(frame,button,action,spell)
    if action=="normal" then return self:RunNormalFrameClick(frame,button) end
    if action=="target" then return self:TargetClickUnit(frame) end
    if action=="menu" then
        if self.UnitMenuForFrame then self:UnitMenuForFrame(frame) end
        return true
    end
    if action=="spell" then
        -- Spell mode owns the click. A failed/cooldown/invalid spell must not
        -- unexpectedly target the unit or open a menu.
        if spell and spell~="" then self:CastClickSpell(spell,frame.unit) end
        return true
    end
    if action=="item" then
        -- Item mode is the /use equivalent. Potions and food are immediate
        -- self-use items; targetable items such as bandages use the clicked unit.
        if spell and spell~="" then self:UseClickItem(spell,frame.unit) end
        return true
    end
    -- NONE / disabled owns and intentionally consumes the click.
    return true
end

function SF:FrameUsesClickCasting(frame)
    if not frame or not SlamFramesDB or not SlamFramesDB.clickCastingEnabled then return false end
    if frame.frameKey=="party" or frame.frameKey=="raid" then return true end
    if SlamFramesDB.clickCastingApplyNormal and (frame.frameKey=="player" or frame.frameKey=="target" or frame.frameKey=="tot") then return true end
    return false
end

function SF:HandleUnitFrameClick(frame,button)
    if not self:FrameUsesClickCasting(frame) then return false end
    if button~="LeftButton" and button~="RightButton" and button~="MiddleButton" then return false end

    local modifier=self:GetActiveClickModifier()
    -- TEST48 intentionally exposes only the three individual modifiers. If
    -- multiple modifiers are held simultaneously, use normal frame behavior
    -- instead of guessing which healing binding the player intended.
    if modifier=="multi" then return self:RunNormalFrameClick(frame,button) end

    local b=self:GetClickBinding(modifier,button)
    if not b then return self:RunNormalFrameClick(frame,button) end
    return self:RunClickAction(frame,button,b.action or "normal",b.spell)
end

function SF:GetClickBindingText(modifier,button)
    if button==nil then button=modifier; modifier="none" end
    local b=self:GetClickBinding(modifier,button)
    if not b then return "Normal" end
    if b.action=="spell" then
        if b.spell and b.spell~="" then return "Cast: "..b.spell end
        return "Cast Spell (not set)"
    end
    if b.action=="item" then
        if b.spell and b.spell~="" then return "Use: "..b.spell end
        return "Use Item (not set)"
    end
    return ACTION_LABELS[b.action] or "Normal"
end

function SF:ShowClickCastingTooltip(frame)
    if not frame or not self:FrameUsesClickCasting(frame) or not SlamFramesDB.clickCastingTooltip then return end
    if not GameTooltip then return end
    GameTooltip:SetOwner(frame,"ANCHOR_RIGHT")
    local title=(frame.unit and UnitName(frame.unit)) or "SlamFrames"
    GameTooltip:SetText(title or "SlamFrames",1,0.82,0)
    local modifier=self:GetActiveClickModifier()
    if modifier=="multi" then
        GameTooltip:AddLine("Multiple modifiers: normal frame behavior",0.72,0.72,0.72)
    else
        GameTooltip:AddLine(MODIFIER_LABELS[modifier] or "No Modifier",0.72,0.72,0.72)
        GameTooltip:AddLine("Left: "..self:GetClickBindingText(modifier,"LeftButton"),1,1,1)
        GameTooltip:AddLine("Right: "..self:GetClickBindingText(modifier,"RightButton"),1,1,1)
        GameTooltip:AddLine("Middle: "..self:GetClickBindingText(modifier,"MiddleButton"),1,1,1)
    end
    GameTooltip:Show()
end


-- -------------------------------------------------------------------------
-- Dedicated hardware click buttons
-- -------------------------------------------------------------------------

function SF:EnsureUnitClickButton(frame)
    if not frame or frame.sfClickButton then return frame and frame.sfClickButton end
    local b=CreateFrame("Button",nil,frame)
    b:SetAllPoints(frame)
    b:RegisterForClicks("LeftButtonUp","RightButtonUp","MiddleButtonUp")
    b:SetNormalTexture(nil)
    b:SetHighlightTexture(nil)
    b:SetPushedTexture(nil)
    b.ownerFrame=frame

    b:SetScript("OnClick",function()
        local owner=this.ownerFrame
        if not owner then return end

        if SF.HandleUnitFrameClick and SF:HandleUnitFrameClick(owner,arg1) then return end

        -- Click casting disabled: preserve the frame's stock interactions.
        if arg1=="RightButton" then
            if SF.UnitMenuForFrame then SF:UnitMenuForFrame(owner) end
        elseif arg1=="LeftButton" then
            if owner.frameKey=="party" and owner.unit and type(TargetUnit)=="function" then
                TargetUnit(owner.unit)
                if SF.UpdateTarget then SF:UpdateTarget() end
            elseif owner.frameKey=="player" and SlamFramesDB.selfTargetOnClick and type(TargetUnit)=="function" then
                TargetUnit("player")
                if SF.UpdateTarget then SF:UpdateTarget() end
            end
        end
    end)

    b:SetScript("OnEnter",function()
        local owner=this.ownerFrame
        if owner and SF.ShowClickCastingTooltip then SF:ShowClickCastingTooltip(owner) end
    end)
    b:SetScript("OnLeave",function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    frame.sfClickButton=b
    self:RefreshUnitClickButton(frame)
    return b
end

function SF:RefreshUnitClickButton(frame)
    if not frame then return end
    local b=frame.sfClickButton
    if not b then return end
    -- Locked = interactive unit frame. Unlocked = parent owns the mouse so the
    -- player can drag/scale frames without accidentally casting.
    b:EnableMouse(SlamFramesDB and SlamFramesDB.locked and true or false)
    if SlamFramesDB and SlamFramesDB.locked then b:Show() else b:Hide() end
end

-- -------------------------------------------------------------------------
-- Party debuff alerts
-- -------------------------------------------------------------------------

local function CanonicalDebuffType(v)
    if type(v)~="string" then return nil end
    local s=string.lower(v)
    if string.find(s,"magic") then return "Magic" end
    if string.find(s,"curse") then return "Curse" end
    if string.find(s,"disease") then return "Disease" end
    if string.find(s,"poison") then return "Poison" end
    return nil
end

local function TextureCandidate(v)
    if type(v)~="string" then return nil end
    if string.find(v,"\\") or string.find(v,"Interface") then return v end
    return nil
end

local function ReadDebuff(unit,index,filtered)
    local r1,r2,r3,r4,r5,r6,r7,r8,r9,r10
    if filtered then r1,r2,r3,r4,r5,r6,r7,r8,r9,r10=UnitDebuff(unit,index,1)
    else r1,r2,r3,r4,r5,r6,r7,r8,r9,r10=UnitDebuff(unit,index) end
    if not r1 then return nil end
    local vals={r1,r2,r3,r4,r5,r6,r7,r8,r9,r10}
    local info={icon=nil,debuffType=nil,name=nil,filtered=filtered and true or false}
    local i,v
    for i=1,table.getn(vals) do
        v=vals[i]
        if not info.debuffType then info.debuffType=CanonicalDebuffType(v) end
        if not info.icon then info.icon=TextureCandidate(v) end
    end
    -- Compatibility APIs can return name first and texture third.
    if type(r1)=="string" and not TextureCandidate(r1) then info.name=r1 end
    return info
end

function SF:RefreshDispelCapabilities()
    self.dispelTypes={}
    local i=1
    while true do
        local name=GetSpellName(i,BOOK)
        if not name then break end
        local n=string.lower(name)
        if n=="cleanse" then self.dispelTypes.Magic=true; self.dispelTypes.Poison=true; self.dispelTypes.Disease=true
        elseif n=="purify" then self.dispelTypes.Poison=true; self.dispelTypes.Disease=true
        elseif n=="dispel magic" then self.dispelTypes.Magic=true
        elseif n=="cure disease" or n=="abolish disease" then self.dispelTypes.Disease=true
        elseif n=="cure poison" or n=="abolish poison" then self.dispelTypes.Poison=true
        elseif n=="remove curse" or n=="remove lesser curse" then self.dispelTypes.Curse=true
        end
        i=i+1
    end
end

function SF:CreatePartyDebuffAlerts()
    if not self.partyFrames then return end
    self.partyDebuffAlertState=self.partyDebuffAlertState or {}
    local i,f,a,t
    for i=1,table.getn(self.partyFrames) do
        f=self.partyFrames[i]
        if f and not f.debuffAlertFrame then
            a=CreateFrame("Frame",nil,f)
            a:SetAllPoints(f)
            a:SetFrameLevel(f:GetFrameLevel()+12)
            a:EnableMouse(false)
            a.top=a:CreateTexture(nil,"OVERLAY"); a.top:SetTexture("Interface\\Buttons\\WHITE8X8"); a.top:SetPoint("TOPLEFT",a,"TOPLEFT",1,-1); a.top:SetPoint("TOPRIGHT",a,"TOPRIGHT",-1,-1); a.top:SetHeight(2)
            a.bottom=a:CreateTexture(nil,"OVERLAY"); a.bottom:SetTexture("Interface\\Buttons\\WHITE8X8"); a.bottom:SetPoint("BOTTOMLEFT",a,"BOTTOMLEFT",1,1); a.bottom:SetPoint("BOTTOMRIGHT",a,"BOTTOMRIGHT",-1,1); a.bottom:SetHeight(2)
            a.left=a:CreateTexture(nil,"OVERLAY"); a.left:SetTexture("Interface\\Buttons\\WHITE8X8"); a.left:SetPoint("TOPLEFT",a,"TOPLEFT",1,-1); a.left:SetPoint("BOTTOMLEFT",a,"BOTTOMLEFT",1,1); a.left:SetWidth(2)
            a.right=a:CreateTexture(nil,"OVERLAY"); a.right:SetTexture("Interface\\Buttons\\WHITE8X8"); a.right:SetPoint("TOPRIGHT",a,"TOPRIGHT",-1,-1); a.right:SetPoint("BOTTOMRIGHT",a,"BOTTOMRIGHT",-1,1); a.right:SetWidth(2)
            a.icon=a:CreateTexture(nil,"OVERLAY")
            a.icon:SetPoint("TOPRIGHT",f,"TOPRIGHT",-5,-5)
            a.icon:SetWidth(18); a.icon:SetHeight(18)
            a.icon:SetTexCoord(0.07,0.93,0.07,0.93)
            a:Hide()
            f.debuffAlertFrame=a
        end
    end
    self:RefreshDispelCapabilities()
end

function SF:SetPartyDebuffAlerts(v,quiet)
    SlamFramesDB.partyDebuffAlerts=v and true or false
    self:UpdatePartyDebuffAlerts()
    if not quiet then Print("party debuff alerts "..(SlamFramesDB.partyDebuffAlerts and "ON" or "OFF")) end
    if self.RefreshSettings then self:RefreshSettings() end
end

function SF:SetPartyDebuffOnlyDispellable(v,quiet)
    SlamFramesDB.partyDebuffOnlyDispellable=v and true or false
    self:RefreshDispelCapabilities(); self:UpdatePartyDebuffAlerts()
    if not quiet then Print("debuff filter: "..(SlamFramesDB.partyDebuffOnlyDispellable and "dispellable by me" or "all debuffs")) end
    if self.RefreshSettings then self:RefreshSettings() end
end

function SF:SetPartyDebuffMessage(v,quiet)
    SlamFramesDB.partyDebuffMessage=v and true or false
    if not quiet then Print("debuff screen notifications "..(SlamFramesDB.partyDebuffMessage and "ON" or "OFF")) end
    if self.RefreshSettings then self:RefreshSettings() end
end

function SF:SetPartyDebuffSound(v,quiet)
    SlamFramesDB.partyDebuffSound=v and true or false
    if not quiet then Print("debuff sound notifications "..(SlamFramesDB.partyDebuffSound and "ON" or "OFF")) end
    if self.RefreshSettings then self:RefreshSettings() end
end

local function IsRelevantDebuff(info)
    if not info then return false end
    if not SlamFramesDB.partyDebuffOnlyDispellable then return true end
    if info.debuffType then
        return SF.dispelTypes and SF.dispelTypes[info.debuffType] and true or false
    end
    -- On localized clients the debuff type text may not be English.  When the
    -- Vanilla API itself returned the aura from UnitDebuff(..., 1), trust that
    -- native dispellable filter and still surface the alert with the neutral
    -- "Other" color rather than silently hiding it.
    return info.filtered and true or false
end

function SF:FindPartyDebuff(unit)
    if not unit or not UnitExists(unit) then return nil end
    local i=1
    while i<=32 do
        local info=ReadDebuff(unit,i,SlamFramesDB.partyDebuffOnlyDispellable)
        if not info then break end
        if IsRelevantDebuff(info) then return info end
        i=i+1
    end
    return nil
end

function SF:ShowPartyDebuffAlertMessage(unit,info)
    if not info or not unit then return end
    local name=UnitName(unit) or unit
    local dtype=info.debuffType or "Other"
    local c=DEBUFF_COLORS[dtype] or DEBUFF_COLORS.Other
    if SlamFramesDB.partyDebuffMessage and UIErrorsFrame and UIErrorsFrame.AddMessage then
        local alertText
        if info.name and info.name~="" then alertText=name.." has "..info.name.." ("..dtype..")"
        else
            if dtype=="Other" then alertText=name.." has a debuff"
            else alertText=name.." has a "..dtype.." debuff" end
        end
        UIErrorsFrame:AddMessage(alertText,c[1],c[2],c[3],1,UIERRORS_HOLD_TIME or 1)
    end
    if SlamFramesDB.partyDebuffSound and type(PlaySound)=="function" then pcall(PlaySound,"TellMessage") end
end

function SF:UpdatePartyDebuffAlert(index)
    local f=self.partyFrames and self.partyFrames[index]
    if not f or not f.debuffAlertFrame then return end
    local unit="party"..index
    if not SlamFramesDB.partyDebuffAlerts or not UnitExists(unit) then
        f.debuffAlertFrame:Hide(); self.partyDebuffAlertState[unit]=nil; return
    end
    local info=self:FindPartyDebuff(unit)
    if not info then
        f.debuffAlertFrame:Hide(); self.partyDebuffAlertState[unit]=nil; return
    end
    local dtype=info.debuffType or "Other"
    local c=DEBUFF_COLORS[dtype] or DEBUFF_COLORS.Other
    local a=f.debuffAlertFrame
    a.top:SetVertexColor(c[1],c[2],c[3],1); a.bottom:SetVertexColor(c[1],c[2],c[3],1); a.left:SetVertexColor(c[1],c[2],c[3],1); a.right:SetVertexColor(c[1],c[2],c[3],1)
    if info.icon then a.icon:SetTexture(info.icon); a.icon:Show() else a.icon:Hide() end
    a:Show()
    local sig=dtype.."|"..tostring(info.icon or "")
    if self.partyDebuffAlertState[unit]~=sig then
        self.partyDebuffAlertState[unit]=sig
        self:ShowPartyDebuffAlertMessage(unit,info)
    end
end

function SF:UpdatePartyDebuffAlerts(unit)
    if not self.partyFrames then return end
    if unit and string.sub(unit,1,5)=="party" then
        local idx=tonumber(string.sub(unit,6))
        if idx then self:UpdatePartyDebuffAlert(idx) end
        return
    end
    local i
    for i=1,table.getn(self.partyFrames) do self:UpdatePartyDebuffAlert(i) end
end

function SF:ApplyClickAlertLayer(frame,unitStrata,base)
    if not frame or not frame.debuffAlertFrame then return end
    frame.debuffAlertFrame:SetFrameStrata(unitStrata)
    frame.debuffAlertFrame:SetFrameLevel((base or frame.sfLayerBase or 10)+9)
    if frame.debuffAlertFrame.icon then
        local sz=math.max(10,18*(frame.layoutScale or 1))
        frame.debuffAlertFrame.icon:SetWidth(sz); frame.debuffAlertFrame.icon:SetHeight(sz)
    end
end
