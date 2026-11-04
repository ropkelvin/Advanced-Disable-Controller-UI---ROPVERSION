-- Gameplay action bar presentation. All action execution and binding resolution stay native to ESO.

local ADDON = ESOHybridUI

local KEYBOARD_BUTTON_TEMPLATE = "ZO_ActionButton_Keyboard_Template"
local KEYBOARD_ULTIMATE_TEMPLATE = "ZO_UltimateActionButton_Keyboard_Template"
local KEYBOARD_BACKBAR_TEMPLATE = "ZO_ActionBarTimer_BackBarSlot_Keyboard_Template"
local KEYBOARD_BACKBAR_ULTIMATE_TEMPLATE = "ZO_ActionBarTimer_BackBarSlot_Ultimate_Keyboard_Template"

local GAMEPAD_BUTTON_TEMPLATE = "ZO_ActionButton_Gamepad_Template"
local GAMEPAD_ULTIMATE_TEMPLATE = "ZO_UltimateActionButton_Gamepad_Template"
local GAMEPAD_BACKBAR_TEMPLATE = "ZO_ActionBarTimer_BackBarSlot_Gamepad_Template"
local GAMEPAD_BACKBAR_ULTIMATE_TEMPLATE = "ZO_ActionBarTimer_BackBarSlot_Ultimate_Gamepad_Template"

local KEYBOARD_TIMER_FRAME = "EsoUI/Art/ActionBar/backrow_abilityFrame.dds"
local GAMEPAD_TIMER_FRAME = "EsoUI/Art/ActionBar/Gamepad/gp_backrow_abilityFrame.dds"
local KEYBOARD_BUTTON_BORDER = "EsoUI/Art/ActionBar/abilityFrame64_up.dds"
local KEYBOARD_BUTTON_PRESSED_BORDER = "EsoUI/Art/ActionBar/abilityFrame64_down.dds"

local function IsHybridHUD()
    return ADDON:GetSettings().useHybridUI == true and ADDON:IsNativeGamepadMode()
end

local function RegisterActionButtonLabel(button)
    if not button or not button.buttonText then return end

    local slotNum = button:GetSlot()
    local hotbarCategory = button:GetHotbarCategory()

    local keyboardAction
    local gamepadAction
    if hotbarCategory == HOTBAR_CATEGORY_COMPANION then
        keyboardAction = "COMMAND_PET"
        gamepadAction = "COMMAND_PET"
    elseif hotbarCategory == HOTBAR_CATEGORY_QUICKSLOT_WHEEL then
        keyboardAction = "ACTION_BUTTON_9"
        gamepadAction = "GAMEPAD_ACTION_BUTTON_9"
    else
        keyboardAction = "ACTION_BUTTON_" .. tostring(slotNum)
        gamepadAction = "GAMEPAD_ACTION_BUTTON_" .. tostring(slotNum)
    end

    -- Remove ESO's ultimate-label callback, which hides the glyph in Gamepad
    -- Mode. The per-label preference selects the real gamepad binding while
    -- leaving the action and its input handler untouched.
    ZO_Keybindings_UnregisterLabelForBindingUpdate(button.buttonText)
    ZO_Keybindings_RegisterLabelForBindingUpdate(
        button.buttonText,
        keyboardAction,
        false,
        gamepadAction,
        nil,
        ADDON:ShouldShowControllerPrompts()
    )
end

local function ApplyActionButtonPresentation(button)
    if not IsHybridHUD() or not button or not button.slot then return end

    local slotNum = button:GetSlot()
    local category = button:GetHotbarCategory()
    local template = ZO_ActionBar_IsUltimateSlot(slotNum, category)
        and KEYBOARD_ULTIMATE_TEMPLATE or KEYBOARD_BUTTON_TEMPLATE

    ApplyTemplateToControl(button.slot, template)
    if button.button then
        button.button:SetNormalTexture(KEYBOARD_BUTTON_BORDER)
        button.button:SetPressedTexture(KEYBOARD_BUTTON_PRESSED_BORDER)
    end
    if button.countText then
        button.countText:SetFont("ZoFontGameShadow")
    end

    local decoration = button.slot:GetNamedChild("Decoration")
    if decoration then decoration:SetHidden(false) end

    if button.cooldown then
        button.cooldown:SetHidden(not button.showingCooldown)
    end
    if button.cooldownEdge then button.cooldownEdge:SetHidden(true) end
end

