-- Scene-local controller pointer integration.
-- LibMousePointer owns cursor drawing, hit-testing, click dispatch and left-stick
-- directional input. ESO's DIRECTIONAL_INPUT arbitrates owners by control visual
-- order; LibMousePointer brings its top-level cursor above GuiRoot when shown.

local ADDON = ESOHybridUI
local rt = ADDON.runtime

local function PointerEnabled()
    return rt.hybrid == true
        and ADDON:GetSettings().keyboardControllerMousePointer ~= false
        and LibMousePointer ~= nil
        and MOUSE_POINTER_FRAGMENT ~= nil
end

local function IsPointerScene(scene)
    if not scene or not scene.GetName then return false end
    local name = scene:GetName()
    if name == "hud" then return false end
    if name == "hudui" then
        return SCENE_MANAGER and SCENE_MANAGER.IsInUIMode
            and SCENE_MANAGER:IsInUIMode()
    end
    return ADDON:GetScenePresentation(name) == ADDON.SCENE_PRESENTATION_KEYBOARD_POINTER
end

local function IsPointerFragmentActive()
    if not PointerEnabled() or not MOUSE_POINTER_FRAGMENT
        or not MOUSE_POINTER_FRAGMENT.IsShowing
        or not MOUSE_POINTER_FRAGMENT:IsShowing() then
        return false
    end
    local cursor = LibMousePointer.gamepadCursor
    local control = cursor and cursor.control
    return control ~= nil and control.IsHidden and not control:IsHidden()
end

local function AttachToScene(scene)
    if not scene then return false end
    if PointerEnabled() and IsPointerScene(scene) then
        if scene.AddTemporaryFragment then
            scene:AddTemporaryFragment(MOUSE_POINTER_FRAGMENT)
        elseif scene.AddFragment then
            scene:AddFragment(MOUSE_POINTER_FRAGMENT)
        end
        return true
    end
    if MOUSE_POINTER_FRAGMENT then
        if scene.RemoveTemporaryFragment then
            scene:RemoveTemporaryFragment(MOUSE_POINTER_FRAGMENT)
        elseif scene.RemoveFragment then
            scene:RemoveFragment(MOUSE_POINTER_FRAGMENT)
        end
    end
    return false
end

local function OnSceneStateChanged(scene, _, newState)
    if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
        AttachToScene(scene)
        ADDON:TraceScenePresentation(scene and scene.GetName and scene:GetName())
    elseif newState == SCENE_HIDDEN then
        if scene and scene.RemoveTemporaryFragment then
            scene:RemoveTemporaryFragment(MOUSE_POINTER_FRAGMENT)
        end
    end
end

local function InstallSceneManagerInputHook()
    local manager = SCENE_MANAGER
    if not manager or type(manager.UpdateDirectionalInput) ~= "function"
        or rt.mousePointerSceneInputHookInstalled then
        return manager ~= nil
    end

    -- LibMousePointer is a top-level overlay and brings its control to the top.
    -- DIRECTIONAL_INPUT therefore updates it before GuiRoot's scene-manager owner.
    -- Its GetXY call consumes LEFT. Suppress ESO's subsequent consume of both
    -- sticks only while the cursor is visible: RIGHT remains the camera input.
    ZO_PreHook(manager, "UpdateDirectionalInput", function()
        if IsPointerFragmentActive() then return true end
        return false
    end)
    rt.mousePointerSceneInputHookInstalled = true
    return true
end

function ADDON:InvokeMousePointerClick(button)
    if not PointerEnabled() or not LibMousePointer.GetControlAtCursor
        or not LibMousePointer.InvokeClick then
        return false
    end
    if not LibMousePointer:GetControlAtCursor() then return false end
    LibMousePointer:InvokeClick(button or MOUSE_BUTTON_INDEX_LEFT)
    return true
end

function ADDON:ResetMousePointer()
    if not PointerEnabled() or not LibMousePointer.ResetPosition then return false end
    LibMousePointer:ResetPosition()
    return true
end

function ADDON:DumpMousePointerDiagnostics()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetCurrentScene()
    local name = scene and scene.GetName and scene:GetName() or "none"
    local fragmentShowing = MOUSE_POINTER_FRAGMENT and MOUSE_POINTER_FRAGMENT.IsShowing
        and MOUSE_POINTER_FRAGMENT:IsShowing() or false
    local cursor = LibMousePointer and LibMousePointer.gamepadCursor
    local control = cursor and cursor.control
    self:Say("Pointer enabled=" .. tostring(PointerEnabled())
        .. " scene=" .. tostring(name)
        .. " fragment=" .. tostring(fragmentShowing)
        .. " cursor=" .. tostring(cursor ~= nil)
        .. " visible=" .. tostring(control ~= nil and not control:IsHidden()))
    self:Say("Directional owner=" .. tostring(DIRECTIONAL_INPUT and DIRECTIONAL_INPUT:IsListening(LibMousePointer))
        .. " managerHook=" .. tostring(rt.mousePointerSceneInputHookInstalled))
end

function ADDON:ApplyMousePointer()
    InstallSceneManagerInputHook()
    if not SCENE_MANAGER then return false end
    if not rt.mousePointerSceneHookInstalled then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", OnSceneStateChanged)
        rt.mousePointerSceneHookInstalled = true
    end
    AttachToScene(SCENE_MANAGER:GetCurrentScene())
    if rt.hybrid and not MOUSE_POINTER_FRAGMENT and not rt.mousePointerMissingLogged then
        rt.mousePointerMissingLogged = true
        self:LogWarn("Keyboard UI pointer requires the optional LibMousePointer library.")
    end
    return true
end

-- Scene lifecycle is authoritative; these events cover mode changes while a
-- menu remains open and the initial player activation.
EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_PointerModeChanged",
    EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        zo_callLater(function() ADDON:ApplyMousePointer() end, 50)
    end)
EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_PointerPlayerActivated",
    EVENT_PLAYER_ACTIVATED, function()
        ADDON:ApplyMousePointer()
    end)
