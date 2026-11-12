local ADDON = ESOHybridUI
local rt = ADDON.runtime

local LEFT_KEYBIND = "UI_SHORTCUT_LEFT_SHOULDER"
local RIGHT_KEYBIND = "UI_SHORTCUT_RIGHT_SHOULDER"

local descriptors = {
    previous = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        name = "Previous category",
        keybind = LEFT_KEYBIND,
        callback = function()
            ADDON:SelectAdjacentMainMenuCategory(-1)
        end,
    },
    next = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        name = "Next category",
        keybind = RIGHT_KEYBIND,
        callback = function()
            ADDON:SelectAdjacentMainMenuCategory(1)
        end,
    },
}

local function UnwrapDescriptor(value)
    if type(value) == "userdata" then
        return value.keybindButtonDescriptor
    end
    return value
end

local function HasActiveKeybind(keybind)
    local value = KEYBIND_STRIP and KEYBIND_STRIP.keybinds
        and KEYBIND_STRIP.keybinds[keybind]
    return UnwrapDescriptor(value) ~= nil
end

local function CanUseNavigation()
    return ADDON:IsActive()
        and ADDON:IsHybrid()
        and ADDON:IsGamepadModeOn()
        and not ADDON:IsRestrictedSceneActive()
        and MAIN_MENU_KEYBOARD ~= nil
        and MAIN_MENU_KEYBOARD.IsShowing
        and MAIN_MENU_KEYBOARD:IsShowing()
        and MAIN_MENU_KEYBOARD.categoryBar ~= nil
end

function ADDON:SelectAdjacentMainMenuCategory(direction)
    if not CanUseNavigation() or not ZO_CATEGORY_LAYOUT_INFO
        or not ZO_MenuBar_GetSelectedDescriptor
        or not ZO_MenuBar_SelectDescriptor then
        return
    end

    local menu = MAIN_MENU_KEYBOARD
    local categoryBar = menu.categoryBar
    local count = #ZO_CATEGORY_LAYOUT_INFO
    if count == 0 then
        return
    end

    local selectedDescriptor = ZO_MenuBar_GetSelectedDescriptor(categoryBar)
    local selectedIndex = menu.lastCategory or 1
    for index = 1, count do
        local info = ZO_CATEGORY_LAYOUT_INFO[index]
        if info and info.descriptor == selectedDescriptor then
            selectedIndex = index
            break
        end
    end

    for offset = 1, count do
        local index = ((selectedIndex - 1 + direction * offset) % count) + 1
        local info = ZO_CATEGORY_LAYOUT_INFO[index]
        if info and (not info.visible or info.visible()) then
            local button = categoryBar.m_object
                and categoryBar.m_object.ButtonObjectForDescriptor
                and categoryBar.m_object:ButtonObjectForDescriptor(info.descriptor)
            if button and button.m_state ~= BSTATE_DISABLED then
                if ZO_MenuBar_SelectDescriptor(categoryBar, info.descriptor, true) then
                    return
                end
            end
        end
    end
end

function ADDON:DeactivateMainMenuNavigation()
    if not rt.mainMenuNavigationActive or not KEYBIND_STRIP then
        return
    end

    -- The scene manager owns UI teardown during loading. Do not mutate the
    -- keybind strip after EVENT_PLAYER_DEACTIVATED.
    if not ADDON:IsActive() then
        rt.mainMenuNavigationPreviousAdded = false
        rt.mainMenuNavigationNextAdded = false
        rt.mainMenuNavigationActive = false
        return
    end

    if rt.mainMenuNavigationPreviousAdded then
        KEYBIND_STRIP:RemoveKeybindButton(descriptors.previous)
        rt.mainMenuNavigationPreviousAdded = false
    end
    if rt.mainMenuNavigationNextAdded then
        KEYBIND_STRIP:RemoveKeybindButton(descriptors.next)
        rt.mainMenuNavigationNextAdded = false
    end
    rt.mainMenuNavigationActive = false
