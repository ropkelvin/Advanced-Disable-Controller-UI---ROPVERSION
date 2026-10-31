-- Lightweight smoke tests for Core.lua with ESO API stubs.
-- This does not replace in-client integration testing.

TOP = 1
BOTTOM = 2
SETTING_TYPE_GAMEPAD = 1
GAMEPAD_SETTING_INPUT_PREFERRED_MODE = 2
INPUT_PREFERRED_MODE_ALWAYS_KEYBOARD = 0
INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD = 1
INPUT_PREFERRED_MODE_AUTOMATIC = 2

EVENT_ADD_ON_LOADED = "EVENT_ADD_ON_LOADED"
EVENT_BEGIN_LOCKPICK = "EVENT_BEGIN_LOCKPICK"
EVENT_LOCKPICK_SUCCESS = "EVENT_LOCKPICK_SUCCESS"
EVENT_LOCKPICK_FAILED = "EVENT_LOCKPICK_FAILED"
EVENT_LOCKPICK_BROKE = "EVENT_LOCKPICK_BROKE"
EVENT_GAMEPAD_PREFERRED_MODE_CHANGED = "EVENT_GAMEPAD_PREFERRED_MODE_CHANGED"

local nativeMode = INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD
local function NativeIsGamepadPreferred()
    return nativeMode == INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD
end
IsInGamepadPreferredMode = NativeIsGamepadPreferred

GetSetting = function(_, setting)
    assert(setting == GAMEPAD_SETTING_INPUT_PREFERRED_MODE)
    return tostring(nativeMode)
end

local events = {}
EVENT_MANAGER = {
    RegisterForEvent = function(_, name, event, callback)
        events[event] = events[event] or {}
        table.insert(events[event], { name = name, callback = callback })
    end,
    UnregisterForEvent = function(_, name, event)
        local registered = events[event] or {}
        for index = #registered, 1, -1 do
            if registered[index].name == name then
                table.remove(registered, index)
            end
        end
    end,
}

SetSetting = function(_, setting, value)
    assert(setting == GAMEPAD_SETTING_INPUT_PREFERRED_MODE)
    nativeMode = tonumber(value)
    for _, item in ipairs(events[EVENT_GAMEPAD_PREFERRED_MODE_CHANGED] or {}) do
        item.callback(EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, NativeIsGamepadPreferred())
    end
end

local function CopyDefaults(defaults)
    local copy = {}
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            copy[key] = CopyDefaults(value)
        else
            copy[key] = value
        end
    end
    return copy
end

local accountSaved
local characterSaved
ZO_SavedVars = {
    NewAccountWide = function(_, _, _, _, defaults)
        accountSaved = accountSaved or CopyDefaults(defaults)
        return accountSaved
    end,
    NewCharacterIdSettings = function(_, _, _, _, defaults)
        characterSaved = characterSaved or CopyDefaults(defaults)
        return characterSaved
    end,
}

SLASH_COMMANDS = {}
CHAT_SYSTEM = { AddMessage = function() end }

dofile("AdvancedDisableControllerUI/src/Defaults.lua")
dofile("AdvancedDisableControllerUI/src/Core.lua")

for _, event in ipairs({
    EVENT_ADD_ON_LOADED,
    EVENT_BEGIN_LOCKPICK,
    EVENT_LOCKPICK_SUCCESS,
    EVENT_LOCKPICK_FAILED,
    EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,
}) do
    events[event] = events[event] or {}
end

for _, item in ipairs(events[EVENT_ADD_ON_LOADED]) do
    item.callback(EVENT_ADD_ON_LOADED, ADCUI.ADDON_NAME)
end

assert(ADCUI.runtime.initialized == true, "addon did not initialize")
assert(ADCUI:GetSettings().useGamepadActionBar == false, "compact action bar should be default")
assert(NativeIsGamepadPreferred() == true, "native controller preference unexpectedly changed")
assert(IsInGamepadPreferredMode() == false, "keyboard UI override was not installed")
assert(nativeMode == INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD, "refresh did not restore original input mode")

