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

ADDON.runtime = {
    initialized = false,
    inWorld = false,
    lockPicking = false,
    pointerScene = false,
    pointerHookInstalled = false,
    directionalHookInstalled = false,
    promptHooksInstalled = false,
    originalPromptStyle = nil,
}

-- Keep ESO's original query. HUI changes presentation only while the player
-- is active in the world, never during pregame, character select, or loading.
ADDON.NativeIsInGamepadPreferredMode = IsInGamepadPreferredMode

function ADDON:IsActive()
    return self.runtime.inWorld == true
end

function ADDON:IsNativeGamepadMode()
    return self.NativeIsInGamepadPreferredMode
        and self.NativeIsInGamepadPreferredMode() == true
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
    ADDON:InitializeSceneController()
    ADDON:InitializePrompts()
    ADDON:InitializeSettings()

    if ADDON:IsHybrid() and not ADDON:IsNativeGamepadMode() then
        ADDON:Print("Hybrid requires ESO Gamepad Mode to be On in Controls settings.")
    end
end

local function OnPlayerDeactivated()
    ADDON.runtime.inWorld = false
    ADDON.runtime.lockPicking = false
    ADDON:ApplyMode()
    if ADDON.RestorePrompts then
        ADDON:RestorePrompts()
    end
    if ADDON.RefreshSceneController then
        ADDON:RefreshSceneController()
    end
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON.name then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED)
    ADDON:InitializeSavedVariables()
    ADDON:InitializeMode()

    EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_PLAYER_DEACTIVATED, OnPlayerDeactivated)

    -- /reloadui while already in the world may not require another transition.
    if IsPlayerActivated and IsPlayerActivated() then
        OnPlayerActivated()
    end

    ADDON.runtime.initialized = true
end

EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
