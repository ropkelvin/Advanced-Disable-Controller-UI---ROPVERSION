local ADDON = ESOHybridUI
local rt = ADDON.runtime

local NON_POINTER_SCENES = {
    hud = true,
    hudui = true,
    loot_gamepad = true,
    loading = true,
    characterselect = true,
    lockpickkeyboard = true,
    lockpickgamepad = true,
}

local function IsPointerScene(sceneName)
    if type(sceneName) ~= "string" then
        return false
    end
    local normalized = string.lower(sceneName)
    if NON_POINTER_SCENES[normalized] or string.find(normalized, "^gamepad") then
        return false
    end
    return true
end

local function ShouldUsePointer(sceneName)
    return ADDON:IsHybrid()
        and ADDON.saved.pointerEnabled
        and ADDON:IsNativeGamepadMode()
        and MOUSE_POINTER_FRAGMENT ~= nil
        and IsPointerScene(sceneName)
end

function ADDON:ApplyPointerToScene(sceneName, makeActive)
    if not SCENE_MANAGER or type(sceneName) ~= "string" then
        return
    end

    local scene = SCENE_MANAGER:GetScene(sceneName)
    if not scene then
        return
    end

    local shouldAttach = ShouldUsePointer(sceneName)
    if shouldAttach then
        scene:AddFragment(MOUSE_POINTER_FRAGMENT)
        rt.pointerScenes = rt.pointerScenes or {}
        rt.pointerScenes[sceneName] = scene
    else
        if MOUSE_POINTER_FRAGMENT then
            scene:RemoveFragment(MOUSE_POINTER_FRAGMENT)
        end
        if rt.pointerScenes then
            rt.pointerScenes[sceneName] = nil
        end
    end

    if makeActive then
        rt.pointerScene = shouldAttach
        rt.pointerSceneName = shouldAttach and sceneName or nil
    end
end

function ADDON:RefreshSceneController()
    if not SCENE_MANAGER then
        return
    end

    local shouldRunPointer = self:IsHybrid()
        and self.saved.pointerEnabled
        and self:IsNativeGamepadMode()
        and MOUSE_POINTER_FRAGMENT ~= nil

    if not shouldRunPointer and rt.pointerScenes then
        for _, scene in pairs(rt.pointerScenes) do
            scene:RemoveFragment(MOUSE_POINTER_FRAGMENT)
        end
        rt.pointerScenes = {}
    end

    local sceneName = SCENE_MANAGER:GetCurrentSceneName()
    if sceneName then
        self:ApplyPointerToScene(sceneName, true)
    else
        rt.pointerScene = false
        rt.pointerSceneName = nil
    end
end

local function InstallSceneHooks()
    if not SCENE_MANAGER or rt.pointerHookInstalled then
        return
    end

    -- Add the fragment before the scene begins showing. This hook does not
    -- replace scene routing or change ESO's scene transition behaviour.
    if SCENE_MANAGER.Show then
        ZO_PreHook(SCENE_MANAGER, "Show", function(_, sceneName)
            if type(sceneName) == "string" then
                ADDON:ApplyPointerToScene(sceneName, false)
            end
        end)
    end

    -- Track the actual top scene after ESO has processed the state transition.
    if SCENE_MANAGER.OnSceneStateChange then
        ZO_PostHook(SCENE_MANAGER, "OnSceneStateChange", function(_, scene, oldState, newState)
            if not scene or not scene.GetName then
                return
            end

            if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                ADDON:ApplyPointerToScene(scene:GetName(), true)
            elseif newState == SCENE_HIDDEN then
                if string.lower(scene:GetName()) == "lockpickkeyboard"
                    or string.lower(scene:GetName()) == "lockpickgamepad" then
                    rt.lockPicking = false
                    ADDON:ApplyMode()
                end
                ADDON:RefreshSceneController()
            end
        end)
    end

    rt.pointerHookInstalled = true
end

local function InstallDirectionalInputHook()
    if not ZO_IngameSceneManager or not ZO_IngameSceneManager.UpdateDirectionalInput
        or rt.directionalHookInstalled then
        return
    end

    ZO_PreHook(ZO_IngameSceneManager, "UpdateDirectionalInput", function()
        if ADDON:IsHybrid() and rt.pointerScene and DIRECTIONAL_INPUT then
            -- LibMousePointer owns the left stick while its fragment is active.
            -- Keep the right stick consumed by the UI so it cannot rotate the camera.
            DIRECTIONAL_INPUT:Consume(ZO_DI_RIGHT_STICK)
            return true
        end
        return false
    end)

    rt.directionalHookInstalled = true
end

function ADDON:InitializeSceneController()
    rt.pointerScenes = rt.pointerScenes or {}
    InstallSceneHooks()
    InstallDirectionalInputHook()
    self:RefreshSceneController()
end
