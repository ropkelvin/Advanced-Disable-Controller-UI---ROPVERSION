-- Keep the compact keyboard-style action bar while displaying controller glyphs.

local ADDON = ESOHybridUI

local function ShouldUseControllerActionGlyphs()
    return ADDON:ShouldShowControllerPrompts()
end

local function RegisterControllerActionGlyph(button)
    if not button or not button.buttonText
        or type(button.GetSlot) ~= "function"
        or type(button.GetHotbarCategory) ~= "function"
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

    if type(ZO_Keybindings_UnregisterLabelForBindingUpdate) == "function" then
        ZO_Keybindings_UnregisterLabelForBindingUpdate(button.buttonText)
    end
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
        if type(ZO_PostHook) == "function" then
            -- This is a pure after-initialize task; use ESO's hook system
            -- rather than replacing the shared ActionButton method.
            ZO_PostHook(ActionButton, "Initialize", RegisterControllerActionGlyph)
        else
            -- Defensive fallback for clients without the hook helper.
            ActionButton.Initialize = function(self, ...)
                local function Pack(...) return { n = select("#", ...), ... } end
                local results = Pack(originalInitialize(self, ...))
                RegisterControllerActionGlyph(self)
                return unpack(results, 1, results.n)
            end
        end
    end

    ADDON.runtime.actionButtonHooksInstalled = true
end

function ADDON:ApplyActionBar()
    InstallActionButtonHooks()
    RefreshExistingActionGlyphs()
end
