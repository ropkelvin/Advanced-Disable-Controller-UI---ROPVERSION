-- HUI: keyboard-presentation / native-controller-input foundation.
ESOHybridUI = ESOHybridUI or {}
local ADDON = ESOHybridUI

ADDON.name = "ESOHybridUI"
ADDON.version = "1.0.0"
ADDON.defaults = {
    mode = "hybrid",
    pointerEnabled = true,
    debug = false,
}

-- Preserve the runtime table across /reloadui so installed wrappers and
-- scene hooks keep referencing the same state object.
ADDON.runtime = ADDON.runtime or {}
local runtime = ADDON.runtime
runtime.initialized = runtime.initialized or false
runtime.inWorld = runtime.inWorld or false
runtime.modeOverrideConflict = runtime.modeOverrideConflict or false
runtime.lockPicking = runtime.lockPicking or false
runtime.pointerScene = runtime.pointerScene or false
runtime.pointerHookInstalled = runtime.pointerHookInstalled or false
runtime.directionalHookInstalled = runtime.directionalHookInstalled or false
runtime.promptHooksInstalled = runtime.promptHooksInstalled or false

-- Keep ESO's original query. HUI changes presentation only while the player
-- is active in the world, never during pregame, character select, or loading.
if not ADDON.NativeIsInGamepadPreferredMode then
    ADDON.NativeIsInGamepadPreferredMode = IsInGamepadPreferredMode
end

function ADDON:IsActive()
    return self.runtime.inWorld == true
end

function ADDON:IsNativeGamepadMode()
    return self.NativeIsInGamepadPreferredMode
        and self.NativeIsInGamepadPreferredMode() == true
end

-- "Gamepad Mode: On" is a distinct setting from Auto. In Auto,
-- IsInGamepadPreferredMode() can be true only because the last input was a
-- controller, which is not the fixed mode HUI requires.
function ADDON:IsGamepadModeOn()
    return tonumber(GetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_INPUT_PREFERRED_MODE))
        == INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD
end

function ADDON:IsHybrid()
    return self.saved and self.saved.mode == "hybrid"
end

function ADDON:Print(message)
    d("|c66CCFFHUI|r: " .. tostring(message))
end

function ADDON:Debug(message)
    if self.saved and self.saved.debug then
        self:Print(tostring(message))
    end
end

function ADDON:InitializeSavedVariables()
    self.saved = ZO_SavedVars:NewAccountWide(
        "ESOHybridUISavedVariables",
        1,
        nil,
        self.defaults
    )
end

local function OnPlayerActivated()
    ADDON.runtime.inWorld = true
    ADDON:InitializeLockpickHook()
    ADDON:ApplyMode()
    ADDON:TryRefreshHUDSettings()
    ADDON:InitializeSceneController()
    ADDON:InitializePrompts()
    ADDON:InitializeMainMenuNavigation()
    ADDON:InitializeSettings()

    if ADDON:IsHybrid() and not ADDON:IsGamepadModeOn()
        and not ADDON.runtime.gamepadSettingWarningShown then
        ADDON:Print("Hybrid requires ESO Gamepad Mode to be On in Controls settings.")
        ADDON.runtime.gamepadSettingWarningShown = true
    end
end

local function OnPlayerDeactivated()
    -- EVENT_PLAYER_DEACTIVATED is raised as the loading screen is shown.
    -- Only update internal state here; all presentation hooks become pass-through
    -- while inactive. Do not touch scenes, controls, or HUD during loading.
    ADDON.runtime.inWorld = false
    ADDON.runtime.lockPicking = false
    ADDON.runtime.restrictedSceneActive = false
    ADDON.runtime.restrictedScenes = {}
    ADDON.runtime.hudRefreshPending = true
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON.name then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED)
    ADDON:InitializeSavedVariables()
    ADDON:InitializeMode()
    ADDON:InitializeDiagnostics()

    EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_PLAYER_DEACTIVATED, OnPlayerDeactivated)

    -- /reloadui while already in the world may not require another transition.
    if IsPlayerActivated and IsPlayerActivated() then
        OnPlayerActivated()
    end

    ADDON.runtime.initialized = true
end

EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
