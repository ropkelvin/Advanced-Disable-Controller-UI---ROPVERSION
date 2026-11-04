-- Presentation-only reticle styling. Input, bindings and interactions remain ESO-native.

local ADDON = ESOHybridUI

local function ApplyReticleStyle(settings, hybrid)
    if not RETICLE or not RETICLE.ApplyPlatformStyle then return end

    local isGamepad = ADDON:IsNativeGamepadMode()
    local style
    if hybrid then
        style = {
            font = settings.fonts.reticleContext or "ZoInteractionPrompt",
            keybindButtonStyle = ZO_ShallowTableCopy(KEYBIND_STRIP_STANDARD_STYLE),
        }
        style.keybindButtonStyle.nameFont = settings.fonts.reticle or "ZoFontKeybindStripDescription"
        -- This is a per-control display preference. The underlying action
        -- remains the gamepad binding selected by ESO.
        style.keybindButtonStyle.alwaysPreferGamepadMode = true
    elseif isGamepad then
        style = {
            font = "ZoFontGamepad42",
            keybindButtonStyle = ZO_ShallowTableCopy(KEYBIND_STRIP_GAMEPAD_STYLE),
        }
    else
        style = {
            font = "ZoInteractionPrompt",
            keybindButtonStyle = ZO_ShallowTableCopy(KEYBIND_STRIP_STANDARD_STYLE),
        }
    end
    RETICLE:ApplyPlatformStyle(style)

    local stealthStyle = { font = hybrid and (settings.fonts.stealthIcon or "ZoInteractionPrompt") or (isGamepad and "ZoFontGamepad42" or "ZoInteractionPrompt") }
    if RETICLE.stealthIcon and RETICLE.stealthIcon.ApplyPlatformStyle then
        RETICLE.stealthIcon:ApplyPlatformStyle(stealthStyle)
    end
    if LOCK_PICK and LOCK_PICK.stealthIcon and LOCK_PICK.stealthIcon.ApplyPlatformStyle then
        LOCK_PICK.stealthIcon:ApplyPlatformStyle(stealthStyle)
    end
end

function ADDON:ApplyPrompts()
    local settings = self:GetSettings()
    if not KEYBIND_STRIP_STANDARD_STYLE or not KEYBIND_STRIP_GAMEPAD_STYLE then return end
    ApplyReticleStyle(settings, self:ShouldShowControllerPrompts())
end
