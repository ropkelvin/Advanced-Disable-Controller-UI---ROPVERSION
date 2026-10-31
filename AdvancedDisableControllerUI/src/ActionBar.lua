-- Action bar presentation is independently selectable from the rest of the UI.
-- Uses current ZO_PlatformStyle and ActionButton entry points instead of copying
-- the old 2019 ActionButton implementation.

local ADDON = ADCUI

local ACTION_BAR_TEMPLATES = {
    ZO_ActionButton = true,
    ZO_UltimateActionButton = true,
    ZO_ActionBarTimer_BackBarSlot = true,
    ZO_ActionBarTimer_BackBarSlot_Ultimate = true,
}

local function IsActionBarPlatformStyle(style)
    return style
        and style.keyboardStyle
        and style.gamepadStyle
        and style.keyboardStyle.width == 483
        and style.gamepadStyle.width == 606
        and style.keyboardStyle.showWeaponSwapButton ~= nil
        and style.gamepadStyle.showWeaponSwapButton ~= nil
end

local function InstallTemplateHook()
    if ADDON.runtime.actionBarTemplateHookInstalled or type(ZO_GetPlatformTemplate) ~= "function" then
        return
    end

    local original = ZO_GetPlatformTemplate
    ADDON.runtime.originalGetPlatformTemplate = original

    local wrapper = function(baseTemplate)
        if ACTION_BAR_TEMPLATES[baseTemplate] and ADDON:ShouldUseGamepadActionBar() then
            return baseTemplate .. "_Gamepad_Template"
        end
        return original(baseTemplate)
    end

    ADDON.runtime.getPlatformTemplateWrapper = wrapper
    _G.ZO_GetPlatformTemplate = wrapper
    ADDON.runtime.actionBarTemplateHookInstalled = true
end

local function InstallPlatformStyleHook()
    if ADDON.runtime.actionBarPlatformHookInstalled or not ZO_PlatformStyle then
        return
    end

    local original = ZO_PlatformStyle.Apply
    if type(original) ~= "function" then return end
    ADDON.runtime.originalPlatformStyleApply = original

    local wrapper = function(self)
        if IsActionBarPlatformStyle(self) and ADDON:ShouldUseGamepadActionBar() then
            return self.applyFunction(self.gamepadStyle)
        end
        return original(self)
    end

    ADDON.runtime.platformStyleApplyWrapper = wrapper
    ZO_PlatformStyle.Apply = wrapper
    ADDON.runtime.actionBarPlatformHookInstalled = true
end

local function InstallActionButtonHooks()
    if ADDON.runtime.actionButtonHooksInstalled or type(ActionButton) ~= "table" then
        return
    end

    local methods = {
        "ApplyStyle",
        "HandleSlotChanged",
        "UpdateState",
        "UpdateCooldown",
        "UpdateUsable",
        "Clear",
        "SetCooldownEdgeState",
        "RefreshCooldown",
        "SetupSwapAnimation",
        "ApplySwapAnimationStyle",
        "UpdateUltimateMeter",
    }

    ADDON.runtime.actionButtonOriginals = {}
    for _, methodName in ipairs(methods) do
        local original = ActionButton[methodName]
        if type(original) == "function" then
            ADDON.runtime.actionButtonOriginals[methodName] = original
            ActionButton[methodName] = function(self, ...)
                local callback = ADDON.runtime.actionButtonOriginals[methodName]
                if ADDON:ShouldUseGamepadActionBar() then
                    return ADDON:WithNativeGamepadMode(callback, self, ...)
                end
                return callback(self, ...)
            end
        end
    end

    ADDON.runtime.actionButtonHooksInstalled = true
end

function ADDON:ApplyActionBar()
    InstallTemplateHook()
    InstallPlatformStyleHook()
    InstallActionButtonHooks()
    -- The core refreshes EVENT_GAMEPAD_PREFERRED_MODE_CHANGED after hooks are
    -- installed. ESO's own platform-style manager then reapplies the bar layout.
end
