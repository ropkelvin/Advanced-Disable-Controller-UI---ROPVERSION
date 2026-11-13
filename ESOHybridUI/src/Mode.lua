-- Presentation mode ownership.
-- HUI changes the preferred-mode query only while it owns the wrapper. If
-- another addon replaces the global query, HUI yields instead of clobbering it.
local ADDON = ESOHybridUI
local rt = ADDON.rt

local function IsHUIKeyboardPresentationPreferredMode()
    if rt.keyboardPresentation and not rt.nativeQuery then
        return false
    end
    return ADDON.NativeIsInGamepadPreferredMode()
end

ADDON.HUIPreferredModeWrapper = IsHUIKeyboardPresentationPreferredMode

function ADDON:Recompute()
    rt.gamepadOn = tonumber(GetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_INPUT_PREFERRED_MODE))
        == INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD

    local want = rt.inWorld and self:IsHybrid() and rt.gamepadOn
        and not rt.lockPick and not rt.restricted

    local changed = want ~= rt.keyboardPresentation
    rt.keyboardPresentation = want
    return changed
end

function ADDON:TryRefreshHUDSettings()
    if not rt.hudRefreshPending then
        return
    end
    if HUD_MANAGER and HUD_MANAGER.PropagateSettings
        and HUD_TRACKER_MANAGER
        and HUD_TRACKER_MANAGER.keyboardHUDElement
        and HUD_TRACKER_MANAGER.gamepadHUDElement then
        HUD_MANAGER:PropagateSettings()
        rt.hudRefreshPending = false
    end
end

local function RestoreOwnedWrapper()
    if rt.modeOverrideApplied
        and _G.IsInGamepadPreferredMode == IsHUIKeyboardPresentationPreferredMode then
        _G.IsInGamepadPreferredMode = ADDON.NativeIsInGamepadPreferredMode
    end
    rt.modeOverrideApplied = false
end

function ADDON:ApplyMode()
    if not self.saved then
        return
    end

    if not rt.inWorld then
        rt.keyboardPresentation = false
        RestoreOwnedWrapper()
        rt.modeOverrideConflict = false
        self:TryRefreshHUDSettings()
        return
    end

    local changed = self:Recompute()
    local modeQueryChanged = false

    if rt.keyboardPresentation then
        if _G.IsInGamepadPreferredMode == self.NativeIsInGamepadPreferredMode
            or _G.IsInGamepadPreferredMode == IsHUIKeyboardPresentationPreferredMode then
            if _G.IsInGamepadPreferredMode ~= IsHUIKeyboardPresentationPreferredMode then
                _G.IsInGamepadPreferredMode = IsHUIKeyboardPresentationPreferredMode
                modeQueryChanged = true
            end
            rt.modeOverrideApplied = true
            rt.modeOverrideConflict = false
        else
            -- Never replace an unrelated addon's wrapper. Pause Hybrid
            -- presentation rather than running a partially mixed UI mode.
            rt.modeOverrideConflict = true
            rt.keyboardPresentation = false
            self:Debug("Another addon owns IsInGamepadPreferredMode; HUI yielded to avoid replacing its hook.")
        end
    else
        if rt.modeOverrideApplied then
            modeQueryChanged = _G.IsInGamepadPreferredMode == IsHUIKeyboardPresentationPreferredMode
            RestoreOwnedWrapper()
        end
        rt.modeOverrideConflict = false
    end

    if changed or modeQueryChanged then
        rt.hudRefreshPending = true
        self:Record("MODE", "keyboardPresentation=", rt.keyboardPresentation,
            "modeOverrideConflict=", rt.modeOverrideConflict)
    end

    self:TryRefreshHUDSettings()
    self:RefreshPointerScenes()
    self:RefreshNavigation()
end

function ADDON:SetMode(mode)
    if mode ~= "hybrid" and mode ~= "gamepad" then
        self:Print("Usage: /hui hybrid  or  /hui gamepad")
        return
    end
    self.saved.mode = mode
    self:ApplyMode()
    self:Print("Mode: " .. (mode == "hybrid" and "Hybrid" or "Pure Gamepad")
        .. ". Reopen the current menu to apply its layout.")
end

function ADDON:InitializeLockpick()
    if rt.lockpickHooked or not LOCK_PICK or not LOCK_PICK.SetHidden then
        return
    end
    ZO_PreHook(LOCK_PICK, "SetHidden", function(_, hidden)
        rt.lockPick = not hidden
        ADDON:ApplyMode()
        return false
    end)
    rt.lockpickHooked = true
end

function ADDON:InitializeMode()
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        ADDON:ApplyMode()
    end)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_BEGIN_LOCKPICK, function()
        rt.lockPick = true
        ADDON:ApplyMode()
    end)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_LOCKPICK_SUCCESS, function()
        rt.lockPick = false
        ADDON:ApplyMode()
    end)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_LOCKPICK_FAILED, function()
        rt.lockPick = false
        ADDON:ApplyMode()
    end)
end
