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

local function ShouldUseControllerActionGlyphs()
    return ADDON:ShouldShowControllerPrompts()
end

local function SetNativeUltimateKeysHidden(button, hidden)
    if not button or not button.slot then return end

    local leftKey = button.slot:GetNamedChild("LeftKeybind")
    local rightKey = button.slot:GetNamedChild("RightKeybind")
    if leftKey then leftKey:SetHidden(hidden) end
    if rightKey then rightKey:SetHidden(hidden) end
end

local function CreateHybridUltimateKey(button, side, keyCode)
    local control = button["hybrid" .. side .. "Key"]
    if control then return control end

    -- Keyboard ultimate templates omit ESO's dedicated two-part key controls.
    -- Create native key textures independently so controller glyphs remain
    -- correct for the active controller type and user bindings.
    local controlName = button.slot:GetName() .. "ESOHybrid" .. side .. "Keybind"
    control = CreateControlFromVirtual(controlName, button.slot, "ZO_KeyTexture")
    control:SetKeyCode(keyCode)
    control:SetDimensions(24, 24)
    control:SetDrawLayer(DL_OVERLAY)

    if side == "Left" then
        control:SetAnchor(TOPRIGHT, button.slot, BOTTOMLEFT, 8, -8)
    else
        control:SetAnchor(TOPLEFT, button.slot, BOTTOMRIGHT, -8, -8)
    end

    button["hybrid" .. side .. "Key"] = control
    return control
end

local function SetHybridUltimateGlyphs(button, visible)
    if not button or not button.slot then return end

    if not visible then
        if button.hybridLeftKey then button.hybridLeftKey:SetHidden(true) end
        if button.hybridRightKey then button.hybridRightKey:SetHidden(true) end
        return
    end

    local isCompanion = button:GetHotbarCategory() == HOTBAR_CATEGORY_COMPANION
    local leftCode = isCompanion and KEY_GAMEPAD_LEFT_STICK or KEY_GAMEPAD_LEFT_SHOULDER
    local rightCode = isCompanion and KEY_GAMEPAD_RIGHT_STICK or KEY_GAMEPAD_RIGHT_SHOULDER

    CreateHybridUltimateKey(button, "Left", leftCode):SetHidden(false)
    CreateHybridUltimateKey(button, "Right", rightCode):SetHidden(false)
    SetNativeUltimateKeysHidden(button, true)
end

local function RegisterControllerActionGlyph(button)
    if not button or not button.buttonText or button.hybridGlyphBindingRegistered then return end

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

    local isUltimate = ZO_ActionBar_IsUltimateSlot(slotNum, hotbarCategory)
    local onUltimateChanged = isUltimate and function(label)
        if ADDON:GetSettings().useHybridUI and ShouldUseControllerActionGlyphs() then
            label:SetHidden(true)
            SetHybridUltimateGlyphs(button, true)
            return
        end

        SetHybridUltimateGlyphs(button, false)
        local showNativeKeys = IsInGamepadPreferredMode()
            and ZO_Keybindings_ShouldShowGamepadKeybind()
        SetNativeUltimateKeysHidden(button, not showNativeKeys)
        label:SetHidden(showNativeKeys)
        if button.leftKey and button.rightKey then
            button:HideKeys(not showNativeKeys)
        end
    end or nil

    ZO_Keybindings_UnregisterLabelForBindingUpdate(button.buttonText)
    ZO_Keybindings_RegisterLabelForBindingUpdate(
        button.buttonText,
        keyboardActionName,
        false,
        gamepadActionName,
        onUltimateChanged,
        ShouldUseControllerActionGlyphs()
    )
    button.hybridGlyphBindingRegistered = true
end

local function RefreshExistingActionGlyphs()
    for _, hotbarCategory in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
        for slotNum = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1,
            ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + ACTION_BAR_SLOTS_PER_PAGE - 1 do
            RegisterControllerActionGlyph(ZO_ActionBar_GetButton(slotNum, hotbarCategory))
        end
        RegisterControllerActionGlyph(
            ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, hotbarCategory))
    end

    RegisterControllerActionGlyph(
        ZO_ActionBar_GetButton(GetCurrentQuickslot(), HOTBAR_CATEGORY_QUICKSLOT_WHEEL))
    RegisterControllerActionGlyph(
        ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, HOTBAR_CATEGORY_COMPANION))
