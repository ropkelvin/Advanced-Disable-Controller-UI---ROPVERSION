-- Core: saved variables and settings scope, install helpers, platform refresh,
-- events, slash commands and initialization order.

local ADDON = ESOHybridUI
local rt = ADDON.runtime

-- ---------------------------------------------------------------------------
-- Saved variables
-- ---------------------------------------------------------------------------

-- Copy every key named in `defaults` from `source` to `target`, reading each
-- value through `source` so it works whether or not ZO_SavedVars keeps default
-- values physically in the table. Nested tables are filled leaf by leaf into a
-- table the target owns, so a shared defaults table is never written to.
local function CopyLeaves(defaults, source, target)
    if type(defaults) ~= "table" or type(source) ~= "table" or type(target) ~= "table" then
        return false
    end
    for key, default in pairs(defaults) do
        if type(default) == "table" then
            local owned = rawget(target, key)
            if type(owned) ~= "table" then
                owned = {}
                target[key] = owned
            end
            CopyLeaves(default, source[key], owned)
        else
            local value = source[key]
            if value ~= nil then
                target[key] = value
            end
        end
    end
    return true
end

local function GetSettings()
    -- Never fall back to the defaults just because one profile failed to
    -- initialize: changes would then be written to the defaults table and lost.
    local account = ADDON.savedVariablesAccountWide
    if account and account._esoHybridUseAccountWideSettings == true then
        return account
    end
    return ADDON.savedVariables or account or ADDON.defaults
end

function ADDON:GetSettings()
    return GetSettings()
end

function ADDON:GetFont(key)
    local fonts = GetSettings().fonts
    local value = type(fonts) == "table" and fonts[key] or nil
    return value or ADDON.defaults.fonts[key]
end

function ADDON:SetFont(key, value)
    local settings = GetSettings()
    local fonts = rawget(settings, "fonts")
    if type(fonts) ~= "table" then
        -- Own the table before writing so nothing shared is modified.
        fonts = {}
        for fontKey in pairs(ADDON.defaults.fonts) do
            fonts[fontKey] = self:GetFont(fontKey)
        end
        settings.fonts = fonts
    end
    fonts[key] = value
end

-- v3 stored the mode as two booleans. Convert once and remove the old keys so a
-- stale "useHybridUI = true" can never override a later choice.
local function MigrateLegacyMode(profile)
    if type(profile) ~= "table" then
        return
    end
    if profile.useHybridUI == true then
        profile.mode = ADDON.MODE_HYBRID
    end
    profile.useHybridUI = nil
    profile.useControllerUI = nil
    profile.useGamepadButtons = nil
end

local function InitializeSavedVariables()
    -- Character ids already contain a server prefix; account-wide profiles do not,
    -- so namespace them by megaserver (EU / NA / PTS stay separate).
    local legacyAccountProfile = ZO_SavedVars:NewAccountWide(
        ADDON.SAVED_VARIABLES, ADDON.SAVED_VARIABLES_VERSION, nil, ADDON.defaults)

    ADDON.savedVariablesAccountWide = ZO_SavedVars:NewAccountWide(
        ADDON.SAVED_VARIABLES, ADDON.SAVED_VARIABLES_VERSION, GetWorldName(), ADDON.defaults)

    ADDON.savedVariables = ZO_SavedVars:NewCharacterIdSettings(
        ADDON.SAVED_VARIABLES, ADDON.SAVED_VARIABLES_VERSION, nil, ADDON.defaults)

    local account = ADDON.savedVariablesAccountWide
    if not account._esoHybridServerProfileMigrated then
        -- One-time, non-destructive copy of the old un-namespaced account profile.
        CopyLeaves(ADDON.defaults, legacyAccountProfile, account)
        if legacyAccountProfile.useHybridUI == true then
            account.mode = ADDON.MODE_HYBRID
        end
        account._esoHybridUseAccountWideSettings = legacyAccountProfile._esoHybridUseAccountWideSettings
        account._esoHybridWelcomeShown = legacyAccountProfile._esoHybridWelcomeShown
        account._esoHybridServerProfileMigrated = true
    end

    MigrateLegacyMode(account)
    MigrateLegacyMode(ADDON.savedVariables)

    if type(_G[ADDON.SAVED_VARIABLES]) ~= "table" then
        ADDON:LogError("ESO did not create the declared SavedVariables root table.")
    end
