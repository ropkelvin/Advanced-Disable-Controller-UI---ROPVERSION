-- Optional controller-operated pointer support for keyboard-style UI scenes.
-- The pointer surrogate and hit-testing are supplied by LibMousePointer.
-- We only attach its native scene fragment and expose explicit click actions;
-- we do not synthesize OS mouse movement or poll the sticks ourselves.

local ADDON = ESOHybridUI
local rt = ADDON.runtime

local function IsPointerScene(scene)
    if not scene or not scene.GetName then
        return false
    end

    local name = scene:GetName()
    return name ~= "hud" and name ~= "hudui"
end

local function IsPointerEnabled()
    return rt.keyboardController == true
        and ADDON:IsNativeGamepadMode()
        and ADDON:GetSettings().keyboardControllerMousePointer ~= false
        and LibMousePointer ~= nil
        and MOUSE_POINTER_FRAGMENT ~= nil
end

local function AttachToScene(scene)
    if IsPointerEnabled() and IsPointerScene(scene) and scene.AddTemporaryFragment then
        scene:AddTemporaryFragment(MOUSE_POINTER_FRAGMENT)
        return true
    end
    return false
end

local function OnSceneStateChanged(scene, oldState, newState)
    if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
        AttachToScene(scene)
    end
end

function ADDON:InvokeMousePointerClick(button)
    if not IsPointerEnabled() or type(LibMousePointer.GetControlAtCursor) ~= "function"
        or type(LibMousePointer.InvokeClick) ~= "function" then
        return false
    end

    -- Do not consume the configured button when the pointer is not over a
    -- mouse-hit-testable control; normal ESO keybind handling can then proceed.
    if not LibMousePointer:GetControlAtCursor() then
        return false
    end

    LibMousePointer:InvokeClick(button or MOUSE_BUTTON_INDEX_LEFT)
    return true
end

function ADDON:ResetMousePointer()
    if not IsPointerEnabled() or type(LibMousePointer.ResetPosition) ~= "function" then
        return false
    end

    LibMousePointer:ResetPosition()
    return true
end

function ADDON:ApplyMousePointer()
    if not SCENE_MANAGER then
        return false
    end

    if not rt.mousePointerSceneHookInstalled then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", OnSceneStateChanged)
        rt.mousePointerSceneHookInstalled = true
    end

    local currentScene = SCENE_MANAGER:GetCurrentScene()
    if IsPointerEnabled() then
        AttachToScene(currentScene)
        self:LogDebug("Controller mouse pointer integration active.")
        return true
    end

    if currentScene and MOUSE_POINTER_FRAGMENT and currentScene.RemoveTemporaryFragment then
        currentScene:RemoveTemporaryFragment(MOUSE_POINTER_FRAGMENT)
    end

    if rt.keyboardController and not rt.mousePointerMissingLogged
        and (not LibMousePointer or not MOUSE_POINTER_FRAGMENT) then
        rt.mousePointerMissingLogged = true
        self:LogInfo("Keyboard UI + Controller mouse pointer is unavailable; install the optional LibMousePointer library.")
    end
    return true
end
