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
    -- Restricted activities can have keyboard/gamepad scene suffixes.
    -- Match the activity token rather than only one exact root scene name.
    -- "scrying" is deliberately distinct from "scribing".
    return string.find(normalized, "scrying", 1, true) ~= nil
        or string.find(normalized, "tribute", 1, true) ~= nil
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
        and self:IsGamepadModeOn()
        and not rt.modeOverrideConflict
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

            ADDON:RecordDiagnostic("SCENE_SHOW_REQUEST", sceneName)

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
            ADDON:RecordDiagnostic("SCENE_STATE", sceneName
                .. ",old=" .. tostring(oldState)
                .. ",new=" .. tostring(newState))
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

local function InstallPointerKeybindConflictHook()
    if rt.pointerKeybindConflictHookInstalled
        or not KEYBIND_STRIP
        or not KEYBIND_STRIP.AddKeybindButton
        or not LibMousePointer
        or not LibMousePointer.keybindButton then
        return
    end

    local pointerClickDescriptor = LibMousePointer.keybindButton
    local pointerClickKeybind = pointerClickDescriptor.keybind

    local function UnwrapDescriptor(value)
        if type(value) == "userdata" then
            return value.keybindButtonDescriptor
        end
        return value
    end

    local function GetExistingDescriptor(keybindStrip, stateIndex)
        local state = keybindStrip.GetKeybindState
            and keybindStrip:GetKeybindState(stateIndex)
        local existing = state and state.individualButtons
            and state.individualButtons[pointerClickKeybind]
        existing = UnwrapDescriptor(existing)
        if existing then
            return existing
        end
        return UnwrapDescriptor(keybindStrip.keybinds
            and keybindStrip.keybinds[pointerClickKeybind])
    end

    -- LibMousePointer uses UI_SHORTCUT_PRIMARY for cursor clicks. Native
    -- keyboard scenes can also claim that key (for example Notifications).
    -- Handle both registration orders: if the pointer was added first, remove
    -- only its descriptor before the native descriptor is processed; if the
    -- native descriptor was added first, suppress the library descriptor.
    -- This avoids duplicate-key processing while preserving the scene's
    -- native action. The cursor fragment itself remains active.
    ZO_PreHook(KEYBIND_STRIP, "AddKeybindButton", function(keybindStrip, descriptor, stateIndex)
        if not descriptor or descriptor.keybind ~= pointerClickKeybind then
            return false
        end

        local existingDescriptor = GetExistingDescriptor(keybindStrip, stateIndex)
        local sceneName = SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName()

        if descriptor == pointerClickDescriptor then
            if existingDescriptor and existingDescriptor ~= pointerClickDescriptor then
                ADDON:RecordDiagnostic("POINTER_PRIMARY_SUPPRESSED",
                    "scene=" .. tostring(sceneName))
                return true
            end
            return false
        end

        if existingDescriptor == pointerClickDescriptor then
            ADDON:RecordDiagnostic("POINTER_PRIMARY_CONFLICT",
                "scene=" .. tostring(sceneName))
            keybindStrip:RemoveKeybindButton(pointerClickDescriptor, stateIndex)
        end
        return false
    end)

    rt.pointerKeybindConflictHookInstalled = true
end
local function InstallDirectionalInputHook()
    -- ZO_IngameSceneManager is a local class in ESO's ingame scene-manager
    -- source, not a global. Hook the live SCENE_MANAGER instance instead.
    --
    -- IMPORTANT: DIRECTIONAL_INPUT invokes owners in visual-priority order,
    -- and that order can put SCENE_MANAGER before LibMousePointer. Testing
    -- IsAvailable(LEFT_STICK) here is therefore too early: when the pointer
    -- has not had its turn yet, the stock handler consumes BOTH sticks and
    -- starves the pointer for this frame. While the pointer is registered,
    -- skip only ESO's consume-both-sticks handler and reserve the right stick.
    -- LibMousePointer:GetXY(LEFT_STICK) consumes the left stick in its own
    -- callback (including zero-magnitude frames); CLIENT_INPUT then marks it
    -- consumed for the game camera/player. If the pointer is not registered,
    -- leave ESO's stock safety behaviour untouched.
    if rt.directionalHookInstalled then
        return
    end
    if not SCENE_MANAGER or not SCENE_MANAGER.UpdateDirectionalInput then
        ADDON:RecordDiagnostic("DIRECTIONAL_HOOK_UNAVAILABLE",
            "SCENE_MANAGER.UpdateDirectionalInput missing")
        return
    end

    ZO_PreHook(SCENE_MANAGER, "UpdateDirectionalInput", function()
        if ADDON:IsActive()
            and ADDON:IsHybrid()
            and rt.pointerScene
            and DIRECTIONAL_INPUT
            and LibMousePointer
            and DIRECTIONAL_INPUT.IsListening
            and DIRECTIONAL_INPUT:IsListening(LibMousePointer) then
            DIRECTIONAL_INPUT:Consume(ZO_DI_RIGHT_STICK)
            return true
        end
        return false
    end)

    rt.directionalHookInstalled = true
    ADDON:RecordDiagnostic("DIRECTIONAL_HOOK_INSTALLED",
        "target=SCENE_MANAGER.UpdateDirectionalInput,policy=pointer-owns-left-stick;hui-reserves-right-stick")
end

function ADDON:InitializeSceneController()
    rt.pointerScenes = rt.pointerScenes or {}
    InstallSceneHooks()
    InstallPointerKeybindConflictHook()
    InstallDirectionalInputHook()
    self:RefreshSceneController()
end
