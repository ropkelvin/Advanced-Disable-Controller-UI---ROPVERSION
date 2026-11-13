-- Controller glyphs. ESO's keybind-text helpers decide keyboard vs gamepad by
-- calling IsInGamepadPreferredMode(), which Hybrid answers "keyboard". While
-- one of these helpers runs, HUI lets that query answer natively (gamepad), so
-- the helper behaves exactly as it does in real Gamepad mode: gamepad action
-- names, gamepad glyphs, no guessing about each helper's internals.
local ADDON = ESOHybridUI
local rt = ADDON.rt

local HELPERS = {
    "ZO_Keybindings_GetHighestPriorityBindingStringFromAction",
    "ZO_Keybindings_RegisterLabelForBindingUpdate",
    "ZO_Keybindings_ShouldShowGamepadKeybind",
    "ZO_Keybindings_ShouldUseGamepadAction",
    "ZO_Keybindings_GetPreferredKeyType",
}

local function Finish(previous, ok, ...)
    rt.nativeQuery = previous
    if not ok then
        error((...), 0)
    end
    return ...
end

function ADDON:InitializePrompts()
    if rt.promptsHooked then
        return
    end
    for _, name in ipairs(HELPERS) do
        local original = _G[name]
        if type(original) == "function" then
            _G[name] = function(...)
                if not (rt.keyboardPresentation and ADDON.saved.controllerPrompts) then
                    return original(...)
                end
                local previous = rt.nativeQuery
                rt.nativeQuery = true
                return Finish(previous, pcall(original, ...))
            end
        end
    end
    rt.promptsHooked = true
end
