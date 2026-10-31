-- Lightweight smoke tests for Core.lua with ESO API stubs.
-- This does not replace in-client integration testing.

TOP = 1
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

print("ADCUI core smoke tests passed.")