local function RefreshActionButtonCooldown(button)
    if not IsHybridHUD() or not button or not button.cooldown then return end
    button.cooldown:SetHidden(not button.showingCooldown)
    if button.cooldownEdge then button.cooldownEdge:SetHidden(true) end
end

local function ApplyBackbarPresentation(button)
    if not IsHybridHUD() or not button or not button.slot then return end
    local template = ZO_ActionBar_IsUltimateSlot(button.slot.slotNum, button.barType)
        and KEYBOARD_BACKBAR_ULTIMATE_TEMPLATE or KEYBOARD_BACKBAR_TEMPLATE
    ApplyTemplateToControl(button.slot, template)
    if button.frame then button.frame:SetTexture(KEYBOARD_TIMER_FRAME) end
end

local function GetActiveAndBackHotbar()
    local active = GetActiveHotbarCategory()
    if active == HOTBAR_CATEGORY_PRIMARY then
        return active, HOTBAR_CATEGORY_BACKUP
    end
    return active, HOTBAR_CATEGORY_PRIMARY
end

local function ApplyActionBarLayout()
    if not ZO_ActionBar1 or not ZO_ActionBar1WeaponSwap then return end

    if not ADDON:IsNativeGamepadMode() then return end

    local hybrid = IsHybridHUD()
    local firstSlot = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1
    local lastSlot = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + ACTION_BAR_SLOTS_PER_PAGE - 1
    local ultimateSlot = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
    local activeHotbar, backHotbar = GetActiveAndBackHotbar()

    local barWidth = hybrid and 483 or 606
    local abilityOffset = hybrid and 2 or 10
    local ultimateOffset = hybrid and 62 or 65
    local backbarOffset = -17
    local backbarUltimateOffset = hybrid and -20 or -30
    local weaponSwapX = hybrid and 59 or 61
    local weaponSwapY = hybrid and -4 or 4

    ZO_ActionBar1:ClearAnchors()
    ZO_ActionBar1:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, hybrid and 0 or -25)
    ZO_ActionBar1:SetWidth(barWidth)

    ZO_ActionBar1WeaponSwap:SetAnchor(TOPLEFT, nil, nil, weaponSwapX, weaponSwapY)

    local lastButton
    for slot = firstSlot, lastSlot do
        local button = ZO_ActionBar_GetButton(slot, activeHotbar)
        if button then
            local anchorTarget = lastButton and lastButton.slot or ZO_ActionBar1WeaponSwap
            button:ApplyAnchor(anchorTarget, abilityOffset)

            local backbar = ZO_ActionBar_GetButton(slot, backHotbar)
            if backbar then
                backbar:ApplyAnchor(button.slot, backbarOffset)
                if hybrid then ApplyBackbarPresentation(backbar) end
            end
            lastButton = button
        end
    end

    local ultimate = ZO_ActionBar_GetButton(ultimateSlot, activeHotbar)
    if ultimate and lastButton then
        ultimate:SetShowBindingText(hybrid)
        ultimate:ApplyAnchor(lastButton.slot, ultimateOffset)
        if hybrid then ApplyActionButtonPresentation(ultimate) end
    end

    local backbarUltimate = ZO_ActionBar_GetButton(ultimateSlot, backHotbar)
    if backbarUltimate and ultimate then
        backbarUltimate:ApplyAnchor(ultimate.slot, backbarUltimateOffset)
        if hybrid then ApplyBackbarPresentation(backbarUltimate) end
    end

    local companionUltimate = ZO_ActionBar_GetButton(ultimateSlot, HOTBAR_CATEGORY_COMPANION)
    if companionUltimate then
        companionUltimate:SetShowBindingText(hybrid)
        if lastButton then companionUltimate:ApplyAnchor(ZO_ActionBar_GetButton(firstSlot, activeHotbar).slot, ultimateOffset, true) end
        if hybrid then ApplyActionButtonPresentation(companionUltimate) end
    end

    local quickslot = ZO_ActionBar_GetButton(GetCurrentQuickslot(), HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    if quickslot then
        if companionUltimate and DoesUnitExist("companion") and HasActiveCompanion() then
            quickslot:ApplyAnchor(companionUltimate.slot, hybrid and 18 or 45, true)
        else
            quickslot:ApplyAnchor(ZO_ActionBar1WeaponSwap, 5, true)
        end
        if hybrid then ApplyActionButtonPresentation(quickslot) end
    end

    local keybindBackground = ZO_ActionBar1:GetNamedChild("KeybindBG")
    if keybindBackground then
        keybindBackground:SetHidden(not hybrid)
        if hybrid then
            if companionUltimate and DoesUnitExist("companion") and HasActiveCompanion() then
                keybindBackground:SetDimensions(580, 64)
                keybindBackground:SetAnchor(BOTTOM, nil, nil, -34, 0)
            else
                keybindBackground:SetDimensions(512, 64)
                keybindBackground:SetAnchor(BOTTOM, nil, nil, 0, 0)
            end
        end
    end

    local weaponSwap = ZO_ActionBar1:GetNamedChild("WeaponSwap")
    if weaponSwap then
        ZO_WeaponSwap_SetPermanentlyHidden(weaponSwap, not hybrid)
    end

    if not hybrid then
        -- Restore the exact native gamepad templates after leaving Hybrid HUD.
        for slot = firstSlot, lastSlot do
            local button = ZO_ActionBar_GetButton(slot, activeHotbar)
            if button then button:ApplyStyle(GAMEPAD_BUTTON_TEMPLATE) end
            local backbar = ZO_ActionBar_GetButton(slot, backHotbar)
            if backbar then backbar:ApplyStyle(GAMEPAD_BACKBAR_TEMPLATE) end
        end
        if ultimate then ultimate:ApplyStyle(GAMEPAD_ULTIMATE_TEMPLATE) end
        if backbarUltimate then backbarUltimate:ApplyStyle(GAMEPAD_BACKBAR_ULTIMATE_TEMPLATE) end
        if companionUltimate then companionUltimate:ApplyStyle(GAMEPAD_ULTIMATE_TEMPLATE) end
        if quickslot then quickslot:ApplyStyle(GAMEPAD_BUTTON_TEMPLATE) end
    end
end

local function RefreshExistingActionLabels()
    local firstSlot = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1
    local lastSlot = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + ACTION_BAR_SLOTS_PER_PAGE - 1
    for _, category in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
        for slot = firstSlot, lastSlot do
            RegisterActionButtonLabel(ZO_ActionBar_GetButton(slot, category))
        end
        RegisterActionButtonLabel(ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, category))
    end
    RegisterActionButtonLabel(ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, HOTBAR_CATEGORY_COMPANION))
    RegisterActionButtonLabel(ZO_ActionBar_GetButton(GetCurrentQuickslot(), HOTBAR_CATEGORY_QUICKSLOT_WHEEL))
