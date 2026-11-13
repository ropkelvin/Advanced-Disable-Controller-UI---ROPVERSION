-- Pointer input. LibMousePointer owns the cursor object and its fragment;
-- HUI owns how the sticks drive it and how a "click" is delivered.
--
--  * Movement: HUI registers its own DIRECTIONAL_INPUT object. It reads the
--    raw stick values (GetXFromInputDevice ignores "consumed" state, so no
--    other handler can starve it) and consumes both sticks, telling the game
--    directly (SetGamepad*StickConsumedByUI) so the character and camera stay
--    still regardless of handler order.
--  * Clicks: ESO mouse-up handlers take (control, button, upInside, ...) and
--    the stock ones ignore the event unless upInside is true.
local ADDON = ESOHybridUI
local rt = ADDON.rt

local MAX_PARENT_DEPTH = 10
local CLICK_HANDLERS = { "OnClicked", "OnMouseDown", "OnMouseUp" }
local ENTER_HANDLER = { "OnMouseEnter" }
local WHEEL_HANDLER = { "OnMouseWheel" }
local WHEEL_THRESHOLD = 0.35
local WHEEL_INTERVAL_MS = 90

rt.pointerUpdates = 0

-- Nearest control (starting at `control`, walking up) with any listed handler.
local function FindOwner(control, names)
    for _ = 1, MAX_PARENT_DEPTH do
        if not control then
            return nil
        end
        for i = 1, #names do
            if control:GetHandler(names[i]) then
                return control, names[i]
            end
        end
        control = control:GetParent()
    end
    return nil
end

local function GetCursor()
    local lib = LibMousePointer
    local cursor = lib and lib.gamepadCursor
    if cursor and cursor.cursorId then
        return cursor
    end
    return nil
end

-- Click -------------------------------------------------------------------

local function Click(button)
    local cursor = GetCursor()
    if not cursor then
        return
    end
    local target = FindOwner(cursor.mouseOverControl, CLICK_HANDLERS)
    if not target then
        return
    end

    local onClicked = target:GetHandler("OnClicked")
    if onClicked then
        onClicked(target, button, false, false, false, false)
        return
    end

    local down = target:GetHandler("OnMouseDown")
    if down then
        down(target, button, false, false, false, false)
    end
    local up = target:GetHandler("OnMouseUp")
    if up then
        zo_callLater(function()
            up(target, button, true, false, false, false, false) -- upInside = true
        end, 30)
    end
end

-- Hover: row highlights and tooltips run from OnMouseEnter/Exit, which the
-- virtual cursor does not raise by itself.
local hovered = nil

local function ClearHover()
    if hovered then
        local onExit = hovered:GetHandler("OnMouseExit")
        if onExit then
            onExit(hovered)
        end
        hovered = nil
    end
end

local function UpdateHover(control)
    local owner = FindOwner(control, ENTER_HANDLER)
    if owner == hovered then
        return
    end
    ClearHover()
    hovered = owner
    if owner then
        owner:GetHandler("OnMouseEnter")(owner)
    end
end

-- Per-frame stick handling -------------------------------------------------

local moveStart = 0
local lastWheel = 0

local function Step()
    local cursor = GetCursor()
    if not cursor then
        return
    end
    rt.pointerUpdates = rt.pointerUpdates + 1

    local input = DIRECTIONAL_INPUT
    -- Menu owns both sticks: no character movement, no camera.
    input:Consume(ZO_DI_LEFT_STICK, ZO_DI_RIGHT_STICK)
    SetGamepadLeftStickConsumedByUI(true)
    SetGamepadRightStickConsumedByUI(true)

    local x = input:GetXFromInputDevice(ZO_DI_LEFT_STICK)
    local y = input:GetYFromInputDevice(ZO_DI_LEFT_STICK)
    rt.rawStickX, rt.rawStickY = x, y
    local now = GetGameTimeMilliseconds()
    if x == 0 and y == 0 then
        moveStart = now
    end

    local speed = ADDON.saved.pointerSpeed or 3
    local step = GetFrameDeltaNormalizedForTargetFramerate()
        * speed * zo_clamp((now - moveStart) / 250, 1, 8)
    local dx, dy = x * step, -y * step

    local control = cursor.control
    control:SetAnchor(CENTER, GuiRoot, TOPLEFT, cursor.x + dx, cursor.y + dy)
    local cx, cy = control:GetCenter()
    if cx ~= cursor.x or cy ~= cursor.y then
        cursor.x, cursor.y = cx, cy
        cursor.directionalX, cursor.directionalY = cx + dx, cy + dy
    end
    cursor:UpdateCursorInfo()
    UpdateHover(cursor.mouseOverControl)

    -- Right stick -> mouse wheel on the hovered control or nearest parent.
    local wheel = input:GetYFromInputDevice(ZO_DI_RIGHT_STICK)
    if math.abs(wheel) > WHEEL_THRESHOLD and now - lastWheel >= WHEEL_INTERVAL_MS then
        lastWheel = now
        local target = FindOwner(cursor.mouseOverControl, WHEEL_HANDLER)
        if target then
            target:GetHandler("OnMouseWheel")(target, wheel > 0 and 1 or -1, false, false, false, false)
        end
    end
