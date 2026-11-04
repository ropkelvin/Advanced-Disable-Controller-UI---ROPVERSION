-- Core: keep ESO's native gamepad platform and limit the addon to HUD presentation.

local ADDON = ESOHybridUI

local function DeepCopy(source)
    if type(source) ~= "table" then return source end
    local target = {}
    for key, value in pairs(source) do target[key] = DeepCopy(value) end
    return target
end

local function CopyProfileSettings(source, target)
    if type(source) ~= "table" or type(target) ~= "table" then return false end
    for key in pairs(ADDON.defaults) do
        local value = source[key]
        if value ~= nil then target[key] = DeepCopy(value) end
    end
    return true
end

local function GetSettings()
    local account = ADDON.savedVariablesAccountWide
    if account and account._esoHybridUseAccountWideSettings == true then return account end
    return ADDON.savedVariables or account or ADDON.defaults
end

function ADDON:GetSettings()
    return GetSettings()
end

function ADDON:IsNativeGamepadMode()
    -- Never replace or spoof this ESO API. It is the source of truth for
    -- platform selection, scene routing, bindings, menus and interactions.
    return IsInGamepadPreferredMode()
end

function ADDON:ShouldShowControllerPrompts()
    return GetSettings().useHybridUI == true and self:IsNativeGamepadMode()
end

function ADDON:ApplyRecommendedESOSettings()
    local saveOption = SETTINGS_SET_OPTION_SAVE_TO_PERSISTED_DATA
    SetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_INPUT_PREFERRED_MODE,
        tostring(INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD), saveOption)
    SetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_KEYBIND_DISPLAY_MODE,
        tostring(KEYBIND_DISPLAY_MODE_ALWAYS_GAMEPAD), saveOption)
    SetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_USE_KEYBOARD_CHAT, "1", saveOption)
    SetSetting(SETTING_TYPE_UI, UI_SETTING_RETURN_CURSOR_ON_CHAT_FOCUS, "1", saveOption)

    self:LogInfo("Saved ESO settings: Gamepad Mode On, Gamepad keybinds, Keyboard Chat and cursor-on-chat-focus.")
    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage("[ESO Hybrid UI] ESO Gamepad Mode and Gamepad keybinds enabled. Keyboard Chat and cursor-on-chat-focus enabled.")
    end
end

function ADDON:ApplyAll()
    self:ApplyPrompts()
    self:ApplyActionBar()
end

function ADDON:Refresh()
    self:LogDebug("Refreshing HUD presentation only; ESO platform mode is unchanged.")
    self:ApplyAll()
end

function ADDON:SetUseAccountWideSettings(enabled)
    local character, account = self.savedVariables, self.savedVariablesAccountWide
    if not character or not account then
        self:LogError("Cannot change settings scope: SavedVariables are not initialized.")
        return
    end
    if enabled and account._esoHybridUseAccountWideSettings == nil then
        CopyProfileSettings(character, account)
    elseif not enabled then
        CopyProfileSettings(account, character)
    end
    account._esoHybridUseAccountWideSettings = enabled == true
    self:Refresh()
end

function ADDON:ToggleUI()
    local settings = GetSettings()
    settings.useHybridUI = not (settings.useHybridUI == true)
    settings.useControllerUI = true
    settings.useGamepadButtons = true
    self:LogInfo("HUD style:", settings.useHybridUI and "keyboard-style HUD / native gamepad" or "native gamepad HUD")
    self:Refresh()
end

local function InitializeSavedVariables()
    local legacyAccountProfile = ZO_SavedVars:NewAccountWide(
        ADDON.SAVED_VARIABLES, ADDON.SAVED_VARIABLES_VERSION, nil, ADDON.defaults)
    ADDON.savedVariablesAccountWide = ZO_SavedVars:NewAccountWide(
        ADDON.SAVED_VARIABLES, ADDON.SAVED_VARIABLES_VERSION, GetWorldName(), ADDON.defaults)
    ADDON.savedVariables = ZO_SavedVars:NewCharacterIdSettings(
        ADDON.SAVED_VARIABLES, ADDON.SAVED_VARIABLES_VERSION, nil, ADDON.defaults)

    local account = ADDON.savedVariablesAccountWide
    if not account._esoHybridServerProfileMigrated then
        CopyProfileSettings(legacyAccountProfile, account)
        account._esoHybridUseAccountWideSettings = legacyAccountProfile._esoHybridUseAccountWideSettings
        account._esoHybridWelcomeShown = legacyAccountProfile._esoHybridWelcomeShown
        account._esoHybridServerProfileMigrated = true
    end

    -- Older releases used "controller UI" as a mode switch. It is now always
    -- native ESO gamepad; only the HUD presentation preference is retained.
    local function Normalize(profile)
        if type(profile) ~= "table" then return end
        profile.useControllerUI = true
        profile.useGamepadButtons = true
    end
    Normalize(ADDON.savedVariables)
    Normalize(ADDON.savedVariablesAccountWide)

    if type(_G[ADDON.SAVED_VARIABLES]) ~= "table" then
        ADDON:LogError("ESO did not create the declared SavedVariables root table.")
    end
end

local function PrintStatus()
    local hybrid = GetSettings().useHybridUI == true
    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage("[ESO Hybrid UI] " ..
            (hybrid and "Keyboard-style HUD / native gamepad controls" or "Native gamepad HUD and controls"))
    end
end

local function RegisterSlashCommands()
    SLASH_COMMANDS["/esohybrid"] = function()
        ADDON:ToggleUI()
        PrintStatus()
    end
    SLASH_COMMANDS["/esohybrid_status"] = PrintStatus
    SLASH_COMMANDS["/esohybrid_sv"] = function()
        local account = ADDON.savedVariablesAccountWide
        local message = string.format("[ESO Hybrid UI] SavedVariables root=%s | account=%s | character=%s | account-wide=%s",
            type(_G[ADDON.SAVED_VARIABLES]), type(account), type(ADDON.savedVariables),
            tostring(account and account._esoHybridUseAccountWideSettings == true))
        if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then CHAT_SYSTEM:AddMessage(message) end
        ADDON:LogInfo(message)
    end
end

local function ShowFirstInstallWelcome()
    local account = ADDON.savedVariablesAccountWide
    if not account or account._esoHybridWelcomeShown then return end
    account._esoHybridWelcomeShown = true

    local dialogName = "ESOHYBRIDUI_FIRST_INSTALL"
    ZO_Dialogs_RegisterCustomDialog(dialogName, {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title = { text = "Welcome to ESO Hybrid UI" },
        mainText = {
            text = "ESO Hybrid UI keeps ESO's native Gamepad Mode and changes selected gameplay HUD visuals only. Open addon settings and apply the recommended ESO controller and keyboard-chat settings if needed.",
        },
        buttons = { { text = "Got it" } },
    })
    ZO_Dialogs_ShowDialog(dialogName)
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON.ADDON_NAME or ADDON.runtime.initialized then return end

    InitializeSavedVariables()
    ADDON:InitializeDiagnostics()
    ADDON:RegisterDiagnosticCommands()
    RegisterSlashCommands()
    ADDON:RegisterSettings()

    ADDON.runtime.initialized = true
    ADDON:ApplyAll()
    ShowFirstInstallWelcome()

    ADDON:LogInfo("Initialized", ADDON.VERSION, "- native ESO gamepad systems preserved.")
    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage("[ESO Hybrid UI] " .. ADDON.VERSION ..
            " loaded. Native gamepad controls are preserved. Use /esohybrid to toggle HUD styling.")
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON.ADDON_NAME, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