SLASH_COMMANDS["/adcui"]()
assert(ADCUI:GetSettings().useControllerUI == true, "UI toggle did not enable native gamepad UI")
assert(IsInGamepadPreferredMode() == true, "native gamepad UI toggle failed")
assert(NativeIsGamepadPreferred() == true, "UI toggle changed native input preference")

SLASH_COMMANDS["/adcui"]()
assert(ADCUI:GetSettings().useControllerUI == false, "UI toggle did not restore keyboard UI")
assert(IsInGamepadPreferredMode() == false, "keyboard UI toggle failed")

for _, item in ipairs(events[EVENT_BEGIN_LOCKPICK]) do
    item.callback(EVENT_BEGIN_LOCKPICK)
end
assert(ADCUI.runtime.isLockpicking == true, "lockpicking begin was not handled")
assert(IsInGamepadPreferredMode() == true, "native lockpicking UI was not enabled")

for _, item in ipairs(events[EVENT_LOCKPICK_SUCCESS]) do
    item.callback(EVENT_LOCKPICK_SUCCESS)
end
assert(ADCUI.runtime.isLockpicking == false, "lockpicking break was not handled")
assert(IsInGamepadPreferredMode() == false, "keyboard UI was not restored after lockpicking")

characterSaved.useGamepadButtons = false
ADCUI:SetUseAccountWideSettings(true)
assert(ADCUI:GetSettings() == accountSaved, "account-wide profile was not selected")
assert(ADCUI:GetSettings().useGamepadButtons == false, "first account-wide enable did not copy character settings")

accountSaved.useGamepadButtons = true
ADCUI:SetUseAccountWideSettings(false)
assert(ADCUI:GetSettings() == characterSaved, "character profile was not restored")
assert(characterSaved.useGamepadButtons == true, "account-wide settings were not copied back to character")

nativeMode = INPUT_PREFERRED_MODE_ALWAYS_KEYBOARD
assert(IsInGamepadPreferredMode() == false, "keyboard-preferred mode should remain keyboard")


-- Action-bar isolation smoke test: only the bar uses native gamepad styling.
local originalTemplate = function(base)
    return base .. (IsInGamepadPreferredMode() and "_Gamepad_Template" or "_Keyboard_Template")
end
ZO_GetPlatformTemplate = originalTemplate
ZO_PlatformStyle = {
    Apply = function(self)
        return self.applyFunction(self:GetStyle())
    end,
}
ActionButton = {
    ApplyStyle = function(self, template)
        self.template = template
        self.nativeModeDuringApply = IsInGamepadPreferredMode()
    end,
}

local actionButton = setmetatable({}, { __index = ActionButton })
local actionBarStyle = {
    keyboardStyle = { width = 483, showWeaponSwapButton = true },
    gamepadStyle = { width = 606, showWeaponSwapButton = false },
    GetStyle = function(self)
        return IsInGamepadPreferredMode() and self.gamepadStyle or self.keyboardStyle
    end,
}
actionBarStyle.applyFunction = function(style)
    actionBarStyle.appliedStyle = style
    local template = ZO_GetPlatformTemplate("ZO_ActionButton")
    actionButton:ApplyStyle(template)
end

dofile("AdvancedDisableControllerUI/src/ActionBar.lua")
ADCUI.savedVariables.useControllerUI = false
ADCUI.savedVariables.useGamepadActionBar = true
nativeMode = INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD
ADCUI:ApplyActionBar()
ZO_PlatformStyle.Apply(actionBarStyle)
assert(actionBarStyle.appliedStyle == actionBarStyle.gamepadStyle, "gamepad action bar style was not selected")
assert(actionButton.template == "ZO_ActionButton_Gamepad_Template", "gamepad action button template was not selected")
assert(actionButton.nativeModeDuringApply == true, "action bar did not temporarily use native gamepad mode")
assert(ADCUI.runtime.forceNativeModeDepth == 0, "native mode scope was not restored")

ADCUI.savedVariables.useGamepadActionBar = false
ZO_PlatformStyle.Apply(actionBarStyle)
assert(actionBarStyle.appliedStyle == actionBarStyle.keyboardStyle, "keyboard action bar style was not restored")
assert(actionButton.template == "ZO_ActionButton_Keyboard_Template", "keyboard action button template was not restored")
assert(actionButton.nativeModeDuringApply == false, "keyboard action bar unexpectedly used gamepad mode")


