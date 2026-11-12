-- ScenePolicy: keyboard UI is the default in Hybrid; explicitly native workflows stay native.
-- The native Gamepad scenes are selected by ESO or scoped routes. Unknown keyboard
-- scene names are treated as keyboard-pointer scenes so new ESO menus participate.

local ADDON = ESOHybridUI
local rt = ADDON.runtime

ADDON.SCENE_PRESENTATION_NATIVE = "native_gamepad"
ADDON.SCENE_PRESENTATION_KEYBOARD_POINTER = "keyboard_pointer"
ADDON.SCENE_PRESENTATION_SPECIAL = "special_native"

local SCENE_POLICIES = {
    hud = ADDON.SCENE_PRESENTATION_NATIVE,
    hudui = ADDON.SCENE_PRESENTATION_KEYBOARD_POINTER,
    lockpick = ADDON.SCENE_PRESENTATION_SPECIAL,
    gamepad_lockpick = ADDON.SCENE_PRESENTATION_SPECIAL,
    loot = ADDON.SCENE_PRESENTATION_SPECIAL,
    gamepad_loot = ADDON.SCENE_PRESENTATION_SPECIAL,
    death = ADDON.SCENE_PRESENTATION_SPECIAL,
    gamepad_death = ADDON.SCENE_PRESENTATION_SPECIAL,
    housingEditorHud = ADDON.SCENE_PRESENTATION_SPECIAL,
    housingEditorHudUI = ADDON.SCENE_PRESENTATION_SPECIAL,
    gamepadScreenshotMode = ADDON.SCENE_PRESENTATION_SPECIAL,
}

local function IsSpecialName(sceneName)
    local lower = string.lower(sceneName)
    return lower:find("lockpick", 1, true)
        or lower:find("loot", 1, true)
        or lower:find("death", 1, true)
        or lower:find("resurrect", 1, true)
        or lower:find("housingeditor", 1, true)
        or lower:find("playerinteraction", 1, true)
end

function ADDON:RegisterScenePresentation(sceneName, presentation)
    if type(sceneName) ~= "string" or sceneName == "" then return false end
    if presentation ~= self.SCENE_PRESENTATION_NATIVE
        and presentation ~= self.SCENE_PRESENTATION_KEYBOARD_POINTER
        and presentation ~= self.SCENE_PRESENTATION_SPECIAL then
        return false
    end
    SCENE_POLICIES[sceneName] = presentation
    return true
end

function ADDON:GetScenePresentation(sceneName)
    if type(sceneName) ~= "string" or sceneName == "" then
        return self.SCENE_PRESENTATION_NATIVE
    end
    local explicit = SCENE_POLICIES[sceneName]
    if explicit then return explicit end
    if sceneName:match("^gamepad") then return self.SCENE_PRESENTATION_NATIVE end
    if IsSpecialName(sceneName) then return self.SCENE_PRESENTATION_SPECIAL end
    return self.SCENE_PRESENTATION_KEYBOARD_POINTER
end

function ADDON:GetCurrentScenePresentation()
    local sceneManager = SCENE_MANAGER
    local sceneName = sceneManager and sceneManager.GetCurrentSceneName
        and sceneManager:GetCurrentSceneName() or nil
    return sceneName, self:GetScenePresentation(sceneName)
end

function ADDON:TraceScenePresentation(sceneName)
    if rt.traceEnabled then
        self:LogDebug("Scene presentation:", tostring(sceneName), "=>", self:GetScenePresentation(sceneName))
    end
end
