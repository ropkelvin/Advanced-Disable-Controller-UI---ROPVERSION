-- Pointer integration.
--
-- LibMousePointer owns cursor creation, left-stick sampling, cursor hit
-- testing, hover and its primary-click descriptor. HUI does not add a second
-- cursor or alter ESO's directional-input dispatch.
local ADDON = ESOHybridUI

local rightClick = {
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    name = "Context menu",
    keybind = "UI_SHORTCUT_RIGHT_STICK",
    ethereal = true,
    callback = function()
        if LibMousePointer and LibMousePointer.InvokeClick then
            LibMousePointer:InvokeClick(MOUSE_BUTTON_INDEX_RIGHT)
        end
    end,
}

local function OnFragmentState(_, newState)
    if newState == SCENE_FRAGMENT_SHOWN then
        ADDON:SetKeybind(rightClick, true)
    elseif newState == SCENE_FRAGMENT_HIDING or newState == SCENE_FRAGMENT_HIDDEN then
        ADDON:SetKeybind(rightClick, false)
    end
end

function ADDON:StopPointer()
    if self.SetKeybind then
        self:SetKeybind(rightClick, false)
    end
end

function ADDON:InitializePointer()
    if ADDON.rt.pointerInitialized then
        return
    end
    if not LibMousePointer or not MOUSE_POINTER_FRAGMENT
        or not LibMousePointer.InvokeClick or not LibMousePointer.GetCursorPosition then
        self:Print("LibMousePointer is missing or too old; pointer support is unavailable.")
        return
    end

    -- LibMousePointer registers a high-priority DIRECTIONAL_INPUT owner using
    -- its cursor control. Its GetXY call consumes the left stick. ESO's native
    -- scene-manager owner runs later and consumes any remaining sticks, which
    -- is the fallback that prevents input leaking into character movement if
    -- another visible UI control has higher priority. Do not bypass that owner.
    MOUSE_POINTER_FRAGMENT:SetConditional(function()
        return ADDON.rt.keyboardPresentation and ADDON.saved.pointerEnabled
    end)
    MOUSE_POINTER_FRAGMENT:RegisterCallback("StateChange", OnFragmentState)

    ADDON.rt.pointerInitialized = true
    if MOUSE_POINTER_FRAGMENT:IsShowing() then
        ADDON:SetKeybind(rightClick, true)
    end
end

