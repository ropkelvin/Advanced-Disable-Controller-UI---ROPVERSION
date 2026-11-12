-- ADCUI-style controller navigation for the keyboard main menu.
--
-- ESO already exposes controller shoulder actions as UI_SHORTCUT_LEFT_SHOULDER
-- and UI_SHORTCUT_RIGHT_SHOULDER. Bindings.xml inherits those native bindings
-- and routes them through this small adapter. Category changes are delegated to
-- MAIN_MENU_KEYBOARD so ESO retains its normal scene/confirmation handling.

local ADDON = ESOHybridUI
local rt = ADDON.runtime

function ADDON:CycleKeyboardMainMenuCategory(direction)
    if not rt.keyboardController or not self:IsNativeGamepadMode() then
        return false
    end

    local menu = MAIN_MENU_KEYBOARD
    if not menu or not menu.IsShowing or not menu:IsShowing() then
        return false
    end

    local categoryBar = menu.categoryBar
    if not categoryBar or categoryBar:IsHidden() then
        return false
    end

    local categories = ZO_CATEGORY_LAYOUT_INFO
    local count = #categories
    if count == 0 then
        return false
    end

    local selectedDescriptor = ZO_MenuBar_GetSelectedDescriptor(categoryBar)
    local selectedIndex = 0
    for index = 1, count do
        if categories[index].descriptor == selectedDescriptor then
            selectedIndex = index
            break
        end
    end

    local step = direction < 0 and -1 or 1
    for offset = 1, count do
        local index = ((selectedIndex - 1 + step * offset) % count) + 1
        local category = categories[index]

        if category and not category.hidden and not category.alias
            and (not category.visible or category.visible()) then
            local button = ZO_MenuBar_GetButtonControl(categoryBar, category.descriptor)
            local buttonObject = button and button.m_object

            if button and not button:IsHidden() and buttonObject
                and buttonObject.m_state ~= BSTATE_DISABLED then
                -- This native callback preserves blocking-scene and
                -- confirmation-before-close behaviour.
                menu:OnCategoryClicked(index)
                return true
            end
        end
    end

    return false
end
