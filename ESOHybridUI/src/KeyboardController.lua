-- Controller navigation adapters for keyboard-style ESO menus.
-- LB/RB reuse ESO's native shoulder bindings and delegate to the keyboard menu's
-- own category callback, preserving its scene and confirmation behavior.

local ADDON = ESOHybridUI
local rt = ADDON.runtime

function ADDON:CycleKeyboardMainMenuCategory(direction)
    if not rt.hybrid or not self:IsNativeGamepadMode() then return false end
    local menu = MAIN_MENU_KEYBOARD
    if not menu or not menu.IsShowing or not menu:IsShowing() then return false end

    local bar = menu.categoryBar
    if not bar or bar:IsHidden() then return false end

    local categories = ZO_CATEGORY_LAYOUT_INFO
    local count = categories and #categories or 0
    if count == 0 then return false end

    local descriptor = ZO_MenuBar_GetSelectedDescriptor(bar)
    local selected = 0
    for index = 1, count do
        if categories[index].descriptor == descriptor then
            selected = index
            break
        end
    end

    local step = direction < 0 and -1 or 1
    for offset = 1, count do
        local index = ((selected - 1 + step * offset) % count) + 1
        local category = categories[index]
        if category and not category.hidden and not category.alias
            and (not category.visible or category.visible()) then
            local button = ZO_MenuBar_GetButtonControl(bar, category.descriptor)
            local object = button and button.m_object
            if button and not button:IsHidden() and object
                and object.m_state ~= BSTATE_DISABLED then
                menu:OnCategoryClicked(index)
                return true
            end
        end
    end
    return false
end
