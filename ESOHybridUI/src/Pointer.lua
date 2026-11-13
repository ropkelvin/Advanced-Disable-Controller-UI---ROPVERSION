-- Pointer input for keyboard-style scenes.
--
-- LibMousePointer owns the virtual cursor and its native click keybind. HUI
-- supplies left-stick movement only. Never synthesize OnClicked/OnMouseUp:
-- arbitrary handler calls are not trusted mouse input and can trip ESO's
-- protected-action boundary (inventory destruction, etc.).
local ADDON = ESOHybridUI
local rt = ADDON.rt

rt.pointerUpdates = 0

local function GetCursor()
    local lib = LibMousePointer
    local cursor = lib and lib.gamepadCursor
    if cursor and cursor.cursorId and cursor.control then
        return cursor
    end
    return nil
end

local moveStart = 0

local function Step()
    local cursor = GetCursor()
    if not cursor or not DIRECTIONAL_INPUT then
        return
    end

    rt.pointerUpdates = rt.pointerUpdates + 1
    DIRECTIONAL_INPUT:Consume(ZO_DI_LEFT_STICK, ZO_DI_RIGHT_STICK)
    SetGamepadLeftStickConsumedByUI(true)
    SetGamepadRightStickConsumedByUI(true)

    local x = DIRECTIONAL_INPUT:GetXFromInputDevice(ZO_DI_LEFT_STICK)
    local y = DIRECTIONAL_INPUT:GetYFromInputDevice(ZO_DI_LEFT_STICK)
    rt.rawStickX, rt.rawStickY = x, y

    local now = GetGameTimeMilliseconds()
    if x == 0 and y == 0 then
        moveStart = now
    end

    local speed = ADDON.saved.pointerSpeed or 3
    local delta = GetFrameDeltaNormalizedForTargetFramerate()
    local acceleration = zo_clamp((now - moveStart) / 250, 1, 8)
    local dx, dy = x * delta * speed * acceleration, -y * delta * speed * acceleration

    local control = cursor.control
    control:SetAnchor(CENTER, GuiRoot, TOPLEFT, cursor.x + dx, cursor.y + dy)
    local cx, cy = control:GetCenter()
    if cx and cy then
        local width, height = GuiRoot:GetDimensions()
        cx, cy = zo_clamp(cx, 0, width), zo_clamp(cy, 0, height)
        cursor.x, cursor.y = cx, cy
        cursor.directionalX, cursor.directionalY = cx, cy
        control:ClearAnchors()
        control:SetAnchor(CENTER, GuiRoot, TOPLEFT, cx, cy)
    end
    cursor:UpdateCursorInfo()
end

local inputObject = {}
rt.pointerInputObject = inputObject
function inputObject:UpdateDirectionalInput()
    Step()
end

local function ReleaseSticks()
    SetGamepadLeftStickConsumedByUI(false)
    SetGamepadRightStickConsumedByUI(false)
    rt.rawStickX, rt.rawStickY = 0, 0
end

local function RestoreLibraryDriver()
    if rt.libraryDriverSuppressed and LibMousePointer then
        LibMousePointer.UpdateDirectionalInput = rt.originalLibraryDriver
        rt.libraryDriverSuppressed = false
        rt.originalLibraryDriver = nil
    end
end

function ADDON:StopPointer()
    if DIRECTIONAL_INPUT and DIRECTIONAL_INPUT:IsListening(inputObject) then
        DIRECTIONAL_INPUT:Deactivate(inputObject)
    end
    ReleaseSticks()
    RestoreLibraryDriver()
end

local function OnFragmentState(_, newState)
    if newState == SCENE_FRAGMENT_SHOWN then
        moveStart = GetGameTimeMilliseconds()
        if not rt.libraryDriverSuppressed then
            rt.originalLibraryDriver = LibMousePointer.UpdateDirectionalInput
            LibMousePointer.UpdateDirectionalInput = function() end
            rt.libraryDriverSuppressed = true
        end
        if not DIRECTIONAL_INPUT:IsListening(inputObject) then
            DIRECTIONAL_INPUT:Activate(inputObject, LibMousePointer.control)
        end
    elseif newState == SCENE_FRAGMENT_HIDING or newState == SCENE_FRAGMENT_HIDDEN then
        if DIRECTIONAL_INPUT:IsListening(inputObject) then
            DIRECTIONAL_INPUT:Deactivate(inputObject)
        end
        ReleaseSticks()
        RestoreLibraryDriver()
    end
end

function ADDON:InitializePointer()
    local lib = LibMousePointer
    if rt.pointerInitialized then
        return
    end
    if not lib or not MOUSE_POINTER_FRAGMENT or not lib.control or not lib.gamepadCursor then
        self:Print("LibMousePointer is not ready; controller pointer is unavailable.")
        return
    end

    -- Keep the library's fragment and native click descriptor intact. The
    -- library adds its click action only when the active screen leaves the
    -- primary shortcut free; HUI never overrides a screen's native action.
    MOUSE_POINTER_FRAGMENT:SetConditional(function()
        return rt.keyboardPresentation and ADDON.saved.pointerEnabled
    end)
    MOUSE_POINTER_FRAGMENT:RegisterCallback("StateChange", OnFragmentState)

    rt.pointerInitialized = true
    if MOUSE_POINTER_FRAGMENT:IsShowing() then
        OnFragmentState(nil, SCENE_FRAGMENT_SHOWN)
    end
end

function ADDON:PrintPointerProbe()
    self:Print("Open a supported menu and move the left stick for five seconds.")
    zo_callLater(function()
        local cursor = LibMousePointer and LibMousePointer.gamepadCursor
        self:Print(string.format(
            "init=%s listening=%s cursorId=%s updates=%d rawStick=%.2f,%.2f cursor=%s,%s",
            tostring(rt.pointerInitialized), tostring(DIRECTIONAL_INPUT:IsListening(inputObject)),
            tostring(cursor and cursor.cursorId), rt.pointerUpdates,
            DIRECTIONAL_INPUT:GetXFromInputDevice(ZO_DI_LEFT_STICK),
            DIRECTIONAL_INPUT:GetYFromInputDevice(ZO_DI_LEFT_STICK),
            tostring(cursor and cursor.x), tostring(cursor and cursor.y)))
    end, 5000)
end