end

local function HideGamepadUltimateDecorations(button)
    if not button or not button.slot then return end
    local controlNames = {
        "Glow",
        "Frame",
        "FillAnimationLeft",
        "FillAnimationRight",
        "ReadyBurst",
        "ReadyLoop",
    }
    for _, name in ipairs(controlNames) do
        local control = button.slot:GetNamedChild(name)
        if control then control:SetHidden(true) end
    end
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
    if button.ApplySwapAnimationStyle then
        button:ApplySwapAnimationStyle()
    end
    if button.countText then
        button.countText:SetFont("ZoFontGameShadow")
    end

    local isUltimate = ZO_ActionBar_IsUltimateSlot(slotNum, category)
    if isUltimate then
        HideGamepadUltimateDecorations(button)
        if ADDON:ShouldShowControllerPrompts() then
            if button.buttonText then button.buttonText:SetHidden(true) end
            -- Apply after the keyboard template: it has no native ultimate
            -- LeftKeybind/RightKeybind children for gamepad prompts.
            SetHybridUltimateGlyphs(button, true)
        else
            SetHybridUltimateGlyphs(button, false)
        end
    end

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
        if lastButton then companionUltimate:ApplyAnchor(ZO_ActionBar_GetButton(firstSlot, activeHotbar).slot, ultimateOffset, true) end
        if hybrid then ApplyActionButtonPresentation(companionUltimate) end
    end

    local quickslot = ZO_ActionBar_GetButton(GetCurrentQuickslot(), HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    if quickslot then
        if companionUltimate and DoesUnitExist("companion") and HasActiveCompanion() then
            quickslot:ApplyAnchor(companionUltimate.slot, 45, true)
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
        if ultimate then
            ultimate:ApplyStyle(GAMEPAD_ULTIMATE_TEMPLATE)
            if ultimate.glow then ultimate.glow:SetHidden(false) end
        end
        if backbarUltimate then backbarUltimate:ApplyStyle(GAMEPAD_BACKBAR_ULTIMATE_TEMPLATE) end
        if companionUltimate then
            companionUltimate:ApplyStyle(GAMEPAD_ULTIMATE_TEMPLATE)
            if companionUltimate.glow then companionUltimate.glow:SetHidden(false) end
        end
        if quickslot then quickslot:ApplyStyle(GAMEPAD_BUTTON_TEMPLATE) end
    end
end

local function InstallActionButtonHooks()
    if ADDON.runtime.actionButtonHooksInstalled then return end

    ZO_PostHook(ActionButton, "Initialize", RegisterControllerActionGlyph)
    ZO_PostHook(ActionButton, "ApplyStyle", function(button, ...)
        ApplyActionButtonPresentation(button)
        RegisterControllerActionGlyph(button)
    end)
    ZO_PostHook(ActionButton, "UpdateCooldown", RefreshActionButtonCooldown)
    ZO_PostHook(ActionButton, "RefreshCooldown", RefreshActionButtonCooldown)
    ZO_PostHook(ZO_ActionBarTimer, "ApplyStyle", ApplyBackbarPresentation)

    -- ESO registers ultimate key presentation during ActionButton:Initialize.
    -- Preserve its OnUltimateChanged callback and dedicated LeftKeybind /
    -- RightKeybind controls; do not replace them with ordinary ButtonText labels.
    ZO_PostHook(ActionButton, "SetUltimateMeter", function(button)
        if IsHybridHUD() and button
            and ZO_ActionBar_IsUltimateSlot(button:GetSlot(), button:GetHotbarCategory()) then
            HideGamepadUltimateDecorations(button)
        end
    end)

    -- ESO's gamepad bounce uses fixed 61/67px dimensions. The keyboard
    -- template is smaller and has no matching native bounce style, so stop
    -- that gamepad-only animation in Hybrid rather than resize the HUD.
    ZO_PostHook(ActionButton, "PlayAbilityUsedBounce", function(button)
        if IsHybridHUD() and button.ResetBounceAnimation then
            button:ResetBounceAnimation()
        end
    end)

    local eventNamespace = ADDON.ADDON_NAME .. "_ActionBarStyle"
    local function RefreshActionBar()
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
    RefreshExistingActionGlyphs()
    ApplyActionBarLayout()
end
