-- Controller navigation of ZO_MenuBar tab bars (verified against ESO's
-- zo_menubar.lua): bar.m_object.m_buttons is an ordered list of
-- { buttonControl, poolKey, descriptor }, selected via GetSelectedDescriptor.
--   LB / RB : main menu categories (the category bar)
--   LT / RT : tabs of the current screen (topmost other tab bar)
local ADDON = ESOHybridUI
local rt = ADDON.rt

local function GetCategoryBar()
    return MAIN_MENU_KEYBOARD and MAIN_MENU_KEYBOARD.categoryBar
end

local function IsMenuBar(control)
    local object = control.m_object
    return type(object) == "table" and type(object.m_buttons) == "table"
        and object.GetSelectedDescriptor ~= nil
end

-- Click a tab like a player would (OnMouseUp with upInside) so the bar's
-- player-driven callbacks and click sound run; fall back to the API.
local function Activate(bar, entry)
    local control = entry[1]
    local onUp = control:GetHandler("OnMouseUp")
    if onUp then
        onUp(control, MOUSE_BUTTON_INDEX_LEFT, true, false, false, false, false)
        return true
    end
    return ZO_MenuBar_SelectDescriptor(bar, entry[3]) == true
end

local function CycleBar(bar, direction)
    if not bar or not IsMenuBar(bar) then
        return false
    end
    local object = bar.m_object
    local buttons = object.m_buttons
    local count = #buttons
    if count < 2 then
        return false
    end

    local selected = object:GetSelectedDescriptor()
    local start = direction > 0 and 0 or count + 1
    for i = 1, count do
        if buttons[i][3] == selected then
            start = i
            break
        end
    end

    for offset = 1, count do
        local index = ((start - 1 + direction * offset) % count) + 1
        local entry = buttons[index]
        local control = entry[1]
        local buttonObject = control.m_object
        if not control:IsHidden() and buttonObject
            and buttonObject:GetState() ~= BSTATE_DISABLED
            and entry[3] ~= selected then
            if Activate(bar, entry) then
                return true
            end
        end
    end
    return false
end

local function CountVisible(bar)
    local n = 0
    for _, entry in ipairs(bar.m_object.m_buttons) do
        if not entry[1]:IsHidden() then
            n = n + 1
        end
    end
    return n
end

-- Walks only visible controls and never into a bar. Runs on a button press,
-- not per frame, so the cost is irrelevant.
local function Scan(control, best, depth, excluded)
    if control:IsHidden() then
        return best
    end
    if control ~= excluded and IsMenuBar(control) then
        if CountVisible(control) >= 2 then
            local top, left = control:GetTop(), control:GetLeft()
            if not best or top < best.top or (top == best.top and left < best.left) then
                best = { bar = control, top = top, left = left }
            end
        end
        return best
    end
    if depth < 14 then
        for i = 1, control:GetNumChildren() do
            best = Scan(control:GetChild(i), best, depth + 1, excluded)
        end
    end
    return best
end

local function FindTabBar()
    local best = Scan(GuiRoot, nil, 0, GetCategoryBar())
    return best and best.bar or nil
end

function ADDON:PrintTabProbe()
    local bar = FindTabBar()
    if not bar then
        self:Print("No tab bar found on this screen.")
        return
    end
    self:Print(string.format("Tab bar: %s | visible buttons=%d | selected=%s",
        tostring(bar:GetName()), CountVisible(bar), tostring(bar.m_object:GetSelectedDescriptor())))
end

local previousCategory = {
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    name = "Previous category",
    keybind = "UI_SHORTCUT_LEFT_SHOULDER",
    callback = function() CycleBar(GetCategoryBar(), -1) end,
}
local nextCategory = {
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    name = "Next category",
    keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
    callback = function() CycleBar(GetCategoryBar(), 1) end,
}
local previousTab = {
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    name = "Previous tab",
    keybind = "UI_SHORTCUT_LEFT_TRIGGER",
    callback = function() CycleBar(FindTabBar(), -1) end,
}
local nextTab = {
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    name = "Next tab",
    keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
    callback = function() CycleBar(FindTabBar(), 1) end,
}

local function CategoryBarShowing()
    local fragment = MAIN_MENU_KEYBOARD and MAIN_MENU_KEYBOARD.categoryBarFragment
    return fragment ~= nil and fragment:IsShowing()
end

function ADDON:RefreshNavigation()
    if not rt.navigationInitialized then
        return
    end
    local allowed = rt.inWorld and rt.keyboardPresentation
    local categories = allowed and CategoryBarShowing()
    local tabs = allowed and rt.menuScene
    self:SetKeybind(previousCategory, categories)
    self:SetKeybind(nextCategory, categories)
    self:SetKeybind(previousTab, tabs)
    self:SetKeybind(nextTab, tabs)
end

function ADDON:InitializeNavigation()
    if rt.navigationInitialized then
        return
    end
    local fragment = MAIN_MENU_KEYBOARD and MAIN_MENU_KEYBOARD.categoryBarFragment
    if fragment then
        fragment:RegisterCallback("StateChange", function()
            ADDON:RefreshNavigation()
        end)
    else
        self:Debug("MAIN_MENU_KEYBOARD.categoryBarFragment missing; category navigation unavailable.")
    end
    rt.navigationInitialized = true
end
