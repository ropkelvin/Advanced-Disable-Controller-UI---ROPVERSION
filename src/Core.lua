-- Core: separates controller input preference from the UI's preferred platform.

local ADDON = ESOHybridUI

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
    -- Do not fall back to the defaults merely because one saved-variable
    -- profile failed to initialize. That would make settings appear to work
    -- for the session while every change was written only to the defaults
    -- table and lost at logout.
    if ADDON.savedVariables and ADDON.savedVariables.useAccountWideSettings
        and ADDON.savedVariablesAccountWide then
        return ADDON.savedVariablesAccountWide
    end
    if ADDON.savedVariables then
        return ADDON.savedVariables
    end
    if ADDON.savedVariablesAccountWide then
        return ADDON.savedVariablesAccountWide
    end
    return ADDON.defaults
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

function ADDON:ShouldUseGamepadResourceBars()
    local settings = GetSettings()
    return settings.useGamepadResourceBars == true
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

    -- Loot containers have a dedicated native gamepad scene, but ESO can
    -- request the keyboard scene while Hybrid mode keeps the gameplay HUD in
    -- keyboard presentation. Preserve the native controller loot workflow.
    if (settings.useHybridUI or settings.useGamepadButtons)
        and OriginalGamepadPreferredMode()
        and type(GetInteractionType) == "function"
        and INTERACTION_LOOT ~= nil
        and GetInteractionType() == INTERACTION_LOOT then
        return true
    end

    -- In Hybrid mode, ESO's own UI-mode state selects native gamepad menus,
    -- while the base gameplay HUD remains on the compact keyboard platform.
    if settings.useHybridUI then
        -- Keep the combat/world HUD on the compact keyboard platform, but let
        -- the world map opt into ESO's native gamepad map presentation even
        -- though opening the map does not necessarily enter UI mode.
        local worldMapShowing = WORLD_MAP_SCENE
            and WORLD_MAP_SCENE.IsShowing
            and WORLD_MAP_SCENE:IsShowing()
        if worldMapShowing then
            return OriginalGamepadPreferredMode()
        end

        return OriginalGamepadPreferredMode()
            and SCENE_MANAGER
            and SCENE_MANAGER.IsInUIMode
            and SCENE_MANAGER:IsInUIMode()
            or false
    end

    return settings.useGamepadLockpicking
        and ADDON.runtime.isLockpicking
        and OriginalGamepadPreferredMode()
        or false
end

local function InstallModeOverride()
    if type(IsInGamepadPreferredMode) ~= "function" then
        ADDON:LogWarn("IsInGamepadPreferredMode is unavailable; UI mode override was not installed.")
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
    local changed, changeError = pcall(SetSetting, SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_INPUT_PREFERRED_MODE, tostring(temporaryMode))
    local restored, restoreError = pcall(SetSetting, SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_INPUT_PREFERRED_MODE, tostring(currentMode))
    runtime.isRefreshing = false

    if not changed or not restored then
        ADDON:LogError("Could not refresh platform styles:", tostring(changeError or restoreError))
    end
end

function ADDON:Refresh()
    self:LogDebug("Refreshing UI presentation.")
    InstallModeOverride()

    if self.ApplyAll then
        self:ApplyAll()
    end

    RefreshPlatformMode()
end

function ADDON:ApplyAll()
    if self.ApplyPrompts then self:LogDebug("Applying prompt styles."); self:ApplyPrompts() end
    if self.ApplyDialogs then self:LogDebug("Applying dialog styles."); self:ApplyDialogs() end
    if self.ApplyUtilityWheel then self:LogDebug("Applying utility-wheel bridge."); self:ApplyUtilityWheel() end
    if self.ApplyActionBar then self:LogDebug("Applying action-bar style."); self:ApplyActionBar() end
    if self.ApplyResourceBars then self:LogDebug("Applying resource-bar style."); self:ApplyResourceBars() end
    if self.ApplyMainMenu then self:LogDebug("Applying main-menu navigation."); self:ApplyMainMenu() end
    if self.ApplyWorldMap then self:LogDebug("Applying world-map behavior."); self:ApplyWorldMap() end
