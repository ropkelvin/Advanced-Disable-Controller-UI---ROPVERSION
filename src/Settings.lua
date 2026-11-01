-- LibAddonMenu-2.0 settings panel. Access LAM through its native global; no LibStub.

local ADDON = ESOHybridUI

local function FontDropdown(name, tooltip, key, choices, values)
    return {
        type = "dropdown",
        name = name,
        tooltip = tooltip,
        choices = choices,
        choicesValues = values,
        default = ADDON.defaults.fonts[key],
        getFunc = function()
            local current = ADDON:GetSettings().fonts[key]
            for _, value in ipairs(values) do
                if current == value then return current end
            end
            -- Older versions offered many more font sizes. Show the default
            -- choice for legacy values without changing the saved value.
            return ADDON.defaults.fonts[key]
        end,
        setFunc = function(value)
            ADDON:GetSettings().fonts[key] = value
            ADDON:ApplyPrompts()
        end,
    }
end

local function OpenDonationMail(amount)
    if not (MAIL_SEND and MAIL_SEND.ComposeMailTo and QueueMoneyAttachment) then
        if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
            CHAT_SYSTEM:AddMessage("[ESO Hybrid UI] The mail composer or gold attachment function is not available.")
        end
        return
    end

    -- ESO requires the player to review and send the mail manually.
    MAIL_SEND:ComposeMailTo("@ZOSPlsFix")
    QueueMoneyAttachment(amount)
end

local function DonationButton(amount)
    local formatted = amount == 5000 and "5,000"
        or amount == 10000 and "10,000"
        or "50,000"

    return {
        type = "button",
        name = formatted .. " gold",
        buttonText = "Donate " .. formatted,
        func = function() OpenDonationMail(amount) end,
        width = "half",
    }
end

function ADDON:RegisterSettings()
    if not LibAddonMenu2 then
        if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
            CHAT_SYSTEM:AddMessage("[ESO Hybrid UI] LibAddonMenu-2.0 >= 43 is required; settings panel was skipped.")
        end
        return
    end

    local panelName = "ESOHybridUI_Settings"
    LibAddonMenu2:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "ESO Hybrid UI",
        author = "ZOSPlsFix",
        version = ADDON.VERSION,
        slashCommand = "/esohybrid_settings",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    local fontChoices = { "Small", "Default", "Large", "Extra large" }
    local fontValues = {
        reticle = { "ZoFontWinH5", "ZoFontKeybindStripDescription", "ZoFontCallout", "ZoFontCallout2" },
        reticleContext = { "ZoFontWinH5", "ZoInteractionPrompt", "ZoFontCallout", "ZoFontCallout2" },
        stealthIcon = { "ZoFontWinH5", "ZoInteractionPrompt", "ZoFontCallout", "ZoFontCallout2" },
    }

    local options = {
        {
            type = "description",
            text = "Choose your interface style and adjust prompt text.",
        },
        {
            type = "dropdown",
            name = "UI mode",
            tooltip = "Keyboard keeps the compact keyboard interface. Gamepad uses ESO's full controller interface. Hybrid keeps the compact gameplay HUD with controller prompts and gamepad menus.",
            choices = { "Keyboard", "Gamepad", "Hybrid" },
            choicesValues = { "keyboard", "gamepad", "hybrid" },
            default = "keyboard",
            getFunc = function()
                local settings = ADDON:GetSettings()
                if settings.useHybridUI then return "hybrid" end
                return settings.useControllerUI and "gamepad" or "keyboard"
            end,
            setFunc = function(value)
                local settings = ADDON:GetSettings()
                settings.useHybridUI = value == "hybrid"
                settings.useControllerUI = value == "gamepad"
                ADDON:Refresh()
            end,
        },
        {
            type = "checkbox",
            name = "Controller button prompts",
            tooltip = "Show controller button icons on supported prompts and action buttons. Hybrid mode always enables this.",
            default = ADDON.defaults.useGamepadButtons,
            getFunc = function()
                local settings = ADDON:GetSettings()
                if settings.useHybridUI then return true end
                return settings.useGamepadButtons
            end,
            setFunc = function(value)
                local settings = ADDON:GetSettings()
                settings.useGamepadButtons = settings.useHybridUI and true or value
                ADDON:Refresh()
            end,
        },
        {
            type = "checkbox",
            name = "Account-wide settings",
            tooltip = "Use the same settings on all characters. Your current settings are copied to the shared profile when first enabled.",
            default = false,
            getFunc = function()
                return ADDON.savedVariablesAccountWide
                    and ADDON.savedVariablesAccountWide._esoHybridUseAccountWideSettings == true
                    or false
            end,
            setFunc = function(value) ADDON:SetUseAccountWideSettings(value) end,
        },
        FontDropdown("Interaction button font", "Size of the button label beside the reticle.", "reticle", fontChoices, fontValues.reticle),
        FontDropdown("Interaction context font", "Size of the interaction description beside the reticle.", "reticleContext", fontChoices, fontValues.reticleContext),
        FontDropdown("Stealth icon font", "Size of stealth and lockpicking prompt icons.", "stealthIcon", fontChoices, fontValues.stealthIcon),
        {
            type = "submenu",
            name = "Advanced",
            tooltip = "Troubleshooting options.",
            controls = {
                {
                    type = "checkbox",
                    name = "Diagnostic logging",
                    tooltip = "Enable detailed debug messages. For saved logs and stack traces, install LibDebugLogger and DebugLogViewer.",
                    default = false,
                    getFunc = function() return ADDON.runtime.debugLoggingEnabled end,
                    setFunc = function(value) ADDON:SetDebugLogging(value) end,
                },
                {
                    type = "description",
                    text = "Troubleshooting commands: /esohybrid_debug on|off and /esohybrid_dump.",
                },
            },
        },
        {
            type = "header",
            name = "Support the addon",
        },
        {
            type = "description",
            text = "Optional in-game gold donations are appreciated.",
        },
        DonationButton(5000),
        DonationButton(10000),
        DonationButton(50000),
    }

    LibAddonMenu2:RegisterOptionControls(panelName, options)
end
