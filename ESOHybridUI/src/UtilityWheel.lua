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

    local methodName = direction < 0 and "CycleLeft" or "CycleRight"
    local manager = INTERACTIVE_WHEEL_MANAGER
    if type(manager[methodName]) ~= "function" then
        self:LogWarn("Wheel manager has no", methodName, "- cannot cycle the quickslot wheel.")
        return false
    end

    -- The manager picks its keyboard or gamepad wheel from IsInGamepadPreferredMode()
    -- on every call. The open wheel was started under the keyboard answer, so cycling
    -- must be asked under the same answer; otherwise the manager addresses the
    -- (closed) gamepad wheel and the button press does nothing.
    local ok, result = pcall(self.WithKeyboardWheelMode, self, manager[methodName], manager, ZO_INTERACTIVE_WHEEL_TYPE_UTILITY)
    if not ok then
        self:LogWarn("Quickslot wheel", methodName, "failed:", tostring(result))
        return false
    end
    self:LogDebug("Quickslot wheel", methodName, "result:", tostring(result))
    -- The press was ours either way; do not let it fall through to ESO's gated action.
    return true
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

-- Keep the bridge actions in step with the player's own gamepad cycle bindings.
-- ESO's keybindings screen changes bindings with BindKeyToAction /
-- UnbindKeyFromAction and announces every change with EVENT_KEYBINDING_SET and
-- EVENT_KEYBINDING_CLEARED, so we mirror a change of the source action onto the
-- bridge action as it happens. Only changes to the source are mirrored: a
-- binding the player sets directly on a bridge action is never overwritten.
local BRIDGE_MIRRORS = {
    { source = "UTILITY_WHEEL_GAMEPAD_CYCLE_LEFT", target = "ESOHYBRIDUI_UTILITY_WHEEL_CYCLE_LEFT" },
    { source = "UTILITY_WHEEL_GAMEPAD_CYCLE_RIGHT", target = "ESOHYBRIDUI_UTILITY_WHEEL_CYCLE_RIGHT" },
}

local function MirrorBinding(entry, bindingIndex)
    local sourceLayer, sourceCategory, sourceAction = GetActionIndicesFromName(entry.source)
    local targetLayer, targetCategory, targetAction = GetActionIndicesFromName(entry.target)
    if not sourceLayer or not targetLayer then
        return
    end

    local key, mod1, mod2, mod3, mod4 =
        GetActionBindingInfo(sourceLayer, sourceCategory, sourceAction, bindingIndex)
    if key and key ~= KEY_INVALID and IsKeyCodeGamepadKey(key) then
        BindKeyToAction(targetLayer, targetCategory, targetAction, bindingIndex, key, mod1, mod2, mod3, mod4)
    else
        UnbindKeyFromAction(targetLayer, targetCategory, targetAction, bindingIndex)
    end
    ADDON:LogDebug("Mirrored binding", entry.source, "slot", bindingIndex, "->", entry.target)
end

local function OnKeybindingChanged(_, layerIndex, categoryIndex, actionIndex, bindingIndex)
    for _, entry in ipairs(BRIDGE_MIRRORS) do
        local sourceLayer, sourceCategory, sourceAction = GetActionIndicesFromName(entry.source)
        if sourceLayer == layerIndex and sourceCategory == categoryIndex and sourceAction == actionIndex then
            -- ESO limits how many changed bindings can be saved; a refused bind
            -- must never break the keybindings screen.
            local ok, err = pcall(MirrorBinding, entry, bindingIndex)
            if not ok then
                ADDON:LogWarn("Could not mirror binding for", entry.source, "-", tostring(err))
            end
        end
    end
end

local function InstallBindingSync()
    local name = ADDON.ADDON_NAME
    EVENT_MANAGER:RegisterForEvent(name .. "_BindingSet", EVENT_KEYBINDING_SET, OnKeybindingChanged)
    EVENT_MANAGER:RegisterForEvent(name .. "_BindingCleared", EVENT_KEYBINDING_CLEARED, OnKeybindingChanged)
    return true
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
    self:InstallWhenReady("wheelBindingSync", InstallBindingSync)
    self:InstallWhenReady("wheelCleanup", function()
        -- Never leave the bridge layer behind across a zone change or logout.
        EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_WheelCleanup", EVENT_PLAYER_DEACTIVATED, RemoveBridgeLayer)
        return true
    end)
end
