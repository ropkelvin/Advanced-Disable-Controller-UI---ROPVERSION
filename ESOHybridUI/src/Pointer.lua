-- Pointer integration.
--
-- LibMousePointer already owns the cursor, left-stick sampling, cursor hit
-- testing, hover and primary-click descriptor. HUI must not implement a
-- second cursor or replace library methods. Its own documented InvokeClick
-- API is used only for an optional right-click/context action.
local ADDON = ESOHybridUI
local rt = ADDON.rt

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

local function InstallDirectionalInputIntegration()
    if rt.pointerDirectionalHooked or not SCENE_MANAGER
        or not SCENE_MANAGER.UpdateDirectionalInput then
        return
    end

    -- ESO's stock scene-manager owner consumes BOTH sticks while in UI mode.
    -- LibMousePointer is also a DIRECTIONAL_INPUT owner and consumes the left
    -- stick itself via DIRECTIONAL_INPUT:GetXY(ZO_DI_LEFT_STICK). If the stock
    -- owner runs first, it starves the pointer for that frame. Only while the
    -- library is actively listening, skip the stock consume-both-sticks call
    -- and reserve the right stick here. When the pointer is absent, ESO's
    -- original handler remains completely untouched.
    ZO_PreHook(SCENE_MANAGER, "UpdateDirectionalInput", function()
        if rt.inWorld and rt.keyboardPresentation and ADDON.saved.pointerEnabled
            and MOUSE_POINTER_FRAGMENT and MOUSE_POINTER_FRAGMENT:IsShowing()
            and DIRECTIONAL_INPUT and LibMousePointer
            and DIRECTIONAL_INPUT:IsListening(LibMousePointer) then
            DIRECTIONAL_INPUT:Consume(ZO_DI_RIGHT_STICK)
            return true
        end
        return false
    end)

    rt.pointerDirectionalHooked = true
end

function ADDON:StopPointer()
    if self.SetKeybind then
        self:SetKeybind(rightClick, false)
    end
end

function ADDON:InitializePointer()
    if rt.pointerInitialized then
        return
    end
    if not LibMousePointer or not MOUSE_POINTER_FRAGMENT
        or not LibMousePointer.InvokeClick or not LibMousePointer.GetCursorPosition then
        self:Print("LibMousePointer is missing or too old; pointer support is unavailable.")
        return
    end

    -- The library handles cursor lifetime, movement, hit testing and the
    -- native primary-click keybind. HUI controls only when its fragment shows.
    MOUSE_POINTER_FRAGMENT:SetConditional(function()
        return rt.keyboardPresentation and ADDON.saved.pointerEnabled
    end)
    MOUSE_POINTER_FRAGMENT:RegisterCallback("StateChange", OnFragmentState)

    InstallDirectionalInputIntegration()
    rt.pointerInitialized = true
    if MOUSE_POINTER_FRAGMENT:IsShowing() then
        ADDON:SetKeybind(rightClick, true)
    end
end

function ADDON:PrintPointerProbe()
    self:Print("Move the left stick in this window for five seconds; checking scene and directional-input ownership.")
    zo_callLater(function()
        local lib = LibMousePointer
        local x, y = lib and lib:GetCursorPosition()
        local listening = DIRECTIONAL_INPUT and lib and DIRECTIONAL_INPUT:IsListening(lib)
        local sceneName = SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName()
        local scene = sceneName and SCENE_MANAGER:GetScene(sceneName)
        local sceneState = scene and scene:GetState()
        local attached = scene and scene:HasFragment(MOUSE_POINTER_FRAGMENT)
        local fragmentShowing = MOUSE_POINTER_FRAGMENT and MOUSE_POINTER_FRAGMENT:IsShowing()
        local cursorExists = lib and lib.gamepadCursor and lib.gamepadCursor.cursorId ~= nil
        local rawX = GetGamepadLeftStickX(GAMEPAD_INCLUDE_DEADZONE)
        local rawY = GetGamepadLeftStickY(GAMEPAD_INCLUDE_DEADZONE)

        self:Print(string.format("scene=%s state=%s menu=%s restricted=%s",
            tostring(sceneName), tostring(sceneState), tostring(rt.menuScene), tostring(rt.restricted)))
        self:Print(string.format("fragmentAttached=%s fragmentShowing=%s cursorExists=%s listening=%s",
            tostring(attached), tostring(fragmentShowing), tostring(cursorExists), tostring(listening)))
        self:Print(string.format("rawLeftStick=%.3f,%.3f cursor=%s,%s",
            rawX, rawY, tostring(x), tostring(y)))

        -- Some ESO windows are shown as fragments/top-level UI while the
        -- scene manager continues to report the HUD as its current scene.
        local function IsSceneShowing(name)
            return SCENE_MANAGER and SCENE_MANAGER.IsShowing
                and SCENE_MANAGER:IsShowing(name) or false
        end
        local function IsFragmentShowing(fragment)
            return fragment and fragment.IsShowing and fragment:IsShowing() or false
        end
        self:Print(string.format("mapScenes worldMap=%s gamepad_worldMap=%s mapFragment=%s gamepadMapInfo=%s",
            tostring(IsSceneShowing("worldMap")),
            tostring(IsSceneShowing("gamepad_worldMap")),
            tostring(IsFragmentShowing(WORLD_MAP_FRAGMENT)),
            tostring(IsFragmentShowing(GAMEPAD_WORLD_MAP_INFO_FRAGMENT))))
        self:Print(string.format("inventoryFragments inventory=%s gamepadInventory=%s",
            tostring(IsFragmentShowing(INVENTORY_FRAGMENT)),
            tostring(IsFragmentShowing(GAMEPAD_INVENTORY_FRAGMENT))))

        if DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.inputObjects then
            for index = #DIRECTIONAL_INPUT.inputObjects, 1, -1 do
                local owner = DIRECTIONAL_INPUT.inputObjects[index]
                local control = DIRECTIONAL_INPUT.inputControls[index]
                local name = control and control.GetName and control:GetName() or tostring(control)
                self:Print(string.format("inputOwner[%d]=%s control=%s", index, tostring(owner == lib and "LibMousePointer" or owner), tostring(name)))
            end
        end
    end, 5000)
end
