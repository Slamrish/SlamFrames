-- SlamFrames v0.19.20 - cast icon resolver / fallback database
-- Uses exact engine textures first, then recent action/item capture, the player's
-- spellbook, and finally a small built-in database for common Vanilla casts.

SlamFrames_CastIcons = SlamFrames_CastIcons or {}
local CI = SlamFrames_CastIcons

CI.session = CI.session or {}
CI.lastAction = CI.lastAction or nil
CI.hooksInstalled = CI.hooksInstalled or false
CI.lastTooltip = CI.lastTooltip or nil
CI.tooltipWatcher = CI.tooltipWatcher or nil

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

-- These are Blizzard-supplied icon paths already present in the client. No
-- external image files are required. The database is deliberately category-
-- oriented: exact item/action capture below still wins, so a Heavy Runecloth
-- Bandage can show its real item icon while "First Aid" still has a fallback.
CI.exact = {
    ["First Aid"]       = "Interface\\Icons\\INV_Misc_Bandage_12",
    ["Bandage"]         = "Interface\\Icons\\INV_Misc_Bandage_12",
    ["Hearthstone"]     = "Interface\\Icons\\INV_Misc_Rune_01",
    ["Mining"]          = "Interface\\Icons\\Trade_Mining",
    ["Smelting"]        = "Interface\\Icons\\Trade_Mining",
    ["Herbalism"]       = "Interface\\Icons\\Trade_Herbalism",
    ["Herb Gathering"]  = "Interface\\Icons\\Trade_Herbalism",
    ["Skinning"]        = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
    ["Fishing"]         = "Interface\\Icons\\Trade_Fishing",
    ["Cooking"]         = "Interface\\Icons\\INV_Misc_Food_15",
    ["Alchemy"]         = "Interface\\Icons\\Trade_Alchemy",
    ["Blacksmithing"]   = "Interface\\Icons\\Trade_BlackSmithing",
    ["Engineering"]     = "Interface\\Icons\\Trade_Engineering",
    ["Leatherworking"]  = "Interface\\Icons\\Trade_LeatherWorking",
    ["Tailoring"]       = "Interface\\Icons\\Trade_Tailoring",
    ["Enchanting"]      = "Interface\\Icons\\Trade_Engraving",
    ["Pick Lock"]       = "Interface\\Icons\\Spell_Nature_MoonKey",
    ["Lockpicking"]     = "Interface\\Icons\\Spell_Nature_MoonKey",
    ["Opening"]         = "Interface\\Icons\\INV_Misc_Bag_10",
}

CI.keywords = {
    {"bandage",       "Interface\\Icons\\INV_Misc_Bandage_12"},
    {"first aid",     "Interface\\Icons\\INV_Misc_Bandage_12"},
    {"hearth",        "Interface\\Icons\\INV_Misc_Rune_01"},
    {"mining",        "Interface\\Icons\\Trade_Mining"},
    {"smelt",         "Interface\\Icons\\Trade_Mining"},
    {"herb",          "Interface\\Icons\\Trade_Herbalism"},
    {"skinning",      "Interface\\Icons\\INV_Misc_Pelt_Wolf_01"},
    {"fish",          "Interface\\Icons\\Trade_Fishing"},
    {"cook",          "Interface\\Icons\\INV_Misc_Food_15"},
    {"alchemy",       "Interface\\Icons\\Trade_Alchemy"},
    {"blacksmith",    "Interface\\Icons\\Trade_BlackSmithing"},
    {"engineering",   "Interface\\Icons\\Trade_Engineering"},
    {"leatherwork",   "Interface\\Icons\\Trade_LeatherWorking"},
    {"tailor",        "Interface\\Icons\\Trade_Tailoring"},
    {"enchant",       "Interface\\Icons\\Trade_Engraving"},
    {"lock",          "Interface\\Icons\\Spell_Nature_MoonKey"},
    {"open",          "Interface\\Icons\\INV_Misc_Bag_10"},
    {"resurrect",     "Interface\\Icons\\Spell_Holy_Resurrection"},
    {"revive",        "Interface\\Icons\\Spell_Nature_Regenerate"},
    {"summon",        "Interface\\Icons\\Spell_Shadow_Twilight"},
}

local function UsefulTexture(tex)
    -- Vanilla-era SetTexture is most reliable with file paths. Treat numeric
    -- file IDs as unresolved so we can fall back to a real Interface\Icons path.
    if type(tex) ~= "string" or tex == "" then return false end
    local low = string.lower(tex)
    if string.find(low, "questionmark", 1, true) then return false end
    return true
end
CI.UsefulTexture = UsefulTexture

local function FirstTextureFromValues(...)
    local i,v
    for i=1,table.getn(arg) do
        v=arg[i]
        if type(v)=="string" and string.find(v,"Interface\\Icons\\",1,true) then return v end
    end
    return nil
end

local function CleanTooltipLabel(text)
    if type(text)~="string" then return nil end
    text=string.gsub(text,"^%s+","")
    text=string.gsub(text,"%s+$","")
    if text=="" then return nil end
    return text
