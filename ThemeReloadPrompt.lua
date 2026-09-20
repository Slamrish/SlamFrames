-- SlamFrames TEST 14 - theme reload prompt.
-- Reverts to the stable TEST 12 cast-bar skin behavior and asks for a UI reload
-- after a user changes Light/Dark so all texture-backed artwork is guaranteed
-- to reload consistently on the Vanilla/OctoWoW renderer.

local SF=SlamFrames
if not SF then return end

local POPUP_KEY="SLAMFRAMES_THEME_RELOAD"

local function ThemeLabel(name)
    if string.lower(tostring(name or ""))=="light" then return "Light" end
    return "Dark"
end

function SF:PromptThemeReload(name)
    local label=ThemeLabel(name)

    if StaticPopupDialogs and StaticPopup_Show then
        StaticPopupDialogs[POPUP_KEY]={
            text="SlamFrames theme changed to "..label..".\n\nReload the UI now so all theme artwork, including the Ornate cast bar, updates correctly?",
            button1="Reload Now",
            button2="Later",
            OnAccept=function()
                if type(ReloadUI)=="function" then ReloadUI() end
            end,
            timeout=0,
            whileDead=1,
            hideOnEscape=1,
        }
        StaticPopup_Show(POPUP_KEY)
        return
    end

    if self.Print then
        self.Print("theme changed to "..label..". Please /reload so all artwork updates correctly.")
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("SlamFrames: theme changed to "..label..". Please /reload so all artwork updates correctly.")
    end
end

local OriginalSetSkin=SF.SetSkin
if OriginalSetSkin and not SF.themeReloadPromptWrapped then
    SF.themeReloadPromptWrapped=true
    function SF:SetSkin(name,quiet)
        local old=(SlamFramesDB and SlamFramesDB.skin) or nil
        local ok=OriginalSetSkin(self,name,quiet)
        local new=(SlamFramesDB and SlamFramesDB.skin) or string.lower(tostring(name or ""))
        if ok and old and old~=new then
            self:PromptThemeReload(new)
        end
        return ok
    end
end
