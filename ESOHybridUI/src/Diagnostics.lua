-- /huidebug: 90 s capture to SavedVariables (then /reloadui). Costs nothing
-- when idle: Record() returns immediately unless a capture is running.
local ADDON = ESOHybridUI
local rt = ADDON.rt

local UPDATE_NAME = "ESOHybridUI_Diagnostics"
local SAMPLE_MS, DURATION_MS, MAX_ENTRIES = 500, 90000, 600

local function Append(kind, detail)
    local log = ADDON.saved.diagnostics.log
    log[#log + 1] = GetGameTimeMilliseconds() .. "|" .. kind .. "|" .. detail
    if #log > MAX_ENTRIES then
        table.remove(log, 1)
    end
end

function ADDON:Record(kind, ...)
    if not rt.diagActive then
        return
    end
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring((select(i, ...)))
    end
    Append(kind, table.concat(parts, " "))
end

local function NameOf(control)
    return control and control.GetName and control:GetName() or "nil"
end

local function Sample()
    local lib = LibMousePointer
    local cursor = lib and lib.gamepadCursor
    local sceneName = SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName()
    local primary = KEYBIND_STRIP and KEYBIND_STRIP.keybinds and KEYBIND_STRIP.keybinds.UI_SHORTCUT_PRIMARY
    return string.format(
        "mode=%s inWorld=%s gamepadOn=%s keyboardUI=%s restricted=%s lockpick=%s menuScene=%s scene=%s "
        .. "fragmentShowing=%s cursorId=%s x=%s y=%s hit=%s primaryHeld=%s "
        .. "updates=%s rawX=%s rawY=%s err=%s",
        tostring(ADDON.saved.mode), tostring(rt.inWorld), tostring(rt.gamepadOn),
        tostring(rt.keyboardPresentation), tostring(rt.restricted), tostring(rt.lockPick),
        tostring(rt.menuScene), tostring(sceneName),
        tostring(MOUSE_POINTER_FRAGMENT and MOUSE_POINTER_FRAGMENT:IsShowing()),
        tostring(cursor and cursor.cursorId), tostring(cursor and cursor.x), tostring(cursor and cursor.y),
        NameOf(cursor and cursor.mouseOverControl), tostring(primary ~= nil),
        tostring(rt.pointerUpdates), tostring(rt.rawStickX), tostring(rt.rawStickY),
        tostring(rt.lastError))
end

function ADDON:StopDiagnostics(reason)
    if not rt.diagActive then
        return
    end
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
    Append("END", reason or "manual")
    rt.diagActive = false
    self.saved.diagnostics.complete = true
    self:Print("Capture complete. /reloadui, then upload SavedVariables\\ESOHybridUISavedVariables.lua.")
end

function ADDON:StartDiagnostics()
    if rt.diagActive then
        self:Print("Capture already running.")
        return
    end
    self.saved.diagnostics = { version = 2, complete = false, log = {} }
    rt.diagActive = true
    Append("START", Sample())

    local startedAt = GetGameTimeMilliseconds()
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, SAMPLE_MS, function()
        Append("SAMPLE", Sample())
        if GetGameTimeMilliseconds() - startedAt >= DURATION_MS then
            ADDON:StopDiagnostics("timeout")
        end
    end)
    self:Print("Capturing 90 s. Reproduce the problem now.")
end

function ADDON:InitializeDiagnostics()
    SLASH_COMMANDS["/huidebug"] = function() ADDON:StartDiagnostics() end
end
