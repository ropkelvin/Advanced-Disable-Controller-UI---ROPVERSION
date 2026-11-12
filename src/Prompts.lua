local ADDON = ESOHybridUI
local rt = ADDON.runtime

local originalShouldUseGamepadAction
local originalGetPreferredKeyType
local originalShouldShowGamepadKeybind
local wrapperShouldUseGamepadAction
local wrapperGetPreferredKeyType
local wrapperShouldShowGamepadKeybind

function ADDON:ApplyPromptPresentation()
    local hybridPrompts = self:IsActive() and self:IsHybrid() and self:IsNativeGamepadMode()

    if KEYBIND_STRIP_STANDARD_STYLE then
        if not rt.originalPromptStyleCaptured then
            rt.originalPromptStyle = KEYBIND_STRIP_STANDARD_STYLE.alwaysPreferGamepadMode
            rt.originalPromptStyleCaptured = true
        end

        KEYBIND_STRIP_STANDARD_STYLE.alwaysPreferGamepadMode = hybridPrompts or rt.originalPromptStyle
    end
end

function ADDON:RestorePrompts()
    self:ApplyPromptPresentation()

    if wrapperShouldUseGamepadAction and _G.ZO_Keybindings_ShouldUseGamepadAction == wrapperShouldUseGamepadAction then
        _G.ZO_Keybindings_ShouldUseGamepadAction = originalShouldUseGamepadAction
    end
    if wrapperGetPreferredKeyType and _G.ZO_Keybindings_GetPreferredKeyType == wrapperGetPreferredKeyType then
        _G.ZO_Keybindings_GetPreferredKeyType = originalGetPreferredKeyType
    end
    if wrapperShouldShowGamepadKeybind and _G.ZO_Keybindings_ShouldShowGamepadKeybind == wrapperShouldShowGamepadKeybind then
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

function ADDON:InitializePrompts()
    if not self:IsActive() then
        return
    end

    if not rt.promptHooksInstalled then
        originalShouldUseGamepadAction = _G.ZO_Keybindings_ShouldUseGamepadAction
        originalGetPreferredKeyType = _G.ZO_Keybindings_GetPreferredKeyType
        originalShouldShowGamepadKeybind = _G.ZO_Keybindings_ShouldShowGamepadKeybind

        if originalShouldUseGamepadAction then
            wrapperShouldUseGamepadAction = function(alwaysPreferGamepadMode, ...)
                if ADDON:IsActive() and ADDON:IsHybrid() and ADDON:IsNativeGamepadMode() then
                    return true
                end
                return originalShouldUseGamepadAction(alwaysPreferGamepadMode, ...)
            end
            _G.ZO_Keybindings_ShouldUseGamepadAction = wrapperShouldUseGamepadAction
        end

        if originalGetPreferredKeyType then
            wrapperGetPreferredKeyType = function(alwaysPreferGamepadMode, ...)
                if ADDON:IsActive() and ADDON:IsHybrid() and ADDON:IsNativeGamepadMode() then
                    return PREFERRED_INPUT_DEVICE_TYPE_GAMEPAD
                end
                return originalGetPreferredKeyType(alwaysPreferGamepadMode, ...)
            end
            _G.ZO_Keybindings_GetPreferredKeyType = wrapperGetPreferredKeyType
        end

        if originalShouldShowGamepadKeybind then
            wrapperShouldShowGamepadKeybind = function(alwaysPreferGamepadMode, ...)
                if ADDON:IsActive() and ADDON:IsHybrid() and ADDON:IsNativeGamepadMode() then
                    return true
                end
                return originalShouldShowGamepadKeybind(alwaysPreferGamepadMode, ...)
            end
            _G.ZO_Keybindings_ShouldShowGamepadKeybind = wrapperShouldShowGamepadKeybind
        end

        rt.promptHooksInstalled = true
    end

    self:ApplyPromptPresentation()
end