-- Dialogs keep the keyboard dialog while using controller glyph generation.
local dialogNativeMode
ZO_Dialogs_ShowDialog = function(name, data, textParams, isGamepad)
    dialogNativeMode = IsInGamepadPreferredMode()
    return name .. "_shown"
end
dofile("AdvancedDisableControllerUI/src/Dialogs.lua")
ADCUI.savedVariables.useGamepadButtons = true
ADCUI.savedVariables.useControllerUI = false
nativeMode = INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD
ADCUI:ApplyDialogs()
assert(ZO_Dialogs_ShowDialog("TEST_DIALOG") == "TEST_DIALOG_shown", "dialog wrapper did not return original result")
assert(dialogNativeMode == true, "dialog construction did not temporarily expose gamepad prompt mode")
assert(IsInGamepadPreferredMode() == false, "dialog wrapper did not restore keyboard UI mode")
ADCUI.savedVariables.useGamepadButtons = false
ZO_Dialogs_ShowDialog("TEST_DIALOG")
assert(dialogNativeMode == false, "dialog wrapper forced gamepad prompts while disabled")

-- Prompt styles and the original descriptors must be restored exactly.
KEYBIND_STRIP_ALIGN_RIGHT = 2
KEYBIND_STRIP_ALIGN_LEFT = 1
KEYBIND_STRIP_STANDARD_STYLE = { alwaysPreferGamepadMode = false }
local keybindPreHooks = {}
ZO_PreHook = function(object, method, callback)
    keybindPreHooks[method] = callback
end
local activeKeybindGroups = {}
KEYBIND_STRIP = {
    SetStyle = function(self, style) self.style = style end,
    AddKeybindButtonGroup = function(self, group)
        self.lastGroup = group
        activeKeybindGroups[group] = true
    end,
    RemoveKeybindButtonGroup = function(self, group)
        activeKeybindGroups[group] = nil
    end,
}
QUEST_JOURNAL_KEYBOARD = { keybindStripDescriptor = { [2] = { keybind = "QUEST_ORIGINAL" } } }
ZONE_STORIES_KEYBOARD = { keybindStripDescriptor = { keybind = "STORY_ORIGINAL" } }
GUILD_HOME = { keybindStripDescriptor = { [1] = { keybind = "GUILD_ORIGINAL" } } }
LOCK_PICK = { keybindStripDescriptor = { {}, {}, {}, {} } }

dofile("AdvancedDisableControllerUI/src/Prompts.lua")
ADCUI.savedVariables.useGamepadButtons = true
ADCUI:ApplyPrompts()
assert(KEYBIND_STRIP_STANDARD_STYLE.alwaysPreferGamepadMode == true, "gamepad glyph style was not enabled")
assert(QUEST_JOURNAL_KEYBOARD.keybindStripDescriptor[2].keybind == "UI_SHORTCUT_SECONDARY", "quest journal prompt was not remapped")
assert(ZONE_STORIES_KEYBOARD.keybindStripDescriptor.keybind == "UI_SHORTCUT_SECONDARY", "zone story prompt was not remapped")
assert(GUILD_HOME.keybindStripDescriptor[1].keybind == "UI_SHORTCUT_LEFT_STICK", "guild prompt was not remapped")
assert(LOCK_PICK.keybindStripDescriptor[4].alignment == KEYBIND_STRIP_ALIGN_RIGHT, "lockpick prompt alignment was not changed")

