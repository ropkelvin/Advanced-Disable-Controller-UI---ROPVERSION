-- Resource bars are independently styleable from the action bar and the rest
-- of the keyboard-style interface.

local ADDON = ESOHybridUI

function ADDON:ShouldUseGamepadResourceBars()
    local settings = self:GetSettings()
    return settings.useGamepadResourceBars == true
        and settings.useControllerUI ~= true
        and self:IsNativeGamepadMode()
end

function ADDON:ApplyResourceBars()
    if self.runtime.resourceBarHooksInstalled then return end

    local target = PLAYER_ATTRIBUTE_BARS
    if not target or type(target.OnGamepadPreferredModeChanged) ~= "function" then
        target = ZO_PlayerAttributeBars
    end
    if not target or type(target.OnGamepadPreferredModeChanged) ~= "function" then
        return
    end

    local original = target.OnGamepadPreferredModeChanged
    self.runtime.originalResourceBarsModeChanged = original

    if type(ZO_PreHook) == "function" then
        -- The ESO callback is a style refresh with no meaningful return value.
        -- Re-run it under the native platform context and suppress the normal
        -- keyboard-style pass only when the optional gamepad bars are enabled.
        ZO_PreHook(target, "OnGamepadPreferredModeChanged", function(control, ...)
            if ADDON:ShouldUseGamepadResourceBars() then
                ADDON:WithNativeGamepadMode(original, control, ...)
                return true
            end
            return false
        end)
    else
        target.OnGamepadPreferredModeChanged = function(control, ...)
            if ADDON:ShouldUseGamepadResourceBars() then
                return ADDON:WithNativeGamepadMode(original, control, ...)
            end
            return original(control, ...)
        end
    end

    self.runtime.resourceBarHooksInstalled = true
end