end

function ADDON:SetUseAccountWideSettings(enabled)
    local character = self.savedVariables
    local account = self.savedVariablesAccountWide
    if not character or not account then
        self:LogError("Cannot change settings scope: SavedVariables profiles are not initialized.")
        return
    end

    if enabled and account._esoHybridUseAccountWideSettings == nil then
        -- Seed the shared profile only on its first-ever activation; later toggles
        -- keep it instead of overwriting it with this character's settings.
        CopyLeaves(ADDON.defaults, character, account)
    end
    if not enabled then
        CopyLeaves(ADDON.defaults, account, character)
    end

    -- The selector is account-wide: once on, every character uses the shared profile.
    account._esoHybridUseAccountWideSettings = enabled == true
    self:Refresh()
end

-- ---------------------------------------------------------------------------
-- ESO settings the addon recommends (only ever applied by an explicit button press)
-- ---------------------------------------------------------------------------

function ADDON:ApplyRecommendedESOSettings()
    local saveOption = SETTING_SET_OPTION_SAVE_TO_PERSISTED_DATA

    SetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_INPUT_PREFERRED_MODE,
        tostring(INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD), saveOption)
    SetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_KEYBIND_DISPLAY_MODE,
        tostring(KEYBIND_DISPLAY_MODE_ALWAYS_GAMEPAD), saveOption)
    SetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_USE_KEYBOARD_CHAT, "1", saveOption)
    SetSetting(SETTING_TYPE_UI, UI_SETTING_RETURN_CURSOR_ON_CHAT_FOCUS, "1", saveOption)

    self:Say("Recommended ESO settings applied and saved: Gamepad Mode, gamepad keybind display, keyboard chat and cursor-on-chat-focus are on.")
end

-- ---------------------------------------------------------------------------
-- Install helper: run an installer now; if ESO objects it needs do not exist yet,
-- retry on the next few player activations (bounded) instead of failing silently.
-- ---------------------------------------------------------------------------

local MAX_INSTALL_ATTEMPTS = 3

function ADDON:InstallWhenReady(name, installer)
    if rt.installed[name] then
        return true
    end

    rt.attempts[name] = (rt.attempts[name] or 0) + 1
    local ok, result = pcall(installer)
    if ok and result ~= false then
        rt.installed[name] = true
        self:LogDebug("Installed:", name)
        return true
    end
    if not ok then
        self:LogWarn("Install failed for", name, "-", tostring(result))
    end

    if rt.attempts[name] < MAX_INSTALL_ATTEMPTS and not rt.retryRegistered[name] then
        rt.retryRegistered[name] = true
        local eventName = ADDON.ADDON_NAME .. "_Retry_" .. name
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_PLAYER_ACTIVATED, function()
            EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_PLAYER_ACTIVATED)
            rt.retryRegistered[name] = false
            ADDON:InstallWhenReady(name, installer)
        end)
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Platform refresh
--
-- HUD elements restyle themselves only on EVENT_GAMEPAD_PREFERRED_MODE_CHANGED.
-- Hybrid's answer changes without that event, so after any overlay scene we nudge
-- ESO by flipping the preferred-mode setting and restoring it immediately.
-- Rules learned from ESO's source:
--   * never from a menu scene (it can close the menu);
--   * never while a wheel is open (ZO_InteractiveWheel_Manager cancels the open
--     wheel on that event).
-- ---------------------------------------------------------------------------

local function IsShowingBaseHUDScene()
    local sceneManager = SCENE_MANAGER
    return sceneManager ~= nil and sceneManager.IsShowingBaseScene ~= nil
        and sceneManager:IsShowingBaseScene() == true
end

local function WheelBusy()
    local manager = INTERACTIVE_WHEEL_MANAGER
    if manager and manager.IsInteracting and manager:IsInteracting() then
        return true
    end
    return false
end

local SchedulePlatformRefresh

