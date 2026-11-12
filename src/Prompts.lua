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

function ADDON:ApplyPromptPresentation()
    if not self:IsActive() or not KEYBIND_STRIP or not KEYBIND_STRIP.GetStyle
        or not KEYBIND_STRIP.SetStyle or not KEYBIND_STRIP_STANDARD_STYLE
        or not ZO_ShallowTableCopy then
        return
    end

    local currentStyle = KEYBIND_STRIP:GetStyle()
    if currentStyle ~= KEYBIND_STRIP_STANDARD_STYLE and currentStyle ~= rt.appliedStandardStyle then
        return
    end

    if ShouldUseControllerPrompts() then
        local styleCopy = ZO_ShallowTableCopy(KEYBIND_STRIP_STANDARD_STYLE)
        styleCopy.alwaysPreferGamepadMode = true
        rt.appliedStandardStyle = styleCopy
        KEYBIND_STRIP:SetStyle(styleCopy)
    else
        rt.appliedStandardStyle = nil
        KEYBIND_STRIP:SetStyle(KEYBIND_STRIP_STANDARD_STYLE)
    end
end

local function InstallKeybindStripStyleHook()
    if rt.keybindStripStyleHookInstalled or not KEYBIND_STRIP
        or not KEYBIND_STRIP.SetStyle or not KEYBIND_STRIP_STANDARD_STYLE then
        return
    end

    -- Post-hook rather than replacing SetStyle: preserve other addons' hooks,
    -- then reapply a copied standard style only when Hybrid is active.
    ZO_PostHook(KEYBIND_STRIP, "SetStyle", function(strip, styleInfo)
        if rt.reapplyingStandardStyle then
            return
        end

        if styleInfo == KEYBIND_STRIP_STANDARD_STYLE and ShouldUseControllerPrompts() then
            local styleCopy = ZO_ShallowTableCopy(styleInfo)
            styleCopy.alwaysPreferGamepadMode = true
            rt.appliedStandardStyle = styleCopy

            rt.reapplyingStandardStyle = true
            strip:SetStyle(styleCopy)
            rt.reapplyingStandardStyle = false
        elseif styleInfo == KEYBIND_STRIP_STANDARD_STYLE then
            rt.appliedStandardStyle = nil
        end
    end)

    rt.keybindStripStyleHookInstalled = true
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

        rt.promptHooksInstalled = true
    end

    InstallKeybindStripStyleHook()
    self:ApplyPromptPresentation()
end
