-- Advanced Disable Controller UI settings
-- LibAddonMenu is a required manifest dependency and is accessed through its
-- native global. LibStub is deliberately not used.

local ADDON = ADCUI

function ADDON:RegisterSettings()
    if not LibAddonMenu2 then
        d("[ADCUI] LibAddonMenu-2.0 >= 43 is required; settings panel skipped.")
        return
    end

    local panelName = "AdvancedDisableControllerUI_Settings"
    local panel = {
        type = "panel",
        name = "Advanced Disable Controller UI",
        author = "RopKelvin",
        version = "2.0.0",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    LibAddonMenu2:RegisterAddonPanel(panelName, panel)
    LibAddonMenu2:RegisterOptionControls(panelName, {
        {
            type = "description",
            text = "Use a gamepad for movement and combat while keeping ESO's keyboard-style interface. This does not disable controller input.",
        },
        {
            type = "checkbox",
            name = "Use native gamepad UI",
            tooltip = "Enable ESO's normal gamepad interface. Disable this to use the keyboard-style interface while continuing to play with a controller.",
            default = ADDON.defaults.useControllerUI,
            getFunc = function()
                return ADDON:GetSettings().useControllerUI
            end,
            setFunc = function(value)
                ADDON:GetSettings().useControllerUI = value
                ADDON:Refresh()
            end,
        },
        {
            type = "description",
            text = "Quick toggle: /adcui    |    Status: /adcui_status",
        },
    })
end
