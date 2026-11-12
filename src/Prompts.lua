local ADDON = ESOHybridUI
local rt = ADDON.runtime

local originalShouldUseGamepadAction
local originalGetPreferredKeyType
local originalShouldShowGamepadKeybind
local wrapperShouldUseGamepadAction
local wrapperGetPreferredKeyType
local wrapperShouldShowGamepadKeybind

local function ShouldUseControllerPrompts()
    return ADDON:IsActive()
        and ADDON:IsHybrid()
        and ADDON:IsGamepadModeOn()
        and not rt.modeOverrideConflict
        and not ADDON:IsRestrictedSceneActive()
end

function ADDON:InitializePrompts()
    if not self:IsActive() or rt.promptHooksInstalled then
        return
    end

    originalShouldUseGamepadAction = _G.ZO_Keybindings_ShouldUseGamepadAction
    originalGetPreferredKeyType = _G.ZO_Keybindings_GetPreferredKeyType
    originalShouldShowGamepadKeybind = _G.ZO_Keybindings_ShouldShowGamepadKeybind

    if originalShouldUseGamepadAction then
        wrapperShouldUseGamepadAction = function(alwaysPreferGamepadMode, ...)
            if ShouldUseControllerPrompts() then
                return true
            end
            return originalShouldUseGamepadAction(alwaysPreferGamepadMode, ...)
        end
        _G.ZO_Keybindings_ShouldUseGamepadAction = wrapperShouldUseGamepadAction
    end

    if originalGetPreferredKeyType then
        wrapperGetPreferredKeyType = function(alwaysPreferGamepadMode, ...)
            if ShouldUseControllerPrompts() then
                return PREFERRED_INPUT_DEVICE_TYPE_GAMEPAD
            end
            return originalGetPreferredKeyType(alwaysPreferGamepadMode, ...)
        end
        _G.ZO_Keybindings_GetPreferredKeyType = wrapperGetPreferredKeyType
    end

    if originalShouldShowGamepadKeybind then
        wrapperShouldShowGamepadKeybind = function(alwaysPreferGamepadMode, ...)
            if ShouldUseControllerPrompts() then
                return true
            end
            return originalShouldShowGamepadKeybind(alwaysPreferGamepadMode, ...)
        end
        _G.ZO_Keybindings_ShouldShowGamepadKeybind = wrapperShouldShowGamepadKeybind
    end

    -- These wrappers are intentionally left installed after the first
    -- in-world activation. While inactive or on restricted screens they are
    -- exact pass-throughs, so no loading/pregame UI is modified.
    rt.promptHooksInstalled = true
end