end

function CI:RememberTooltip(text)
    text=CleanTooltipLabel(text)
    if not text then return end
    local low=string.lower(text)
    if low=="game menu" or low=="options" or low=="backpack" then return end
    self.lastTooltip={label=text,time=GetTime()}
end

function CI:RecentTooltip(maxAge)
    local a=self.lastTooltip
    if not a or not a.label then return nil end
    if (GetTime()-(a.time or 0)) > (maxAge or 1.25) then return nil end
    return a.label
end

function CI:ResolveDisplayName(name,isChannel)
    if type(name)=="string" then name=CleanTooltipLabel(name) end
    local low=name and string.lower(name) or ""
    local generic=(not name or name=="" or low=="casting" or low=="channeling" or low=="unknown")
    if not generic then return name end

    -- Timed world-object interactions can fire SPELLCAST_* with no name.
    -- Cache the world tooltip just before the click so we can show useful
    -- labels such as "Opening Barrel" rather than a blank cast bar.
    local object=self:RecentTooltip(1.50)
    if object and object~="" then return "Opening "..object end
    return isChannel and "Channeling" or "Opening"
end

function CI:InstallTooltipWatcher()
    if self.tooltipWatcher or type(CreateFrame)~="function" then return end
    local w=CreateFrame("Frame","SlamFramesCastTooltipWatcher",UIParent)
    w.elapsed=0
    w:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+(arg1 or 0)
        if this.elapsed<0.08 then return end
        this.elapsed=0
        if GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown() and GameTooltipTextLeft1 and GameTooltipTextLeft1.GetText then
            local text=GameTooltipTextLeft1:GetText()
            if text and text~="" then CI:RememberTooltip(text) end
        end
    end)
    self.tooltipWatcher=w
end

function CI:RememberAction(texture,label)
    if not UsefulTexture(texture) then return end
    self.lastAction={texture=texture,label=label,time=GetTime()}
end

function CI:RecentAction(maxAge)
    local a=self.lastAction
    if not a or not UsefulTexture(a.texture) then return nil end
    if (GetTime()-(a.time or 0)) > (maxAge or 1.50) then return nil end
    return a.texture,a.label
end

function CI:SpellIDTexture(spellID)
    spellID=tonumber(spellID)
    if not spellID then return nil end

    if C_Spell and type(C_Spell.GetSpellInfo)=="function" then
        local ok,a,b,c,d,e,f,g,h=pcall(C_Spell.GetSpellInfo,spellID)
        if ok then
            if type(a)=="table" then
                local t=a.iconID or a.icon or a.texture or a.iconFileID
                if UsefulTexture(t) then return t end
            else
                local t=FirstTextureFromValues(a,b,c,d,e,f,g,h)
                if UsefulTexture(t) then return t end
            end
        end
    end

    if type(GetSpellInfo)=="function" then
        local ok,a,b,c,d,e,f,g,h=pcall(GetSpellInfo,spellID)
        if ok then
            local t=FirstTextureFromValues(a,b,c,d,e,f,g,h)
            if UsefulTexture(t) then return t end
        end
    end
    return nil
end

function CI:SpellbookTexture(name)
    if not name or name=="" then return nil end
    if type(GetSpellName)~="function" or type(GetSpellTexture)~="function" then return nil end
    local book=BOOKTYPE_SPELL or "spell"
    local i=1
    while i<1200 do
        local n=GetSpellName(i,book)
        if not n then break end
        if n==name then
            local tex=GetSpellTexture(i,book)
            if UsefulTexture(tex) then return tex end
        end
        i=i+1
    end
    return nil
end

function CI:DatabaseTexture(name)
    if not name or name=="" then return nil end
    local tex=self.exact[name]
    if UsefulTexture(tex) then return tex end
    local low=string.lower(name)
    local i,pair
    for i=1,table.getn(self.keywords) do
        pair=self.keywords[i]
        if string.find(low,pair[1],1,true) then return pair[2] end
    end
    return nil
end

function CI:Resolve(name,spellID,engineTexture)
    -- 1) Never replace a real icon supplied by the cast API/native frame.
    if UsefulTexture(engineTexture) then
        if name and name~="" then self.session[name]=engineTexture end
        return engineTexture,"engine"
    end

    -- 2) A spell ID is the most reliable way to recover an omitted icon.
    local tex=self:SpellIDTexture(spellID)
    if UsefulTexture(tex) then
        if name and name~="" then self.session[name]=tex end
        return tex,"spellid"
    end

    -- 3) Ordinary spellbook lookup prevents a stale item click from ever
    -- replacing the icon of a normal learned spell.
    tex=self:SpellbookTexture(name)
    if UsefulTexture(tex) then
        if name and name~="" then self.session[name]=tex end
        return tex,"spellbook"
    end

    -- 4) Item/action hooks capture the actual icon that initiated the cast.
    -- This is the key path for bandages and other item-driven cast bars.
    tex=self:RecentAction(1.50)
    if UsefulTexture(tex) then
        if name and name~="" then self.session[name]=tex end
        return tex,"recent-action"
    end

    -- 5) Session associations learned earlier in this login.
    if name and UsefulTexture(self.session[name]) then return self.session[name],"session" end

    -- 6) Built-in Vanilla category database.
    tex=self:DatabaseTexture(name)
    if UsefulTexture(tex) then return tex,"database" end

    return QUESTION,"fallback"
