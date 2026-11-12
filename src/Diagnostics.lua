local ADDON = ESOHybridUI
local rt = ADDON.runtime

local UPDATE_NAME = "ESOHybridUI_Diagnostics"
local SAMPLE_INTERVAL_MS = 500
local CAPTURE_DURATION_MS = 90000
local MAX_LOG_ENTRIES = 240

local function SafeString(value)
    if value == nil then
        return "nil"
    end
    return tostring(value)
end

local function GetCurrentSceneName()
    if SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName then
        return SCENE_MANAGER:GetCurrentSceneName() or "nil"
    end
    return "unavailable"
end

local function GetPointerState()
    local lib = LibMousePointer
    if not lib then
        return "library=missing"
    end

    local cursor = lib.gamepadCursor
    if not cursor then
        return "library=ready,cursor=uninitialized"
    end

    local controlVisible = "unknown"
    if cursor.control and cursor.control.IsHidden then
        controlVisible = tostring(not cursor.control:IsHidden())
    end

    local hitControl = cursor.mouseOverControl
    local hitName = hitControl and hitControl.GetName and hitControl:GetName() or "nil"
    local hasOnClicked = hitControl and hitControl.GetHandler
        and hitControl:GetHandler("OnClicked") ~= nil
    local hasOnMouseDown = hitControl and hitControl.GetHandler
        and hitControl:GetHandler("OnMouseDown") ~= nil
    local hasOnMouseUp = hitControl and hitControl.GetHandler
        and hitControl:GetHandler("OnMouseUp") ~= nil

    return "library=ready"
        .. ",cursorId=" .. SafeString(cursor.cursorId)
        .. ",cursorVisible=" .. controlVisible
        .. ",x=" .. SafeString(cursor.x)
        .. ",y=" .. SafeString(cursor.y)
        .. ",hitControl=" .. SafeString(hitName)
        .. ",hitOnClicked=" .. tostring(hasOnClicked)
        .. ",hitOnMouseDown=" .. tostring(hasOnMouseDown)
        .. ",hitOnMouseUp=" .. tostring(hasOnMouseUp)
end

local function GetPrimaryKeybindState()
    if not KEYBIND_STRIP or not KEYBIND_STRIP.keybinds then
        return "keybindStrip=unavailable"
    end

    local descriptor = KEYBIND_STRIP.keybinds.UI_SHORTCUT_PRIMARY
    if type(descriptor) == "userdata" then
        descriptor = descriptor.keybindButtonDescriptor
    end
    if not descriptor then
        return "primary=unassigned"
    end

    -- Never evaluate descriptor.name here. Some ESO callbacks assume a
    -- selected row and can themselves throw while the UI is transitioning.
    return "primary=assigned"
        .. ",descriptorType=" .. type(descriptor)
        .. ",nameType=" .. type(descriptor.name)
        .. ",scene=" .. SafeString(descriptor.addedForSceneName)
        .. ",isPointerClick=" .. tostring(
            LibMousePointer and descriptor == LibMousePointer.keybindButton
        )
end