local stackGroup = { { keybind = "UI_SHORTCUT_STACK_ALL" } }
local currentSceneName = "inventory"
SCENE_MANAGER = {
    GetCurrentSceneName = function() return currentSceneName end,
    RegisterCallback = function(self, event, callback) self.sceneCallback = callback end,
}
keybindPreHooks.AddKeybindButtonGroup(KEYBIND_STRIP, stackGroup)
assert(stackGroup[1].keybind == "UI_SHORTCUT_LEFT_STICK", "stack-all prompt was not mapped for controller")
ADCUI.savedVariables.useGamepadButtons = false
ADCUI:ApplyPrompts()
keybindPreHooks.AddKeybindButtonGroup(KEYBIND_STRIP, stackGroup)
assert(stackGroup[1].keybind == "UI_SHORTCUT_STACK_ALL", "stack-all prompt was not restored")
assert(KEYBIND_STRIP_STANDARD_STYLE.alwaysPreferGamepadMode == false, "gamepad glyph style was not disabled")
assert(QUEST_JOURNAL_KEYBOARD.keybindStripDescriptor[2].keybind == "QUEST_ORIGINAL", "quest prompt original was not restored")
assert(ZONE_STORIES_KEYBOARD.keybindStripDescriptor.keybind == "STORY_ORIGINAL", "zone story original was not restored")
assert(GUILD_HOME.keybindStripDescriptor[1].keybind == "GUILD_ORIGINAL", "guild prompt original was not restored")
assert(LOCK_PICK.keybindStripDescriptor[4].alignment == nil, "nil lockpick alignment was not restored")

-- Compass sizing, movement locking and reset-to-original behavior.
MOUSE_BUTTON_INDEX_LEFT = 1
EVENT_GLOBAL_MOUSE_UP = "EVENT_GLOBAL_MOUSE_UP"
ZO_PreHookHandler = function(control, handler, callback)
    control.hooks = control.hooks or {}
    control.hooks[handler] = callback
end
local function MakeControl(width, height, scale)
    local control = { width = width, height = height, scale = scale or 1 }
    function control:SetScale(value) self.scale = value end
    function control:GetScale() return self.scale end
    function control:SetDimensions(w, h) self.width, self.height = w, h end
    function control:GetDimensions() return self.width, self.height end
    return control
end
GuiRoot = {}
local pinLabel = MakeControl(100, 20, 1)
local leftEdge = MakeControl(18, 39, 1)
local rightEdge = MakeControl(18, 39, 1)
local compass = MakeControl(580, 39, 1)
function compass:GetNamedChild(name)
    if name == "CenterOverPinLabel" then return pinLabel end
end
local compassFrame = MakeControl(600, 39, 1)
local frameAnchor = { TOP, GuiRoot, TOP, 0, 40 }
function compassFrame:GetAnchor()
    return nil, frameAnchor[1], frameAnchor[2], frameAnchor[3], frameAnchor[4], frameAnchor[5]
end
function compassFrame:ClearAnchors() end
function compassFrame:SetAnchor(point, relativeTo, relativePoint, x, y)
    frameAnchor = { point, relativeTo, relativePoint, x, y }
end
function compassFrame:SetClampedToScreen(value) self.clamped = value end
function compassFrame:SetMovable(value) self.movable = value end
function compassFrame:SetMouseEnabled(value) self.mouseEnabled = value end
function compassFrame:StartMoving() self.moving = true end
function compassFrame:StopMovingOrSizing() self.moving = false end
function compassFrame:GetNamedChild(name)
    if name == "Left" then return leftEdge end
    if name == "Right" then return rightEdge end
end
ZO_CompassFrame = compassFrame
ZO_Compass = compass

dofile("AdvancedDisableControllerUI/src/Compass.lua")
ADCUI.savedVariables.enableCompassCustomization = true
ADCUI.savedVariables.width = 560
ADCUI.savedVariables.height = 32
ADCUI.savedVariables.scale = 1.1
ADCUI.savedVariables.pinLabelScale = 0.9
ADCUI.savedVariables.lockEnabled = false
ADCUI:ApplyCompass()
assert(compassFrame.width == 560 and compassFrame.height == 32, "compass dimensions were not applied")
assert(compass.scale == 1.1 and pinLabel.scale == 0.9, "compass scale settings were not applied")
assert(compassFrame.movable == true and compassFrame.mouseEnabled == true, "unlocked compass is not draggable")
assert(compassFrame.clamped == true, "compass is not clamped to the screen")
assert(compassFrame.hooks and compassFrame.hooks.OnMouseDown and compassFrame.hooks.OnMouseUp, "compass drag handlers were not installed")
compassFrame.hooks.OnMouseDown(compassFrame, MOUSE_BUTTON_INDEX_LEFT)
assert(compassFrame.moving == true, "unlocked compass did not start moving")
frameAnchor = { BOTTOM, GuiRoot, BOTTOM, 12, -45 }
compassFrame.hooks.OnMouseUp(compassFrame, MOUSE_BUTTON_INDEX_LEFT)
assert(compassFrame.moving == false, "compass did not stop moving")
assert(ADCUI.savedVariables.point == BOTTOM and ADCUI.savedVariables.anchorOffsetX == 12 and ADCUI.savedVariables.anchorOffsetY == -45, "dragged compass position was not saved")

