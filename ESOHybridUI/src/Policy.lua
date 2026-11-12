-- Policy: keep the real controller input active while selecting keyboard UI templates.
-- The preferred-mode query is a presentation decision; it is not the physical input device.
-- Native-only workflows opt in through scoped WithNativeGamepadMode calls or explicit context checks.

local ADDON = ESOHybridUI
local rt = ADDON.runtime

local function RealAnswer()
    local original = rt.originalIsInGamepadPreferredMode
    if original then return original() end
    return false
end

function ADDON:IsNativeGamepadMode()
    return RealAnswer()
end

function ADDON:IsHybrid()
    return rt.hybrid == true
end

local function PackResults(...)
    return { n = select("#", ...), ... }
end

local function RunWithDepth(depthKey, callback, ...)
    rt[depthKey] = (rt[depthKey] or 0) + 1
    -- Do not add pcall/xpcall here: native ESO actions may call protected functions.
    local results = PackResults(callback(...))
    rt[depthKey] = math.max(0, rt[depthKey] - 1)
    return unpack(results, 1, results.n)
end

function ADDON:WithNativeGamepadMode(callback, ...)
    return RunWithDepth("forceNativeModeDepth", callback, ...)
end

function ADDON:WithKeyboardWheelMode(callback, ...)
    return RunWithDepth("forceKeyboardWheelDepth", callback, ...)
end

function ADDON:WithKeyboardPresentationMode(callback, ...)
    return RunWithDepth("forceKeyboardPresentationDepth", callback, ...)
end

local function IsShowingGamepadDialog()
    return type(ZO_Dialogs_IsShowing) == "function"
        and ZO_Dialogs_IsShowing("RECALL_CONFIRM") == true
end

local function IsNativeSceneAlreadyActive()
    local sceneManager = SCENE_MANAGER
    if not sceneManager or not sceneManager.GetCurrentSceneName
        or not sceneManager.IsShowingBaseScene or sceneManager:IsShowingBaseScene() then
        return false
    end
    local presentation = ADDON:GetScenePresentation(sceneManager:GetCurrentSceneName())
    return presentation == ADDON.SCENE_PRESENTATION_NATIVE
        or presentation == ADDON.SCENE_PRESENTATION_SPECIAL
end

local function HybridWantsGamepad()
    if IsShowingGamepadDialog() then return true end
    if rt.isLockpicking then return true end
    if GetInteractionType and INTERACTION_LOOT and GetInteractionType() == INTERACTION_LOOT then
        return true
    end
    if type(IsUnitDead) == "function" and IsUnitDead("player") then
        return true
    end

    local sceneManager = SCENE_MANAGER
    if sceneManager and sceneManager.GetHUDSceneName then
        local hudName = sceneManager:GetHUDSceneName()
        if hudName == "housingEditorHud" or hudName == "gamepadScreenshotMode" then
            return true
        end
    end
    return IsNativeSceneAlreadyActive()
end

local function IsGamepadUIAllowed()
    local answer
    if (rt.forceNativeModeDepth or 0) > 0 then
        answer = RealAnswer()
    elseif (rt.forceKeyboardWheelDepth or 0) > 0
        or (rt.forceKeyboardPresentationDepth or 0) > 0 then
        answer = false
    elseif not rt.hybrid then
        answer = RealAnswer()
    else
        answer = RealAnswer() and HybridWantsGamepad() or false
    end

    if rt.traceEnabled then ADDON:TraceModeQuery(answer) end
    return answer
end

function ADDON:InstallModeOverride()
    if not rt.hybrid then
        if not rt.modeOverrideInstalled then return true end
        if _G.IsInGamepadPreferredMode == rt.overrideFunction then
            _G.IsInGamepadPreferredMode = rt.originalIsInGamepadPreferredMode
            rt.modeOverrideInstalled = false
            rt.overrideReplacedWarned = false
            return true
        end
        if not rt.overrideReplacedWarned then
            rt.overrideReplacedWarned = true
            self:LogWarn("IsInGamepadPreferredMode is no longer owned by Hybrid UI; leaving the newer implementation untouched.")
        end
        return false
    end

    if rt.modeOverrideInstalled then
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

function ADDON:RefreshSettingsCache()
    local settings = self:GetSettings()
    rt.hybrid = settings.mode == ADDON.MODE_HYBRID

    -- One-time migration: profiles created by the previous branch defaulted to
    -- native Gamepad menus. This branch's default is keyboard menus + pointer.
    if rt.hybrid and settings._keyboardPointerRoutingVersion ~= 1 then
        settings.menuPolicy = ADDON.POLICY_LEGACY
        settings._keyboardPointerRoutingVersion = 1
    end
    rt.menusGamepad = settings.menuPolicy ~= ADDON.POLICY_LEGACY
end
