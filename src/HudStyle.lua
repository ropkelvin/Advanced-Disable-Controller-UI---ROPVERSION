-- Presentation-only styling for additional gameplay HUD components.
-- No scene, dialog, action-layer, interaction, targeting or combat handlers are replaced.

local ADDON = ESOHybridUI
local trackedHUDTrackers = {}
local applyingTrackerStyle = {}

local function IsHybridHUD()
    return ADDON:GetSettings().useHybridUI == true and ADDON:IsNativeGamepadMode()
end

local function StyleBossBar()
    if not IsHybridHUD() or not BOSS_BAR or not BOSS_BAR.control then return end
    ApplyTemplateToControl(BOSS_BAR.control, "ZO_BossBar_Keyboard_Template")
end

local function StyleCompassFrame()
    if not IsHybridHUD() or not COMPASS_FRAME or not COMPASS_FRAME.control then return end

    ApplyTemplateToControl(COMPASS_FRAME.control, "ZO_CompassFrame_Keyboard_Template")
    local center = COMPASS_FRAME.control:GetNamedChild("Center")
    if center then
        local topOverlay = center:GetNamedChild("TopMungeOverlay")
        local bottomOverlay = center:GetNamedChild("BottomMungeOverlay")
        if topOverlay then topOverlay:SetHidden(false) end
        if bottomOverlay then bottomOverlay:SetHidden(false) end
    end

    -- Clear HUD-editor offsets for either platform so the keyboard HUD
    -- element owns its normal position. Scene membership is untouched.
    if COMPASS_FRAME.keyboardHUDElement then
        COMPASS_FRAME.keyboardHUDElement:RevertOffsetModifications()
    end
    if COMPASS_FRAME.gamepadHUDElement then
        COMPASS_FRAME.gamepadHUDElement:RevertOffsetModifications()
    end
end

local function StyleCompass()
    if IsHybridHUD() and COMPASS and COMPASS.ApplyKeyboardStyle then
        COMPASS:ApplyKeyboardStyle()
    end
end

local function StyleActiveCombatTip()
    if not IsHybridHUD() or not ACTIVE_COMBAT_TIP_SYSTEM then return end
    local tipSystem = ACTIVE_COMBAT_TIP_SYSTEM
    if tipSystem.control then
        ApplyTemplateToControl(tipSystem.control, "ZO_ActiveCombatTips_Keyboard_Template")
    end
end

local function ApplyTrackerPlatformStyle(owner)
    if not owner or not owner.ApplyPlatformStyle or not owner.styles then return end

    local style
    if IsHybridHUD() then
        style = owner.styles.keyboard
    elseif ADDON:IsNativeGamepadMode() then
        style = owner.styles.gamepad
    else
        style = owner.styles.keyboard
    end

    if style then
        applyingTrackerStyle[owner] = true
        owner:ApplyPlatformStyle(style)
        applyingTrackerStyle[owner] = nil
    end
end

local function RegisterHUDTracker(owner)
    if not owner then return end
    trackedHUDTrackers[owner] = true

    -- HUD trackers own separate keyboard and gamepad HUD-editor elements.
    -- Select the keyboard element only for these HUD tracker objects.
    if not owner._esoHybridOriginalGetPlatformHUDElement and owner.GetPlatformHUDElement then
        owner._esoHybridOriginalGetPlatformHUDElement = owner.GetPlatformHUDElement
        owner.GetPlatformHUDElement = function(self)
            if IsHybridHUD() and self.keyboardHUDElement then
                return self.keyboardHUDElement
            end
            return self._esoHybridOriginalGetPlatformHUDElement(self)
        end
    end
end

local function ApplyAllHUDTrackerStyles()
    if HUD_TRACKER_MANAGER and HUD_TRACKER_MANAGER.trackers then
        for _, trackerData in ipairs(HUD_TRACKER_MANAGER.trackers) do
            RegisterHUDTracker(trackerData.owner)
        end
    end

    for owner in pairs(trackedHUDTrackers) do
        ApplyTrackerPlatformStyle(owner)
    end
end

local function OnTrackerPlatformStyleApplied(owner)
    if applyingTrackerStyle[owner] then return end
    RegisterHUDTracker(owner)
    if IsHybridHUD() then
        ApplyTrackerPlatformStyle(owner)
    end
end

local function ApplyAllAdditionalHUDStyles()
    local hybrid = IsHybridHUD()
    ApplyAllHUDTrackerStyles()

    -- First let ESO choose the native platform presentation. Only then apply
    -- keyboard templates to these specific gameplay HUD controls in Hybrid.
    if BOSS_BAR and BOSS_BAR.ApplyStyle then BOSS_BAR:ApplyStyle() end
    if hybrid then StyleBossBar() end

    if COMPASS_FRAME and COMPASS_FRAME.ApplyStyle then COMPASS_FRAME:ApplyStyle() end
    if hybrid then StyleCompassFrame() end

    if COMPASS then
        if hybrid then
            StyleCompass()
        elseif ADDON:IsNativeGamepadMode() and COMPASS.ApplyGamepadStyle then
            COMPASS:ApplyGamepadStyle()
        elseif COMPASS.ApplyKeyboardStyle then
            COMPASS:ApplyKeyboardStyle()
        end
    end

    if ACTIVE_COMBAT_TIP_SYSTEM and ACTIVE_COMBAT_TIP_SYSTEM.ApplyStyle then
        ACTIVE_COMBAT_TIP_SYSTEM:ApplyStyle()
    end
    if hybrid then StyleActiveCombatTip() end
end

function ADDON:ApplyAdditionalHUDStyles()
    ApplyAllAdditionalHUDStyles()
end

local function InstallHooks()
    if ADDON.runtime.additionalHUDHooksInstalled then return end

    if CompassFrame then
        ZO_PostHook(CompassFrame, "ApplyStyle", StyleCompassFrame)
    end
    if Compass then
        ZO_PostHook(Compass, "OnGamepadPreferredModeChanged", StyleCompass)
    end
    if ZO_ActiveCombatTip then
        ZO_PostHook(ZO_ActiveCombatTip, "ApplyStyle", StyleActiveCombatTip)
    end
    if ZO_HUDTracker_Base then
        ZO_PostHook(ZO_HUDTracker_Base, "ApplyPlatformStyle", OnTrackerPlatformStyleApplied)
    end

    ADDON.runtime.additionalHUDHooksInstalled = true
end

local function OnHUDStyleRefresh()
    ApplyAllAdditionalHUDStyles()
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON.ADDON_NAME then return end

    InstallHooks()
    ApplyAllAdditionalHUDStyles()

    EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_HUDStyle", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, OnHUDStyleRefresh)
    EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_HUDStyle", EVENT_PLAYER_ACTIVATED, OnHUDStyleRefresh)
    EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_HUDTrackerStyle", EVENT_ADD_ONS_LOADED, function()
        ApplyAllHUDTrackerStyles()
    end)
    EVENT_MANAGER:UnregisterForEvent(ADDON.ADDON_NAME .. "_HUDStyle_Load", EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_HUDStyle_Load", EVENT_ADD_ON_LOADED, OnAddonLoaded)