end

local function InstallActionButtonHooks()
    if ADDON.runtime.actionButtonHooksInstalled then return end

    ZO_PostHook(ActionButton, "Initialize", RegisterActionButtonLabel)
    ZO_PostHook(ActionButton, "ApplyStyle", function(button)
        ApplyActionButtonPresentation(button)
        if IsHybridHUD() then ApplyActionBarLayout() end
    end)
    ZO_PostHook(ActionButton, "UpdateCooldown", RefreshActionButtonCooldown)
    ZO_PostHook(ActionButton, "RefreshCooldown", RefreshActionButtonCooldown)
    ZO_PostHook(ZO_ActionBarTimer, "ApplyStyle", function(button)
        ApplyBackbarPresentation(button)
        if IsHybridHUD() then ApplyActionBarLayout() end
    end)

    local eventNamespace = ADDON.ADDON_NAME .. "_ActionBarStyle"
    local function RefreshActionBar()
        RefreshExistingActionLabels()
        ApplyActionBarLayout()
    end
    EVENT_MANAGER:RegisterForEvent(eventNamespace, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, RefreshActionBar)
    EVENT_MANAGER:RegisterForEvent(eventNamespace, EVENT_PLAYER_ACTIVATED, RefreshActionBar)
    EVENT_MANAGER:RegisterForEvent(eventNamespace, EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, RefreshActionBar)
    EVENT_MANAGER:RegisterForEvent(eventNamespace, EVENT_HOTBAR_SLOT_UPDATED, RefreshActionBar)
    EVENT_MANAGER:RegisterForEvent(eventNamespace, EVENT_ACTIVE_COMPANION_STATE_CHANGED, RefreshActionBar)

    ADDON.runtime.actionButtonHooksInstalled = true
end

function ADDON:ApplyActionBar()
    if not ActionButton or not ZO_ActionBarTimer or not ZO_ActionBar1 then return end

    InstallActionButtonHooks()
    RefreshExistingActionLabels()
    ApplyActionBarLayout()
end
