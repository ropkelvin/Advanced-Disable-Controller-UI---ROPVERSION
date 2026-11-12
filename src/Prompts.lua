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

function ADDON:RestorePrompts()
    -- Restore only if HUI still owns every wrapped helper. If another addon
    -- wrapped one of ours, keep the pass-through chain rather than clobber it.
    local canRestore = true
    if wrapperShouldUseGamepadAction and _G.ZO_Keybindings_ShouldUseGamepadAction ~= wrapperShouldUseGamepadAction then
        canRestore = false
    end
    if wrapperGetPreferredKeyType and _G.ZO_Keybindings_GetPreferredKeyType ~= wrapperGetPreferredKeyType then
        canRestore = false
    end
    if wrapperShouldShowGamepadKeybind and _G.ZO_Keybindings_ShouldShowGamepadKeybind ~= wrapperShouldShowGamepadKeybind then
        canRestore = false
    end

    if canRestore then
        if wrapperShouldUseGamepadAction then
            _G.ZO_Keybindings_ShouldUseGamepadAction = originalShouldUseGamepadAction
        end
        if wrapperGetPreferredKeyType then
            _G.ZO_Keybindings_GetPreferredKeyType = originalGetPreferredKeyType
        end
        if wrapperShouldShowGamepadKeybind then
            _G.ZO_Keybindings_ShouldShowGamepadKeybind = originalShouldShowGamepadKeybind
        end

        originalShouldUseGamepadAction = nil
        originalGetPreferredKeyType = nil
        originalShouldShowGamepadKeybind = nil
        wrapperShouldUseGamepadAction = nil
        wrapperGetPreferredKeyType = nil
        wrapperShouldShowGamepadKeybind = nil
        rt.promptHooksInstalled = false
    end
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
