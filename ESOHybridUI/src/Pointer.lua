-- Self-contained gamepad pointer.
--
-- Uses ESO's DIRECTIONAL_INPUT ownership/consumption API and native virtual
-- cursor APIs. It deliberately does not synthesize mouse events or call
-- arbitrary control handlers: those calls are not trusted mouse input and can
-- taint protected inventory actions.
local ADDON = ESOHybridUI
local rt = ADDON.rt

local pointerOwner = { name = "ESOHybridUI_PointerInput" }
local pointerFragment
local cursorControl
local cursorId
local cursorX, cursorY
local initialX, initialY
local lastMoveTime = 0
local cursorSpeed = 3
local pointerTopLevel
local pointerListening = false
local pointerUpdateCount = 0
local lastAvailableBefore, lastAvailableAfterGetXY
local lastInputX, lastInputY = 0, 0
local lastInputScene

local function UpdateCursorInfo()
    if not cursorId then
        return
    end
    WINDOW_MANAGER:UpdateCursorPosition(cursorId, cursorX, cursorY)
    rt.pointerX, rt.pointerY = cursorX, cursorY
    pointerOwner.mouseOverControl = WINDOW_MANAGER:GetControlAtCursor(cursorId)
end

function pointerOwner:UpdateDirectionalInput()
    pointerUpdateCount = pointerUpdateCount + 1
    lastInputScene = SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName()
    lastAvailableBefore = DIRECTIONAL_INPUT:IsAvailable(ZO_DI_LEFT_STICK)
    if not lastAvailableBefore then
        lastInputX, lastInputY = 0, 0
        lastAvailableAfterGetXY = nil
        return
    end

    local dx, dy = DIRECTIONAL_INPUT:GetXY(ZO_DI_LEFT_STICK)
    lastInputX, lastInputY = dx, dy
    -- ESO's GetXY consumes the queried device itself (even when the stick is
    -- neutral), preserving DIRECTIONAL_INPUT's owner priority for this frame.
    lastAvailableAfterGetXY = DIRECTIONAL_INPUT:IsAvailable(ZO_DI_LEFT_STICK)

    dx, dy = zo_clampLength2D(dx, dy, 1.5)
    if dx == 0 and dy == 0 then
        lastMoveTime = GetGameTimeMilliseconds()
        return
    end

    local elapsed = GetGameTimeMilliseconds() - lastMoveTime
    local acceleration = zo_clamp(elapsed / 250, 1, 8)
    local frameDelta = GetFrameDeltaNormalizedForTargetFramerate()
    local magnitude = frameDelta * cursorSpeed * acceleration

    local oldX, oldY = cursorX, cursorY
    cursorControl:SetAnchor(CENTER, GuiRoot, TOPLEFT,
        cursorX + dx * magnitude, cursorY - dy * magnitude)
    cursorX, cursorY = cursorControl:GetCenter()

    if cursorX ~= oldX or cursorY ~= oldY then
        UpdateCursorInfo()
    end
end

local function SetCursorVisible(visible)
    cursorControl:SetHidden(not visible)
    if visible then
        if not cursorId then
            cursorId = WINDOW_MANAGER:CreateCursor(cursorX, cursorY)
        end
        pointerTopLevel:BringWindowToTop()
        UpdateCursorInfo()
    else
        if cursorId then
            WINDOW_MANAGER:DestroyCursor(cursorId)
            cursorId = nil
        end
        pointerOwner.mouseOverControl = nil
    end
end

local function StartPointer()
    if not cursorId then
        cursorX, cursorY = initialX, initialY
        cursorControl:SetAnchor(CENTER, GuiRoot, TOPLEFT, cursorX, cursorY)
    end
    SetCursorVisible(true)
    if not pointerListening then
        DIRECTIONAL_INPUT:Activate(pointerOwner, pointerTopLevel)
        pointerListening = true
    end
end

local function StopPointer()
    if pointerListening then
        DIRECTIONAL_INPUT:Deactivate(pointerOwner)
        pointerListening = false
    end
    SetCursorVisible(false)
end

local function OnPointerFragmentState(_, newState)
    -- Take ownership as soon as the fragment starts appearing, not only after
    -- its transition completes. This closes the first-frame input leak window.
    if newState == SCENE_FRAGMENT_SHOWING or newState == SCENE_FRAGMENT_SHOWN then
        StartPointer()
    elseif newState == SCENE_FRAGMENT_HIDING then
        StopPointer()
    end
end

function ADDON:StopPointer()
    if DIRECTIONAL_INPUT and pointerListening then
        DIRECTIONAL_INPUT:Deactivate(pointerOwner)
        pointerListening = false
    end
    if cursorId then
        SetCursorVisible(false)
    end
end

function ADDON:InitializePointer()
    if rt.pointerInitialized then
        return
    end
    if not HUI_PointerTopLevel or not HUI_PointerTopLevelGamepadCursor
        or not DIRECTIONAL_INPUT or not WINDOW_MANAGER.CreateCursor
        or not WINDOW_MANAGER.GetControlAtCursor then
        self:Print("Native pointer controls or directional-input APIs are unavailable.")
        return
    end

    pointerTopLevel = HUI_PointerTopLevel
    cursorControl = HUI_PointerTopLevelGamepadCursor
    initialX, initialY = GuiRoot:GetCenter()
    cursorX, cursorY = initialX, initialY
    cursorSpeed = tonumber(self.saved.pointerSpeed) or 3
    lastMoveTime = GetGameTimeMilliseconds()

    cursorControl:SetAnchor(CENTER, GuiRoot, TOPLEFT, cursorX, cursorY)
    pointerFragment = ZO_SimpleSceneFragment:New(pointerTopLevel)
    pointerFragment:SetConditional(function()
        return rt.keyboardPresentation and ADDON.saved.pointerEnabled
    end)
    pointerFragment:RegisterCallback("StateChange", OnPointerFragmentState)

    -- Existing scene integration expects this global fragment name. HUI now
    -- owns it; LibMousePointer is no longer required.
    ADDON.PointerFragment = pointerFragment
    rt.pointerOwner = pointerOwner
    rt.pointerInitialized = true
