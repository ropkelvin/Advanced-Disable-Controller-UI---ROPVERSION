-- HybridUI
-- Clean implementation using ESO's native scene and platform UI systems.

local ADDON_NAME = "HybridUI"
local MODE_NATIVE = "native"
local MODE_HYBRID = "hybrid"

local DEFAULTS =
{
    mode = MODE_NATIVE,
    applyGamepadModeOn = true,
    originalPreferredMode = nil,
}

local savedVariables
local initialized = false
local refreshingPlatformStyles = false
local originalIsInGamepadPreferredMode = IsInGamepadPreferredMode

local originalSystemMethods = {}
local originalDialogMethods = {}

local function IsHybridMode()
    return savedVariables and savedVariables.mode == MODE_HYBRID
end

local function IsBaseHUDSceneShowing()
    return SCENE_MANAGER
        and SCENE_MANAGER.IsShowingBaseScene
        and SCENE_MANAGER:IsShowingBaseScene()
end

-- ESO's platform style manager asks this function which style to apply.
-- In Hybrid mode, only the active base HUD scene reports Keyboard preference.
-- Native Gamepad menu scenes continue to report Gamepad preference.
IsInGamepadPreferredMode = function()
    if IsHybridMode() then
        return not IsBaseHUDSceneShowing()
    end

    return originalIsInGamepadPreferredMode()
end

local function ApplyGamepadModeSetting()
    if savedVariables.applyGamepadModeOn then
        if savedVariables.originalPreferredMode == nil then
            savedVariables.originalPreferredMode = GetSetting(
                SETTING_TYPE_GAMEPAD,
                GAMEPAD_SETTING_INPUT_PREFERRED_MODE
            )
        end

        SetSetting(
            SETTING_TYPE_GAMEPAD,
            GAMEPAD_SETTING_INPUT_PREFERRED_MODE,
            tostring(INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD)
        )
    elseif savedVariables.originalPreferredMode ~= nil then
        SetSetting(
            SETTING_TYPE_GAMEPAD,
            GAMEPAD_SETTING_INPUT_PREFERRED_MODE,
            savedVariables.originalPreferredMode
        )
    end
end

local originalSceneSetRequestedMode = ZO_Scene.SetWasRequestedToShowInGamepadPreferredMode

local function InstallScenePreferredMode()
    ZO_Scene.SetWasRequestedToShowInGamepadPreferredMode = function(self, gamepad)
        if IsHybridMode() then
            local baseScene = SCENE_MANAGER:GetBaseScene()
            local isHUDScene = self == HUD_SCENE
                or self == HUD_UI_SCENE
                or self == baseScene

            originalSceneSetRequestedMode(self, not isHUDScene)
        else
            originalSceneSetRequestedMode(self, gamepad)
        end
    end

    local baseScene = SCENE_MANAGER:GetBaseScene()
    if baseScene then
        if IsHybridMode() then
            baseScene:SetWasRequestedToShowInGamepadPreferredMode(false)
        else
            baseScene:SetWasRequestedToShowInGamepadPreferredMode(originalIsInGamepadPreferredMode())
        end
    end
end

local function InstallNativeGamepadRouting()
    if not originalSystemMethods.getObject then
        originalSystemMethods.getObject = SYSTEMS.GetObject
        originalSystemMethods.getRootScene = SYSTEMS.GetRootScene

        SYSTEMS.GetObject = function(self, systemName)
            if IsHybridMode() then
                return self:GetGamepadObject(systemName)
            end

            return originalSystemMethods.getObject(self, systemName)
        end

        SYSTEMS.GetRootScene = function(self, systemName)
            if IsHybridMode() then
                return self:GetGamepadRootScene(systemName)
            end

            return originalSystemMethods.getRootScene(self, systemName)
        end
    end

    if not originalSystemMethods.openPlatformUISystem then
        originalSystemMethods.openPlatformUISystem = ZO_UISystemManager.OpenPlatformUISystem

        ZO_UISystemManager.OpenPlatformUISystem = function(self, system, ...)
            if IsHybridMode() then
                return self:OpenGamepadUISystem(system, ...)
            end

            return originalSystemMethods.openPlatformUISystem(self, system, ...)
        end
    end

    if not originalSystemMethods.getPlatformUISystemDisplayName then
        originalSystemMethods.getPlatformUISystemDisplayName = ZO_UISystemManager.GetPlatformUISystemDisplayName

        ZO_UISystemManager.GetPlatformUISystemDisplayName = function(self, system)
            if IsHybridMode() then
                return self:GetGamepadUISystemDisplayName(system)
            end

            return originalSystemMethods.getPlatformUISystemDisplayName(self, system)
        end
    end
end

