-- Core: separates controller input preference from the UI's preferred platform.

local ADDON = ADCUI

local function DeepCopy(source)
    if type(source) ~= "table" then
        return source
    end
    local target = {}
    for key, value in pairs(source) do
        target[key] = DeepCopy(value)
    end
    return target
end

local function OriginalGamepadPreferredMode()
    local original = ADDON.runtime.originalIsInGamepadPreferredMode
    if type(original) == "function" then
        return original()
    end
    return false
end

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

function ADDON:IsNativeGamepadMode()
    return OriginalGamepadPreferredMode()
end

function ADDON:ShouldUseGamepadActionBar()
    local settings = GetSettings()
    return settings.useGamepadActionBar == true
        and settings.useControllerUI ~= true
        and OriginalGamepadPreferredMode()
end

function ADDON:WithNativeGamepadMode(callback, ...)
    local runtime = ADDON.runtime
    runtime.forceNativeModeDepth = runtime.forceNativeModeDepth + 1

    local function Pack(...) return { n = select("#", ...), ... } end
    local results = Pack(pcall(callback, ...))
    runtime.forceNativeModeDepth = math.max(0, runtime.forceNativeModeDepth - 1)

    if not results[1] then
        error(results[2], 0)
    end
    return unpack(results, 2, results.n)
end

local function IsGamepadUIAllowed()
    if ADDON.runtime.forceNativeModeDepth > 0 then
        return OriginalGamepadPreferredMode()
    end

    local settings = GetSettings()
    if settings.useControllerUI then
        return OriginalGamepadPreferredMode()
    end

    return settings.useGamepadLockpicking
        and ADDON.runtime.isLockpicking
        and OriginalGamepadPreferredMode()
        or false
end

local function InstallModeOverride()
    if type(IsInGamepadPreferredMode) ~= "function" then
        if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
            CHAT_SYSTEM:AddMessage("[ADCUI] IsInGamepadPreferredMode is unavailable; UI mode override was not installed.")
        end
        return false
    end

    if not ADDON.runtime.originalIsInGamepadPreferredMode then
        ADDON.runtime.originalIsInGamepadPreferredMode = IsInGamepadPreferredMode
    end

    _G.IsInGamepadPreferredMode = IsGamepadUIAllowed
    return true
end

local function RefreshPlatformMode()
    local runtime = ADDON.runtime
    if runtime.isRefreshing then
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

    local currentNumeric = tonumber(currentMode)
    local keyboardMode = INPUT_PREFERRED_MODE_ALWAYS_KEYBOARD
    local temporaryMode = currentNumeric == keyboardMode
        and INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD
        or keyboardMode

    runtime.isRefreshing = true
    local ok, err = pcall(function()
        SetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_INPUT_PREFERRED_MODE, tostring(temporaryMode))
        SetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_INPUT_PREFERRED_MODE, tostring(currentMode))
    end)
    runtime.isRefreshing = false

    if not ok and CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage("[ADCUI] Could not refresh platform styles: " .. tostring(err))
    end
end

function ADDON:Refresh()
    InstallModeOverride()

    if self.ApplyAll then
        self:ApplyAll()
    end

    RefreshPlatformMode()
end

function ADDON:ApplyAll()
    if self.ApplyPrompts then self:ApplyPrompts() end
    if self.ApplyDialogs then self:ApplyDialogs() end
    if self.ApplyUtilityWheel then self:ApplyUtilityWheel() end
    if self.ApplyActionBar then self:ApplyActionBar() end
    if self.ApplyCompass then self:ApplyCompass() end
    if self.ApplyMainMenu then self:ApplyMainMenu() end
    if self.ApplyWorldMap then self:ApplyWorldMap() end
end

function ADDON:SetUseAccountWideSettings(enabled)
    local character = self.savedVariables
    local account = self.savedVariablesAccountWide

    if enabled and not account._adcuiInitialized then
        local snapshot = DeepCopy(character)
        snapshot.useAccountWideSettings = true
        snapshot._adcuiInitialized = true
        for key, value in pairs(snapshot) do
            account[key] = value
        end
    end

    if not enabled and character.useAccountWideSettings then
        for key, value in pairs(account) do
            if key ~= "_adcuiInitialized" then
                character[key] = DeepCopy(value)
            end
        end
    end

    character.useAccountWideSettings = enabled == true
    if enabled then
        account._adcuiInitialized = true
    end
    self:Refresh()
end

function ADDON:ToggleUI()
    local settings = GetSettings()
    settings.useControllerUI = not settings.useControllerUI
    self:Refresh()
end

function ADDON:ToggleButtons()
    local settings = GetSettings()
    settings.useGamepadButtons = not settings.useGamepadButtons
    self:Refresh()
end

function ADDON:ToggleActionBar()
    local settings = GetSettings()
    settings.useGamepadActionBar = not settings.useGamepadActionBar
    self:Refresh()
end

function ADDON:ToggleCompassLock()
    local settings = GetSettings()
    settings.lockEnabled = not settings.lockEnabled
    self:ApplyCompass()
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

    -- The legacy default forced the oversized gamepad action bar on. The
    -- modern default is compact, matching the addon's primary purpose.
    if not ADDON.savedVariables._adcuiV2Migrated then
        ADDON.savedVariables.useGamepadActionBar = false
        ADDON.savedVariables._adcuiV2Migrated = true
    end
    if ADDON.savedVariables.useAccountWideSettings
        and not ADDON.savedVariablesAccountWide._adcuiV2Migrated then
        ADDON.savedVariablesAccountWide.useGamepadActionBar = false
        ADDON.savedVariablesAccountWide._adcuiV2Migrated = true
    end
end

local function PrintStatus()
    local settings = GetSettings()
    local uiMode = settings.useControllerUI and "native gamepad UI" or "keyboard-style UI"
    local barMode = settings.useGamepadActionBar and "gamepad action bar" or "compact keyboard action bar"
    local promptMode = settings.useGamepadButtons and "controller prompts enabled" or "keyboard prompts"
    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage("[ADCUI] " .. uiMode .. " | " .. barMode .. " | " .. promptMode)
    end
end

local function RegisterSlashCommands()
    SLASH_COMMANDS["/adcui"] = function()
        ADDON:ToggleUI()
        PrintStatus()
    end
    SLASH_COMMANDS["/adcui_status"] = PrintStatus
    SLASH_COMMANDS["/adcui_buttons"] = function()
        ADDON:ToggleButtons()
        PrintStatus()
    end
    SLASH_COMMANDS["/adcui_actionbar"] = function()
        ADDON:ToggleActionBar()
        PrintStatus()
    end
    SLASH_COMMANDS["/adcui_compasslock"] = function()
        ADDON:ToggleCompassLock()
        PrintStatus()
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

local function OnGamepadPreferredModeChanged()
    InstallModeOverride()
    if ADDON.ApplyAll then
        ADDON:ApplyAll()
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
    EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_ModeChanged", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, OnGamepadPreferredModeChanged)

    if LOCK_PICK_SCENE and LOCK_PICK_SCENE.RegisterCallback then
        LOCK_PICK_SCENE:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_HIDDEN then
                OnLockpickEnd()
            end
        end)
    end

    RegisterSlashCommands()

    if ADDON.RegisterSettings then
        ADDON:RegisterSettings()
    end

    ADDON.runtime.initialized = true
    ADDON:Refresh()

    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage("[ADCUI] " .. ADDON.VERSION .. " loaded. Controller input remains enabled; use /adcui for the UI toggle.")
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON.ADDON_NAME, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(ADCUI.ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
