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
            return ADDON:WithNativeGamepadMode(self.applyFunction, self.gamepadStyle)
        end
        return original(self)
    end

    ADDON.runtime.platformStyleApplyWrapper = wrapper
    ZO_PlatformStyle.Apply = wrapper
    ADDON.runtime.actionBarPlatformHookInstalled = true
end

local function ShouldUseControllerActionGlyphs()
    local settings = ADDON:GetSettings()
    return settings.useGamepadButtons == true
        and settings.useControllerUI ~= true
        and ADDON:IsNativeGamepadMode()
end

local function RegisterControllerActionGlyph(button)
    if not button or not button.buttonText
        or type(ZO_Keybindings_RegisterLabelForBindingUpdate) ~= "function" then
        return
    end

    local slotNum = button:GetSlot()
    local hotbarCategory = button:GetHotbarCategory()
    local keyboardActionName
    local gamepadActionName

    if hotbarCategory == HOTBAR_CATEGORY_COMPANION then
        keyboardActionName = "COMMAND_PET"
        gamepadActionName = "COMMAND_PET"
    elseif hotbarCategory == HOTBAR_CATEGORY_QUICKSLOT_WHEEL then
        keyboardActionName = "ACTION_BUTTON_9"
        gamepadActionName = "GAMEPAD_ACTION_BUTTON_9"
    else
        keyboardActionName = "ACTION_BUTTON_" .. tostring(slotNum)
        gamepadActionName = "GAMEPAD_ACTION_BUTTON_" .. tostring(slotNum)
    end

    ZO_Keybindings_UnregisterLabelForBindingUpdate(button.buttonText)
    local HIDE_UNBOUND = false
    -- Force only the action label to resolve its gamepad binding; the button
    -- control and all action-bar dimensions retain their keyboard style.
    ZO_Keybindings_RegisterLabelForBindingUpdate(
        button.buttonText,
        keyboardActionName,
        HIDE_UNBOUND,
        gamepadActionName,
        nil,
        ShouldUseControllerActionGlyphs()
    )
end

local function RefreshExistingActionGlyphs()
    if type(ZO_ActionBar_GetButton) ~= "function" then return end

    for _, hotbarCategory in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
        for slotNum = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1,
            ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + ACTION_BAR_SLOTS_PER_PAGE - 1 do
            RegisterControllerActionGlyph(ZO_ActionBar_GetButton(slotNum, hotbarCategory))
        end
        RegisterControllerActionGlyph(ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, hotbarCategory))
    end

    RegisterControllerActionGlyph(ZO_ActionBar_GetButton(GetCurrentQuickslot(), HOTBAR_CATEGORY_QUICKSLOT_WHEEL))
    RegisterControllerActionGlyph(ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, HOTBAR_CATEGORY_COMPANION))
end

local function InstallActionButtonHooks()
    if ADDON.runtime.actionButtonHooksInstalled or type(ActionButton) ~= "table" then
        return
    end

    local originalInitialize = ActionButton.Initialize
    if type(originalInitialize) == "function" then
        ADDON.runtime.originalActionButtonInitialize = originalInitialize
        ActionButton.Initialize = function(self, ...)
            originalInitialize(self, ...)
            RegisterControllerActionGlyph(self)
        end
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
        local method = methodName
        local original = ActionButton[method]
        if type(original) == "function" then
            ADDON.runtime.actionButtonOriginals[method] = original
            ActionButton[method] = function(self, ...)
                local callback = ADDON.runtime.actionButtonOriginals[method]
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
    RefreshExistingActionGlyphs()
    -- The core refreshes EVENT_GAMEPAD_PREFERRED_MODE_CHANGED after hooks are
    -- installed. ESO's own platform-style manager then reapplies the bar layout.
end
