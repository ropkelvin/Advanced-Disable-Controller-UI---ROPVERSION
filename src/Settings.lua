-- LibAddonMenu-2.0 settings panel. Access LAM through its native global; no LibStub.

local ADDON = ESOHybridUI

local function SettingCheckbox(name, tooltip, key, refresh)
    return {
        type = "checkbox",
        name = name,
        tooltip = tooltip,
        default = ADDON.defaults[key],
        getFunc = function()
            local settings = ADDON:GetSettings()
            if key == "useGamepadButtons" and settings.useHybridUI then
                return true
            end
            return settings[key]
        end,
        setFunc = function(value)
            local settings = ADDON:GetSettings()
            settings[key] = key == "useGamepadButtons" and settings.useHybridUI and true or value
            if refresh == false then
                if ADDON.ApplyAll then ADDON:ApplyAll() end
            else
                ADDON:Refresh()
            end
        end,
    }
end

local function FontDropdown(name, tooltip, key, choices, values)
    return {
        type = "dropdown",
        name = name,
        tooltip = tooltip,
        choices = choices,
        choicesValues = values,
        default = ADDON.defaults.fonts[key],
        scrollable = true,
        getFunc = function() return ADDON:GetSettings().fonts[key] end,
        setFunc = function(value)
            ADDON:GetSettings().fonts[key] = value
            ADDON:ApplyPrompts()
        end,
    }
end

local function Header(name)
    return { type = "header", name = name }
end

local function Description(text)
    return { type = "description", text = text }
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

    local fontValues = {
        "ZoFontCallout3", "ZoFontCallout2", "ZoFontCenterScreenAnnounceLarge",
        "ZoFontCallout", "ZoFontCenterScreenAnnounceSmall", "ZoFontConversationName",
        "ZoFontHeader4", "ZoFontKeybindStripDescription", "ZoInteractionPrompt",
        "ZoFontConversationOption", "ZoFontDialogKeybindDescription",
        "ZoFontWindowSubtitle", "ZoFontWinH5", "ZoFontGamepad61", "ZoFontGamepad54",
        "ZoFontGamepad45", "ZoFontGamepad42", "ZoFontGamepad36", "ZoFontGamepad34",
        "ZoFontGamepad27", "ZoFontGamepad25", "ZoFontGamepad22", "ZoFontGamepad20",
        "ZoFontGamepad18",
    }
    local fontNames = {
        "Keyboard size 54", "Keyboard size 48", "Keyboard size 40",
        "Keyboard size 36", "Keyboard size 30", "Keyboard size 28",
        "Keyboard size 26", "Keyboard size 25", "Keyboard size 24",
        "Keyboard size 22", "Keyboard size 20", "Keyboard size 18",
        "Keyboard size 16", "Gamepad size 61", "Gamepad size 54",
        "Gamepad size 45", "Gamepad size 42", "Gamepad size 36",
        "Gamepad size 34", "Gamepad size 27", "Gamepad size 25",
        "Gamepad size 22", "Gamepad size 20", "Gamepad size 18",
    }

    local options = {
        Description("A controller-first interface with a compact gameplay HUD. Choose how ESO displays menus, button prompts and interaction text below."),
        Header("Interface"),
        {
            type = "dropdown",
            name = "Interface mode",
            tooltip = "KEYBOARD: compact keyboard-style interface. GAMEPAD: ESO's full native controller interface. HYBRID: compact keyboard-style gameplay HUD with controller button glyphs and native gamepad menus for navigation and actions.",
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
            name = "Use account-wide settings",
            tooltip = "Share one settings profile across every character on this ESO account. The first time you enable this, your current character's settings are copied into the shared profile. Turning it off copies the shared settings back to this character.",
            default = false,
            getFunc = function()
                return ADDON.savedVariablesAccountWide
                    and ADDON.savedVariablesAccountWide._esoHybridUseAccountWideSettings == true
                    or false
            end,
            setFunc = function(value) ADDON:SetUseAccountWideSettings(value) end,
        },

        Header("Controller prompts"),
        Description("Show controller button glyphs while keeping the compact keyboard-style gameplay HUD. Hybrid mode always enables controller prompts; this switch affects Keyboard mode."),
        SettingCheckbox("Show gamepad button prompts", "Display controller glyphs on supported prompts, keybind strips and action buttons. This setting is automatically enabled while Hybrid mode is active.", "useGamepadButtons"),

        Header("Prompt appearance"),
        Description("Adjust the text styles used by interaction prompts. These options change prompt fonts only; they do not enlarge the HUD or change the overall interface mode."),
        FontDropdown("Interaction button font", "Font used for the button label shown beside the reticle.", "reticle", fontNames, fontValues),
        FontDropdown("Interaction context font", "Font used for the interaction description beside the reticle.", "reticleContext", fontNames, fontValues),
        FontDropdown("Stealth and lockpicking icon font", "Font used by stealth and lockpicking prompt icons.", "stealthIcon", fontNames, fontValues),

        Header("Diagnostics"),
        Description("Only enable detailed logging when troubleshooting. For saved logs and stack traces, install LibDebugLogger and DebugLogViewer. You can also use /esohybrid_debug on|off and /esohybrid_dump."),
        {
            type = "checkbox",
            name = "Enable diagnostic logging",
            tooltip = "Record detailed ESO Hybrid UI debug messages and stack traces through LibDebugLogger. Logging takes effect immediately and the setting is saved. Without LibDebugLogger, messages fall back to ESO's debug output and are not collected into a persistent addon log.",
            default = false,
            getFunc = function() return ADDON.runtime.debugLoggingEnabled end,
            setFunc = function(value) ADDON:SetDebugLogging(value) end,
        },

        Header("Support"),
        Description("If this addon has been useful, optional in-game gold donations help support continued development."),
        {
            type = "button",
            name = "Send an in-game gold donation",
            tooltip = "Open a new ESO mail addressed to @ZOSPlsFix.",
            buttonText = "Open mail",
            func = function()
                if MAIL_SEND and MAIL_SEND.ComposeMailTo then
                    MAIL_SEND:ComposeMailTo("@ZOSPlsFix")
                elseif CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
                    CHAT_SYSTEM:AddMessage("[ESO Hybrid UI] The mail composer is not available right now.")
                end
            end,
            width = "half",
        },
        Description("Slash commands: /esohybrid · /esohybrid_status · /esohybrid_sv · /esohybrid_buttons · /esohybrid_debug on|off · /esohybrid_dump"),
    }

    LibAddonMenu2:RegisterOptionControls(panelName, options)
end
