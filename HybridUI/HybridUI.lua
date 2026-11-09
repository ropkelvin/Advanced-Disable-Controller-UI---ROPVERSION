-- HybridUI
-- Keyboard presentation for selected native HUD controls while ESO remains
-- in native Gamepad mode. No menu, scene, dialog, or input routing changes.

local ADDON_NAME = "HybridUI"
local DEFAULTS =
{
    keyboardHud = true,
}

local savedVariables
local initialized = false
local originalAttributeApplyStyle
local originalCompassApplyStyle
local originalBossBarApplyStyle

local function WithKeyboardTemplates(callback)
    local originalGetPlatformTemplate = ZO_GetPlatformTemplate
    ZO_GetPlatformTemplate = function(baseTemplate)
        return baseTemplate .. "_Keyboard_Template"
    end

    callback()

    ZO_GetPlatformTemplate = originalGetPlatformTemplate
end

local function WithKeyboardPlatform(callback)
    local originalPreferredMode = IsInGamepadPreferredMode
    IsInGamepadPreferredMode = function()
        return false
    end

    WithKeyboardTemplates(callback)

    IsInGamepadPreferredMode = originalPreferredMode
end

local function IsKeyboardHudEnabled()
    return savedVariables and savedVariables.keyboardHud
end

-- ESO registers separate Keyboard and Gamepad HUD elements for the same
-- control. Reuse the real Keyboard element's saved/default anchor, rather
-- than calculating replacement coordinates.
local function ApplyKeyboardHudAnchors()
    if not IsKeyboardHudEnabled() or not HUD_MANAGER or not HUD_MANAGER.keyboardElements then
        return
    end

    for control, keyboardElement in pairs(HUD_MANAGER.keyboardElements) do
        if HUD_MANAGER.gamepadElements[control] then
            keyboardElement:RevertOffsetModifications()
        end
    end
end

local function InstallResourceBarAdapter()
    if not ZO_PlayerAttributeBars or not ZO_PlayerAttributeBars.ApplyStyle or originalAttributeApplyStyle then
        return
    end

    originalAttributeApplyStyle = ZO_PlayerAttributeBars.ApplyStyle
    ZO_PlayerAttributeBars.ApplyStyle = function(self)
        if IsKeyboardHudEnabled() then
            return WithKeyboardTemplates(function()
                originalAttributeApplyStyle(self)
            end)
        end

        return originalAttributeApplyStyle(self)
    end

    if PLAYER_ATTRIBUTE_BARS then
        PLAYER_ATTRIBUTE_BARS:ApplyStyle()
    end
end

local function InstallCompassAdapter()
    if not COMPASS_FRAME or not COMPASS_FRAME.ApplyStyle or originalCompassApplyStyle then
        return
    end

    originalCompassApplyStyle = COMPASS_FRAME.ApplyStyle
    COMPASS_FRAME.ApplyStyle = function(self)
        if IsKeyboardHudEnabled() then
            WithKeyboardPlatform(function()
                originalCompassApplyStyle(self)
            end)
            if self.keyboardHUDElement then
                self.keyboardHUDElement:RevertOffsetModifications()
            end
            return
        end

        return originalCompassApplyStyle(self)
    end

    COMPASS_FRAME:ApplyStyle()
end

local function InstallBossBarAdapter()
    if not BOSS_BAR or not BOSS_BAR.ApplyStyle or originalBossBarApplyStyle then
        return
    end

    originalBossBarApplyStyle = BOSS_BAR.ApplyStyle
    BOSS_BAR.ApplyStyle = function(self)
        if IsKeyboardHudEnabled() then
            return WithKeyboardTemplates(function()
                originalBossBarApplyStyle(self)
            end)
        end

        return originalBossBarApplyStyle(self)
    end

    BOSS_BAR:ApplyStyle()
end

local function ApplyAllKeyboardHudStyles()
    if not IsKeyboardHudEnabled() then
        return
    end

    InstallResourceBarAdapter()
    InstallCompassAdapter()
    InstallBossBarAdapter()

    if PLAYER_ATTRIBUTE_BARS then
        PLAYER_ATTRIBUTE_BARS:ApplyStyle()
    end
    if COMPASS_FRAME then
        COMPASS_FRAME:ApplyStyle()
    end
    if BOSS_BAR then
        BOSS_BAR:ApplyStyle()
    end

    ApplyKeyboardHudAnchors()
end

local function OnHudSettingsReady()
    ApplyAllKeyboardHudStyles()
    HUD_MANAGER:RegisterCallback("PropagateSettings", ApplyKeyboardHudAnchors)
end

local function CreateSettings()
    local panelName = "HybridUIOptions"

    LibAddonMenu2:RegisterAddonPanel(panelName,
    {
        type = "panel",
        name = "HybridUI",
        displayName = "HybridUI",
        author = "@ZOSPlsFix",
        version = "2.1.0",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    LibAddonMenu2:RegisterOptionControls(panelName,
    {
        {
            type = "description",
            text = "Keeps ESO in native Gamepad mode and applies Keyboard presentation to supported gameplay HUD elements only. Menus, inventory, map, dialogue, interactions, input handling and scene routing remain native Gamepad.",
        },
        {
            type = "checkbox",
            name = "Keyboard HUD presentation",
            tooltip = "Uses ESO's Keyboard HUD anchors and platform templates for supported HUD elements. Disable to restore native Gamepad HUD presentation.",
            getFunc = function()
                return savedVariables.keyboardHud
            end,
            setFunc = function(value)
                savedVariables.keyboardHud = value
                if value then
                    ApplyAllKeyboardHudStyles()
                else
                    -- Reapply the original native Gamepad styles and anchors.
                    if PLAYER_ATTRIBUTE_BARS and originalAttributeApplyStyle then
                        originalAttributeApplyStyle(PLAYER_ATTRIBUTE_BARS)
                    end
                    if COMPASS_FRAME and originalCompassApplyStyle then
                        originalCompassApplyStyle(COMPASS_FRAME)
                    end
                    if BOSS_BAR and originalBossBarApplyStyle then
                        originalBossBarApplyStyle(BOSS_BAR)
                    end
                    if HUD_MANAGER then
                        HUD_MANAGER:PropagateSettings()
                    end
                end
            end,
            default = DEFAULTS.keyboardHud,
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
        3,
        nil,
        DEFAULTS
    )

    if HUD_MANAGER then
        HUD_MANAGER:RegisterCallback("SavedVarsReady", OnHudSettingsReady)
        if HUD_MANAGER.savedVars then
            OnHudSettingsReady()
        end
    end

    CreateSettings()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
