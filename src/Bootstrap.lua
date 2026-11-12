-- HUI: clean keyboard-presentation / native-controller-input foundation.
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
    lockPicking = false,
    pointerScene = false,
    pointerHookInstalled = false,
    directionalHookInstalled = false,
    promptHooksInstalled = false,
    originalPromptStyle = nil,
}

-- Capture ESO's actual setting before HUI changes the presentation query.
ADDON.NativeIsInGamepadPreferredMode = IsInGamepadPreferredMode

function ADDON:IsNativeGamepadMode()
    return self.NativeIsInGamepadPreferredMode and self.NativeIsInGamepadPreferredMode() == true
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

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON.name then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED)
    ADDON:InitializeSavedVariables()
    ADDON:InitializeMode()
    ADDON:InitializeSceneController()
    ADDON:InitializePrompts()
    ADDON:InitializeSettings()
    ADDON.runtime.initialized = true

    ADDON:Print("Loaded. Current mode: " .. ADDON.saved.mode)
    if ADDON:IsHybrid() and not ADDON:IsNativeGamepadMode() then
        ADDON:Print("Hybrid requires ESO Gamepad Mode to be On in the game's Controls settings.")
    elseif ADDON:IsHybrid() and not MOUSE_POINTER_FRAGMENT then
        ADDON:Print("LibMousePointer is missing. Keyboard UI will load, but controller pointer support is unavailable.")
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
