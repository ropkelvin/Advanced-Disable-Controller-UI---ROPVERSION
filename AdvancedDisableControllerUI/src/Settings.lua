-- LibAddonMenu-2.0 settings panel. Access LAM through its native global; no LibStub.

local ADDON = ADCUI

local function SettingCheckbox(name, tooltip, key, refresh)
    return {
        type = "checkbox",
        name = name,
        tooltip = tooltip,
        default = ADDON.defaults[key],
        getFunc = function() return ADDON:GetSettings()[key] end,
        setFunc = function(value)
            ADDON:GetSettings()[key] = value
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
            CHAT_SYSTEM:AddMessage("[ADCUI] LibAddonMenu-2.0 >= 43 is required; settings panel was skipped.")
        end
        return
    end

    local panelName = "AdvancedDisableControllerUI_Settings"
    LibAddonMenu2:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "Advanced Disable Controller UI",
        author = "RopKelvin",
        version = ADDON.VERSION,
        slashCommand = "/adcui",
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
        { type = "description", text = "Keep controller input while displaying ESO's keyboard-style interface. Each visual feature can be configured independently." },
        { type = "header", name = "General" },
        {
            type = "checkbox",
            name = "Use account-wide settings",
            tooltip = "Copy this character's current settings to the account profile the first time it is enabled, then share that profile across characters.",
            default = false,
            getFunc = function() return ADDON.savedVariables.useAccountWideSettings end,
            setFunc = function(value) ADDON:SetUseAccountWideSettings(value) end,
        },
        {
            type = "checkbox",
            name = "Use native gamepad UI",
            tooltip = "Turn on ESO's full gamepad interface. Disable this to keep the keyboard interface while using a controller.",
            default = false,
            getFunc = function() return ADDON:GetSettings().useControllerUI end,
            setFunc = function(value)
                ADDON:GetSettings().useControllerUI = value
                ADDON:Refresh()
            end,
        },
        SettingCheckbox("Show gamepad button prompts", "Show controller button glyphs on the keyboard-style interface and keybind strip.", "useGamepadButtons"),
        SettingCheckbox("Use gamepad-style action bar", "Use the larger native gamepad action bar while keeping the rest of the interface keyboard-style. Disabled by default for a compact HUD.", "useGamepadActionBar"),
        SettingCheckbox("Use gamepad lockpicking UI", "Temporarily show the native gamepad lockpicking interface while lockpicking.", "useGamepadLockpicking"),
        SettingCheckbox("Shoulder buttons change main-menu categories", "Use LB/RB to move between keyboard main-menu categories.", "enableMainMenuShoulderButtons"),
        SettingCheckbox("Center world map when opened", "Apply the keyboard map's default pan origin when the map opens.", "centerWorldMap"),

        { type = "header", name = "Compass" },
        SettingCheckbox("Enable compass customization", "Enable saved compass size, scale, position and locking.", "enableCompassCustomization", false),
        {
            type = "checkbox",
            name = "Lock compass position",
            tooltip = "Prevent mouse dragging of the compass. Unlock it to reposition the compass.",
            default = false,
            getFunc = function() return ADDON:GetSettings().lockEnabled end,
            setFunc = function(value)
                ADDON:GetSettings().lockEnabled = value
                ADDON:ApplyCompass()
            end,
            disabled = function() return not ADDON:GetSettings().enableCompassCustomization end,
        },
        {
            type = "slider",
            name = "Compass width",
            tooltip = "Width of the compass frame in pixels.",
            min = 400, max = 800, step = 10, default = 550,
            getFunc = function() return ADDON:GetSettings().width end,
            setFunc = function(value)
                ADDON:GetSettings().width = value
                ADDON:ApplyCompass()
            end,
            disabled = function() return not ADDON:GetSettings().enableCompassCustomization end,
        },
        {
            type = "slider",
            name = "Compass height",
            tooltip = "Height of the compass frame in pixels.",
            min = 20, max = 60, step = 1, default = 30,
            getFunc = function() return ADDON:GetSettings().height end,
            setFunc = function(value)
                ADDON:GetSettings().height = value
                ADDON:ApplyCompass()
            end,
            disabled = function() return not ADDON:GetSettings().enableCompassCustomization end,
        },
        {
            type = "slider",
            name = "Compass scale",
            tooltip = "Scale the compass contents.",
            min = 0.6, max = 1.4, step = 0.05, default = 1,
            getFunc = function() return ADDON:GetSettings().scale end,
            setFunc = function(value)
                ADDON:GetSettings().scale = value
                ADDON:ApplyCompass()
            end,
            disabled = function() return not ADDON:GetSettings().enableCompassCustomization end,
        },
        {
            type = "slider",
            name = "Compass pin-label scale",
            tooltip = "Scale the label shown when a pin is centered on the compass.",
            min = 0.6, max = 1.4, step = 0.05, default = 1,
            getFunc = function() return ADDON:GetSettings().pinLabelScale end,
            setFunc = function(value)
                ADDON:GetSettings().pinLabelScale = value
                ADDON:ApplyCompass()
            end,
            disabled = function() return not ADDON:GetSettings().enableCompassCustomization end,
        },
        {
            type = "button",
            name = "Reset compass position",
            tooltip = "Return the compass to its default top-center position.",
            buttonText = "Reset",
            func = function()
                local settings = ADDON:GetSettings()
                settings.point = TOP
                settings.anchorOffsetX = 0
                settings.anchorOffsetY = 40
                ADDON:ApplyCompass()
            end,
            width = "half",
            disabled = function() return not ADDON:GetSettings().enableCompassCustomization end,
        },

        { type = "header", name = "Prompt fonts" },
        FontDropdown("Reticle button font", "Font used for the interaction button label.", "reticle", fontNames, fontValues),
        FontDropdown("Reticle context font", "Font used for the interaction context text.", "reticleContext", fontNames, fontValues),
        FontDropdown("Stealth icon font", "Font used for stealth and lockpicking prompts.", "stealthIcon", fontNames, fontValues),

        { type = "description", text = "Quick commands: /adcui, /adcui_status, /adcui_buttons, /adcui_actionbar, /adcui_compasslock." },
    }

    LibAddonMenu2:RegisterOptionControls(panelName, options)
end