local function InstallGamepadDialogs()
    if not originalDialogMethods.showPlatformDialog then
        originalDialogMethods.showPlatformDialog = ZO_Dialogs_ShowPlatformDialog

        ZO_Dialogs_ShowPlatformDialog = function(...)
            if IsHybridMode() then
                return ZO_Dialogs_ShowGamepadDialog(...)
            end

            return originalDialogMethods.showPlatformDialog(...)
        end
    end

    if not originalDialogMethods.showDialog then
        originalDialogMethods.showDialog = ZO_Dialogs_ShowDialog

        ZO_Dialogs_ShowDialog = function(name, data, textParams, isGamepad)
            if IsHybridMode() then
                local dialogInfo = ESO_Dialogs[name]
                if dialogInfo and dialogInfo.gamepadInfo then
                    isGamepad = true
                end
            end

            return originalDialogMethods.showDialog(name, data, textParams, isGamepad)
        end
    end
end

-- ZO_PlatformStyle objects are refreshed by ESO when this setting changes.
-- A temporary round-trip forces that native refresh after the base scene
-- changes. The saved setting is restored immediately; Hybrid mode's
-- scene-aware preference determines which style ESO applies during refresh.
local function RefreshNativePlatformStyles()
    if refreshingPlatformStyles then
        return
    end

    refreshingPlatformStyles = true

    local currentMode = GetSetting(
        SETTING_TYPE_GAMEPAD,
        GAMEPAD_SETTING_INPUT_PREFERRED_MODE
    )

    local alwaysKeyboard = tostring(INPUT_PREFERRED_MODE_ALWAYS_KEYBOARD)
    local alwaysGamepad = tostring(INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD)
    local alternateMode = originalIsInGamepadPreferredMode() and alwaysKeyboard or alwaysGamepad

    SetSetting(
        SETTING_TYPE_GAMEPAD,
        GAMEPAD_SETTING_INPUT_PREFERRED_MODE,
        alternateMode
    )

    SetSetting(
        SETTING_TYPE_GAMEPAD,
        GAMEPAD_SETTING_INPUT_PREFERRED_MODE,
        currentMode
    )

    refreshingPlatformStyles = false
end

local function OnSceneStateChanged(scene, oldState, newState)
    if IsHybridMode()
        and newState == SCENE_SHOWN
        and scene == SCENE_MANAGER:GetCurrentScene()
    then
        RefreshNativePlatformStyles()
    end
end

local function ApplyMode()
    ApplyGamepadModeSetting()
    InstallScenePreferredMode()
    InstallNativeGamepadRouting()
    InstallGamepadDialogs()
    RefreshNativePlatformStyles()
end

local function CreateSettings()
    local LAM = LibAddonMenu2
    if not LAM then
        return
    end

    LAM:RegisterAddonPanel("HybridUIOptions",
    {
        type = "panel",
        name = "HybridUI",
        displayName = "HybridUI",
        author = "@ZOSPlsFix",
        version = "1.0.1",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    LAM:RegisterOptionControls("HybridUIOptions",
    {
        {
            type = "description",
            text = "Native Gamepad UI leaves ESO's Gamepad interface untouched. Hybrid UI keeps native Gamepad menus, inventory, map, interactions and dialogues while selecting the original Keyboard platform style for the base gameplay HUD.",
        },
        {
            type = "dropdown",
            name = "Interface mode",
            tooltip = "Native Gamepad UI uses ESO's normal Gamepad interface. Hybrid UI uses Keyboard platform styling only while the base HUD scene is active and routes supported menus and dialogs to their native Gamepad versions.",
            choices = { "Native Gamepad UI", "Hybrid UI" },
            choicesValues = { MODE_NATIVE, MODE_HYBRID },
            getFunc = function()
                return savedVariables.mode
            end,
            setFunc = function(value)
                savedVariables.mode = value
                ApplyMode()
            end,
            default = MODE_NATIVE,
        },
        {
            type = "checkbox",
            name = "Set ESO Gamepad Mode to On",
            tooltip = "Applies ESO's Always Gamepad preference. When disabled, HybridUI restores the setting value saved when the option was first enabled.",
            getFunc = function()
                return savedVariables.applyGamepadModeOn
            end,
            setFunc = function(value)
                savedVariables.applyGamepadModeOn = value
                ApplyGamepadModeSetting()
                RefreshNativePlatformStyles()
            end,
            default = true,
        },
    })
end

local function OnAddonLoaded(eventCode, addonName)
    if addonName ~= ADDON_NAME or initialized then
        return
    end

    initialized = true
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    savedVariables = ZO_SavedVars:NewAccountWide(
        "HybridUI_SavedVariables",
        1,
        nil,
        DEFAULTS
    )

    SCENE_MANAGER:RegisterCallback("SceneStateChanged", OnSceneStateChanged)

    ApplyMode()
    CreateSettings()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