end

function ADDON:SetUseAccountWideSettings(enabled)
    local character = self.savedVariables
    local account = self.savedVariablesAccountWide

    if enabled and not account._esoHybridInitialized then
        -- First-time account-wide setup: copy this character's clean ESOHybridUI
        -- profile into the new account-wide profile.
        local snapshot = DeepCopy(character)
        snapshot.useAccountWideSettings = true
        for key, value in pairs(snapshot) do
            account[key] = value
        end
        account._esoHybridInitialized = true
    end

    if not enabled and character.useAccountWideSettings then
        for key, value in pairs(account) do
            if key ~= "_esoHybridInitialized" then
                character[key] = DeepCopy(value)
            end
        end
    end

    character.useAccountWideSettings = enabled == true
    self:Refresh()
end

function ADDON:ToggleUI()
    local settings = GetSettings()
    if settings.useHybridUI then
        settings.useHybridUI = false
        settings.useControllerUI = false
    else
        settings.useControllerUI = not settings.useControllerUI
    end
    self:LogInfo("UI mode toggled. Native gamepad UI:", tostring(settings.useControllerUI))
    self:Refresh()
end

function ADDON:ToggleButtons()
    local settings = GetSettings()
    settings.useGamepadButtons = not settings.useGamepadButtons
    self:LogInfo("Gamepad button prompts:", tostring(settings.useGamepadButtons))
    self:Refresh()
end

function ADDON:ToggleActionBar()
    local settings = GetSettings()
    settings.useGamepadActionBar = not settings.useGamepadActionBar
    self:LogInfo("Gamepad action bar:", tostring(settings.useGamepadActionBar))
    self:Refresh()
end

function ADDON:ToggleResourceBars()
    local settings = GetSettings()
    settings.useGamepadResourceBars = not settings.useGamepadResourceBars
    self:LogInfo("Gamepad resource bars:", tostring(settings.useGamepadResourceBars))
    self:Refresh()
end


