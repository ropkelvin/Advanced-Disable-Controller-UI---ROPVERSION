local ADDON = ESOHybridUI
local rt = ADDON.runtime

local originalShouldUseGamepadAction
local originalGetPreferredKeyType
local originalShouldShowGamepadKeybind
local wrapperShouldUseGamepadAction
local wrapperGetPreferredKeyType
local wrapperShouldShowGamepadKeybind

function ADDON:ApplyPromptPresentation()
    -- Never touch presentation controls before the player is in-world. On
    -- deactivation, restore the original shared style if HUI had changed it.
    if not self:IsActive() then
        if rt.originalPromptStyleCaptured and KEYBIND_STRIP_STANDARD_STYLE then
            KEYBIND_STRIP_STANDARD_STYLE.alwaysPreferGamepadMode = rt.originalPromptStyle
            if KEYBIND_STRIP and KEYBIND_STRIP.SetStyle and ZO_ShallowTableCopy then
                KEYBIND_STRIP:SetStyle(ZO_ShallowTableCopy(KEYBIND_STRIP_STANDARD_STYLE))
            end
        end
        return
    end

    local hybridPrompts = self:IsHybrid()
        and self:IsNativeGamepadMode() and not self:IsRestrictedSceneActive()

    if KEYBIND_STRIP_STANDARD_STYLE then
        if not rt.originalPromptStyleCaptured then
            rt.originalPromptStyle = KEYBIND_STRIP_STANDARD_STYLE.alwaysPreferGamepadMode
            rt.originalPromptStyleCaptured = true
        end

        KEYBIND_STRIP_STANDARD_STYLE.alwaysPreferGamepadMode = hybridPrompts or rt.originalPromptStyle

        -- SetStyle ignores the same table identity. A shallow copy forces the
        -- strip to rebuild its current buttons using the updated preference.
        if KEYBIND_STRIP and KEYBIND_STRIP.SetStyle and ZO_ShallowTableCopy then
            KEYBIND_STRIP:SetStyle(ZO_ShallowTableCopy(KEYBIND_STRIP_STANDARD_STYLE))
        end
    end
end

function ADDON:RestorePrompts()
    -- Keep the wrappers installed after the first in-world activation. They
    -- become exact pass-throughs while inactive, avoiding wrapper stacking
    -- with other addons across zone transitions.
    self:ApplyPromptPresentation()
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
                if ADDON:IsActive() and ADDON:IsHybrid() and ADDON:IsNativeGamepadMode()
                    and not ADDON:IsRestrictedSceneActive() then
                    return true
                end
                return originalShouldUseGamepadAction(alwaysPreferGamepadMode, ...)
            end
            _G.ZO_Keybindings_ShouldUseGamepadAction = wrapperShouldUseGamepadAction
        end

        if originalGetPreferredKeyType then
            wrapperGetPreferredKeyType = function(alwaysPreferGamepadMode, ...)
                if ADDON:IsActive() and ADDON:IsHybrid() and ADDON:IsNativeGamepadMode()
                    and not ADDON:IsRestrictedSceneActive() then
                    return PREFERRED_INPUT_DEVICE_TYPE_GAMEPAD
                end
                return originalGetPreferredKeyType(alwaysPreferGamepadMode, ...)
            end
            _G.ZO_Keybindings_GetPreferredKeyType = wrapperGetPreferredKeyType
        end

        if originalShouldShowGamepadKeybind then
            wrapperShouldShowGamepadKeybind = function(alwaysPreferGamepadMode, ...)
                if ADDON:IsActive() and ADDON:IsHybrid() and ADDON:IsNativeGamepadMode()
                    and not ADDON:IsRestrictedSceneActive() then
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