ADCUI.savedVariables.lockEnabled = true
ADCUI:ApplyCompass()
assert(compassFrame.movable == false and compassFrame.mouseEnabled == false, "compass lock did not disable dragging")
compassFrame.hooks.OnMouseDown(compassFrame, MOUSE_BUTTON_INDEX_LEFT)
assert(compassFrame.moving == false, "locked compass still started moving")
ADCUI.savedVariables.enableCompassCustomization = false
ADCUI:ApplyCompass()
assert(compassFrame.width == 600 and compassFrame.height == 39, "compass reset did not restore original dimensions")
assert(compass.scale == 1 and pinLabel.scale == 1, "compass reset did not restore original scales")

-- World-map pan reset uses the current PanAndZoom API.
SCENE_SHOWN = "SCENE_SHOWN"
local worldMapCallback
WORLD_MAP_SCENE = {
    RegisterCallback = function(self, event, callback) worldMapCallback = callback end,
}
local mapCalls = { clearLock = 0, clearOffset = 0, delta = nil }
local map = {
    ClearLockPoint = function() mapCalls.clearLock = mapCalls.clearLock + 1 end,
    ClearTargetOffset = function() mapCalls.clearOffset = mapCalls.clearOffset + 1 end,
    AddTargetOffsetDelta = function(_, x, y) mapCalls.delta = { x, y } end,
}
ZO_WorldMap_GetPanAndZoom = function() return map end
dofile("AdvancedDisableControllerUI/src/WorldMap.lua")
ADCUI.savedVariables.centerWorldMap = true
ADCUI:ApplyWorldMap()
worldMapCallback("showing", SCENE_SHOWN)
assert(mapCalls.clearLock == 1 and mapCalls.clearOffset == 1, "world-map pan/lock target was not cleared")
assert(mapCalls.delta and mapCalls.delta[1] == 0 and mapCalls.delta[2] == 0, "world-map center offset was not re-established")

-- Main-menu shoulder navigation skips hidden and unavailable categories.
local menuCategories = {}
MAIN_MENU_KEYBOARD = {
    lastCategory = 1,
    categoryInfo = { [1] = {}, [2] = {}, [3] = {}, [4] = {} },
    sceneInfo = { mainMenu = { category = 1 } },
    ShowCategory = function(self, category)
        self.lastCategory = category
        self.lastShownCategory = category
    end,
}
ZO_CATEGORY_LAYOUT_INFO = {
    [1] = {},
    [2] = {},
    [3] = { hideCategoryBar = true },
    [4] = { visible = function() return false end },
}
SCENE_MANAGER.GetCurrentSceneName = function() return "mainMenu" end
dofile("AdvancedDisableControllerUI/src/MainMenu.lua")
ADCUI.savedVariables.enableMainMenuShoulderButtons = true
ADCUI.savedVariables.useControllerUI = false
ADCUI:ApplyMainMenu()
assert(ADCUI.runtime.menuGroupActive == true, "main-menu shoulder group was not registered")
local menuGroup = KEYBIND_STRIP.lastGroup
assert(menuGroup and menuGroup[1].visible() and menuGroup[2].visible(), "shoulder prompts were not visible in a valid category")
menuGroup[2].callback()
assert(MAIN_MENU_KEYBOARD.lastShownCategory == 2, "next-category shoulder action failed")
menuGroup[2].callback()
assert(MAIN_MENU_KEYBOARD.lastShownCategory == 1, "category navigation did not skip hidden categories")
ADCUI.savedVariables.enableMainMenuShoulderButtons = false
ADCUI:ApplyMainMenu()
assert(ADCUI.runtime.menuGroupActive == false, "main-menu shoulder group was not removed when disabled")


