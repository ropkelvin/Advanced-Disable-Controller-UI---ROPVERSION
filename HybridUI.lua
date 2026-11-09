-- HybridUI
-- Original implementation. No code is copied from other addon branches or projects.

local ADDON_NAME = "HybridUI"
local DEFAULTS =
{
    mode = "native",
    applyGamepadModeOn = true,
}

local MODE_NATIVE = "native"
local MODE_HYBRID = "hybrid"

local savedVariables
local originalIsInGamepadPreferredMode
local isInitialized = false

local function ApplyGamepadModeSetting()
    if savedVariables.applyGamepadModeOn then
        SetSetting(
            SETTING_TYPE_GAMEPAD,
            GAMEPAD_SETTING_INPUT_PREFERRED_MODE,
            INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD
        )
    end
end

local function IsHUDScene(sceneName)
    return sceneName == "hud" or sceneName == "hudui"
end

local function InstallMode()
    if savedVariables.mode == MODE_NATIVE then
        if originalIsInGamepadPreferredMode then
            IsInGamepadPreferredMode = originalIsInGamepadPreferredMode
        end
        return
    end

    if not originalIsInGamepadPreferredMode then
        originalIsInGamepadPreferredMode = IsInGamepadPreferredMode
    end

    if not SCENE_MANAGER or not SCENE_MANAGER.Show or SCENE_MANAGER.__hybridUIWrapped then
        return
    end

    local originalShow = SCENE_MANAGER.Show
    SCENE_MANAGER.Show = function(sceneManager, sceneName, ...)
        if IsHUDScene(sceneName) then
            IsInGamepadPreferredMode = function()
                return false
            end
            local results = { originalShow(sceneManager, sceneName, ...) }
            IsInGamepadPreferredMode = originalIsInGamepadPreferredMode
            return unpack(results)
        end

        IsInGamepadPreferredMode = originalIsInGamepadPreferredMode
        return originalShow(sceneManager, sceneName, ...)
    end
    SCENE_MANAGER.__hybridUIWrapped = true
end

local function ApplyConfiguration()
    ApplyGamepadModeSetting()
    InstallMode()
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
        version = "1.0.0",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    LAM:RegisterOptionControls("HybridUIOptions",
    {
        {
            type = "description",
            text = "Choose between ESO's complete native Gamepad UI and Hybrid UI. Hybrid UI targets the original Keyboard gameplay HUD while retaining native Gamepad menus.",
        },
        {
            type = "dropdown",
            name = "Interface mode",
            tooltip = "Native Gamepad UI uses ESO's normal Gamepad interface. Hybrid UI keeps native Gamepad menus and targets the original Keyboard gameplay HUD.",
            choices = { "Native Gamepad UI", "Hybrid UI" },
            choicesValues = { MODE_NATIVE, MODE_HYBRID },
            getFunc = function() return savedVariables.mode end,
            setFunc = function(value)
                savedVariables.mode = value
                ApplyConfiguration()
            end,
            default = MODE_NATIVE,
        },
        {
            type = "checkbox",
            name = "Set ESO Gamepad Mode to On",
            tooltip = "Applies ESO's Always Gamepad preference instead of Auto.",
            getFunc = function() return savedVariables.applyGamepadModeOn end,
            setFunc = function(value)
                savedVariables.applyGamepadModeOn = value
                ApplyGamepadModeSetting()
            end,
            default = true,
        },
    })
end

local function OnAddonLoaded(eventCode, addonName)
    if addonName ~= ADDON_NAME or isInitialized then
        return
    end

    isInitialized = true
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    savedVariables = ZO_SavedVars:NewAccountWide(
        "HybridUI_SavedVariables",
        1,
        nil,
        DEFAULTS
    )

    ApplyConfiguration()
    CreateSettings()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
