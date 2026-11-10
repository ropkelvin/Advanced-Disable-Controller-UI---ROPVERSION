-- Dialogs built while Hybrid is active get ESO's native gamepad presentation and
-- controller glyphs. Only the construction call runs under the native answer;
-- every argument and return value of the original function is preserved.

local ADDON = ESOHybridUI

local function InstallDialogWrapper()
    local original = _G.ZO_Dialogs_ShowDialog
    if type(original) ~= "function" then
        return false
    end

    _G.ZO_Dialogs_ShowDialog = function(...)
        if ADDON:ShouldShowControllerPrompts() then
            return ADDON:WithNativeGamepadMode(original, ...)
        end
        return original(...)
    end
    return true
end

function ADDON:ApplyDialogs()
    self:InstallWhenReady("dialogWrapper", InstallDialogWrapper)
end
