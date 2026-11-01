-- Keep the keyboard dialog layout while allowing gamepad glyph generation
-- during dialog construction. The explicit isGamepad argument is preserved.

local ADDON = ESOHybridUI

function ADDON:ApplyDialogs()
    if self.runtime.dialogHooksInstalled or type(ZO_Dialogs_ShowDialog) ~= "function" then
        return
    end

    local original = ZO_Dialogs_ShowDialog
    self.runtime.originalShowDialog = original

    local wrapper = function(...)
        local settings = ADDON:GetSettings()
        local shouldUseControllerGlyphs = (settings.useHybridUI or settings.useGamepadButtons)
            and not settings.useControllerUI
            and ADDON:IsNativeGamepadMode()

        -- Forward the complete current/future ESO signature unchanged.
        if shouldUseControllerGlyphs then
            return ADDON:WithNativeGamepadMode(original, ...)
        end
        return original(...)
    end

    self.runtime.showDialogWrapper = wrapper
    _G.ZO_Dialogs_ShowDialog = wrapper
    self.runtime.dialogHooksInstalled = true
end
