-- Dialogs: intentionally do not wrap ZO_Dialogs_ShowDialog or force Gamepad dialogs.
-- ESO's Gamepad dialog creation API can taint later native callbacks that call
-- protected functions (for example RespondToDestroyRequest). Let ESO choose the
-- dialog template. Keep this module entry point so Core's apply list stays simple.

local ADDON = ESOHybridUI

function ADDON:ApplyDialogs()
    -- No dialog hooks are safe here. Native dialog routing remains ESO-owned.
end
