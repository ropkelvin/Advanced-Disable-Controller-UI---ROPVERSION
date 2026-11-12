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

local function IsRestrictedSceneName(sceneName)
    if type(sceneName) ~= "string" then
        return false
    end
    local normalized = string.lower(sceneName)
    return normalized == "scrying"
        or normalized == "tribute"
        or string.find(normalized, "market", 1, true) ~= nil
        or string.find(normalized, "crown", 1, true) ~= nil
        or string.find(normalized, "gildbarstore", 1, true) ~= nil
        or string.find(normalized, "endeavorsealstore", 1, true) ~= nil
        or string.find(normalized, "esoplusoffers", 1, true) ~= nil
        or string.find(normalized, "giftinventory", 1, true) ~= nil
        or string.find(normalized, "dailyloginrewards", 1, true) ~= nil
end

function ADDON:IsRestrictedSceneActive()
    if rt.restrictedSceneActive then
        return true
    end
    local currentSceneName = SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName()
    return IsRestrictedSceneName(currentSceneName)
end

local function IsPointerScene(sceneName)
    if type(sceneName) ~= "string" then
        return false
    end
    local normalized = string.lower(sceneName)
    if NON_POINTER_SCENES[normalized] or IsRestrictedSceneName(sceneName)
        or string.find(normalized, "gamepad", 1, true) ~= nil then
        return false
    end
    return true
end

local function ShouldUsePointer(sceneName)
    return ADDON:IsActive()
        and ADDON:IsHybrid()
        and ADDON.saved.pointerEnabled
        and ADDON:IsGamepadModeOn()
        and not rt.modeOverrideConflict
        and not ADDON:IsRestrictedSceneActive()
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
        and not self:IsRestrictedSceneActive()
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

local function UpdateRestrictedSceneState()
    local restrictedActive = IsRestrictedSceneName(SCENE_MANAGER:GetCurrentSceneName())
    if not restrictedActive and rt.restrictedScenes then
        for name, restrictedScene in pairs(rt.restrictedScenes) do
            if restrictedScene:IsShowing() then
                restrictedActive = true
                break
            else
                rt.restrictedScenes[name] = nil
            end
        end
    end

    local wasRestricted = rt.restrictedSceneActive == true
    rt.restrictedSceneActive = restrictedActive
    return wasRestricted and not restrictedActive
end

local function InstallSceneHooks()
    if not SCENE_MANAGER or rt.pointerHookInstalled then
        return
    end

    if SCENE_MANAGER.Show then
        ZO_PreHook(SCENE_MANAGER, "Show", function(_, sceneName)
            if not ADDON:IsActive() or type(sceneName) ~= "string" then
                return
            end

            if IsRestrictedSceneName(sceneName) then
                rt.restrictedScenes = rt.restrictedScenes or {}
                local restrictedScene = SCENE_MANAGER:GetScene(sceneName)
                if restrictedScene then
                    rt.restrictedScenes[sceneName] = restrictedScene
                end
                if not rt.restrictedSceneActive then
                    rt.restrictedSceneActive = true
                    -- Restore native presentation before the restricted scene
                    -- is resolved/shown. Do not touch that scene afterwards.
                    ADDON:ApplyMode()
                    if ADDON.RestorePrompts then
                        ADDON:RestorePrompts()
                    end
                end
                return
            end

            if not rt.restrictedSceneActive then
                ADDON:ApplyPointerToScene(sceneName, false)
            end
        end)
    end

    if SCENE_MANAGER.OnSceneStateChange then
        ZO_PostHook(SCENE_MANAGER, "OnSceneStateChange", function(_, scene, oldState, newState)
            if not ADDON:IsActive() or not scene or not scene.GetName then
                return
            end

            local sceneName = scene:GetName()
            if IsRestrictedSceneName(sceneName) then
                rt.restrictedScenes = rt.restrictedScenes or {}
                if newState == SCENE_HIDDEN then
                    rt.restrictedScenes[sceneName] = nil
                else
                    rt.restrictedScenes[sceneName] = scene
                end

                -- The pre-show hook already restored native mode. While a
                -- restricted scene (or its overlay stack) is active, do not
                -- attach/remove fragments or refresh controls inside it.
                if UpdateRestrictedSceneState() then
                    ADDON:ApplyMode()
                    ADDON:RefreshSceneController()
                    ADDON:InitializePrompts()
                end
                return
            end

            if rt.restrictedSceneActive then
                if UpdateRestrictedSceneState() then
                    ADDON:ApplyMode()
                    ADDON:RefreshSceneController()
                    ADDON:InitializePrompts()
                end
                return
            end

            if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                ADDON:ApplyPointerToScene(sceneName, false)
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
            -- LibMousePointer's cursor calls GetXY(ZO_DI_LEFT_STICK), which
            -- consumes the left stick through DIRECTIONAL_INPUT. Its high-tier
            -- pointer control is ordered ahead of CLIENT_INPUT. Only then do
            -- we bypass ESO's default consume-both-sticks handler and consume
            -- the right stick here. If the left stick is still available, let
            -- ESO's original handler consume both sticks as normal.
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
