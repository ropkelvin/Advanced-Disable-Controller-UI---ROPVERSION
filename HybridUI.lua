-- HybridUI
-- Fresh implementation; no code is copied from other addon branches or projects.

local ADDON_NAME = "HybridUI"
local MODE_NATIVE = "native"
local MODE_HYBRID = "hybrid"

local DEFAULTS =
{
    mode = MODE_NATIVE,
    applyGamepadModeOn = true,
}

local savedVariables
local initialized = false

local function ApplyGamepadModeSetting()
    if savedVariables.applyGamepadModeOn then
        SetSetting(
            SETTING_TYPE_GAMEPAD,
            GAMEPAD_SETTING_INPUT_PREFERRED_MODE,
            INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD
        )
    end
end

local function ApplyMode()
    ApplyGamepadModeSetting()

    -- Both modes intentionally retain ESO's real preferred-input setting.
    -- Hybrid's HUD selection is not implemented by overriding the global
    -- IsInGamepadPreferredMode() function: doing so also changes how ESO
    -- selects menus and interaction scenes, which violates the specification.
    -- The HUD-only integration must be implemented against the native HUD
    -- fragments and verified in-client before this mode can be called complete.
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
            text = "Native Gamepad UI keeps ESO's complete Gamepad interface. Hybrid UI is intended to use native Gamepad menus with the original Keyboard gameplay HUD.",
        },
        {
            type = "dropdown",
            name = "Interface mode",
            tooltip = "Choose Native Gamepad UI or Hybrid UI.",
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
            tooltip = "Sets ESO's input preference to Always Gamepad instead of Auto.",
            getFunc = function()
                return savedVariables.applyGamepadModeOn
            end,
            setFunc = function(value)
                savedVariables.applyGamepadModeOn = value
                ApplyGamepadModeSetting()
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

    ApplyMode()
    CreateSettings()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