end

-- Our own directional-input owner. An error here is reported once instead of
-- spamming the UI-error window every frame.
local inputObject = {}
function inputObject:UpdateDirectionalInput()
    local ok, err = pcall(Step)
    if not ok and not rt.pointerErrorShown then
        rt.pointerErrorShown = true
        rt.lastError = tostring(err)
        ADDON:Print("Pointer error (please report): " .. rt.lastError)
    end
end

-- Keybinds -------------------------------------------------------------------
-- L3 is the library's own click descriptor (re-keyed below). A is ours and
-- yields to any screen that already uses it. R3 sends a right-click, which is
-- how keyboard inventory/context menus expose Use, Equip, Link, Destroy.

local primaryClick = {
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    name = "Select",
    keybind = "UI_SHORTCUT_PRIMARY",
    ethereal = true,
    callback = function() Click(MOUSE_BUTTON_INDEX_LEFT) end,
}

local rightClick = {
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    name = "Right click",
    keybind = "UI_SHORTCUT_RIGHT_STICK",
    ethereal = true,
    callback = function() Click(MOUSE_BUTTON_INDEX_RIGHT) end,
}

local function OnFragmentState(_, newState)
    local lib = LibMousePointer
    if newState == SCENE_FRAGMENT_SHOWN then
        moveStart = GetGameTimeMilliseconds()
        if not DIRECTIONAL_INPUT:IsListening(inputObject) then
            DIRECTIONAL_INPUT:Activate(inputObject, lib.control)
        end
        ADDON:SetKeybind(primaryClick, true)
        ADDON:SetKeybind(rightClick, true)
    elseif newState == SCENE_FRAGMENT_HIDING then
        DIRECTIONAL_INPUT:Deactivate(inputObject)
        ClearHover()
        ADDON:SetKeybind(primaryClick, false)
        ADDON:SetKeybind(rightClick, false)
    end
end

function ADDON:InitializePointer()
    local lib = LibMousePointer
    if rt.pointerInitialized then
        return
    end
    if not lib or not MOUSE_POINTER_FRAGMENT or not lib.keybindButton or not lib.control then
        self:Print("LibMousePointer is not ready; the pointer is unavailable.")
        return
    end

    -- HUI's input object drives the cursor; silence the library's own driver
    -- so the cursor is never moved twice.
    lib.UpdateDirectionalInput = function() end
    lib.InvokeClick = function(_, button)
        Click(button or MOUSE_BUTTON_INDEX_LEFT)
    end

    -- Move the library's click off UI_SHORTCUT_PRIMARY so it never collides
    -- with a screen's own primary action.
    lib.keybindButton.keybind = "UI_SHORTCUT_LEFT_STICK"
    lib.keybindButton.ethereal = true

    -- The fragment lives in menu scenes permanently (Scenes.lua attaches it
    -- once); this conditional decides when it actually shows.
    MOUSE_POINTER_FRAGMENT:SetConditional(function()
        return rt.keyboardPresentation and ADDON.saved.pointerEnabled
    end)
    MOUSE_POINTER_FRAGMENT:RegisterCallback("StateChange", OnFragmentState)

    rt.pointerInitialized = true
    if MOUSE_POINTER_FRAGMENT:IsShowing() then
        OnFragmentState(nil, SCENE_FRAGMENT_SHOWN)
    end
end

-- /hui pointer: open a menu, then hold the left stick when prompted.
function ADDON:PrintPointerProbe()
    self:Print("Open a menu and HOLD the left stick up-left now (5 s)...")
    zo_callLater(function()
        local lib = LibMousePointer
        local cursor = lib and lib.gamepadCursor
        local listening = DIRECTIONAL_INPUT:IsListening(inputObject)
        self:Print(string.format(
            "init=%s listening=%s cursorId=%s updates=%d rawStick=%.2f,%.2f cursor=%s,%s err=%s",
            tostring(rt.pointerInitialized), tostring(listening),
            tostring(cursor and cursor.cursorId), rt.pointerUpdates,
            DIRECTIONAL_INPUT:GetXFromInputDevice(ZO_DI_LEFT_STICK),
            DIRECTIONAL_INPUT:GetYFromInputDevice(ZO_DI_LEFT_STICK),
            tostring(cursor and cursor.x), tostring(cursor and cursor.y), tostring(rt.lastError)))
    end, 5000)
end