end

local function CaptureUseAction(slot)
    if type(GetActionTexture)=="function" then
        local tex=GetActionTexture(slot)
        if UsefulTexture(tex) then CI:RememberAction(tex,"action:"..tostring(slot)) end
    end
end

local function CaptureContainerItem(bag,slot)
    if type(GetContainerItemInfo)=="function" then
        local tex=GetContainerItemInfo(bag,slot)
        if UsefulTexture(tex) then CI:RememberAction(tex,"bag:"..tostring(bag)..":"..tostring(slot)) end
    end
end

local function CaptureInventoryItem(slot)
    if type(GetInventoryItemTexture)=="function" then
        local tex=GetInventoryItemTexture("player",slot)
        if UsefulTexture(tex) then CI:RememberAction(tex,"inventory:"..tostring(slot)) end
    end
end

local function CaptureSpellBook(index,book)
    if type(GetSpellTexture)=="function" then
        local tex=GetSpellTexture(index,book or BOOKTYPE_SPELL or "spell")
        if UsefulTexture(tex) then CI:RememberAction(tex,"spellbook:"..tostring(index)) end
    end
end

local function CaptureTradeSkill(index)
    if type(GetTradeSkillIcon)=="function" then
        local tex=GetTradeSkillIcon(index)
        if UsefulTexture(tex) then CI:RememberAction(tex,"tradeskill:"..tostring(index)) end
    end
end

local function CaptureItemByName(item)
    if type(GetItemInfo)~="function" then return end
    local ok,a,b,c,d,e,f,g,h,i,j=pcall(GetItemInfo,item)
    if not ok then return end
    local tex=FirstTextureFromValues(a,b,c,d,e,f,g,h,i,j)
    if UsefulTexture(tex) then CI:RememberAction(tex,"item:"..tostring(item)) end
end

function CI:InstallHooks()
    if self.hooksInstalled then return end
    self.hooksInstalled=true

    -- Prefer secure post-hooks when the client provides them. If it doesn't,
    -- Vanilla-style wrappers are safe here because these hooks only remember a
    -- texture and then call the original function unchanged.
    local function Secure(name,func)
        if type(hooksecurefunc)=="function" then
            local ok=pcall(hooksecurefunc,name,func)
            if ok then return true end
        end
        return false
    end

    if type(UseAction)=="function" and not Secure("UseAction",function(slot) CaptureUseAction(slot) end) then
        local old=UseAction
        UseAction=function(slot,checkCursor,onSelf)
            CaptureUseAction(slot)
            return old(slot,checkCursor,onSelf)
        end
    end

    if type(UseContainerItem)=="function" and not Secure("UseContainerItem",function(bag,slot) CaptureContainerItem(bag,slot) end) then
        local old=UseContainerItem
        UseContainerItem=function(bag,slot,onSelf)
            CaptureContainerItem(bag,slot)
            return old(bag,slot,onSelf)
        end
    end

    if type(UseInventoryItem)=="function" and not Secure("UseInventoryItem",function(slot) CaptureInventoryItem(slot) end) then
        local old=UseInventoryItem
        UseInventoryItem=function(slot,onSelf)
            CaptureInventoryItem(slot)
            return old(slot,onSelf)
        end
    end

    if type(CastSpell)=="function" and not Secure("CastSpell",function(index,book) CaptureSpellBook(index,book) end) then
        local old=CastSpell
        CastSpell=function(index,book)
            CaptureSpellBook(index,book)
            return old(index,book)
        end
    end

    if type(CastSpellByName)=="function" and not Secure("CastSpellByName",function(name) local tex=CI:SpellbookTexture(name); if tex then CI:RememberAction(tex,name) end end) then
        local old=CastSpellByName
        CastSpellByName=function(name,onSelf)
            local tex=CI:SpellbookTexture(name); if tex then CI:RememberAction(tex,name) end
            return old(name,onSelf)
        end
    end

    if type(DoTradeSkill)=="function" and not Secure("DoTradeSkill",function(index) CaptureTradeSkill(index) end) then
        local old=DoTradeSkill
        DoTradeSkill=function(index,count)
            CaptureTradeSkill(index)
            return old(index,count)
        end
    end

    if type(UseItemByName)=="function" and not Secure("UseItemByName",function(item) CaptureItemByName(item) end) then
        local old=UseItemByName
        UseItemByName=function(item,onSelf)
            CaptureItemByName(item)
            return old(item,onSelf)
        end
    end
end

CI:InstallHooks()
