-- Hybrid quickslot (utility) wheel.
--
-- ESO has separate keyboard and gamepad wheel classes. ZO_InteractiveWheel_Manager
-- decides which one to use from IsInGamepadPreferredMode() at the moment
-- StartInteraction runs, and its gamepad cycle actions are gated on the same
-- answer. In Hybrid we therefore:
--   1. start the utility wheel under the "keyboard" answer -> keyboard wheel;
--   2. push a short-lived action layer that re-exposes the controller's cycle
--      buttons while that wheel is open;
--   3. remove the layer in StopInteraction, before ESO pops its own layer.
-- Fishing and target-marker wheels keep ESO's native presentation. The
-- player-to-player wheel has its own hook below.

local ADDON = ESOHybridUI
local rt = ADDON.runtime
local BRIDGE_LAYER = "ESOHybridUI_UTILITY_WHEEL_BRIDGE"

function ADDON:ShouldBridgeUtilityWheelInput()
    return rt.utilityWheelLayerActive == true and self:IsHybrid() and self:IsNativeGamepadMode()
end

function ADDON:CycleUtilityWheel(direction)
    if not self:ShouldBridgeUtilityWheelInput() or not INTERACTIVE_WHEEL_MANAGER then
        return false
    end
    if direction < 0 then
        return INTERACTIVE_WHEEL_MANAGER:CycleLeft(ZO_INTERACTIVE_WHEEL_TYPE_UTILITY)
    end
    return INTERACTIVE_WHEEL_MANAGER:CycleRight(ZO_INTERACTIVE_WHEEL_TYPE_UTILITY)
end

local function CopyGamepadDefaultBindings(sourceActionName, targetActionName)
    local sourceLayer, sourceCategory, sourceAction = GetActionIndicesFromName(sourceActionName)
    local targetLayer = GetActionIndicesFromName(targetActionName)
    if not sourceLayer or not targetLayer then
        return false
    end

    local copiedAny = false
    for bindingIndex = 1, GetMaxBindingsPerAction() do
        -- Prefer the player's current binding, then ESO's default.
        local key, mod1, mod2, mod3, mod4 =
            GetActionBindingInfo(sourceLayer, sourceCategory, sourceAction, bindingIndex)
        if not key or key == KEY_INVALID then
            key, mod1, mod2, mod3, mod4 =
                GetActionDefaultBindingInfo(sourceLayer, sourceCategory, sourceAction, bindingIndex)
        end
        if key and key ~= KEY_INVALID and IsKeyCodeGamepadKey(key) then
            CreateDefaultActionBind(targetActionName, key, mod1, mod2, mod3, mod4)
            copiedAny = true
        end
    end
    return copiedAny
end

local function PushBridgeLayer()
    if not rt.utilityWheelLayerActive then
        PushActionLayerByName(BRIDGE_LAYER)
        rt.utilityWheelLayerActive = true
        ADDON:LogDebug("Wheel bridge layer pushed.")
    end
end

local function RemoveBridgeLayer()
    if rt.utilityWheelLayerActive then
        RemoveActionLayerByName(BRIDGE_LAYER)
        rt.utilityWheelLayerActive = false
        ADDON:LogDebug("Wheel bridge layer removed.")
    end
end

local function WantsKeyboardQuickslot()
    return ADDON:IsHybrid() and ADDON:IsNativeGamepadMode()
        and ADDON:GetSettings().hybridQuickslotWheel ~= false
end

-- StartInteraction returns a started flag (ESO's input binding consumes it) plus
-- anything else; hand every value back unchanged.
local function AfterUtilityStart(started, ...)
    if started then
        PushBridgeLayer()
    end
    return started, ...
end

local function InstallManagerHooks()
    local managerClass = ZO_InteractiveWheel_Manager
    if not managerClass or not INTERACTIVE_WHEEL_MANAGER or type(managerClass.StartInteraction) ~= "function" then
        return false
    end

    -- Hook the class, not the live singleton.
    local originalStart = managerClass.StartInteraction
    managerClass.StartInteraction = function(self, wheelType, ...)
        if wheelType == ZO_INTERACTIVE_WHEEL_TYPE_UTILITY and WantsKeyboardQuickslot() then
            return AfterUtilityStart(ADDON:WithKeyboardWheelMode(originalStart, self, wheelType, ...))
        end
        return originalStart(self, wheelType, ...)
    end

    ZO_PreHook(managerClass, "StopInteraction", function(_, wheelType)
        -- Only the utility wheel owns the bridge layer.
        if wheelType == ZO_INTERACTIVE_WHEEL_TYPE_UTILITY then
            RemoveBridgeLayer()
        end
        return false
    end)
    return true
end

local function InstallPlayerWheelHook()
    local playerToPlayerClass = ZO_PlayerToPlayer
    if not playerToPlayerClass or type(playerToPlayerClass.StartInteraction) ~= "function" then
        return false
    end

    local originalStart = playerToPlayerClass.StartInteraction
    playerToPlayerClass.StartInteraction = function(self, ...)
        if ADDON:IsHybrid() and ADDON:IsNativeGamepadMode() and ADDON:GetSettings().hybridPlayerWheel ~= false then
            return ADDON:WithKeyboardWheelMode(originalStart, self, ...)
        end
        return originalStart(self, ...)
    end
    return true
end

local function CopyBridgeBindings()
    if not rt.utilityWheelLeftCopied then
        rt.utilityWheelLeftCopied = CopyGamepadDefaultBindings(
            "UTILITY_WHEEL_GAMEPAD_CYCLE_LEFT", "ESOHYBRIDUI_UTILITY_WHEEL_CYCLE_LEFT")
    end
    if not rt.utilityWheelRightCopied then
        rt.utilityWheelRightCopied = CopyGamepadDefaultBindings(
            "UTILITY_WHEEL_GAMEPAD_CYCLE_RIGHT", "ESOHYBRIDUI_UTILITY_WHEEL_CYCLE_RIGHT")
    end
    rt.utilityWheelDefaultsCopied = rt.utilityWheelLeftCopied and rt.utilityWheelRightCopied
    return rt.utilityWheelDefaultsCopied
end

function ADDON:ApplyUtilityWheel()
    self:InstallWhenReady("utilityWheelHooks", InstallManagerHooks)
    self:InstallWhenReady("playerWheelHook", InstallPlayerWheelHook)
    self:InstallWhenReady("wheelBindings", CopyBridgeBindings)
    self:InstallWhenReady("wheelCleanup", function()
        -- Never leave the bridge layer behind across a zone change or logout.
        EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_WheelCleanup", EVENT_PLAYER_DEACTIVATED, RemoveBridgeLayer)
        return true
    end)
end
