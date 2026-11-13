-- Presentation mode: while Hybrid is active, ESO's "is gamepad UI preferred"
-- query answers false (keyboard layouts); controller input is untouched.
local ADDON = ESOHybridUI
local rt = ADDON.rt

-- Installed once at load and never removed. When keyboardPresentation is
-- false it is an exact pass-through, so loading/pregame/restricted screens
-- see ESO's original answer. It chains whatever function was global at load.
local function IsInGamepadPreferredModeWrapper()
    -- rt.nativeQuery is set only while keybind-prompt helpers run (Prompts.lua)
    -- so they answer exactly as ESO would in real gamepad mode.
    if rt.keyboardPresentation and not rt.nativeQuery then
        return false
    end
    return ADDON.NativeIsInGamepadPreferredMode()
end
_G.IsInGamepadPreferredMode = IsInGamepadPreferredModeWrapper

-- Recomputes the cached flags. Returns true if keyboardPresentation flipped.
function ADDON:Recompute()
    rt.gamepadOn = tonumber(GetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_INPUT_PREFERRED_MODE))
        == INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD

    local want = rt.inWorld
        and self:IsHybrid()
        and rt.gamepadOn
        and not rt.lockPick
        and not rt.restricted

    local changed = want ~= rt.keyboardPresentation
    rt.keyboardPresentation = want
    return changed
end

-- HUD_MANAGER:PropagateSettings assumes both HUD tracker elements exist.
-- Defer until they do rather than firing callbacks into a half-built HUD.
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

function ADDON:ApplyMode()
    if not self.saved or not rt.inWorld then
        return
    end

    if self:Recompute() then
        rt.hudRefreshPending = true
        self:Record("MODE", "keyboardPresentation=", rt.keyboardPresentation)
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

-- Lockpicking keeps ESO's native presentation. LOCK_PICK:SetHidden is where
-- ESO picks the keyboard or gamepad lockpick scene, so the exception must be
-- set before it runs rather than relying on event order.
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
