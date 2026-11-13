-- Pointer input for keyboard-style scenes.
--
-- LibMousePointer owns the virtual cursor and its native click keybind. HUI
-- only supplies left-stick movement. Never synthesize OnClicked/OnMouseUp:
-- calling arbitrary UI handlers is not equivalent to trusted mouse input and
-- can trip ESO's protected-action boundary (inventory destruction, etc.).
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

    -- The pointer owns both sticks while its fragment is visible. Consume via
    -- DIRECTIONAL_INPUT (priority-aware) and tell the game not to pass either
    -- stick to movement/camera processing.
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
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, cx, cy)
    end
    cursor:UpdateCursorInfo()
end

local inputObject = {}
function inputObject:UpdateDirectionalInput()
    Step()
end

local function ReleaseSticks()
    SetGamepadLeftStickConsumedByUI(false)
    SetGamepadRightStickConsumedByUI(false)
    rt.rawStickX, rt.rawStickY = 0, 0
end

local function OnFragmentState(_, newState)
    if newState == SCENE_FRAGMENT_SHOWN then
        moveStart = GetGameTimeMilliseconds()
        -- Ensure the native library's directional driver does not move the
        -- same cursor a second time. Its fragment, cursor and click descriptor
        -- remain intact and are still owned by LibMousePointer.
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

    -- Do not replace InvokeClick, re-key the library descriptor, or dispatch
    -- synthetic mouse events. The library's own click descriptor is added only
    -- when the active screen has not claimed UI_SHORTCUT_PRIMARY.
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
