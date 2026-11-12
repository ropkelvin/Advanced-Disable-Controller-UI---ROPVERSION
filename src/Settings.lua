local ADDON = ESOHybridUI

function ADDON:InitializeSettings()
    if self.runtime.settingsInitialized then
        return
    end
    if not LibAddonMenu2 then
        self:Debug("LibAddonMenu-2.0 not found; /hui hybrid and /hui gamepad remain available.")
        return
    end

    local panelData = {
        type = "panel",
        name = "HUI",
        displayName = "HUI - ESO Hybrid UI",
        author = "@ZOSPlsFix",
        version = self.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }
    LibAddonMenu2:RegisterAddonPanel("HUIOptions", panelData)
    LibAddonMenu2:RegisterOptionControls("HUIOptions", {
        {
            type = "dropdown",
            name = "Interface mode",
            tooltip = "Hybrid uses keyboard-style UI with controller input. Pure Gamepad leaves ESO's native Gamepad UI unchanged.",
            choices = { "Hybrid", "Pure Gamepad" },
            getFunc = function()
                return self.saved.mode == "hybrid" and "Hybrid" or "Pure Gamepad"
            end,
            setFunc = function(value)
                self:SetMode(value == "Hybrid" and "hybrid" or "gamepad")
            end,
            default = "Hybrid",
        },
        {
            type = "checkbox",
            name = "Controller pointer in keyboard menus",
            tooltip = "Moves a controller cursor through keyboard-style scenes. Click support is screen-dependent; use native keybinds for protected actions.",
            getFunc = function()
                return self.saved.pointerEnabled
            end,
            setFunc = function(value)
                self.saved.pointerEnabled = value
                self:RefreshSceneController()
            end,
            default = true,
        },
        {
            type = "checkbox",
            name = "Debug messages",
            getFunc = function()
                return self.saved.debug
            end,
            setFunc = function(value)
                self.saved.debug = value
            end,
            default = false,
        },
    })
    self.runtime.settingsInitialized = true
end
