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

function ADDON:RegisterSettings()
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

    local function OpenDonationMail()
        if not MAIL_SEND or not MAIL_SEND.ComposeMailTo then
            if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
                CHAT_SYSTEM:AddMessage("[ESO Hybrid UI] The mail composer is not available.")
            end
            return
        end

        -- Only open an addressed draft. The player manually chooses whether
        -- to attach gold and the amount; this addon never changes mail gold.
        MAIL_SEND:ComposeMailTo("@ZOSPlsFix")
    end

    local function RegisterGamepadOptions()
        local library = LibGamepadOptions
        if type(library) ~= "table" or type(library.RegisterAddon) ~= "function" then
            ADDON:LogInfo("LibGamepadOptions is not installed; native gamepad settings are unavailable.")
            return false
        end

        local gamepadOptions = {
            {
                type = "description",
                name = "Controller settings",
                text = "Configure ESO Hybrid UI without leaving the gamepad interface. These settings are shared with the keyboard Add-Ons panel.",
            },
            {
                type = "header",
                name = "Interface",
            },
            {
                type = "button",
                name = "Recommended ESO settings",
                tooltip = "Saves Gamepad Mode, Gamepad keybind display, Keyboard Chat, and cursor-on-chat-focus in ESO.",
                buttonText = "Apply settings",
                func = function() ADDON:ApplyRecommendedESOSettings() end,
            },
            {
                type = "dropdown",
                name = "HUD style",
                tooltip = "Both choices keep ESO native Gamepad Mode, menus, wheels, interactions and controller bindings. Hybrid changes selected gameplay HUD visuals to a compact keyboard-style appearance.",
                choices = { "Gamepad HUD", "Keyboard-style HUD" },
                choicesValues = { "gamepad", "hybrid" },
                default = "gamepad",
                getFunc = function()
                    return ADDON:GetSettings().useHybridUI and "hybrid" or "gamepad"
                end,
                setFunc = function(value)
                    local saved = ADDON:GetSettings()
                    saved.useHybridUI = value == "hybrid"
                    saved.useControllerUI = true
                    saved.useGamepadButtons = true
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
            {
                type = "header",
                name = "HUD prompts",
            },
            FontDropdown("Interaction button font", "Size of the button label beside the reticle.", "reticle", fontChoices, fontValues.reticle),
            FontDropdown("Interaction context font", "Size of the interaction description beside the reticle.", "reticleContext", fontChoices, fontValues.reticleContext),
            FontDropdown("Stealth icon font", "Size of stealth and lockpicking prompt icons.", "stealthIcon", fontChoices, fontValues.stealthIcon),
            {
                type = "header",
                name = "Advanced",
            },
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
                name = "Troubleshooting",
                text = "Chat commands: /esohybrid_debug on|off and /esohybrid_dump.",
            },
            {
                type = "header",
                name = "Support the addon",
            },
            {
                type = "description",
                name = "Optional donations",
                text = "The button opens a mail draft addressed to @ZOSPlsFix. You choose whether to attach gold and the amount.",
            },
            {
                type = "button",
                name = "Donation mail",
                tooltip = "Opens a mail draft only. ESO Hybrid UI does not attach or modify gold.",
                buttonText = "Open mail",
                func = OpenDonationMail,
            },
        }

        local ok, err = pcall(function()
            library:RegisterAddon("ESOHybridUI", {
                name = "ESO Hybrid UI",
                displayName = "ESO Hybrid UI",
                categoryName = "ESO Hybrid UI",
                directOpen = true,
                showInRoot = false,
                tooltip = "Controller-friendly settings for ESO Hybrid UI.",
                sortOrder = 200,
            }, gamepadOptions)
        end)

        if not ok then
            ADDON:LogError("Could not register native gamepad settings:", tostring(err))
            return false
        end

        ADDON:LogInfo("Registered native gamepad settings.")
        return true
    end

    local options = {
        {
            type = "description",
            text = "ESO Hybrid UI never changes the active input platform. All gameplay controls and menus remain native gamepad; Hybrid only changes selected HUD visuals.",
        },
        {
            type = "button",
            name = "Recommended ESO settings",
            tooltip = "One click enables Gamepad Mode, Gamepad keybind display, Keyboard Chat, and the cursor when chat receives focus. The settings are saved by ESO and are not reapplied automatically.",
            buttonText = "Apply settings",
            func = function() ADDON:ApplyRecommendedESOSettings() end,
            width = "half",
        },
        {
            type = "dropdown",
            name = "Interface mode",
            tooltip = "Both choices keep ESO native Gamepad Mode, menus, wheels, interactions and controller bindings. Hybrid changes selected gameplay HUD visuals to a compact keyboard-style appearance.",
            choices = { "Gamepad", "Hybrid" },
            choicesValues = { "gamepad", "hybrid" },
            default = "gamepad",
            getFunc = function()
                return ADDON:GetSettings().useHybridUI and "hybrid" or "gamepad"
            end,
            setFunc = function(value)
                local settings = ADDON:GetSettings()
                settings.useHybridUI = value == "hybrid"
                settings.useControllerUI = true
                settings.useGamepadButtons = true
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
            text = "Optional gold donations are appreciated. This opens a mail addressed to @ZOSPlsFix; you choose whether to attach gold and the amount.",
        },
        {
            type = "button",
            name = "Donation mail",
            tooltip = "Opens a mail draft only. ESO Hybrid UI does not attach or modify gold.",
            buttonText = "Open mail",
            func = OpenDonationMail,
            width = "half",
        },
    }

    LibAddonMenu2:RegisterOptionControls(panelName, options)
    RegisterGamepadOptions()
end
