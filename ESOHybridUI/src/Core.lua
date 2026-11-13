-- HUI core: shared state, saved variables, lifecycle, slash commands.
ESOHybridUI = ESOHybridUI or {}
local ADDON = ESOHybridUI

ADDON.name = "ESOHybridUI"
ADDON.version = "2.0.1"
ADDON.defaults = {
    mode = "hybrid",
    pointerEnabled = true,
    pointerSpeed = 3,
    controllerPrompts = true,
    debug = false,
}

-- Runtime state. Everything the hot paths need is a plain boolean here, so
-- the IsInGamepadPreferredMode wrapper never does string work or API calls.
-- (/reloadui rebuilds the Lua state, so nothing here needs to survive it.)
ADDON.rt = {
    inWorld = false,
    gamepadOn = false,            -- ESO "Gamepad Mode: On" (not Auto)
    lockPick = false,
    restricted = false,           -- a restricted screen is showing/pending
    menuScene = false,            -- current scene is a keyboard-style menu
    keyboardPresentation = false, -- the single flag every module reads
    hudRefreshPending = false,
}
local rt = ADDON.rt

-- ESO's original query, captured once at load.
ADDON.NativeIsInGamepadPreferredMode = IsInGamepadPreferredMode

function ADDON:IsHybrid()
    return self.saved ~= nil and self.saved.mode == "hybrid"
end

function ADDON:Print(message)
    d("|c66CCFFHUI|r: " .. tostring(message))
end

function ADDON:Debug(message)
    if self.saved and self.saved.debug then
        self:Print(message)
    end
end

local function OnPlayerActivated()
    rt.inWorld = true

    -- Installers are idempotent. Each runs isolated so one failure can never
    -- stop the others, and is reported instead of failing silently.
    local installers = {
        "InitializeLockpick", "InitializeScenes", "InitializeKeybinds",
        "InitializePointer", "InitializeNavigation", "InitializePrompts",
        "InitializeSettings",
    }
    for _, name in ipairs(installers) do
        local ok, err = pcall(ADDON[name], ADDON)
        if not ok then
            ADDON:Print(name .. " failed: " .. tostring(err))
        end
    end
    ADDON:ApplyMode()

    if ADDON:IsHybrid() and not rt.gamepadOn and not rt.gamepadWarned then
        ADDON:Print("Hybrid needs ESO Gamepad Mode set to On (Settings > Controls).")
        rt.gamepadWarned = true
    end
end

local function OnPlayerDeactivated()
    -- Raised as the loading screen appears. Only touch our own state; do not
    -- touch scenes, controls, HUD or the keybind strip during loading.
    rt.inWorld = false
    rt.lockPick = false
    rt.hudRefreshPending = true
    ADDON:ResetSceneState()
    ADDON:Recompute()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED)

    ADDON.saved = ZO_SavedVars:NewAccountWide("ESOHybridUISavedVariables", 1, nil, ADDON.defaults)
    if ADDON.saved.mode ~= "gamepad" then
        ADDON.saved.mode = "hybrid"
    end

    ADDON:InitializeMode()
    ADDON:InitializeDiagnostics()

    EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_PLAYER_DEACTIVATED, OnPlayerDeactivated)

    SLASH_COMMANDS["/hui"] = function(argument)
        ADDON:HandleSlash(string.lower(argument or ""))
    end

    -- Loaded while already in the world (rare, but cheap to support).
    if IsPlayerActivated and IsPlayerActivated() then
        OnPlayerActivated()
    end
end

function ADDON:HandleSlash(arg)
    if arg == "hybrid" or arg == "gamepad" then
        self:SetMode(arg)
    elseif arg == "tabs" then
        self:PrintTabProbe()
    elseif arg == "pointer" then
        self:PrintPointerProbe()
    elseif arg == "help" then
        self:Print("Left stick: move pointer | A / L3: click | R3: right-click")
        self:Print("Right stick: scroll | LB/RB: main menu category | LT/RT: screen tabs")
        self:Print("/hui hybrid | gamepad | status | tabs | pointer | /huidebug")
    else
        local rtState = self.rt
        self:Print(string.format(
            "mode=%s inWorld=%s gamepadOn=%s keyboardUI=%s restricted=%s lockpick=%s scene=%s",
            tostring(self.saved.mode), tostring(rtState.inWorld), tostring(rtState.gamepadOn),
            tostring(rtState.keyboardPresentation), tostring(rtState.restricted),
            tostring(rtState.lockPick), tostring(SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName())))
        self:Print("/hui help for controls.")
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
