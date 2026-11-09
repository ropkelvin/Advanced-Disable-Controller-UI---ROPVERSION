-- Settings: one control list feeds both the keyboard Add-Ons panel (LibAddonMenu)
-- and the optional native controller page (LibGamepadOptions).

local ADDON = ESOHybridUI

local FONT_CHOICES = { "Small", "Default", "Large", "Extra large" }
local FONT_VALUES = {
    reticle = { "ZoFontWinH5", "ZoFontKeybindStripDescription", "ZoFontCallout", "ZoFontCallout2" },
    reticleContext = { "ZoFontWinH5", "ZoInteractionPrompt", "ZoFontCallout", "ZoFontCallout2" },
    stealthIcon = { "ZoFontWinH5", "ZoInteractionPrompt", "ZoFontCallout", "ZoFontCallout2" },
}

local function FontDropdown(name, tooltip, key)
    local values = FONT_VALUES[key]
    return {
        type = "dropdown",
        name = name,
        tooltip = tooltip,
        choices = FONT_CHOICES,
        choicesValues = values,
        default = ADDON.defaults.fonts[key],
        getFunc = function()
            local current = ADDON:GetFont(key)
            for _, value in ipairs(values) do
                if current == value then
                    return current
                end
            end
            -- Older versions offered more sizes; show the default for those
            -- without changing what is saved.
            return ADDON.defaults.fonts[key]
        end,
        setFunc = function(value)
            ADDON:SetFont(key, value)
            ADDON:ApplyPrompts()
        end,
    }
end

local function Checkbox(name, tooltip, key, default, onChange)
    return {
        type = "checkbox",
        name = name,
        tooltip = tooltip,
        default = default,
        getFunc = function()
            local value = ADDON:GetSettings()[key]
            if value == nil then
                return default
            end
            return value == true
        end,
        setFunc = function(value)
            ADDON:GetSettings()[key] = value == true
            if onChange then onChange(value) end
        end,
    }
end

local function OpenDonationMail()
    if not MAIL_SEND or not MAIL_SEND.ComposeMailTo then
        ADDON:Say("The mail composer is not available.")
        return
    end
    -- Only opens an addressed draft; the player chooses any gold and amount.
    MAIL_SEND:ComposeMailTo("@ZOSPlsFix")
end

local function BuildControls(isGamepad)
    local controls = {}
    local function add(control) controls[#controls + 1] = control end

    if isGamepad then
        add({ type = "description", name = "Controller settings",
            text = "Configure ESO Hybrid UI without leaving the gamepad interface. These settings are shared with the keyboard Add-Ons panel." })
        add({ type = "header", name = "Interface" })
    else
        add({ type = "description",
            text = "For controller users. Use the button below once to configure ESO's recommended input and chat settings, then choose your interface style." })
    end

    add({
        type = "button",
        name = "Recommended ESO settings",
        tooltip = "Saves Gamepad Mode, gamepad keybind display, keyboard chat and cursor-on-chat-focus in ESO. Applied only when you press this button.",
        buttonText = "Apply settings",
        func = function() ADDON:ApplyRecommendedESOSettings() end,
    })

    add({
        type = "dropdown",
        name = "Interface mode",
        tooltip = "Gamepad: ESO's full controller interface. Hybrid: compact keyboard-layout HUD and quickslot wheel with controller glyphs, while menus, map, loot and lockpicking stay native gamepad UI. ESO's Gamepad Mode must be On, not Auto.",
        choices = { "Gamepad", "Hybrid" },
        choicesValues = { ADDON.MODE_GAMEPAD, ADDON.MODE_HYBRID },
        default = ADDON.MODE_GAMEPAD,
        getFunc = function() return ADDON:IsHybrid() and ADDON.MODE_HYBRID or ADDON.MODE_GAMEPAD end,
        setFunc = function(value) ADDON:SetMode(value) end,
    })

    add({
        type = "checkbox",
        name = "Account-wide settings",
        tooltip = "Use the same settings on all characters. Current settings are copied to the shared profile the first time this is enabled.",
        default = false,
        getFunc = function()
            local account = ADDON.savedVariablesAccountWide
            return account ~= nil and account._esoHybridUseAccountWideSettings == true
        end,
        setFunc = function(value) ADDON:SetUseAccountWideSettings(value) end,
    })

    add({ type = "header", name = "Hybrid HUD" })
    local refresh = function() ADDON:Refresh() end
    add(Checkbox("Keyboard-style quickslot wheel",
        "In Hybrid, open the quickslot wheel in ESO's keyboard presentation. Turn off if a game update breaks the wheel.",
        "hybridQuickslotWheel", true, refresh))
    add(Checkbox("Keyboard-style player interaction wheel",
        "In Hybrid, open the player-to-player interaction wheel in the keyboard presentation.",
        "hybridPlayerWheel", true, refresh))
    add(Checkbox("Controller glyphs on the action bar",
        "In Hybrid, show controller button glyphs on the keyboard-layout action bar.",
        "hybridActionBarGlyphs", true, refresh))

    add({ type = "header", name = "HUD prompts" })
    add(FontDropdown("Interaction button font", "Size of the button label beside the reticle.", "reticle"))
    add(FontDropdown("Interaction context font", "Size of the interaction description beside the reticle.", "reticleContext"))
    add(FontDropdown("Stealth icon font", "Size of stealth and lockpicking prompt icons.", "stealthIcon"))

    local advanced = {
        Checkbox("Diagnostic logging",
            "Enable detailed debug messages. For saved logs and stack traces install LibDebugLogger and DebugLogViewer.",
            "debugLoggingEnabled", false, function(value) ADDON:SetDebugLogging(value) end),
        Checkbox("Announce load in chat",
            "Print one chat line when the addon loads. Off by default.",
            "announceLoaded", false),
        { type = "description",
            text = "Chat commands: /esohybrid_debug on|off, /esohybrid_dump, /esohybrid_trace on|off|report|reset." },
    }
    if isGamepad then
        add({ type = "header", name = "Advanced" })
        for _, control in ipairs(advanced) do add(control) end
    else
        add({ type = "submenu", name = "Advanced", tooltip = "Troubleshooting options.", controls = advanced })
    end

    add({ type = "header", name = "Support the addon" })
    add({ type = "description",
        text = "Optional gold donations are appreciated. This opens a mail addressed to @ZOSPlsFix; you choose whether to attach gold and the amount." })
    add({
        type = "button",
        name = "Donation mail",
        tooltip = "Opens a mail draft only. ESO Hybrid UI never attaches or changes gold.",
        buttonText = "Open mail",
        func = OpenDonationMail,
    })

    return controls
end

local function RegisterGamepadOptions()
    local library = LibGamepadOptions
    if type(library) ~= "table" or type(library.RegisterAddon) ~= "function" then
        ADDON:LogInfo("LibGamepadOptions is not installed; native gamepad settings are unavailable.")
        return false
    end

    local ok, err = pcall(function()
        library:RegisterAddon("ESOHybridUI", {
            name = "ESO Hybrid UI",
            displayName = "ESO Hybrid UI",
            categoryName = "ESO Hybrid UI",
            directOpen = true,
            showInRoot = false,
            tooltip = "Controller-friendly settings for ESO Hybrid UI.",
            sortOrder = 200,
        }, BuildControls(true))
    end)

    if not ok then
        ADDON:LogError("Could not register native gamepad settings:", tostring(err))
        return false
    end
    ADDON:LogInfo("Registered native gamepad settings.")
    return true
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
    LibAddonMenu2:RegisterOptionControls(panelName, BuildControls(false))
    RegisterGamepadOptions()
end
