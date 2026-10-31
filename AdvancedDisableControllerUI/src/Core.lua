-- Advanced Disable Controller UI
-- Core input/UI separation. This intentionally avoids the legacy action-bar
-- and platform-template monkey-patches until each can be verified on live UI.

local ADDON = ADCUI

local function GetSettings()
    if not ADDON.savedVariables or not ADDON.savedVariablesAccountWide then
        return ADDON.defaults
    end

    if ADDON.savedVariables.useAccountWideSettings then
        return ADDON.savedVariablesAccountWide
    end

    return ADDON.savedVariables
end

function ADDON:GetSettings()
    return GetSettings()
end

local function OriginalGamepadPreferredMode()
    local original = ADDON.runtime.originalIsInGamepadPreferredMode
    if type(original) == "function" then
        return original()
    end
    return false
end

local function IsGamepadUIAllowed()
    local settings = GetSettings()

    if settings.useControllerUI then
        return OriginalGamepadPreferredMode()
    end

    -- Keep the native gamepad lockpicking interface when requested by the
    -- original behavior. Physical controller input remains available either way.
    return ADDON.runtime.isLockpicking and OriginalGamepadPreferredMode() or false
end

local function InstallModeOverride()
    if type(IsInGamepadPreferredMode) ~= "function" then
        if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then CHAT_SYSTEM:AddMessage("[ADCUI] IsInGamepadPreferredMode is unavailable; UI override not installed.") end
        return false
    end

    if not ADDON.runtime.originalIsInGamepadPreferredMode then
        ADDON.runtime.originalIsInGamepadPreferredMode = IsInGamepadPreferredMode
    end

    _G.IsInGamepadPreferredMode = IsGamepadUIAllowed
    return true
end

local function RefreshPlatformMode()
    if ADDON.runtime.isRefreshing then
        return
    end

    if type(SetSetting) ~= "function"
        or type(GetSetting) ~= "function"
        or type(SETTING_TYPE_GAMEPAD) ~= "number"
        or type(GAMEPAD_SETTING_INPUT_PREFERRED_MODE) ~= "number"
        or type(INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD) ~= "number"
        or type(INPUT_PREFERRED_MODE_ALWAYS_KEYBOARD) ~= "number" then
        return
    end

    local currentMode = GetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_INPUT_PREFERRED_MODE)
    if currentMode == nil then
        return
    end

    -- GAMEPAD_SETTING_GAMEPAD_PREFERRED was removed in favor of the
    -- three-state INPUT_PREFERRED_MODE setting. Temporarily flip to the
    -- opposite fixed mode, then restore the exact user's original value
    -- (including AUTOMATIC). Never leave the user's preference changed.
    local temporaryMode
    if tostring(currentMode) == tostring(INPUT_PREFERRED_MODE_ALWAYS_KEYBOARD) then
        temporaryMode = INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD
    else
        temporaryMode = INPUT_PREFERRED_MODE_ALWAYS_KEYBOARD
    end

    ADDON.runtime.isRefreshing = true
    SetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_INPUT_PREFERRED_MODE, temporaryMode)
    SetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_INPUT_PREFERRED_MODE, currentMode)
    ADDON.runtime.isRefreshing = false
end

function ADDON:Refresh()
    if InstallModeOverride() then
        RefreshPlatformMode()
    end
end

local function OnLockpickBegin()
    ADDON.runtime.isLockpicking = true
    ADDON:Refresh()
end

local function OnLockpickEnd()
    ADDON.runtime.isLockpicking = false
    ADDON:Refresh()
end

local function InitializeSavedVariables()
    ADDON.savedVariablesAccountWide = ZO_SavedVars:NewAccountWide(
        ADDON.SAVED_VARIABLES,
        ADDON.SAVED_VARIABLES_VERSION,
        nil,
        ADDON.defaults
    )

    ADDON.savedVariables = ZO_SavedVars:NewCharacterIdSettings(
        ADDON.SAVED_VARIABLES,
        ADDON.SAVED_VARIABLES_VERSION,
        nil,
        ADDON.defaults
    )
end

local function RegisterSlashCommand()
    SLASH_COMMANDS["/adcui"] = function()
        local settings = GetSettings()
        settings.useControllerUI = not settings.useControllerUI
        ADDON:Refresh()

        local mode = settings.useControllerUI and "native gamepad UI" or "keyboard-style UI"
        if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then CHAT_SYSTEM:AddMessage("[ADCUI] " .. mode .. " selected. Controller input is not disabled.") end
    end

    SLASH_COMMANDS["/adcui_status"] = function()
        local settings = GetSettings()
        local mode = settings.useControllerUI and "native gamepad UI" or "keyboard-style UI"
        if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then CHAT_SYSTEM:AddMessage("[ADCUI] " .. mode .. "; lockpicking override: " ..
            (ADDON.runtime.isLockpicking and "active" or "inactive")) end
    end
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON.ADDON_NAME or ADDON.runtime.initialized then
        return
    end

    InitializeSavedVariables()
    InstallModeOverride()

    EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_LockpickBegin", EVENT_BEGIN_LOCKPICK, OnLockpickBegin)
    EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_LockpickSuccess", EVENT_LOCKPICK_SUCCESS, OnLockpickEnd)
    EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_LockpickFailed", EVENT_LOCKPICK_FAILED, OnLockpickEnd)
    EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_LockpickBroke", EVENT_LOCKPICK_BROKE, OnLockpickEnd)

    RegisterSlashCommand()

    if ADDON.RegisterSettings then
        ADDON:RegisterSettings()
    end

    ADDON.runtime.initialized = true
    ADDON:Refresh()

    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then CHAT_SYSTEM:AddMessage("[ADCUI] Loaded. Use /adcui to switch UI presentation.") end
    EVENT_MANAGER:UnregisterForEvent(ADDON.ADDON_NAME, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(ADCUI.ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
