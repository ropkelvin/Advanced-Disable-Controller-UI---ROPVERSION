-- HUI core: shared state, saved variables, lifecycle, slash commands.
ESOHybridUI = ESOHybridUI or {}
local ADDON = ESOHybridUI

ADDON.name = "ESOHybridUI"
ADDON.version = "2.1.1"
ADDON.defaults = {
    mode = "hybrid",
    pointerEnabled = true,
    pointerSpeed = 3,
    controllerPrompts = true,
    debug = false,
}

ADDON.rt = {
    inWorld = false,
    gamepadOn = false,
    lockPick = false,
    restricted = false,
    menuScene = false,
    keyboardPresentation = false,
    hudRefreshPending = false,
}
local rt = ADDON.rt

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

    local installers = {
        "InitializeLockpick", "InitializePointer", "InitializeScenes",
        "InitializeKeybinds", "InitializeNavigation", "InitializePrompts",
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
        ADDON:Print("Hybrid requires ESO Gamepad Mode set to On (Settings > Controls).")
        rt.gamepadWarned = true
    end
end

local function OnPlayerDeactivated()
    rt.inWorld = false
    rt.lockPick = false
    rt.hudRefreshPending = true
    if ADDON.StopPointer then
        ADDON:StopPointer()
    end
    ADDON:ResetSceneState()
    ADDON:ApplyMode()
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
        self:Print("Left stick: move pointer | A/B: use native screen keybinds and actions.")
        self:Print("LB/RB: categories | LT/RT: detected tabs.")
        self:Print("HUI does not synthesize mouse clicks or invoke arbitrary control handlers.")
        self:Print("/hui hybrid | gamepad | status | tabs | pointer | /huidebug")
    else
        self:Print(string.format(
            "mode=%s inWorld=%s gamepadOn=%s keyboardUI=%s restricted=%s lockpick=%s scene=%s",
            tostring(self.saved.mode), tostring(rt.inWorld), tostring(rt.gamepadOn),
            tostring(rt.keyboardPresentation), tostring(rt.restricted), tostring(rt.lockPick),
            tostring(SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName())))
        self:Print("/hui help for controls.")
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)