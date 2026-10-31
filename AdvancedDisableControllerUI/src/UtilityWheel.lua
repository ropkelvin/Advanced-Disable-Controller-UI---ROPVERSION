-- Bridges gamepad utility-wheel cycling to ESO's keyboard utility wheel.
-- Update 51 has separate keyboard/gamepad wheel classes and gates the native
-- gamepad cycle actions on IsInGamepadPreferredMode(). We keep the keyboard
-- wheel selected, then add a short-lived gamepad-input action layer.

local ADDON = ADCUI
local BRIDGE_LAYER = "ADCUI_UTILITY_WHEEL_BRIDGE"

ZO_CreateStringId("SI_BINDING_NAME_ADCUI_UTILITY_WHEEL_CYCLE_LEFT", "Cycle utility wheel left (controller)")
ZO_CreateStringId("SI_BINDING_NAME_ADCUI_UTILITY_WHEEL_CYCLE_RIGHT", "Cycle utility wheel right (controller)")

function ADDON:ShouldBridgeUtilityWheelInput()
    return self.runtime.utilityWheelLayerActive == true
        and not self:GetSettings().useControllerUI
        and self:IsNativeGamepadMode()
        and INTERACTIVE_WHEEL_MANAGER ~= nil
        and INTERACTIVE_WHEEL_MANAGER.gamepad == false
end

function ADDON:CycleUtilityWheel(direction)
    if not self:ShouldBridgeUtilityWheelInput() then
        return false
    end

    if not INTERACTIVE_WHEEL_MANAGER or not ZO_INTERACTIVE_WHEEL_TYPE_UTILITY then
        return false
    end

    if direction < 0 then
        return INTERACTIVE_WHEEL_MANAGER:CycleLeft(ZO_INTERACTIVE_WHEEL_TYPE_UTILITY)
    end
    return INTERACTIVE_WHEEL_MANAGER:CycleRight(ZO_INTERACTIVE_WHEEL_TYPE_UTILITY)
end

local function CopyGamepadDefaultBindings(sourceActionName, targetActionName)
    if type(GetActionIndicesFromName) ~= "function"
        or type(GetActionBindingInfo) ~= "function"
        or type(CreateDefaultActionBind) ~= "function"
        or type(GetMaxBindingsPerAction) ~= "function" then
        return false
    end

    local sourceLayer, sourceCategory, sourceAction = GetActionIndicesFromName(sourceActionName)
    local targetLayer, targetCategory, targetAction = GetActionIndicesFromName(targetActionName)
    if not sourceLayer or not targetLayer then
        return false
    end

    local copiedAny = false
    for bindingIndex = 1, GetMaxBindingsPerAction() do
        local key, mod1, mod2, mod3, mod4 =
            GetActionBindingInfo(sourceLayer, sourceCategory, sourceAction, bindingIndex)

        if key == KEY_INVALID and type(GetActionDefaultBindingInfo) == "function" then
            key, mod1, mod2, mod3, mod4 =
                GetActionDefaultBindingInfo(sourceLayer, sourceCategory, sourceAction, bindingIndex)
        end

        if key and key ~= KEY_INVALID and (not IsKeyCodeGamepadKey or IsKeyCodeGamepadKey(key)) then
            local ok = pcall(CreateDefaultActionBind, targetActionName, key, mod1, mod2, mod3, mod4)
            if ok then copiedAny = true end
        end
    end

    return copiedAny
end

local function RemoveBridgeLayer()
    if ADDON.runtime.utilityWheelLayerActive then
        if type(RemoveActionLayerByName) == "function" then
            RemoveActionLayerByName(BRIDGE_LAYER)
        end
        ADDON.runtime.utilityWheelLayerActive = false
    end
end

local function InstallManagerHooks()
    local manager = INTERACTIVE_WHEEL_MANAGER
    if not manager or ADDON.runtime.utilityWheelHooksInstalled then
        return
    end

    local originalStart = manager.StartInteraction
    local originalStop = manager.StopInteraction
    if type(originalStart) ~= "function" or type(originalStop) ~= "function" then
        return
    end

    ADDON.runtime.originalUtilityWheelStart = originalStart
    ADDON.runtime.originalUtilityWheelStop = originalStop

    manager.StartInteraction = function(self, wheelType, ...)
        local started = originalStart(self, wheelType, ...)
        if started
            and wheelType == ZO_INTERACTIVE_WHEEL_TYPE_UTILITY
            and self.gamepad == false
            and ADDON:GetSettings().useControllerUI ~= true
            and ADDON:IsNativeGamepadMode()
            and type(PushActionLayerByName) == "function" then
            PushActionLayerByName(BRIDGE_LAYER)
            ADDON.runtime.utilityWheelLayerActive = true
        end
        return started
    end

    manager.StopInteraction = function(self, wheelType, ...)
        -- Remove our layer before ESO pops the wheel's own action layers.
        RemoveBridgeLayer()
        return originalStop(self, wheelType, ...)
    end

    ADDON.runtime.utilityWheelHooksInstalled = true
end

function ADDON:ApplyUtilityWheel()
    InstallManagerHooks()

    if not self.runtime.utilityWheelDefaultsCopied then
        local left = CopyGamepadDefaultBindings(
            "UTILITY_WHEEL_GAMEPAD_CYCLE_LEFT",
            "ADCUI_UTILITY_WHEEL_CYCLE_LEFT"
        )
        local right = CopyGamepadDefaultBindings(
            "UTILITY_WHEEL_GAMEPAD_CYCLE_RIGHT",
            "ADCUI_UTILITY_WHEEL_CYCLE_RIGHT"
        )

        if left and right then
            self.runtime.utilityWheelDefaultsCopied = true
        end
    end

    if not self.runtime.utilityWheelRetryHook and EVENT_MANAGER and EVENT_PLAYER_ACTIVATED
        and (not self.runtime.utilityWheelHooksInstalled or not self.runtime.utilityWheelDefaultsCopied) then
        EVENT_MANAGER:RegisterForEvent(self.ADDON_NAME .. "_UtilityWheelRetry", EVENT_PLAYER_ACTIVATED, function()
            self:ApplyUtilityWheel()
            if self.runtime.utilityWheelHooksInstalled and self.runtime.utilityWheelDefaultsCopied then
                EVENT_MANAGER:UnregisterForEvent(self.ADDON_NAME .. "_UtilityWheelRetry", EVENT_PLAYER_ACTIVATED)
                self.runtime.utilityWheelRetryHook = false
            end
        end)
        self.runtime.utilityWheelRetryHook = true
    end
end
