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
    return ADDON:IsActive()
        and ADDON:IsHybrid()
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
    rt.pointerScenes = rt.pointerScenes or {}

    if shouldAttach then
        -- Do not claim or later remove a fragment another addon already owns.
        if not scene:HasFragment(MOUSE_POINTER_FRAGMENT) then
            scene:AddFragment(MOUSE_POINTER_FRAGMENT)
            rt.pointerScenes[sceneName] = scene
        end
    elseif rt.pointerScenes[sceneName] then
        scene:RemoveFragment(MOUSE_POINTER_FRAGMENT)
        rt.pointerScenes[sceneName] = nil
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

    if not self:IsActive() then
        if rt.pointerScenes then
            for sceneName, scene in pairs(rt.pointerScenes) do
                scene:RemoveFragment(MOUSE_POINTER_FRAGMENT)
                rt.pointerScenes[sceneName] = nil
            end
        end
        rt.pointerScene = false
        rt.pointerSceneName = nil
        return
    end

    local shouldRunPointer = self:IsHybrid()
        and self.saved.pointerEnabled
        and self:IsNativeGamepadMode()
        and MOUSE_POINTER_FRAGMENT ~= nil

    if not shouldRunPointer and rt.pointerScenes then
        for sceneName, scene in pairs(rt.pointerScenes) do
            scene:RemoveFragment(MOUSE_POINTER_FRAGMENT)
            rt.pointerScenes[sceneName] = nil
        end
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

    if SCENE_MANAGER.Show then
        ZO_PreHook(SCENE_MANAGER, "Show", function(_, sceneName)
            if ADDON:IsActive() and type(sceneName) == "string" then
                ADDON:ApplyPointerToScene(sceneName, false)
            end
        end)
    end

    if SCENE_MANAGER.OnSceneStateChange then
        ZO_PostHook(SCENE_MANAGER, "OnSceneStateChange", function(_, scene, oldState, newState)
            if not ADDON:IsActive() or not scene or not scene.GetName then
                return
            end

            if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                ADDON:ApplyPointerToScene(scene:GetName(), false)
            end

            -- Only the actual top scene owns the pointer and stick routing.
            ADDON:RefreshSceneController()
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
        if ADDON:IsActive() and ADDON:IsHybrid() and rt.pointerScene and DIRECTIONAL_INPUT then
            -- Only bypass ESO's "consume both sticks" method after an earlier
            -- UI input owner has already consumed the left stick. This is the
            -- fail-safe: if the pointer has not claimed it, ESO consumes both
            -- sticks normally and the player cannot move behind the menu.
            if DIRECTIONAL_INPUT:IsAvailable(ZO_DI_LEFT_STICK) then
                return false
            end
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
