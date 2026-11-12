local ADDON = ESOHybridUI
local rt = ADDON.runtime

local function IsLockpickActive()
    return rt.lockPicking == true
end

local previousHUIWrapper = ADDON.HUIPreferredModeWrapper
local function IsHUIKeyboardPresentationPreferredMode()
    if ADDON:IsActive()
        and ADDON:IsHybrid()
        and ADDON:IsGamepadModeOn()
        and not IsLockpickActive()
        and not rt.modeOverrideConflict
        and not ADDON:IsRestrictedSceneActive() then
        return false
    end
    return ADDON.NativeIsInGamepadPreferredMode()
end

-- On /reloadui, replace our previous wrapper with the current implementation
-- without losing the original ESO function or stacking wrappers.
if previousHUIWrapper and _G.IsInGamepadPreferredMode == previousHUIWrapper then
    _G.IsInGamepadPreferredMode = IsHUIKeyboardPresentationPreferredMode
end
ADDON.HUIPreferredModeWrapper = IsHUIKeyboardPresentationPreferredMode

function ADDON:ApplyMode()
    if not self.saved or not self:IsActive() then
        -- The player-deactivated event is raised as the loading screen is
        -- shown. While inactive, the global wrapper itself is pass-through;
        -- do not refresh scenes, controls, or HUD until player activation.
        return
    end

    local shouldUseKeyboardPresentation = self:IsActive()
        and self:IsHybrid()
        and self:IsGamepadModeOn()
        and not IsLockpickActive()
        and not self:IsRestrictedSceneActive()

    -- Do not overwrite another addon's mode wrapper. HUI only takes ownership
    -- when the current global is the original function captured at load or
    -- HUI's own wrapper from an earlier application.
    local modeQueryChanged = false
    if shouldUseKeyboardPresentation then
        if _G.IsInGamepadPreferredMode == self.NativeIsInGamepadPreferredMode
            or _G.IsInGamepadPreferredMode == IsHUIKeyboardPresentationPreferredMode then
            if _G.IsInGamepadPreferredMode ~= IsHUIKeyboardPresentationPreferredMode then
                _G.IsInGamepadPreferredMode = IsHUIKeyboardPresentationPreferredMode
                modeQueryChanged = true
            end
            rt.modeOverrideApplied = true
            rt.modeOverrideConflict = false
        else
            rt.modeOverrideApplied = false
            rt.modeOverrideConflict = true
            self:Debug("Another addon replaced IsInGamepadPreferredMode; Hybrid presentation is paused to avoid overwriting its hook.")
        end
    else
        if rt.modeOverrideApplied
            and _G.IsInGamepadPreferredMode == IsHUIKeyboardPresentationPreferredMode then
            _G.IsInGamepadPreferredMode = self.NativeIsInGamepadPreferredMode
            modeQueryChanged = true
        end
        rt.modeOverrideApplied = false
        rt.modeOverrideConflict = false
    end

    -- A mode-query change needs an anchor refresh, but HUD_MANAGER's
    -- PropagateSettings callback assumes ZO_HUDTracker_Manager has already
    -- registered both platform HUD elements. During early player activation
    -- those fields can still be nil. Defer until ESO's add-ons-loaded setup
    -- has completed rather than firing callbacks into a half-built HUD.
    if modeQueryChanged then
        rt.hudRefreshPending = true
    end
    self:TryRefreshHUDSettings()

    if self.RefreshSceneController then
        self:RefreshSceneController()
    end
end

function ADDON:TryRefreshHUDSettings()
    if not rt.hudRefreshPending then
        return true
    end

    if not HUD_MANAGER or not HUD_MANAGER.PropagateSettings
        or not HUD_TRACKER_MANAGER
        or not HUD_TRACKER_MANAGER.keyboardHUDElement
        or not HUD_TRACKER_MANAGER.gamepadHUDElement then
        return false
    end

    HUD_MANAGER:PropagateSettings()
    rt.hudRefreshPending = false
    return true
end

function ADDON:SetMode(mode)
    if mode ~= "hybrid" and mode ~= "gamepad" then
        self:Print("Usage: /hui hybrid  or  /hui gamepad")
        return
    end

    self.saved.mode = mode
    self:ApplyMode()
    self:Print("Mode changed to " .. (mode == "hybrid" and "Hybrid" or "Pure Gamepad") .. ". Reopen the active menu to apply its layout.")
end

local function InstallLockpickHook()
    if rt.lockpickHookInstalled or not LOCK_PICK or not LOCK_PICK.SetHidden then
        return
    end

    -- The stock EVENT_BEGIN_LOCKPICK handler calls SetHidden(false), which
    -- chooses the keyboard/gamepad lockpick scene. Set the exception before
    -- that method makes its scene choice, rather than relying on event order.
    ZO_PreHook(LOCK_PICK, "SetHidden", function(_, hidden)
        rt.lockPicking = not hidden
        ADDON:ApplyMode()
    end)

    rt.lockpickHookInstalled = true
end

function ADDON:InitializeLockpickHook()
    InstallLockpickHook()
end

function ADDON:InitializeMode()
    if self.saved.mode ~= "gamepad" then
        self.saved.mode = "hybrid"
    end

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_ADD_ONS_LOADED, function()
        -- HUD_MANAGER initializes HUD tracker elements during this event.
        -- Our handler runs after ESO's UI initialization handler has had the
        -- opportunity to register the keyboard and gamepad tracker elements.
        self:TryRefreshHUDSettings()
    end)

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        self:ApplyMode()
    end)

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_BEGIN_LOCKPICK, function()
        rt.lockPicking = true
        self:ApplyMode()
    end)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_LOCKPICK_SUCCESS, function()
        rt.lockPicking = false
        self:ApplyMode()
    end)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_LOCKPICK_FAILED, function()
        rt.lockPicking = false
        self:ApplyMode()
    end)

    SLASH_COMMANDS["/hui"] = function(argument)
        local requested = string.lower(argument or "")
        if requested == "" or requested == "status" then
            local sceneName = SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName() or "unknown"
            self:Print("Mode=" .. self.saved.mode
                .. " | InWorld=" .. tostring(self:IsActive())
                .. " | Gamepad Mode On=" .. tostring(self:IsGamepadModeOn())
                .. " | Original preferred query=" .. tostring(self:IsNativeGamepadMode())
                .. " | Mode hook conflict=" .. tostring(rt.modeOverrideConflict)
                .. " | UI preference=" .. tostring(IsInGamepadPreferredMode())
                .. " | Scene=" .. tostring(sceneName)
                .. " | Pointer=" .. tostring(rt.pointerScene))
            self:Print("Use /hui hybrid or /hui gamepad.")
        else
            self:SetMode(requested)
        end
    end

    self:ApplyMode()
end
