-- Dialogs built while Hybrid is active get ESO's native gamepad presentation and
-- controller glyphs. Only the construction call runs under the native answer;
-- every argument and return value of the original function is preserved.

local ADDON = ESOHybridUI

local function InstallDialogWrapper()
    local original = _G.ZO_Dialogs_ShowDialog
    if type(original) ~= "function" then
        return false
    end

    _G.ZO_Dialogs_ShowDialog = function(name, data, textParams, isGamepad, ...)
        if ADDON:ShouldShowControllerPrompts() and isGamepad == nil then
            local dialogInfo = ESO_Dialogs and ESO_Dialogs[name]
            if type(dialogInfo) == "table" and dialogInfo.gamepadInfo then
                isGamepad = true
            end
        end

        if ADDON:ShouldShowControllerPrompts() and isGamepad == true then
            return ADDON:WithNativeGamepadMode(original, name, data, textParams, isGamepad, ...)
        end
        return original(name, data, textParams, isGamepad, ...)
    end
    return true
end

function ADDON:ApplyDialogs()
    self:InstallWhenReady("dialogWrapper", InstallDialogWrapper)
end
