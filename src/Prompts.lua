local ADDON = ESOHybridUI
local rt = ADDON.runtime

local originalShouldUseGamepadAction = ZO_Keybindings_ShouldUseGamepadAction
local originalGetPreferredKeyType = ZO_Keybindings_GetPreferredKeyType
local originalShouldShowGamepadKeybind = ZO_Keybindings_ShouldShowGamepadKeybind

function ADDON:ApplyPromptPresentation()
    local hybridPrompts = self:IsHybrid() and self:IsNativeGamepadMode()

    if KEYBIND_STRIP_STANDARD_STYLE then
        if not rt.originalPromptStyleCaptured then
            rt.originalPromptStyle = KEYBIND_STRIP_STANDARD_STYLE.alwaysPreferGamepadMode
            rt.originalPromptStyleCaptured = true
        end

        if hybridPrompts then
            KEYBIND_STRIP_STANDARD_STYLE.alwaysPreferGamepadMode = true
            if KEYBIND_STRIP and KEYBIND_STRIP.SetStyle then
                KEYBIND_STRIP:SetStyle(KEYBIND_STRIP_STANDARD_STYLE)
            end
        else
            KEYBIND_STRIP_STANDARD_STYLE.alwaysPreferGamepadMode = rt.originalPromptStyle
        end
    end
end

function ADDON:InitializePrompts()
    if not rt.promptHooksInstalled then
        if originalShouldUseGamepadAction then
            _G.ZO_Keybindings_ShouldUseGamepadAction = function(alwaysPreferGamepadMode, ...)
                if ADDON:IsHybrid() and ADDON:IsNativeGamepadMode() then
                    return true
                end
                return originalShouldUseGamepadAction(alwaysPreferGamepadMode, ...)
            end
        end

        if originalGetPreferredKeyType then
            _G.ZO_Keybindings_GetPreferredKeyType = function(alwaysPreferGamepadMode, ...)
                if ADDON:IsHybrid() and ADDON:IsNativeGamepadMode() then
                    return PREFERRED_INPUT_DEVICE_TYPE_GAMEPAD
                end
                return originalGetPreferredKeyType(alwaysPreferGamepadMode, ...)
            end
        end

        if originalShouldShowGamepadKeybind then
            _G.ZO_Keybindings_ShouldShowGamepadKeybind = function(alwaysPreferGamepadMode, ...)
                if ADDON:IsHybrid() and ADDON:IsNativeGamepadMode() then
                    return true
                end
                return originalShouldShowGamepadKeybind(alwaysPreferGamepadMode, ...)
            end
        end

        rt.promptHooksInstalled = true
    end

    self:ApplyPromptPresentation()
end