local function TryPlatformRefresh()
    if rt.isRefreshing then
        return false
    end
    if not IsShowingBaseHUDScene() then
        rt.platformDirty = true
        return false
    end
    if WheelBusy() then
        rt.platformDirty = true
        SchedulePlatformRefresh(300)
        return false
    end

    local currentMode = GetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_INPUT_PREFERRED_MODE)
    local currentNumeric = tonumber(currentMode)
    local temporaryMode = currentNumeric == INPUT_PREFERRED_MODE_ALWAYS_KEYBOARD
        and INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD or INPUT_PREFERRED_MODE_ALWAYS_KEYBOARD

    rt.isRefreshing = true
    local changed, changeError = pcall(SetSetting, SETTING_TYPE_GAMEPAD,
        GAMEPAD_SETTING_INPUT_PREFERRED_MODE, tostring(temporaryMode))
    -- Always restore, even if the first call failed.
    local restored, restoreError = pcall(SetSetting, SETTING_TYPE_GAMEPAD,
        GAMEPAD_SETTING_INPUT_PREFERRED_MODE, tostring(currentMode))
    rt.isRefreshing = false

    if not changed or not restored then
        rt.platformDirty = true
        ADDON:LogError("Could not refresh platform styles:", tostring(changeError or restoreError))
        return false
    end

    rt.platformDirty = false
    ADDON:LogDebug("Platform styles refreshed.")
    return true
end

SchedulePlatformRefresh = function(delay)
    if rt.platformRefreshScheduled then
        return
    end
    rt.platformRefreshScheduled = true
    zo_callLater(function()
        rt.platformRefreshScheduled = false
        if rt.initialized and rt.platformDirty and IsShowingBaseHUDScene() then
            TryPlatformRefresh()
        end
    end, delay or 100)
end

-- ---------------------------------------------------------------------------
-- Refresh / apply
-- ---------------------------------------------------------------------------

local APPLY_STEPS = { "ApplyPrompts", "ApplyDialogs", "ApplyUtilityWheel", "ApplyActionBar", "ApplyWorldMap" }
local reportedStepErrors = {}

function ADDON:ApplyAll()
    for _, stepName in ipairs(APPLY_STEPS) do
        local step = self[stepName]
        if step then
            -- One failing module must not stop the others from applying.
            local ok, err = pcall(step, self)
            if not ok and not reportedStepErrors[stepName] then
                reportedStepErrors[stepName] = true
                self:LogError(stepName .. " failed:", tostring(err))
            end
        end
    end
end

function ADDON:Refresh()
    self:LogDebug("Refreshing UI presentation.")
    self:InstallModeOverride()
    self:RefreshSettingsCache()
    self:ApplyAll()
    rt.platformDirty = true
    TryPlatformRefresh()
end

function ADDON:SetMode(mode)
    local settings = GetSettings()
    settings.mode = mode == ADDON.MODE_HYBRID and ADDON.MODE_HYBRID or ADDON.MODE_GAMEPAD
    self:LogInfo("UI mode:", settings.mode)
    self:Refresh()
end

function ADDON:ToggleUI()
    self:SetMode(self:IsHybrid() and ADDON.MODE_GAMEPAD or ADDON.MODE_HYBRID)
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

local function OnLockpickBegin()
    rt.isLockpicking = true
    ADDON:LogDebug("Lockpicking began.")
    ADDON:Refresh()
end

local function OnLockpickEnd()
    if not rt.isLockpicking then
        return
    end
    rt.isLockpicking = false
    ADDON:LogDebug("Lockpicking ended.")
    ADDON:Refresh()
end

local function OnLockpickSceneStateChanged(_, newState)
    if newState == SCENE_HIDDEN then
        OnLockpickEnd()
    end
end

local function OnGamepadPreferredModeChanged()
    -- Our own refresh flips the setting twice; those events are not real changes.
    if rt.isRefreshing then
        return
    end
    ADDON:LogDebug("Preferred-mode event. Native gamepad preference:", tostring(ADDON:IsNativeGamepadMode()))
    ADDON:InstallModeOverride()
    ADDON:ApplyAll()
end

local function OnSceneStateChanged(_, _, newState)
    if newState ~= SCENE_SHOWN and newState ~= SCENE_HIDDEN then
        return
    end
    -- In Hybrid, any overlay/menu scene may have given shared HUD pieces gamepad
    -- styling, so remember that a refresh is owed once the base HUD is back.
    if rt.hybrid and newState == SCENE_SHOWN and not IsShowingBaseHUDScene() then
        rt.platformDirty = true
    end
    if rt.platformDirty then
        SchedulePlatformRefresh(100)
    end
end

-- ---------------------------------------------------------------------------
-- First activation: optional announcement and one-time welcome dialog
-- ---------------------------------------------------------------------------