end

local function ActivateNavigation()
    if not CanUseNavigation() or not KEYBIND_STRIP then
        return
    end

    ADDON:DeactivateMainMenuNavigation()

    -- Never replace a screen's own shoulder-button action. If a keyboard
    -- screen already owns either shortcut, leave that shortcut untouched.
    if not HasActiveKeybind(LEFT_KEYBIND) then
        KEYBIND_STRIP:AddKeybindButton(descriptors.previous)
        rt.mainMenuNavigationPreviousAdded = true
    end
    if not HasActiveKeybind(RIGHT_KEYBIND) then
        KEYBIND_STRIP:AddKeybindButton(descriptors.next)
        rt.mainMenuNavigationNextAdded = true
    end

    rt.mainMenuNavigationActive = rt.mainMenuNavigationPreviousAdded
        or rt.mainMenuNavigationNextAdded
end

local function InstallShoulderConflictHook()
    if rt.mainMenuNavigationConflictHookInstalled
        or not KEYBIND_STRIP
        or not KEYBIND_STRIP.AddKeybindButton then
        return
    end

    ZO_PreHook(KEYBIND_STRIP, "AddKeybindButton", function(strip, descriptor, stateIndex)
        if not descriptor then
            return false
        end

        local keybind = descriptor.keybind
        if keybind == LEFT_KEYBIND and descriptor ~= descriptors.previous
            and rt.mainMenuNavigationPreviousAdded then
            strip:RemoveKeybindButton(descriptors.previous, stateIndex)
            rt.mainMenuNavigationPreviousAdded = false
        elseif keybind == RIGHT_KEYBIND and descriptor ~= descriptors.next
            and rt.mainMenuNavigationNextAdded then
            strip:RemoveKeybindButton(descriptors.next, stateIndex)
            rt.mainMenuNavigationNextAdded = false
        end

        return false
    end)

    -- When a screen-specific shoulder action goes away while the category bar
    -- remains visible, restore the category shortcut for the new screen.
    ZO_PostHook(KEYBIND_STRIP, "RemoveKeybindButton", function(_, descriptor)
        if descriptor and descriptor ~= descriptors.previous and descriptor ~= descriptors.next
            and (descriptor.keybind == LEFT_KEYBIND or descriptor.keybind == RIGHT_KEYBIND) then
            zo_callLater(function()
                ADDON:RefreshMainMenuNavigation()
            end, 0)
        end
    end)

    rt.mainMenuNavigationConflictHookInstalled = true
end

function ADDON:RefreshMainMenuNavigation()
    if not rt.mainMenuNavigationInitialized or not ADDON:IsActive() then
        return
    end

    local fragment = MAIN_MENU_KEYBOARD and MAIN_MENU_KEYBOARD.categoryBarFragment
    if fragment and fragment:IsShowing() and CanUseNavigation() then
        ActivateNavigation()
    else
        self:DeactivateMainMenuNavigation()
    end
end

function ADDON:InitializeMainMenuNavigation()
    if rt.mainMenuNavigationInitialized then
        return
    end

    if not MAIN_MENU_KEYBOARD or not MAIN_MENU_KEYBOARD.categoryBarFragment then
        self:RecordDiagnostic("MAIN_MENU_NAV_UNAVAILABLE",
            "MAIN_MENU_KEYBOARD.categoryBarFragment missing")
        return
    end

    InstallShoulderConflictHook()

    local fragment = MAIN_MENU_KEYBOARD.categoryBarFragment
    fragment:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_FRAGMENT_SHOWN then
            ActivateNavigation()
        elseif newState == SCENE_FRAGMENT_HIDING or newState == SCENE_FRAGMENT_HIDDEN then
            ADDON:DeactivateMainMenuNavigation()
        end
    end)

    rt.mainMenuNavigationInitialized = true
    if fragment:IsShowing() then
        ActivateNavigation()
    end
end