-- Current utility-wheel bridge keeps the keyboard wheel but accepts gamepad
-- shoulder-cycle inputs through a short-lived addon action layer.
ZO_INTERACTIVE_WHEEL_TYPE_UTILITY = 1
KEY_INVALID = 0
local pushedLayers, removedLayers, createdBinds = {}, {}, {}
PushActionLayerByName = function(name) pushedLayers[#pushedLayers + 1] = name end
RemoveActionLayerByName = function(name) removedLayers[#removedLayers + 1] = name end
GetActionIndicesFromName = function(name)
    if name == "UTILITY_WHEEL_GAMEPAD_CYCLE_LEFT" then return 1, 1, 1 end
    if name == "UTILITY_WHEEL_GAMEPAD_CYCLE_RIGHT" then return 1, 1, 2 end
    if name == "ADCUI_UTILITY_WHEEL_CYCLE_LEFT" then return 2, 1, 1 end
    if name == "ADCUI_UTILITY_WHEEL_CYCLE_RIGHT" then return 2, 1, 2 end
end
GetMaxBindingsPerAction = function() return 1 end
GetActionBindingInfo = function(layer, category, action)
    if action == 1 then return 101, KEY_INVALID, KEY_INVALID, KEY_INVALID, KEY_INVALID end
    if action == 2 then return 102, KEY_INVALID, KEY_INVALID, KEY_INVALID, KEY_INVALID end
    return KEY_INVALID
end
GetActionDefaultBindingInfo = function() return KEY_INVALID end
IsKeyCodeGamepadKey = function() return true end
CreateDefaultActionBind = function(name, key)
    createdBinds[#createdBinds + 1] = { name = name, key = key }
    return true
end
ZO_CreateStringId = function() end
INTERACTIVE_WHEEL_MANAGER = {
    StartInteraction = function(self, wheelType)
        self.gamepad = IsInGamepadPreferredMode()
        self.currentWheelType = wheelType
        return true
    end,
    StopInteraction = function(self, wheelType)
        self.currentWheelType = nil
        return true
    end,
    CycleLeft = function(self)
        self.lastCycle = "left"
        return true
    end,
    CycleRight = function(self)
        self.lastCycle = "right"
        return true
    end,
}
dofile("AdvancedDisableControllerUI/src/UtilityWheel.lua")
ADCUI.savedVariables.useControllerUI = false
nativeMode = INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD
ADCUI:ApplyUtilityWheel()
assert(#createdBinds == 2, "gamepad wheel default bindings were not copied")
assert(INTERACTIVE_WHEEL_MANAGER:StartInteraction(ZO_INTERACTIVE_WHEEL_TYPE_UTILITY) == true, "utility wheel did not start")
assert(INTERACTIVE_WHEEL_MANAGER.gamepad == false, "keyboard utility wheel was not selected")
assert(ADCUI.runtime.utilityWheelLayerActive == true and pushedLayers[1] == "ADCUI_UTILITY_WHEEL_BRIDGE", "controller bridge layer was not pushed")
assert(ADCUI:ShouldBridgeUtilityWheelInput() == true, "utility wheel bridge did not become active")
assert(ADCUI:CycleUtilityWheel(-1) == true and INTERACTIVE_WHEEL_MANAGER.lastCycle == "left", "left controller wheel cycle failed")
assert(ADCUI:CycleUtilityWheel(1) == true and INTERACTIVE_WHEEL_MANAGER.lastCycle == "right", "right controller wheel cycle failed")
INTERACTIVE_WHEEL_MANAGER:StopInteraction(ZO_INTERACTIVE_WHEEL_TYPE_UTILITY)
assert(ADCUI.runtime.utilityWheelLayerActive == false and removedLayers[1] == "ADCUI_UTILITY_WHEEL_BRIDGE", "controller bridge layer was not removed")

print("ADCUI core, prompts, dialogs, action bar, utility wheel, compass, map and menu smoke tests passed.")