local function MergeMissing(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then
        return
    end
    for key, value in pairs(source) do
        if target[key] == nil then
            target[key] = DeepCopy(value)
        elseif type(target[key]) == "table" and type(value) == "table" then
            MergeMissing(target[key], value)
        end
    end
end

local function MigrateLegacySavedVariables()
    local legacy = _G.ADCUI_SavedVariables
    if type(legacy) ~= "table" then
        return
    end

    local current = _G.ESOHybridUI_SavedVariables
    if type(current) ~= "table" then
        _G.ESOHybridUI_SavedVariables = DeepCopy(legacy)
    else
        -- The game may already have created an empty ESOHybridUI table.
        -- Merge legacy data into missing keys instead of checking only whether
        -- the new top-level table exists. Never overwrite newer user choices.
        MergeMissing(current, legacy)
    end
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

local function PrintStatus()
    local settings = GetSettings()
    local uiMode = settings.useHybridUI and "hybrid UI" or (settings.useControllerUI and "native gamepad UI" or "keyboard-style UI")
    local barMode = settings.useGamepadActionBar and "gamepad action bar" or "compact keyboard action bar"
    local resourceMode = settings.useGamepadResourceBars and "gamepad resource bars" or "compact keyboard resource bars"
    local promptMode = settings.useGamepadButtons and "controller prompts enabled" or "keyboard prompts"
    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage("[ESO Hybrid UI] " .. uiMode .. " | " .. barMode .. " | " .. resourceMode .. " | " .. promptMode)
    end
end

local function RegisterSlashCommands()
    SLASH_COMMANDS["/esohybrid"] = function()
        ADDON:ToggleUI()
        PrintStatus()
    end
    SLASH_COMMANDS["/esohybrid_status"] = PrintStatus
    SLASH_COMMANDS["/esohybrid_buttons"] = function()
        ADDON:ToggleButtons()
        PrintStatus()
    end
    SLASH_COMMANDS["/esohybrid_actionbar"] = function()
        ADDON:ToggleActionBar()
        PrintStatus()
    end
    SLASH_COMMANDS["/esohybrid_resourcebars"] = function()
        ADDON:ToggleResourceBars()
        PrintStatus()
    end
    -- Backward-compatible aliases for existing chat macros.
    SLASH_COMMANDS["/adcui"] = SLASH_COMMANDS["/esohybrid"]
    SLASH_COMMANDS["/adcui_status"] = SLASH_COMMANDS["/esohybrid_status"]
    SLASH_COMMANDS["/adcui_buttons"] = SLASH_COMMANDS["/esohybrid_buttons"]
    SLASH_COMMANDS["/adcui_actionbar"] = SLASH_COMMANDS["/esohybrid_actionbar"]
    SLASH_COMMANDS["/adcui_resourcebars"] = SLASH_COMMANDS["/esohybrid_resourcebars"]
end

local function OnLockpickBegin()
    ADDON.runtime.isLockpicking = true
    ADDON:LogDebug("Lockpicking began.")
    ADDON:Refresh()
end

local function OnLockpickEnd()
    if not ADDON.runtime.isLockpicking then
        return
    end
    ADDON.runtime.isLockpicking = false
    ADDON:LogDebug("Lockpicking ended.")
    ADDON:Refresh()
end

local function OnGamepadPreferredModeChanged()
    ADDON:LogDebug("ESO gamepad-preferred-mode event received. Physical gamepad preference:", tostring(OriginalGamepadPreferredMode()))
    InstallModeOverride()
    if ADDON.ApplyAll then
        ADDON:ApplyAll()
    end
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON.ADDON_NAME or ADDON.runtime.initialized then
        return
    end

    -- Preserve settings from the previous ADCUI name, including when ESO
    -- has already created an empty table for the new saved-variable name.
    MigrateLegacySavedVariables()
    InitializeSavedVariables()
    if ADDON.InitializeDiagnostics then
        ADDON:InitializeDiagnostics()
        ADDON:RegisterDiagnosticCommands()
        ADDON:LogInfo("Initializing addon", ADDON.VERSION)
    end
    InstallModeOverride()

    EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_LockpickBegin", EVENT_BEGIN_LOCKPICK, OnLockpickBegin)
    EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_LockpickSuccess", EVENT_LOCKPICK_SUCCESS, OnLockpickEnd)
    EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_LockpickFailed", EVENT_LOCKPICK_FAILED, OnLockpickEnd)
    EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_ModeChanged", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, OnGamepadPreferredModeChanged)

    local function OnLockpickSceneStateChanged(_, newState)
        if newState == SCENE_HIDDEN then
            OnLockpickEnd()
        end
    end

    if LOCK_PICK_SCENE and LOCK_PICK_SCENE.RegisterCallback then
        LOCK_PICK_SCENE:RegisterCallback("StateChange", OnLockpickSceneStateChanged)
    end
    if LOCK_PICK_GAMEPAD_SCENE and LOCK_PICK_GAMEPAD_SCENE.RegisterCallback then
        LOCK_PICK_GAMEPAD_SCENE:RegisterCallback("StateChange", OnLockpickSceneStateChanged)
    end

    RegisterSlashCommands()

    if ADDON.RegisterSettings then
        ADDON:RegisterSettings()
    end

    ADDON.runtime.initialized = true
    ADDON:Refresh()

    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage("[ESO Hybrid UI] " .. ADDON.VERSION .. " loaded. Controller input remains enabled; use /esohybrid for the UI toggle. Debug: /esohybrid_debug on, snapshot: /esohybrid_dump.")
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON.ADDON_NAME, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(ESOHybridUI.ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