local function GetDirectionalState()
    if not DIRECTIONAL_INPUT or not DIRECTIONAL_INPUT.IsAvailable then
        return "directionalInput=unavailable"
    end

    local owners = {}
    for index, object in ipairs(DIRECTIONAL_INPUT.inputObjects or {}) do
        local control = DIRECTIONAL_INPUT.inputControls
            and DIRECTIONAL_INPUT.inputControls[index]
        local ownerName = "owner" .. tostring(index)
        if object == LibMousePointer then
            ownerName = "LibMousePointer"
        elseif object == SCENE_MANAGER then
            ownerName = "SCENE_MANAGER"
        else
            local controlName = control and control.GetName and control:GetName()
            ownerName = (controlName or ownerName)
                .. ":" .. type(object)
                .. ":update=" .. type(object and object.UpdateDirectionalInput)
                .. ":ref=" .. SafeString(object)
        end
        owners[#owners + 1] = ownerName
    end

    local pointerListening = LibMousePointer
        and DIRECTIONAL_INPUT.IsListening
        and DIRECTIONAL_INPUT:IsListening(LibMousePointer)
    return "leftAvailable=" .. tostring(DIRECTIONAL_INPUT:IsAvailable(ZO_DI_LEFT_STICK))
        .. ",rightAvailable=" .. tostring(DIRECTIONAL_INPUT:IsAvailable(ZO_DI_RIGHT_STICK))
        .. ",pointerListening=" .. tostring(pointerListening)
        .. ",owners=" .. table.concat(owners, ";")
end

local function AppendEntry(kind, detail)
    if not ADDON.saved then
        return
    end

    ADDON.saved.diagnostics = ADDON.saved.diagnostics or {}
    local diagnostics = ADDON.saved.diagnostics
    diagnostics.log = diagnostics.log or {}

    table.insert(
        diagnostics.log,
        tostring(GetGameTimeMilliseconds())
            .. "|" .. tostring(kind)
            .. "|" .. tostring(detail or "")
    )

    while #diagnostics.log > MAX_LOG_ENTRIES do
        table.remove(diagnostics.log, 1)
    end
end

function ADDON:RecordDiagnostic(kind, detail)
    if rt.diagnosticCaptureActive then
        AppendEntry(kind, detail)
    end
end

local function BuildSample()
    local sceneName = GetCurrentSceneName()
    local scene = SCENE_MANAGER and SCENE_MANAGER.GetScene and SCENE_MANAGER:GetScene(sceneName)
    local hasPointerFragment = "unknown"
    if scene and MOUSE_POINTER_FRAGMENT and scene.HasFragment then
        hasPointerFragment = tostring(scene:HasFragment(MOUSE_POINTER_FRAGMENT))
    end
    local sceneState = scene and scene.GetState and scene:GetState() or "unavailable"
    local sceneShowing = scene and scene.IsShowing and scene:IsShowing() or false
    local fragmentShowing = MOUSE_POINTER_FRAGMENT
        and MOUSE_POINTER_FRAGMENT.IsShowing
        and MOUSE_POINTER_FRAGMENT:IsShowing() or false

    return "mode=" .. SafeString(ADDON.saved.mode)
        .. ",active=" .. tostring(ADDON:IsActive())
        .. ",gamepadOn=" .. tostring(ADDON:IsGamepadModeOn())
        .. ",nativePreferred=" .. tostring(ADDON:IsNativeGamepadMode())
        .. ",effectivePreferred=" .. tostring(IsInGamepadPreferredMode())
        .. ",modeConflict=" .. tostring(rt.modeOverrideConflict)
        .. ",restricted=" .. tostring(ADDON:IsRestrictedSceneActive())
        .. ",scene=" .. SafeString(sceneName)
        .. ",sceneState=" .. SafeString(sceneState)
        .. ",sceneShowing=" .. tostring(sceneShowing)
        .. ",pointerFragmentShowing=" .. tostring(fragmentShowing)
        .. ",sceneManagerDirectionalMethod=" .. type(SCENE_MANAGER and SCENE_MANAGER.UpdateDirectionalInput)
        .. ",pointerScene=" .. tostring(rt.pointerScene)
        .. ",pointerSceneName=" .. SafeString(rt.pointerSceneName)
        .. ",pointerEnabled=" .. tostring(ADDON.saved.pointerEnabled)
        .. ",pointerHookInstalled=" .. tostring(rt.pointerHookInstalled)
        .. ",directionalHookInstalled=" .. tostring(rt.directionalHookInstalled)
        .. ",promptHooksInstalled=" .. tostring(rt.promptHooksInstalled)
        .. ",mainMenuNavigationActive=" .. tostring(rt.mainMenuNavigationActive)
        .. ",mainMenuPreviousAdded=" .. tostring(rt.mainMenuNavigationPreviousAdded)
        .. ",mainMenuNextAdded=" .. tostring(rt.mainMenuNavigationNextAdded)
        .. ",lockPicking=" .. tostring(rt.lockPicking)
        .. ",hudRefreshPending=" .. tostring(rt.hudRefreshPending)
        .. ",keyboardTrackerReady=" .. tostring(HUD_TRACKER_MANAGER and HUD_TRACKER_MANAGER.keyboardHUDElement ~= nil)
        .. ",gamepadTrackerReady=" .. tostring(HUD_TRACKER_MANAGER and HUD_TRACKER_MANAGER.gamepadHUDElement ~= nil)
        .. ",sceneHasPointerFragment=" .. hasPointerFragment
        .. "," .. GetPointerState()
        .. "," .. GetDirectionalState()
        .. "," .. GetPrimaryKeybindState()
end

function ADDON:StopDiagnostics(reason)
    if not rt.diagnosticCaptureActive then
        return false
    end

    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
    AppendEntry("END", reason or "manual")
    rt.diagnosticCaptureActive = false

    if self.saved and self.saved.diagnostics then
        self.saved.diagnostics.complete = true
        self.saved.diagnostics.finishedAtMs = GetGameTimeMilliseconds()
    end

    self:Print("Diagnostic capture complete. Use /reloadui to save the log, then upload ESOHybridUI.lua from your SavedVariables folder.")
    return true
end

function ADDON:StartDiagnostics()
    if not self.saved then
        self:Print("SavedVariables are not ready; try again after entering the world.")
        return
    end

    if rt.diagnosticCaptureActive then
        self:Print("Diagnostic capture is already running.")
        return
    end

    self.saved.diagnostics = {
        version = 1,
        startedAtMs = GetGameTimeMilliseconds(),
        durationMs = CAPTURE_DURATION_MS,
        complete = false,
        log = {},
    }

    rt.diagnosticCaptureActive = true
    AppendEntry("START", "90-second capture; reproduce the pointer/input issue now")
    AppendEntry("INITIAL", BuildSample())

    local startedAt = GetGameTimeMilliseconds()
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, SAMPLE_INTERVAL_MS, function()
        if not rt.diagnosticCaptureActive then
            EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
            return
        end

        AppendEntry("SAMPLE", BuildSample())

        if GetGameTimeMilliseconds() - startedAt >= CAPTURE_DURATION_MS then
            ADDON:StopDiagnostics("automatic timeout")
        end
    end)

    self:Print("Capturing diagnostics for 90 seconds. Reproduce the pointer stopping, open/close menus, and trigger the actions that normally cause trouble.")
    self:Print("When capture finishes, use /reloadui, then upload Documents\\Elder Scrolls Online\\live\\SavedVariables\\ESOHybridUI.lua.")
end

function ADDON:InitializeDiagnostics()
    SLASH_COMMANDS["/huidebug"] = function()
        self:StartDiagnostics()
    end
end
