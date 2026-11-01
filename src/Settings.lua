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
        { type = "description", text = "Hybrid is designed for controller play with the compact keyboard-style gameplay HUD: controller button glyphs and native gamepad menus remain available for navigation and actions." },
        { type = "header", name = "General" },
        {
            type = "checkbox",
            name = "Use account-wide settings",
            tooltip = "Use one shared settings profile across every character on this ESO account. Enabling it copies this character's current settings into the account profile the first time.",
            default = false,
            getFunc = function()
                return ADDON.savedVariablesAccountWide
                    and ADDON.savedVariablesAccountWide._esoHybridUseAccountWideSettings == true
                    or false
            end,
            setFunc = function(value) ADDON:SetUseAccountWideSettings(value) end,
        },
        {
            type = "dropdown",
            name = "Interface mode",
            tooltip = "Keyboard keeps the compact keyboard interface everywhere. Gamepad uses ESO's full native controller interface. Hybrid keeps the compact keyboard-style gameplay HUD, forces controller button glyphs, and uses native gamepad menus for navigation and actions.",
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
        SettingCheckbox("Show gamepad button prompts", "Show controller button glyphs on the keyboard-style interface and keybind strip. Hybrid mode always uses controller glyphs; this option controls Keyboard mode.", "useGamepadButtons"),
        {
            type = "checkbox",
            name = "Enable diagnostic logging",
            tooltip = "Record detailed ESOHybridUI debug messages and stack traces through LibDebugLogger. Use /esohybrid_debug on or /esohybrid_debug off. Install LibDebugLogger and DebugLogViewer to inspect and share logs.",
            default = false,
            getFunc = function() return ADDON.runtime.debugLoggingEnabled end,
            setFunc = function(value) ADDON:SetDebugLogging(value) end,
        },

        { type = "header", name = "Prompt fonts" },
        FontDropdown("Reticle button font", "Font used for the interaction button label.", "reticle", fontNames, fontValues),
        FontDropdown("Reticle context font", "Font used for the interaction context text.", "reticleContext", fontNames, fontValues),
        FontDropdown("Stealth icon font", "Font used for stealth and lockpicking prompts.", "stealthIcon", fontNames, fontValues),

        { type = "header", name = "Support the addon" },
        { type = "description", text = "Enjoying ESO Hybrid UI? If you would like to support its continued development, optional in-game gold donations are greatly appreciated." },
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

        { type = "description", text = "Quick commands: /esohybrid, /esohybrid_status, /esohybrid_sv, /esohybrid_buttons, /esohybrid_debug on|off, /esohybrid_dump." },
    }

    LibAddonMenu2:RegisterOptionControls(panelName, options)
end
