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

-- LibMousePointer's native cursor reads the left stick. In Keyboard UI + Controller
-- that stick is reserved for character movement, so route the cursor through the
-- right stick instead. The library already registers itself with DIRECTIONAL_INPUT
-- when its fragment is shown; wrapping its callback preserves that native priority
-- arbitration and consumes the right stick before it can reach the game camera.
local POINTER_CURSOR_SPEED = 3
local POINTER_CURSOR_ACCELERATION_MS = 250

local function UpdatePointerFromRightStick(pointer)
    local cursor = pointer.gamepadCursor
    if not cursor or not cursor.cursorId then
        return
    end

    if not DIRECTIONAL_INPUT:IsAvailable(ZO_DI_RIGHT_STICK) then
        return
    end

    local dx, dy = DIRECTIONAL_INPUT:GetXY(ZO_DI_RIGHT_STICK)
    dx, dy = zo_clampLength2D(dx, dy, 1.5)

    local now = GetGameTimeMilliseconds()
    if dx == 0 and dy == 0 then
        rt.mousePointerMoveStartTimestamp = now
    elseif not rt.mousePointerMoveStartTimestamp then
        rt.mousePointerMoveStartTimestamp = now
    end

    local frameDelta = GetFrameDeltaNormalizedForTargetFramerate()
    local elapsed = now - rt.mousePointerMoveStartTimestamp
    local magnitude = frameDelta * POINTER_CURSOR_SPEED
        * zo_clamp(elapsed / POINTER_CURSOR_ACCELERATION_MS, 1, 8)
    dx = dx * magnitude
    dy = -dy * magnitude

    cursor.control:SetAnchor(CENTER, GuiRoot, TOPLEFT, cursor.x + dx, cursor.y + dy)
    local clampedX, clampedY = cursor.control:GetCenter()
    if clampedX ~= cursor.x or clampedY ~= cursor.y then
        cursor.x, cursor.y = clampedX, clampedY
        cursor.directionalX = cursor.x + dx
        cursor.directionalY = cursor.y + dy
    end

    cursor:UpdateCursorInfo()
end

local function InstallPointerDirectionalInputAdapter()
    if not LibMousePointer or type(LibMousePointer.UpdateDirectionalInput) ~= "function"
        or rt.mousePointerDirectionalAdapterInstalled then
        return false
    end

    rt.mousePointerOriginalDirectionalUpdate = LibMousePointer.UpdateDirectionalInput
    LibMousePointer.UpdateDirectionalInput = function(pointer)
        if rt.keyboardController and ADDON:IsNativeGamepadMode() then
            UpdatePointerFromRightStick(pointer)
        else
            rt.mousePointerOriginalDirectionalUpdate(pointer)
        end
    end

    rt.mousePointerDirectionalAdapterInstalled = true
    return true
end

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
