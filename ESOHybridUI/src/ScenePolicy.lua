-- ScenePolicy: explicit per-scene presentation and input ownership.
--
-- Unknown scenes intentionally remain native Gamepad scenes. A scene is moved
-- to keyboard-pointer presentation only after its real ESO scene name and
-- fragments have been verified against the current client.

local ADDON = ESOHybridUI
local rt = ADDON.runtime

ADDON.SCENE_PRESENTATION_NATIVE = "native_gamepad"
ADDON.SCENE_PRESENTATION_KEYBOARD_POINTER = "keyboard_pointer"
ADDON.SCENE_PRESENTATION_SPECIAL = "special_native"

-- Entries are deliberately added only after source/runtime verification.
local SCENE_POLICIES = {}

function ADDON:RegisterScenePresentation(sceneName, presentation)
    if type(sceneName) ~= "string" or sceneName == "" then
        return false
    end
    if presentation ~= self.SCENE_PRESENTATION_NATIVE
        and presentation ~= self.SCENE_PRESENTATION_KEYBOARD_POINTER
        and presentation ~= self.SCENE_PRESENTATION_SPECIAL then
        return false
    end
    SCENE_POLICIES[sceneName] = presentation
    return true
end

function ADDON:GetScenePresentation(sceneName)
    return SCENE_POLICIES[sceneName] or self.SCENE_PRESENTATION_NATIVE
end

function ADDON:GetCurrentScenePresentation()
    local sceneManager = SCENE_MANAGER
    local sceneName = sceneManager and sceneManager.GetCurrentSceneName
        and sceneManager:GetCurrentSceneName() or nil
    return sceneName, self:GetScenePresentation(sceneName)
end

function ADDON:TraceScenePresentation(sceneName)
    if not rt.traceEnabled then
        return
    end
    self:LogDebug("Scene presentation:", tostring(sceneName),
        "=>", self:GetScenePresentation(sceneName))
end