function ADDON:PrintPointerProbe()
    local lib = LibMousePointer
    local startScene = SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName()
    local startX, startY
    if lib then
        startX, startY = lib:GetCursorPosition()
    end
    local startTime = GetGameTimeMilliseconds()
    local samples, shownSamples, listeningSamples = 0, 0, 0
    local sceneChanges = 0
    local previousScene = startScene
    local maxStick = 0
    local lastX, lastY = startX, startY
    local lastScene = startScene
    local lastFragmentShowing = false
    local lastListening = false
    local lastCursorExists = false
    local ownerSnapshot = nil
    local movementEvents = 0
    local movementEventName = "ESOHybridUI_PointerProbeMovement"

    local function CaptureOwners()
        if ownerSnapshot or not DIRECTIONAL_INPUT or not DIRECTIONAL_INPUT.inputObjects then
            return
        end
        local entries = {}
        for index = #DIRECTIONAL_INPUT.inputObjects, 1, -1 do
            local owner = DIRECTIONAL_INPUT.inputObjects[index]
            local control = DIRECTIONAL_INPUT.inputControls[index]
            local name = control and control.GetName and control:GetName() or tostring(control)
            entries[#entries + 1] = string.format("%d:%s/%s", index,
                tostring(owner == lib and "LibMousePointer" or owner), tostring(name))
        end
        ownerSnapshot = table.concat(entries, ",")
    end

    local function Sample()
        local sceneName = SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName()
        local scene = sceneName and SCENE_MANAGER:GetScene(sceneName)
        local fragmentShowing = MOUSE_POINTER_FRAGMENT and MOUSE_POINTER_FRAGMENT:IsShowing() or false
        local listening = lib and DIRECTIONAL_INPUT and DIRECTIONAL_INPUT:IsListening(lib) or false
        local cursorExists = lib and lib.gamepadCursor and lib.gamepadCursor.cursorId ~= nil or false
        local x, y
        if lib then
            x, y = lib:GetCursorPosition()
        end
        local rawX = GetGamepadLeftStickX(GAMEPAD_INCLUDE_DEADZONE)
        local rawY = GetGamepadLeftStickY(GAMEPAD_INCLUDE_DEADZONE)

        samples = samples + 1
        if fragmentShowing then shownSamples = shownSamples + 1 end
        if listening then
            listeningSamples = listeningSamples + 1
            CaptureOwners()
        end
        if sceneName ~= previousScene then
            sceneChanges = sceneChanges + 1
            previousScene = sceneName
        end
        maxStick = math.max(maxStick, math.abs(rawX), math.abs(rawY))
        lastX, lastY = x, y
        lastScene = sceneName
        lastFragmentShowing = fragmentShowing
        lastListening = listening
        lastCursorExists = cursorExists

        return scene, sceneName
    end

    local initialScene, initialName = Sample()
    self:Print(string.format(
        "Pointer trace started: scene=%s state=%s fragment=%s listening=%s cursor=%s stick=%.3f,%.3f",
        tostring(initialName), tostring(initialScene and initialScene:GetState()),
        tostring(lastFragmentShowing), tostring(lastListening),
        tostring(lastCursorExists),
        GetGamepadLeftStickX(GAMEPAD_INCLUDE_DEADZONE),
        GetGamepadLeftStickY(GAMEPAD_INCLUDE_DEADZONE)))
    self:Print("Move the left stick now. Capturing scene, fragment, owner and cursor state for 3 seconds.")

    if EVENT_NEW_MOVEMENT_IN_UI_MODE then
        EVENT_MANAGER:UnregisterForEvent(movementEventName, EVENT_NEW_MOVEMENT_IN_UI_MODE)
        EVENT_MANAGER:RegisterForEvent(movementEventName, EVENT_NEW_MOVEMENT_IN_UI_MODE, function()
            movementEvents = movementEvents + 1
        end)
    end

    EVENT_MANAGER:UnregisterForUpdate("ESOHybridUI_PointerProbe")
    EVENT_MANAGER:RegisterForUpdate("ESOHybridUI_PointerProbe", 100, function()
        Sample()
        if GetGameTimeMilliseconds() - startTime >= 3000 then
            EVENT_MANAGER:UnregisterForUpdate("ESOHybridUI_PointerProbe")
            if EVENT_NEW_MOVEMENT_IN_UI_MODE then
                EVENT_MANAGER:UnregisterForEvent(movementEventName, EVENT_NEW_MOVEMENT_IN_UI_MODE)
            end
            local delta = -1
            if type(startX) == "number" and type(startY) == "number"
                and type(lastX) == "number" and type(lastY) == "number" then
                delta = math.sqrt((lastX - startX) ^ 2 + (lastY - startY) ^ 2)
            end
            ADDON:Print(string.format(
                "Pointer trace: samples=%d sceneChanges=%d shown=%d listening=%d maxStick=%.3f cursorDelta=%.1f movementEvents=%d finalScene=%s fragment=%s listeningNow=%s cursorExists=%s",
                samples, sceneChanges, shownSamples, listeningSamples, maxStick,
                delta, movementEvents, tostring(lastScene), tostring(lastFragmentShowing),
                tostring(lastListening), tostring(lastCursorExists)))
            ADDON:Print("ownersWhileListening=" .. tostring(ownerSnapshot or "none"))

            if DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.inputObjects then
                for index = #DIRECTIONAL_INPUT.inputObjects, 1, -1 do
                    local owner = DIRECTIONAL_INPUT.inputObjects[index]
                    local control = DIRECTIONAL_INPUT.inputControls[index]
                    local name = control and control.GetName and control:GetName() or tostring(control)
                    ADDON:Print(string.format("inputOwner[%d]=%s control=%s", index,
                        tostring(owner == lib and "LibMousePointer" or owner), tostring(name)))
                end
            end
        end
    end)
end
