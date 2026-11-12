local ADDON = ESOHybridUI
local rt = ADDON.runtime

local function IsLockpickActive()
    return rt.lockPicking == true
end

function ADDON:ApplyMode()
    if not self.saved then
        return
    end

    local hybrid = self:IsHybrid()
    local nativeGamepad = self:IsNativeGamepadMode()

    -- Preserve ESO's real setting. Hybrid changes only the UI-preference query;
    -- it never turns off the controller or changes the user's game setting.
    if hybrid and nativeGamepad and not IsLockpickActive() then
        _G.IsInGamepadPreferredMode = function()
            return false
        end
    else
        _G.IsInGamepadPreferredMode = self.NativeIsInGamepadPreferredMode
    end

    if self.ApplyPromptPresentation then
        self:ApplyPromptPresentation()
    end
    if self.RefreshSceneController then
        self:RefreshSceneController()
    end
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

function ADDON:InitializeMode()
    if self.saved.mode ~= "gamepad" then
        self.saved.mode = "hybrid"
    end

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
                .. " | ESO Gamepad Mode=" .. tostring(self:IsNativeGamepadMode())
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
