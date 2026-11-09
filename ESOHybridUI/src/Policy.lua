-- Policy: the one decision "should ESO treat the UI as gamepad right now?".
--
-- ESO asks IsInGamepadPreferredMode() whenever it builds an element, selects a
-- scene or resolves a keybind. Hybrid replaces that global with a wrapper that can
-- answer differently per context while the real input device stays the controller.
--
--   Gamepad mode : answer is the game's own (untouched).
--   Hybrid mode  : base HUD -> false (keyboard layout); loot, lockpicking, the map
--                  and any menu/overlay scene -> the game's own answer (gamepad).
--   Depth scopes : WithNativeGamepadMode / WithKeyboardWheelMode force an answer
--                  for the duration of one call (restored even if it errors).

local ADDON = ESOHybridUI
local rt = ADDON.runtime

local function RealAnswer()
    local original = rt.originalIsInGamepadPreferredMode
    if original then
        return original()
    end
    return false
end

function ADDON:IsNativeGamepadMode()
    return RealAnswer()
end

function ADDON:IsHybrid()
    return rt.hybrid == true
end

-- Re-run `callback` with a forced answer. The depth counter is restored on every
-- exit path and the callback's own return values are passed straight through.
local function Finish(depthKey, ok, ...)
    rt[depthKey] = math.max(0, rt[depthKey] - 1)
    if not ok then
        error((...), 0)
    end
    return ...
end

local function RunWithDepth(depthKey, callback, ...)
    rt[depthKey] = rt[depthKey] + 1
    return Finish(depthKey, pcall(callback, ...))
end

-- Native gamepad answer: used for things that must look like ESO's gamepad UI.
function ADDON:WithNativeGamepadMode(callback, ...)
    return RunWithDepth("forceNativeModeDepth", callback, ...)
end

-- Keyboard answer: used to make ESO build its keyboard-style wheels.
function ADDON:WithKeyboardWheelMode(callback, ...)
    return RunWithDepth("forceKeyboardWheelDepth", callback, ...)
end

local function WorldMapShowing()
    if WORLD_MAP_SCENE and WORLD_MAP_SCENE:IsShowing() then
        return true
    end
    -- The native map is a separate scene object; guarded because the global is
    -- not part of any documented contract.
    local gamepadMap = _G.GAMEPAD_WORLD_MAP_SCENE
    return gamepadMap ~= nil and gamepadMap:IsShowing() == true
end

-- Hybrid only: does the current context want ESO's native gamepad presentation?
local function HybridWantsGamepad()
    -- Loot has a dedicated native scene, but ESO can request the keyboard one.
    if GetInteractionType() == INTERACTION_LOOT then
        return true
    end
    -- Lockpicking keeps ESO's native gamepad scene.
    if rt.isLockpicking then
        return true
    end
    -- Opening the map does not necessarily enter UI mode.
    if WorldMapShowing() then
        return true
    end
    -- UI mode alone is not enough: ESO also enters UI mode on focus loss while
    -- showing its base HUD-UI scene. Require a real menu/overlay scene.
    local sceneManager = SCENE_MANAGER
    if not sceneManager then
        return false
    end
    local inUIMode = sceneManager.IsInUIMode and sceneManager:IsInUIMode()
    local showingBase = sceneManager.IsShowingBaseScene and sceneManager:IsShowingBaseScene()
    return inUIMode and not showingBase
end

local function IsGamepadUIAllowed()
    local answer
    if rt.forceNativeModeDepth > 0 then
        answer = RealAnswer()
    elseif rt.forceKeyboardWheelDepth > 0 then
        answer = false
    elseif not rt.hybrid then
        answer = RealAnswer()
    else
        answer = RealAnswer() and HybridWantsGamepad() or false
    end

    if rt.traceEnabled then
        ADDON:TraceModeQuery(answer)
    end
    return answer
end

function ADDON:InstallModeOverride()
    if rt.modeOverrideInstalled then
        -- Never fight another addon for the global; report it once per change.
        if _G.IsInGamepadPreferredMode ~= rt.overrideFunction then
            if not rt.overrideReplacedWarned then
                rt.overrideReplacedWarned = true
                self:LogWarn("IsInGamepadPreferredMode was replaced after Hybrid UI installed; another addon may be overriding the platform mode.")
            end
            return false
        end
        return true
    end

    rt.originalIsInGamepadPreferredMode = _G.IsInGamepadPreferredMode
    rt.overrideFunction = IsGamepadUIAllowed
    _G.IsInGamepadPreferredMode = IsGamepadUIAllowed
    rt.modeOverrideInstalled = true
    return true
end

-- Cheap cached flags for the hot path above.
function ADDON:RefreshSettingsCache()
    rt.hybrid = self:GetSettings().mode == ADDON.MODE_HYBRID
end