local function ShowWelcomeDialog()
    local account = ADDON.savedVariablesAccountWide
    if not account or account._esoHybridWelcomeShown then
        return
    end

    local dialogName = "ESOHYBRIDUI_FIRST_INSTALL"
    local ok, err = pcall(function()
        ZO_Dialogs_RegisterCustomDialog(dialogName, {
            canQueue = true,
            gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
            title = { text = "Welcome to ESO Hybrid UI" },
            mainText = {
                text = "Open ESO Hybrid UI settings and click Apply Recommended ESO Settings once. This turns on Gamepad Mode, gamepad keybind display, keyboard chat and the mouse cursor when chat receives focus. Then choose Gamepad or Hybrid. You can apply the settings again later if needed.",
            },
            buttons = { { text = "Got it" } },
        })
        ZO_Dialogs_ShowDialog(dialogName)
    end)

    if ok then
        -- Only mark it as seen once it really was shown.
        account._esoHybridWelcomeShown = true
    else
        ADDON:LogWarn("Welcome dialog could not be shown:", tostring(err))
    end
end

local function RegisterFirstActivation()
    local eventName = ADDON.ADDON_NAME .. "_FirstActivated"
    EVENT_MANAGER:RegisterForEvent(eventName, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_PLAYER_ACTIVATED)
        if GetSettings().announceLoaded then
            ADDON:Say(ADDON.VERSION .. " loaded. /esohybrid switches Gamepad and Hybrid.")
        end
        zo_callLater(ShowWelcomeDialog, 1500)
    end)
end

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------

local function PrintStatus()
    ADDON:Say(ADDON:IsHybrid() and "hybrid UI" or "native gamepad UI")
end

local function RegisterSlashCommands()
    SLASH_COMMANDS["/esohybrid"] = function()
        ADDON:ToggleUI()
        PrintStatus()
    end
    SLASH_COMMANDS["/esohybrid_status"] = PrintStatus
    SLASH_COMMANDS["/esohybrid_sv"] = function()
        local account = ADDON.savedVariablesAccountWide
        ADDON:Say(string.format("SV root=%s | account profile=%s | character profile=%s | account-wide=%s",
            type(_G[ADDON.SAVED_VARIABLES]), type(account), type(ADDON.savedVariables),
            tostring(account ~= nil and account._esoHybridUseAccountWideSettings == true)))
    end
end

-- ---------------------------------------------------------------------------
-- Initialization
-- ---------------------------------------------------------------------------

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON.ADDON_NAME or rt.initialized then
        return
    end

    InitializeSavedVariables()
    ADDON:InitializeDiagnostics()
    ADDON:RegisterDiagnosticCommands()
    ADDON:RefreshSettingsCache()
    ADDON:InstallModeOverride()

    local name = ADDON.ADDON_NAME
    EVENT_MANAGER:RegisterForEvent(name .. "_LockpickBegin", EVENT_BEGIN_LOCKPICK, OnLockpickBegin)
    EVENT_MANAGER:RegisterForEvent(name .. "_LockpickSuccess", EVENT_LOCKPICK_SUCCESS, OnLockpickEnd)
    EVENT_MANAGER:RegisterForEvent(name .. "_LockpickFailed", EVENT_LOCKPICK_FAILED, OnLockpickEnd)
    EVENT_MANAGER:RegisterForEvent(name .. "_ModeChanged", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, OnGamepadPreferredModeChanged)

    if SCENE_MANAGER and SCENE_MANAGER.RegisterCallback then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", OnSceneStateChanged)
    end
    if LOCK_PICK_SCENE and LOCK_PICK_SCENE.RegisterCallback then
        LOCK_PICK_SCENE:RegisterCallback("StateChange", OnLockpickSceneStateChanged)
    end
    if LOCK_PICK_GAMEPAD_SCENE and LOCK_PICK_GAMEPAD_SCENE.RegisterCallback then
        LOCK_PICK_GAMEPAD_SCENE:RegisterCallback("StateChange", OnLockpickSceneStateChanged)
    end

    RegisterSlashCommands()

    local ok, err = pcall(function() ADDON:RegisterSettings() end)
    if not ok then
        ADDON:LogError("Settings registration failed:", tostring(err))
    end

    rt.initialized = true
    ADDON:Refresh()
    RegisterFirstActivation()

    EVENT_MANAGER:UnregisterForEvent(name, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
