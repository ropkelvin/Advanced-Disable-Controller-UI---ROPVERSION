-- Per-action HUD binding labels. ESO remains responsible for action execution and ultimate controls.

local ADDON = ESOHybridUI

local function RegisterActionButtonLabel(button)
    if not button or not button.buttonText then return end

    local slotNum = button:GetSlot()
    local hotbarCategory = button:GetHotbarCategory()

    -- Leave ultimate and companion-ultimate presentation to ESO's native
    -- templates. In particular, do not invent fixed shoulder-button glyphs.
    if ZO_ActionBar_IsUltimateSlot(slotNum, hotbarCategory) then return end

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

local function RefreshExistingActionLabels()
    for _, category in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
        for slot = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1,
            ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + ACTION_BAR_SLOTS_PER_PAGE - 1 do
            RegisterActionButtonLabel(ZO_ActionBar_GetButton(slot, category))
        end
    end
    RegisterActionButtonLabel(ZO_ActionBar_GetButton(GetCurrentQuickslot(), HOTBAR_CATEGORY_QUICKSLOT_WHEEL))
end

local function InstallActionButtonHook()
    if ADDON.runtime.actionButtonHooksInstalled then return end
    ZO_PostHook(ActionButton, "Initialize", RegisterActionButtonLabel)
    ADDON.runtime.actionButtonHooksInstalled = true
end

function ADDON:ApplyActionBar()
    InstallActionButtonHook()
    RefreshExistingActionLabels()
end
