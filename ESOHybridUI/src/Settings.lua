local ADDON = ESOHybridUI

function ADDON:InitializeSettings()
    if self.rt.settingsInitialized then
        return
    end
    if not LibAddonMenu2 then
        self:Debug("LibAddonMenu-2.0 not found; use /hui hybrid | gamepad.")
        return
    end

    LibAddonMenu2:RegisterAddonPanel("HUIOptions", {
        type = "panel",
        name = "HUI",
        displayName = "HUI - ESO Hybrid UI",
        author = "@ZOSPlsFix",
        version = self.version,
        registerForRefresh = true,
        registerForDefaults = true,
    })

    LibAddonMenu2:RegisterOptionControls("HUIOptions", {
        {
            type = "dropdown",
            name = "Interface mode",
            tooltip = "Hybrid: keyboard-style UI with controller input. Pure Gamepad: ESO's native Gamepad UI.",
            choices = { "Hybrid", "Pure Gamepad" },
            getFunc = function() return self.saved.mode == "hybrid" and "Hybrid" or "Pure Gamepad" end,
            setFunc = function(value) self:SetMode(value == "Hybrid" and "hybrid" or "gamepad") end,
            default = "Hybrid",
        },
        {
            type = "checkbox",
            name = "Controller pointer in menus",
            tooltip = "Left stick moves a cursor, A or L3 clicks, R3 right-clicks, right stick scrolls.",
            getFunc = function() return self.saved.pointerEnabled end,
            setFunc = function(value)
                self.saved.pointerEnabled = value
                self:RefreshPointerScenes()
            end,
            default = true,
        },
        {
            type = "slider",
            name = "Pointer speed",
            min = 1, max = 8, step = 0.5,
            getFunc = function() return self.saved.pointerSpeed end,
            setFunc = function(value) self.saved.pointerSpeed = value end,
            default = 3,
        },
        {
            type = "checkbox",
            name = "Controller button prompts",
            tooltip = "Show controller glyphs instead of keyboard keys in keyboard-style menus.",
            getFunc = function() return self.saved.controllerPrompts end,
            setFunc = function(value) self.saved.controllerPrompts = value end,
            default = true,
        },
        {
            type = "checkbox",
            name = "Debug messages",
            getFunc = function() return self.saved.debug end,
            setFunc = function(value) self.saved.debug = value end,
            default = false,
        },
    })
    self.rt.settingsInitialized = true
end
