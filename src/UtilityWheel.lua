-- Intentionally no wheel or player-interaction interception.
-- ESO owns utility wheels, player interaction, trade invites and resurrection.
local ADDON = ESOHybridUI
function ADDON:ShouldBridgeUtilityWheelInput() return false end
function ADDON:CycleUtilityWheel() return false end
function ADDON:ApplyUtilityWheel()
    -- Native gamepad wheel behavior is deliberately untouched.
end
