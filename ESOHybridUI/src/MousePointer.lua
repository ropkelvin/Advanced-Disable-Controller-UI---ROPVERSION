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
    if not IsPointerEnabled()
        or not MOUSE_POINTER_FRAGMENT
        or type(MOUSE_POINTER_FRAGMENT.IsShowing) ~= "function"
        or not MOUSE_POINTER_FRAGMENT:IsShowing() then
        return false
    end

    -- A showing fragment is not enough if LibMousePointer failed to create or
    -- reveal its gamepad cursor. In that case keep ESO's normal UI-mode stick
    -- consumption enabled rather than letting LEFT leak into character movement.
    local cursor = LibMousePointer.gamepadCursor
    local control = cursor and cursor.control
    return control ~= nil
        and type(control.IsHidden) == "function"
        and not control:IsHidden()
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
    if not pointer or type(pointer.UpdateDirectionalInput) ~= "function"
        or type(ZO_PostHook) ~= "function" then
        return false
    end
    if rt.mousePointerInputHookInstalled then
        return true
    end

    -- Leave cursor movement to LibMousePointer's own Cursor_Gamepad handler.
    -- It already uses DIRECTIONAL_INPUT:IsAvailable/GetXY and owns its speed,
    -- deadzone, bounds and hit-testing. Consume LEFT after it has processed the
    -- frame so the same stick cannot also move the character.
    ZO_PostHook(pointer, "UpdateDirectionalInput", function()
        if IsPointerFragmentActive()
            and DIRECTIONAL_INPUT:IsAvailable(ZO_DI_LEFT_STICK) then
            DIRECTIONAL_INPUT:Consume(ZO_DI_LEFT_STICK)
        end
    end)

    rt.mousePointerInputHookInstalled = true
    return true
end

local function IsPointerScene(scene)
    if not scene or not scene.GetName then
        return false
    end

    -- Lockpicking has its own ESO virtual cursor, adapted above. Do not attach
    -- the general mouse pointer there or one stick would drive two cursors.
    if scene == LOCK_PICK_SCENE or scene == LOCK_PICK_GAMEPAD_SCENE then
        return false
    end

    local name = scene:GetName()
    if name == "hud" then
        return false
    end

    -- ESO enters UI mode by showing hudui as its base scene. It is a valid
    -- pointer surface only while the scene manager confirms actual UI mode;
    -- otherwise the left stick must remain normal character movement.
    if name == "hudui" then
        return SCENE_MANAGER ~= nil
            and SCENE_MANAGER.IsInUIMode ~= nil
            and SCENE_MANAGER:IsInUIMode()
    end

    return true
end

IsPointerEnabled = function()
    -- Keyboard UI + Controller intentionally forces ESO's UI presentation
    -- query to keyboard mode. Do not gate pointer availability on the native
    -- gamepad-presentation answer: the controller remains the active input.
    return rt.keyboardController == true
        and ADDON:GetSettings().keyboardControllerMousePointer ~= false
        and LibMousePointer ~= nil
        and MOUSE_POINTER_FRAGMENT ~= nil
end

local function AttachToScene(scene)
    if not scene then
        return false
    end

    if IsPointerEnabled() and IsPointerScene(scene) and scene.AddTemporaryFragment then
        -- AddTemporaryFragment also updates an already-visible scene. Do not
        -- call fragment:Refresh() manually; LibMousePointer owns its state
        -- transition and DIRECTIONAL_INPUT activation in its fragment callback.
        scene:AddTemporaryFragment(MOUSE_POINTER_FRAGMENT)
        return true
    end

    -- Keep the fragment out of HUD/non-UI scenes if a mode refresh occurs while
    -- that scene is still current.
    if MOUSE_POINTER_FRAGMENT and scene.RemoveTemporaryFragment then
        scene:RemoveTemporaryFragment(MOUSE_POINTER_FRAGMENT)
    end
    return false
end

local function OnSceneStateChanged(scene, oldState, newState)
    if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
        AttachToScene(scene)
    end
end

local function OnGameCameraUIModeChanged()
    -- Secondary signal for UI-mode transitions that do not produce a new
    -- top-level menu scene. SceneStateChanged remains the primary lifecycle
    -- path, because this engine event is not emitted consistently on all paths.
    if SCENE_MANAGER then
        AttachToScene(SCENE_MANAGER:GetCurrentScene())
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

        -- Optional fallback. SceneStateChanged is still authoritative for
        -- entering/leaving hudui and for ordinary menu scene transitions.
        if EVENT_GAME_CAMERA_UI_MODE_CHANGED and EVENT_MANAGER then
            EVENT_MANAGER:RegisterForEvent(
                ADDON.ADDON_NAME .. "_MousePointerUIMode",
                EVENT_GAME_CAMERA_UI_MODE_CHANGED,
                OnGameCameraUIModeChanged)
        end

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
