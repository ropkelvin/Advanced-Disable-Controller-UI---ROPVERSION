-- HybridUI
-- HUD-only visual adapter. ESO remains in native Gamepad mode.

local ADDON_NAME = "HybridUI"
local DEFAULTS =
{
    keyboardResourceBars = true,
}

local savedVariables
local originalGetPlatformTemplate
local originalApplyAttributeStyle
local initialized = false

local function ApplyKeyboardResourceBarStyle(self, ...)
    -- Scope the template choice to the native player-attribute HUD style pass.
    -- No input mode, scene, dialog, menu, or UI-system routing is changed.
    local getPlatformTemplate = ZO_GetPlatformTemplate
    ZO_GetPlatformTemplate = function(baseTemplate)
        return baseTemplate .. "_Keyboard_Template"
    end

    originalApplyAttributeStyle(self, ...)

    ZO_GetPlatformTemplate = getPlatformTemplate
end

local function InstallAttributeBarAdapter()
    if not ZO_PlayerAttributeBars or not ZO_PlayerAttributeBars.ApplyStyle then
        return false
    end

    if originalApplyAttributeStyle then
        return true
    end

    originalApplyAttributeStyle = ZO_PlayerAttributeBars.ApplyStyle

    ZO_PlayerAttributeBars.ApplyStyle = function(self, ...)
        if savedVariables and savedVariables.keyboardResourceBars then
            return ApplyKeyboardResourceBarStyle(self, ...)
        end

        return originalApplyAttributeStyle(self, ...)
    end

    -- Apply the selected appearance immediately. ESO continues to own the
    -- resource-bar objects, events, values, visibility and combat behavior.
    if PLAYER_ATTRIBUTE_BARS then
        PLAYER_ATTRIBUTE_BARS:ApplyStyle()
    end

    return true
end

local function CreateSettings()
    local panelName = "HybridUIOptions"

    LibAddonMenu2:RegisterAddonPanel(panelName,
    {
        type = "panel",
        name = "HybridUI",
        displayName = "HybridUI",
        author = "@ZOSPlsFix",
        version = "2.0.0",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    LibAddonMenu2:RegisterOptionControls(panelName,
    {
        {
            type = "description",
            text = "HybridUI changes HUD presentation only. ESO remains in native Gamepad mode; menus, inventory, map, interactions, dialogues, input handling and UI-system routing are left alone. The first HUD adapter gives the native Health, Magicka and Stamina bars the original Keyboard platform templates and layout.",
        },
        {
            type = "checkbox",
            name = "Keyboard-style resource bars",
            tooltip = "Uses ESO's own Keyboard templates for the native Health, Magicka and Stamina HUD bars while keeping Gamepad mode and Gamepad input active. Disable to restore the normal Gamepad resource-bar appearance.",
            getFunc = function()
                return savedVariables.keyboardResourceBars
            end,
            setFunc = function(value)
                savedVariables.keyboardResourceBars = value
                if PLAYER_ATTRIBUTE_BARS then
                    PLAYER_ATTRIBUTE_BARS:ApplyStyle()
                end
            end,
            default = DEFAULTS.keyboardResourceBars,
        },
    })
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME or initialized then
        return
    end

    initialized = true
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    savedVariables = ZO_SavedVars:NewAccountWide(
        "HybridUI_SavedVariables",
        2,
        nil,
        DEFAULTS
    )

    InstallAttributeBarAdapter()
    CreateSettings()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
