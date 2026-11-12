-- Optional controller-operated pointer support for keyboard-style UI scenes.
-- LibMousePointer supplies the cursor control, scene fragment, hit-testing and click dispatch.
-- This file only adapts ESO's directional-input ownership for this addon mode.

local ADDON = ESOHybridUI
local rt = ADDON.runtime

-- ESO's keyboard lockpick template normally enables its virtual cursor only
-- when IsInGamepadPreferredMode() is true. This mode deliberately reports
-- keyboard presentation, so reuse ESO's native lockpick cursor calculation.
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

local IsPointerEnabled

-- The UI-mode handler consumes both sticks to stop them leaking into movement
-- and camera input. Suppress that consumption only while LibMousePointer's
-- fragment is actually showing. Merely enabling the setting must never change
-- stick handling on the HUD or during a scene transition.
local function IsPointerFragmentActive()
    return IsPointerEnabled()
        and MOUSE_POINTER_FRAGMENT ~= nil
        and type(MOUSE_POINTER_FRAGMENT.IsShowing) == "function"
        and MOUSE_POINTER_FRAGMENT:IsShowing()
end

local function InstallSceneManagerInputHook()
    local sceneManagerClass = ZO_IngameSceneManager
    if not sceneManagerClass or type(sceneManagerClass.UpdateDirectionalInput) ~= "function" then
        return false
    end
    if rt.mousePointerSceneInputHookInstalled then
        return true
    end

    ZO_PreHook(sceneManagerClass, "UpdateDirectionalInput", function()
        if IsPointerFragmentActive() then
            -- The pointer handler consumes LEFT. Let RIGHT pass through to the
            -- normal camera path, matching the Keyboard UI + Controller design.
            return true
        end
        -- Keep ESO's original both-stick consumption everywhere else.
        return false
    end)

    rt.mousePointerSceneInputHookInstalled = true
    return true
end

-- LibMousePointer activates this callback through DIRECTIONAL_INPUT:Activate.
-- Use the same arbitration API as ESO's native handlers: IsAvailable/GetXY,
-- then Consume the left stick after using it. Do not poll raw/eased stick
-- getters here; doing so bypasses directional-input priority and deadzone rules.
local function InstallPointerInputHook()
    local pointer = LibMousePointer
    if not pointer or type(pointer.UpdateDirectionalInput) ~= "function" then
        return false
    end
    if rt.mousePointerInputHookInstalled then
        return true
    end

    local moveStartTimestamp = GetGameTimeMilliseconds()
    ZO_PreHook(pointer, "UpdateDirectionalInput", function(lib)
        if not IsPointerFragmentActive() then
            return false
        end

        local cursor = lib.gamepadCursor
        if not cursor or not cursor.control then
            return true
        end

        if not DIRECTIONAL_INPUT:IsAvailable(ZO_DI_LEFT_STICK) then
            moveStartTimestamp = GetGameTimeMilliseconds()
            return true
        end

        local dx, dy = DIRECTIONAL_INPUT:GetXY(ZO_DI_LEFT_STICK)
        dx, dy = zo_clampLength2D(dx, dy, 1.5)

        if dx == 0 and dy == 0 then
            moveStartTimestamp = GetGameTimeMilliseconds()
            return true
        end

        DIRECTIONAL_INPUT:Consume(ZO_DI_LEFT_STICK)

        local frameDelta = GetFrameDeltaNormalizedForTargetFramerate()
        local heldMilliseconds = GetGameTimeMilliseconds() - moveStartTimestamp
        local acceleration = zo_clamp(heldMilliseconds / 250, 1, 8)
        local magnitude = frameDelta * 3 * acceleration
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

local function IsPointerScene(scene)
    if not scene or not scene.GetName then
        return false
    end

    local name = scene:GetName()
    return name ~= "hud" and name ~= "hudui"
end

IsPointerEnabled = function()
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

function ADDON:DumpMousePointerDiagnostics()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetCurrentScene()
    local sceneName = scene and scene.GetName and scene:GetName() or "none"
    local fragmentShowing = MOUSE_POINTER_FRAGMENT ~= nil
        and type(MOUSE_POINTER_FRAGMENT.IsShowing) == "function"
        and MOUSE_POINTER_FRAGMENT:IsShowing() or false
    local cursor = LibMousePointer and LibMousePointer.gamepadCursor
    local control = cursor and cursor.control
    local available = DIRECTIONAL_INPUT:IsAvailable(ZO_DI_LEFT_STICK)
    local stickX, stickY = 0, 0
    if available then
        stickX, stickY = DIRECTIONAL_INPUT:GetXY(ZO_DI_LEFT_STICK)
    end

    self:Say("Pointer mode=" .. tostring(rt.keyboardController)
        .. " enabled=" .. tostring(IsPointerEnabled())
        .. " fragment=" .. tostring(fragmentShowing)
        .. " scene=" .. tostring(sceneName))
    self:Say("LibMousePointer=" .. tostring(LibMousePointer ~= nil)
        .. " cursor=" .. tostring(cursor ~= nil)
        .. " control=" .. tostring(control ~= nil)
        .. " controlHidden=" .. tostring(control and control:IsHidden() or "n/a"))
    self:Say("leftAvailable=" .. tostring(available)
        .. " leftXY=" .. string.format("%.3f, %.3f", stickX, stickY)
        .. " sceneHook=" .. tostring(rt.mousePointerSceneInputHookInstalled)
        .. " pointerHook=" .. tostring(rt.mousePointerInputHookInstalled))
end

function ADDON:ApplyMousePointer()
    InstallLockpickInputHook()
    InstallSceneManagerInputHook()
    InstallPointerInputHook()

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