end

local function CaptureOwners()
    local entries = {}
    if DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.inputObjects then
        for index = #DIRECTIONAL_INPUT.inputObjects, 1, -1 do
            local owner = DIRECTIONAL_INPUT.inputObjects[index]
            local control = DIRECTIONAL_INPUT.inputControls[index]
            local name = control and control.GetName and control:GetName() or tostring(control)
            entries[#entries + 1] = string.format("%d:%s/%s", index,
                tostring(owner == pointerOwner and "HUI_Pointer" or owner == SCENE_MANAGER and "SceneManager" or owner == CLIENT_INPUT and "ClientInput" or owner), tostring(name))
        end
    end
    return table.concat(entries, ",")
end

function ADDON:PrintPointerProbe()
    local startScene = SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName()
    local startX, startY = cursorX, cursorY
    local startTime = GetGameTimeMilliseconds()
    local startPointerUpdates = pointerUpdateCount
    local samples, shownSamples, listeningSamples = 0, 0, 0
    local sceneChanges, movementEvents = 0, 0
    local previousScene = startScene
    local ownerSnapshot = nil
    local maxStick = 0
    local lastScene = startScene
    local movementEventName = "ESOHybridUI_PointerProbeMovement"

    self:Print(string.format("Pointer trace started: scene=%s fragment=%s listening=%s cursor=%s stick=%.3f,%.3f",
        tostring(startScene), tostring(pointerFragment and pointerFragment:IsShowing()),
        tostring(DIRECTIONAL_INPUT and DIRECTIONAL_INPUT:IsListening(pointerOwner)),
        tostring(cursorId ~= nil),
        GetGamepadLeftStickX(GAMEPAD_INCLUDE_DEADZONE),
        GetGamepadLeftStickY(GAMEPAD_INCLUDE_DEADZONE)))
    self:Print("Move the left stick now. Capturing pointer owner and movement events for 3 seconds.")

    if EVENT_NEW_MOVEMENT_IN_UI_MODE then
        EVENT_MANAGER:UnregisterForEvent(movementEventName, EVENT_NEW_MOVEMENT_IN_UI_MODE)
        EVENT_MANAGER:RegisterForEvent(movementEventName, EVENT_NEW_MOVEMENT_IN_UI_MODE, function()
            movementEvents = movementEvents + 1
        end)
    end

    EVENT_MANAGER:UnregisterForUpdate("ESOHybridUI_PointerProbe")
    EVENT_MANAGER:RegisterForUpdate("ESOHybridUI_PointerProbe", 100, function()
        samples = samples + 1
        local sceneName = SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName()
        if sceneName ~= previousScene then
            sceneChanges = sceneChanges + 1
            previousScene = sceneName
        end
        lastScene = sceneName

        local showing = pointerFragment and pointerFragment:IsShowing() or false
        local listening = DIRECTIONAL_INPUT and DIRECTIONAL_INPUT:IsListening(pointerOwner) or false
        if showing then shownSamples = shownSamples + 1 end
        if listening then
            listeningSamples = listeningSamples + 1
            if not ownerSnapshot then ownerSnapshot = CaptureOwners() end
        end
        maxStick = math.max(maxStick,
            math.abs(GetGamepadLeftStickX(GAMEPAD_INCLUDE_DEADZONE)),
            math.abs(GetGamepadLeftStickY(GAMEPAD_INCLUDE_DEADZONE)))

        if GetGameTimeMilliseconds() - startTime >= 3000 then
            EVENT_MANAGER:UnregisterForUpdate("ESOHybridUI_PointerProbe")
            if EVENT_NEW_MOVEMENT_IN_UI_MODE then
                EVENT_MANAGER:UnregisterForEvent(movementEventName, EVENT_NEW_MOVEMENT_IN_UI_MODE)
            end
            local delta = -1
            if type(startX) == "number" and type(startY) == "number"
                and type(cursorX) == "number" and type(cursorY) == "number" then
                delta = math.sqrt((cursorX - startX) ^ 2 + (cursorY - startY) ^ 2)
            end
            ADDON:Print(string.format(
                "Pointer trace: samples=%d sceneChanges=%d shown=%d listening=%d maxStick=%.3f cursorDelta=%.1f movementEvents=%d finalScene=%s fragment=%s listeningNow=%s cursorExists=%s",
                samples, sceneChanges, shownSamples, listeningSamples, maxStick,
                delta, movementEvents, tostring(lastScene),
                tostring(pointerFragment and pointerFragment:IsShowing()),
                tostring(DIRECTIONAL_INPUT and DIRECTIONAL_INPUT:IsListening(pointerOwner)),
                tostring(cursorId ~= nil)))
            ADDON:Print("ownersWhileListening=" .. tostring(ownerSnapshot or "none"))
            ADDON:Print(string.format(
                "pointerCallback: calls=%d lastScene=%s input=%.3f,%.3f availableBefore=%s availableAfterGetXY=%s",
                pointerUpdateCount - startPointerUpdates, tostring(lastInputScene),
                lastInputX, lastInputY, tostring(lastAvailableBefore),
                tostring(lastAvailableAfterGetXY)))
        end
    end)
end