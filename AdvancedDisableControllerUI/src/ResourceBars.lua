-- Resource bars are independently styleable from the action bar and the rest
-- of the keyboard-style interface.

local ADDON = ADCUI

function ADDON:ShouldUseGamepadResourceBars()
    local settings = self:GetSettings()
    return settings.useGamepadResourceBars == true
        and settings.useControllerUI ~= true
        and self:IsNativeGamepadMode()
end

function ADDON:ApplyResourceBars()
    if self.runtime.resourceBarHooksInstalled then return end

    local target = PLAYER_ATTRIBUTE_BARS or ZO_PlayerAttributeBars
    if not target or type(target.OnGamepadPreferredModeChanged) ~= "function" then
        return
    end

    local original = target.OnGamepadPreferredModeChanged
    self.runtime.originalResourceBarsModeChanged = original

    target.OnGamepadPreferredModeChanged = function(control, ...)
        if ADDON:ShouldUseGamepadResourceBars() then
            return ADDON:WithNativeGamepadMode(original, control, ...)
        end
        return original(control, ...)
    end

    self.runtime.resourceBarHooksInstalled = true
end
