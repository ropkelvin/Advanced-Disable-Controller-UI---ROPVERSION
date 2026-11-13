-- /huidebug: 90 s capture to SavedVariables. Idle overhead is negligible.
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

local function Sample()
    local sceneName = SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName()
    local primary = KEYBIND_STRIP and KEYBIND_STRIP.keybinds
        and KEYBIND_STRIP.keybinds.UI_SHORTCUT_PRIMARY
    local leftStickAvailable = DIRECTIONAL_INPUT
        and DIRECTIONAL_INPUT:IsAvailable(ZO_DI_LEFT_STICK)
    local rightStickAvailable = DIRECTIONAL_INPUT
        and DIRECTIONAL_INPUT:IsAvailable(ZO_DI_RIGHT_STICK)

    return string.format(
        "mode=%s inWorld=%s gamepadOn=%s keyboardUI=%s modeConflict=%s restricted=%s lockpick=%s menuScene=%s scene=%s "
        .. "primaryHeld=%s leftStickAvailable=%s rightStickAvailable=%s tabBar=%s",
        tostring(ADDON.saved.mode), tostring(rt.inWorld), tostring(rt.gamepadOn),
        tostring(rt.keyboardPresentation), tostring(rt.modeOverrideConflict),
        tostring(rt.restricted), tostring(rt.lockPick), tostring(rt.menuScene),
        tostring(sceneName), tostring(primary ~= nil),
        tostring(leftStickAvailable), tostring(rightStickAvailable),
        tostring(rt.lastTabBar or "not-probed"))
end

function ADDON:StopDiagnostics(reason)
    if not rt.diagActive then
        return
    end
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
    Append("END", reason or "manual")
    rt.diagActive = false
    self.saved.diagnostics.complete = true
    self:Print("Capture complete. /reloadui, then upload SavedVariables\\ESOHybridUI.lua.")
end

function ADDON:StartDiagnostics()
    if rt.diagActive then
        self:Print("Capture already running.")
        return
    end
    self.saved.diagnostics = { version = 4, complete = false, log = {} }
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
