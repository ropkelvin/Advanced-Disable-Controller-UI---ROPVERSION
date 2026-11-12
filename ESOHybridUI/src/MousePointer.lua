-- Optional controller-operated pointer support for keyboard-style UI scenes.
-- The pointer surrogate and hit-testing are supplied by LibMousePointer.
-- We only attach its native scene fragment and expose explicit click actions;
-- we do not synthesize OS mouse movement or poll the sticks ourselves.

local ADDON = ESOHybridUI
local rt = ADDON.runtime


-- ESO's keyboard lockpick template normally enables its virtual cursor only
-- when IsInGamepadPreferredMode() is true. This mode deliberately reports
-- keyboard presentation, so reuse ESO's own native lockpick cursor calculation
-- with the real controller stick input. This is the narrow approach used by
-- EnhancedGamepadUI, updated to the current ESO method and fields.
local STARTING_NORMALIZED_LOCKPICK_X = 0.53
local GAMEPAD_LOCKPICK_SPEED_FACTOR = 3.5

local function UpdateKeyboardControllerLockpick(lockpick)
    if not lockpick.virtualMouseX then
        lockpick.virtualMouseX = zo_lerp(
            lockpick.lockpickLowerBound,
            lockpick.lockpickUpperBound,
            STARTING_NORMALIZED_LOCKPICK_X)
        lockpick.virtualNormalizedMouseX = STARTING_NORMALIZED_LOCKPICK_X
        lockpick:OnVirtualLockpickPositionChanged()
        return true
    end

    local deltaX = ZO_Gamepad_GetLeftStickEasedX() * GAMEPAD_LOCKPICK_SPEED_FACTOR
    if deltaX == 0 and not IsConsoleUI() then
        deltaX = GetUIMouseDeltas()
    end
    deltaX = deltaX * GetFrameDeltaNormalizedForTargetFramerate()

    if deltaX ~= 0 then
        local clampedX = zo_clamp(
            lockpick.virtualMouseX + deltaX,
            lockpick.lockpickLowerBound,
            lockpick.lockpickUpperBound)

        if clampedX ~= lockpick.virtualMouseX then
            lockpick.virtualMouseX = clampedX
            lockpick.virtualNormalizedMouseX =
                (clampedX - lockpick.lockpickLowerBound)
                / (lockpick.lockpickUpperBound - lockpick.lockpickLowerBound)
            lockpick:OnVirtualLockpickPositionChanged()
        end
    end

    return true
end

local function InstallLockpickInputHook()
    local lockpickClass = ZO_Lockpick
    if not lockpickClass or type(lockpickClass.UpdateVirtualMousePosition) ~= "function" then
        return false
    end

    if rt.keyboardControllerLockpickHookInstalled then
        return true
    end

    ZO_PreHook(lockpickClass, "UpdateVirtualMousePosition", function(lockpick)
        if rt.keyboardController and ADDON:IsNativeGamepadMode() then
            return UpdateKeyboardControllerLockpick(lockpick)
        end
        return false
    end)

    rt.keyboardControllerLockpickHookInstalled = true
    return true
end

-- LibMousePointer registers a directional-input handler, but its stock cursor
-- refuses to move when ESO's UI-mode handler has already consumed the stick.
-- Keep the library's scene/cursor/hit-test implementation and replace only that
-- per-frame movement method: read ESO's eased physical left-stick values, then
-- consume LEFT only while the pointer fragment is active. This prevents movement
-- input from leaking through in menus without touching the HUD or right stick.
local function InstallPointerInputHook()
    local cursorClass = LibMousePointer and LibMousePointer.Cursor_Gamepad
    if not cursorClass or type(cursorClass.UpdateDirectionalInput) ~= "function" then
        return false
    end
    if rt.mousePointerInputHookInstalled then
        return true
    end

    local moveStartTimestamp = 0
    ZO_PreHook(cursorClass, "UpdateDirectionalInput", function(cursor)
        if not IsPointerEnabled() then
            return false
        end

        DIRECTIONAL_INPUT:Consume(ZO_DI_LEFT_STICK)

        local dx = ZO_Gamepad_GetLeftStickEasedX()
        local dy = ZO_Gamepad_GetLeftStickEasedY()
        dx, dy = zo_clampLength2D(dx, dy, 1.5)

        if dx == 0 and dy == 0 then
            moveStartTimestamp = GetGameTimeMilliseconds()
            return true
        end

        local frameDelta = GetFrameDeltaNormalizedForTargetFramerate()
        local magnitude = frameDelta * 3
            * zo_clamp((GetGameTimeMilliseconds() - moveStartTimestamp) / 250, 1, 8)
        dx = dx * magnitude
        dy = -dy * magnitude

        cursor.control:SetAnchor(CENTER, GuiRoot, TOPLEFT, cursor.x + dx, cursor.y + dy)
        local clampedX, clampedY = cursor.control:GetCenter()
        if clampedX ~= cursor.x or clampedY ~= cursor.y then
            cursor.x, cursor.y = clampedX, clampedY
            cursor.directionalX = cursor.x + dx
            cursor.directionalY = cursor.y + dy
            cursor:UpdateCursorInfo()
        end
        return true
    end)

    rt.mousePointerInputHookInstalled = true
    return true
end

-- LibMousePointer already implements cursor movement through ESO's
-- DIRECTIONAL_INPUT arbitration using ZO_DI_LEFT_STICK. Keep that native
-- implementation: while a keyboard-style UI scene is open, the left stick
-- navigates the pointer; in the HUD it remains available for character
-- movement. Do not redirect the right stick, which remains the camera input.

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
    InstallLockpickInputHook()

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
