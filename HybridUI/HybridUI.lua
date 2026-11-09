-- HybridUI
-- Keyboard presentation for selected native HUD controls while ESO remains
-- in native Gamepad mode. No menu, scene, dialog, or input routing changes.

local ADDON_NAME = "HybridUI"
local DEFAULTS =
{
    keyboardHud = true,
}

local savedVariables
local initialized = false
local originalAttributeApplyStyle
local originalCompassApplyStyle
local originalBossBarApplyStyle
local originalUnitFrameApplyVisualStyle
local originalAttributeModeChanged
local originalTrackerApplyPlatformStyle
local originalEquipmentApplyPlatformStyle
local originalSynergyApplyTextStyle
local originalBuffApplyPlatformStyle
local originalBuffUpdate
local originalReticleApplyPlatformStyle
local originalStealthApplyPlatformStyle
local actionButtonOriginalStyles = setmetatable({}, { __mode = "k" })
local hudSettingsReady = false

local function WithKeyboardTemplates(callback)
    local originalGetPlatformTemplate = ZO_GetPlatformTemplate
    ZO_GetPlatformTemplate = function(baseTemplate)
        return baseTemplate .. "_Keyboard_Template"
    end

    callback()

    ZO_GetPlatformTemplate = originalGetPlatformTemplate
end

local function WithPlatformStyle(useKeyboard, callback)
    local originalPreferredMode = IsInGamepadPreferredMode
    local originalGetPlatformTemplate = ZO_GetPlatformTemplate

    IsInGamepadPreferredMode = function()
        return not useKeyboard
    end
    ZO_GetPlatformTemplate = function(baseTemplate)
        return baseTemplate .. (useKeyboard and "_Keyboard_Template" or "_Gamepad_Template")
    end

    callback()

    ZO_GetPlatformTemplate = originalGetPlatformTemplate
    IsInGamepadPreferredMode = originalPreferredMode
end

local function IsKeyboardHudEnabled()
    return savedVariables and savedVariables.keyboardHud
end

-- ESO registers separate Keyboard and Gamepad HUD elements for the same
-- control. Reuse the real Keyboard element's saved/default anchor, rather
-- than calculating replacement coordinates.
local function ApplyKeyboardHudAnchors()
    if not IsKeyboardHudEnabled() or not HUD_MANAGER or not HUD_MANAGER.keyboardElements then
        return
    end

    for control, keyboardElement in pairs(HUD_MANAGER.keyboardElements) do
        if HUD_MANAGER.gamepadElements[control] then
            keyboardElement:RevertOffsetModifications()
        end
    end
end

local function InstallResourceBarAdapter()
    if not ZO_PlayerAttributeBars or not ZO_PlayerAttributeBars.ApplyStyle or originalAttributeApplyStyle then
        return
    end

    originalAttributeApplyStyle = ZO_PlayerAttributeBars.ApplyStyle
    originalAttributeModeChanged = ZO_PlayerAttributeBars.OnGamepadPreferredModeChanged
    if originalAttributeModeChanged then
        ZO_PlayerAttributeBars.OnGamepadPreferredModeChanged = function(self)
            if IsKeyboardHudEnabled() then
                return WithPlatformStyle(true, function()
                    originalAttributeModeChanged(self)
                end)
            end
            return originalAttributeModeChanged(self)
        end
    end
    ZO_PlayerAttributeBars.ApplyStyle = function(self)
        if IsKeyboardHudEnabled() then
            return WithKeyboardTemplates(function()
                originalAttributeApplyStyle(self)
            end)
        end

        return originalAttributeApplyStyle(self)
    end

end

local function InstallCompassAdapter()
    if not COMPASS_FRAME or not COMPASS_FRAME.ApplyStyle or originalCompassApplyStyle then
        return
    end

    originalCompassApplyStyle = COMPASS_FRAME.ApplyStyle
    COMPASS_FRAME.ApplyStyle = function(self)
        if IsKeyboardHudEnabled() then
            WithPlatformStyle(true, function()
                originalCompassApplyStyle(self)
            end)
            if self.keyboardHUDElement then
                self.keyboardHUDElement:RevertOffsetModifications()
            end
            return
        end

        return originalCompassApplyStyle(self)
    end

    COMPASS_FRAME:ApplyStyle()
end


local function InstallUnitFrameAdapter()
    if not ZO_UnitFrameObject or not ZO_UnitFrameObject.ApplyVisualStyle or originalUnitFrameApplyVisualStyle then
        return
    end

    originalUnitFrameApplyVisualStyle = ZO_UnitFrameObject.ApplyVisualStyle
    ZO_UnitFrameObject.ApplyVisualStyle = function(self)
        if IsKeyboardHudEnabled() then
            return WithPlatformStyle(true, function()
                originalUnitFrameApplyVisualStyle(self)
            end)
        end

        return originalUnitFrameApplyVisualStyle(self)
    end

end

local function InstallBossBarAdapter()
    if not BOSS_BAR or not BOSS_BAR.ApplyStyle or originalBossBarApplyStyle then
        return
    end

    originalBossBarApplyStyle = BOSS_BAR.ApplyStyle
    BOSS_BAR.ApplyStyle = function(self)
        if IsKeyboardHudEnabled() then
            return WithKeyboardTemplates(function()
                originalBossBarApplyStyle(self)
            end)
        end

        return originalBossBarApplyStyle(self)
    end

end


-- The stock action-bar style callback is a file-local closure in ESO's UI.
-- Reapply its documented Keyboard/Gamepad layout constants through the
-- public action-bar button objects, without changing input or preferred mode.
local function InstallActionButtonAdapter(button)
    if not button or actionButtonOriginalStyles[button] then
        return
    end

    local originalApplyStyle = button.ApplyStyle
    actionButtonOriginalStyles[button] = originalApplyStyle
    button.ApplyStyle = function(self, template, ...)
        if IsKeyboardHudEnabled() then
            if type(template) == "string" then
                template = template:gsub("_Gamepad_Template$", "_Keyboard_Template")
            end
            return WithPlatformStyle(true, function()
                originalApplyStyle(self, template)
            end)
        end
        return originalApplyStyle(self, template, ...)
    end
end

local function ApplyActionBarPresentation(useKeyboard)
    if not ZO_ActionBar1 or not ZO_ActionBar_GetButton then
        return
    end

    local ultimateSlot = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
    local activeHotbar = GetActiveHotbarCategory()
    local backHotbar = activeHotbar == HOTBAR_CATEGORY_PRIMARY and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
    for slotIndex = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ultimateSlot do
        InstallActionButtonAdapter(ZO_ActionBar_GetButton(slotIndex))
        InstallActionButtonAdapter(ZO_ActionBar_GetButton(slotIndex, backHotbar))
    end
    InstallActionButtonAdapter(ZO_ActionBar_GetButton(ultimateSlot, HOTBAR_CATEGORY_COMPANION))
    InstallActionButtonAdapter(ZO_ActionBar_GetButton(GetCurrentQuickslot(), HOTBAR_CATEGORY_QUICKSLOT_WHEEL))

    local style
    if useKeyboard then
        style =
        {
            abilitySlotOffsetX = 2,
            ultimateSlotOffsetX = 62,
            quickslotOffsetXFromCompanionUltimate = 18,
            quickslotOffsetXFromFirstSlot = 5,
            backRowSlotOffsetY = -17,
            backRowUltimateSlotOffsetY = -20,
            anchor = ZO_Anchor:New(BOTTOM, GuiRoot, BOTTOM, 0, 0),
            width = 483,
            showNormalBindingTextOnUltimate = true,
            showKeybindBG = true,
            showWeaponSwapButton = true,
            weaponSwapOffsetX = 59,
            weaponSwapOffsetY = -4,
            hudElementRefPrimaryAnchor = ZO_Anchor:New(TOPLEFT, nil, TOPLEFT, -68, -20),
            hudElementRefSecondaryAnchor = ZO_Anchor:New(BOTTOMRIGHT, nil, BOTTOMRIGHT, 2, 0),
        }
    else
        style =
        {
            abilitySlotOffsetX = 10,
            ultimateSlotOffsetX = 65,
            quickslotOffsetXFromCompanionUltimate = 45,
            quickslotOffsetXFromFirstSlot = 5,
            backRowSlotOffsetY = -17,
            backRowUltimateSlotOffsetY = -30,
            anchor = ZO_Anchor:New(BOTTOM, GuiRoot, BOTTOM, 0, -25),
            width = 606,
            showNormalBindingTextOnUltimate = false,
            showKeybindBG = false,
            showWeaponSwapButton = false,
            weaponSwapOffsetX = 61,
            weaponSwapOffsetY = 4,
            hudElementRefPrimaryAnchor = ZO_Anchor:New(TOPLEFT, nil, TOPLEFT, -125, -18),
            hudElementRefSecondaryAnchor = ZO_Anchor:New(BOTTOMRIGHT, nil, BOTTOMRIGHT, 52, 22),
        }
    end

    WithPlatformStyle(useKeyboard, function()
        style.anchor:Set(ZO_ActionBar1)
        ZO_ActionBar1:SetWidth(style.width)

        local weaponSwap = ZO_ActionBar1WeaponSwap
        weaponSwap:SetAnchor(TOPLEFT, nil, TOPLEFT, style.weaponSwapOffsetX, style.weaponSwapOffsetY)

        local buttonTemplate = ZO_GetPlatformTemplate("ZO_ActionButton")
        local backBarTemplate = ZO_GetPlatformTemplate("ZO_ActionBarTimer_BackBarSlot")
        local lastButton
        for slotIndex = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + ACTION_BAR_SLOTS_PER_PAGE - 1 do
            local button = ZO_ActionBar_GetButton(slotIndex)
            if button then
                button:ApplyStyle(buttonTemplate)

                local anchorTarget = lastButton and lastButton.slot or weaponSwap
                if not lastButton then
                    anchorTarget = weaponSwap
                end
                button:ApplyAnchor(anchorTarget, style.abilitySlotOffsetX)

                local backButton = ZO_ActionBar_GetButton(slotIndex, backHotbar)
                if backButton then
                    backButton:ApplyStyle(backBarTemplate)
                    backButton:ApplyAnchor(button.slot, style.backRowSlotOffsetY)
                end

                lastButton = button
            end
        end

        local ultimateSlot = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
        local ultimateButton = ZO_ActionBar_GetButton(ultimateSlot)
        if ultimateButton and lastButton then
            ultimateButton:ApplyStyle(ZO_GetPlatformTemplate("ZO_UltimateActionButton"))
            ultimateButton:SetShowBindingText(style.showNormalBindingTextOnUltimate)
            ultimateButton:ApplyAnchor(lastButton.slot, style.ultimateSlotOffsetX)
            ultimateButton:UpdateUltimateMeter()

            local backUltimate = ZO_ActionBar_GetButton(ultimateSlot, backHotbar)
            if backUltimate then
                backUltimate:ApplyStyle(ZO_GetPlatformTemplate("ZO_ActionBarTimer_BackBarSlot_Ultimate"))
                backUltimate:ApplyAnchor(ultimateButton.slot, style.backRowUltimateSlotOffsetY)
            end

            local companionUltimate = ZO_ActionBar_GetButton(ultimateSlot, HOTBAR_CATEGORY_COMPANION)
            if companionUltimate then
                companionUltimate:ApplyStyle(ZO_GetPlatformTemplate("ZO_UltimateActionButton"))
                companionUltimate:SetShowBindingText(style.showNormalBindingTextOnUltimate)
                companionUltimate:ApplyAnchor(ZO_ActionBar_GetButton(ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1).slot, style.ultimateSlotOffsetX, true)
                companionUltimate:UpdateUltimateMeter()
            end
        end

        local companionActive = DoesUnitExist("companion") and HasActiveCompanion()
        local companionUltimate = ZO_ActionBar_GetButton(ultimateSlot, HOTBAR_CATEGORY_COMPANION)
        local quickslot = ZO_ActionBar_GetButton(GetCurrentQuickslot(), HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        local keybindBackground = ZO_ActionBar1:GetNamedChild("KeybindBG")

        if companionActive and companionUltimate then
            companionUltimate:SetEnabled(true)
            keybindBackground:SetDimensions(580, 64)
            keybindBackground:SetAnchor(BOTTOM, nil, nil, -34, 0)
            quickslot:ApplyAnchor(companionUltimate.slot, style.quickslotOffsetXFromCompanionUltimate, true)
        else
            if companionUltimate then
                companionUltimate:SetEnabled(false)
            end
            keybindBackground:SetDimensions(512, 64)
            keybindBackground:SetAnchor(BOTTOM, nil, nil, 0, 0)
            quickslot:ApplyAnchor(weaponSwap, style.quickslotOffsetXFromFirstSlot, true)
        end

        quickslot:ApplyStyle(buttonTemplate)
        keybindBackground:SetHidden(not style.showKeybindBG)
        ZO_WeaponSwap_SetPermanentlyHidden(ZO_ActionBar1:GetNamedChild("WeaponSwap"), not style.showWeaponSwapButton)

        style.hudElementRefPrimaryAnchor:Set(ZO_ActionBar1.hudElementRef)
        style.hudElementRefSecondaryAnchor:AddToControl(ZO_ActionBar1.hudElementRef)
    end)
end


local function InstallTrackerAdapter()
    if not ZO_HUDTracker_Base or not ZO_HUDTracker_Base.ApplyPlatformStyle or originalTrackerApplyPlatformStyle then
        return
    end

    originalTrackerApplyPlatformStyle = ZO_HUDTracker_Base.ApplyPlatformStyle
    ZO_HUDTracker_Base.ApplyPlatformStyle = function(self, style)
        if IsKeyboardHudEnabled() and self.styles and self.styles.keyboard then
            return originalTrackerApplyPlatformStyle(self, self.styles.keyboard)
        end
        return originalTrackerApplyPlatformStyle(self, style)
    end
end

local function ApplyTrackerStyles(useKeyboard)
    if not originalTrackerApplyPlatformStyle or not HUD_TRACKER_MANAGER or not HUD_TRACKER_MANAGER.trackers then
        return
    end

    for _, tracker in pairs(HUD_TRACKER_MANAGER.trackers) do
        if tracker.styles then
            local style = useKeyboard and tracker.styles.keyboard or tracker.styles.gamepad
            if style then
                originalTrackerApplyPlatformStyle(tracker, style)
            end
        end
    end
end

local function InstallEquipmentStatusAdapter()
    if not HUD_EQUIPMENT_STATUS or not HUD_EQUIPMENT_STATUS.ApplyPlatformStyle or originalEquipmentApplyPlatformStyle then
        return
    end

    originalEquipmentApplyPlatformStyle = HUD_EQUIPMENT_STATUS.ApplyPlatformStyle
    HUD_EQUIPMENT_STATUS.ApplyPlatformStyle = function(self, style)
        if IsKeyboardHudEnabled() then
            return originalEquipmentApplyPlatformStyle(self, { template = "ZO_HUDEquipmentStatus_Keyboard_Template" })
        end
        return originalEquipmentApplyPlatformStyle(self, style)
    end
end

local function InstallSynergyAdapter()
    if not SYNERGY or not SYNERGY.ApplyTextStyle or originalSynergyApplyTextStyle then
        return
    end

    originalSynergyApplyTextStyle = SYNERGY.ApplyTextStyle
    SYNERGY.ApplyTextStyle = function(self, constants)
        if IsKeyboardHudEnabled() then
            -- Keyboard font, frame, width and position; retain the Gamepad
            -- keybind template so the interaction prompt remains controller-native.
            return originalSynergyApplyTextStyle(self,
            {
                FONT = "ZoInteractionPrompt",
                TEMPLATE = "ZO_KeybindButton_Gamepad_Template",
                OFFSET_Y = ZO_COMMON_INFO_DEFAULT_KEYBOARD_BOTTOM_OFFSET_Y,
                FRAME_TEXTURE = "EsoUI/Art/ActionBar/abilityFrame64_up.dds",
                HUD_ELEMENT_REF_MIN_WIDTH = 300,
            })
        end
        return originalSynergyApplyTextStyle(self, constants)
    end
end

local function InstallBuffDebuffAdapter()
    if not ZO_BuffDebuff_ContainerObject then
        return
    end

    if not originalBuffApplyPlatformStyle then
        originalBuffApplyPlatformStyle = ZO_BuffDebuff_ContainerObject.ApplyPlatformStyle
        ZO_BuffDebuff_ContainerObject.ApplyPlatformStyle = function(self, style)
            if IsKeyboardHudEnabled() then
                return originalBuffApplyPlatformStyle(self, ZO_BUFF_DEBUFF_KEYBOARD_STYLE)
            end
            return originalBuffApplyPlatformStyle(self, style)
        end
    end

    if not originalBuffUpdate then
        originalBuffUpdate = ZO_BuffDebuff_ContainerObject.Update
        ZO_BuffDebuff_ContainerObject.Update = function(self)
            if IsKeyboardHudEnabled() then
                return WithPlatformStyle(true, function()
                    originalBuffUpdate(self)
                end)
            end
            return originalBuffUpdate(self)
        end
    end
end

local function InstallReticleAdapter()
    if ZO_Reticle and ZO_Reticle.ApplyPlatformStyle and not originalReticleApplyPlatformStyle then
        originalReticleApplyPlatformStyle = ZO_Reticle.ApplyPlatformStyle
        ZO_Reticle.ApplyPlatformStyle = function(self, style)
            if IsKeyboardHudEnabled() then
                return originalReticleApplyPlatformStyle(self,
                {
                    font = "ZoInteractionPrompt",
                    keybindButtonStyle = KEYBIND_STRIP_GAMEPAD_STYLE,
                })
            end
            return originalReticleApplyPlatformStyle(self, style)
        end
    end

    if ZO_StealthIcon and ZO_StealthIcon.ApplyPlatformStyle and not originalStealthApplyPlatformStyle then
        originalStealthApplyPlatformStyle = ZO_StealthIcon.ApplyPlatformStyle
        ZO_StealthIcon.ApplyPlatformStyle = function(self, style)
            if IsKeyboardHudEnabled() then
                return originalStealthApplyPlatformStyle(self, { font = "ZoInteractionPrompt" })
            end
            return originalStealthApplyPlatformStyle(self, style)
        end
    end
end

local function ApplyAdditionalHudStyles(useKeyboard)
    if SYNERGY and originalSynergyApplyTextStyle then
        if useKeyboard then
            SYNERGY:ApplyTextStyle(
            {
                FONT = "ZoInteractionPrompt",
                TEMPLATE = "ZO_KeybindButton_Gamepad_Template",
                OFFSET_Y = ZO_COMMON_INFO_DEFAULT_KEYBOARD_BOTTOM_OFFSET_Y,
                FRAME_TEXTURE = "EsoUI/Art/ActionBar/abilityFrame64_up.dds",
                HUD_ELEMENT_REF_MIN_WIDTH = 300,
            })
        else
            SYNERGY:ApplyTextStyle(
            {
                FONT = "ZoFontGamepad42",
                TEMPLATE = "ZO_KeybindButton_Gamepad_Template",
                OFFSET_Y = ZO_COMMON_INFO_DEFAULT_GAMEPAD_BOTTOM_OFFSET_Y,
                FRAME_TEXTURE = "EsoUI/Art/ActionBar/Gamepad/gp_abilityFrame64.dds",
                HUD_ELEMENT_REF_MIN_WIDTH = 330,
            })
        end
    end

    if HUD_EQUIPMENT_STATUS and originalEquipmentApplyPlatformStyle then
        local template = useKeyboard and "ZO_HUDEquipmentStatus_Keyboard_Template" or "ZO_HUDEquipmentStatus_Gamepad_Template"
        originalEquipmentApplyPlatformStyle(HUD_EQUIPMENT_STATUS, { template = template })
    end

    if BUFF_DEBUFF and originalBuffApplyPlatformStyle then
        local style = useKeyboard and ZO_BUFF_DEBUFF_KEYBOARD_STYLE or ZO_BUFF_DEBUFF_GAMEPAD_STYLE
        for _, container in pairs(BUFF_DEBUFF.containerObjectsByUnitTag) do
            originalBuffApplyPlatformStyle(container, style)
            if originalBuffUpdate then
                if useKeyboard then
                    WithPlatformStyle(true, function()
                        originalBuffUpdate(container)
                    end)
                else
                    originalBuffUpdate(container)
                end
            end
        end
    end

    if RETICLE and originalReticleApplyPlatformStyle then
        if useKeyboard then
            originalReticleApplyPlatformStyle(RETICLE,
            {
                font = "ZoInteractionPrompt",
                keybindButtonStyle = KEYBIND_STRIP_GAMEPAD_STYLE,
            })
        else
            originalReticleApplyPlatformStyle(RETICLE,
            {
                font = "ZoFontGamepad42",
                keybindButtonStyle = KEYBIND_STRIP_GAMEPAD_STYLE,
            })
        end
    end

    if RETICLE and RETICLE.stealthIcon and originalStealthApplyPlatformStyle then
        local font = useKeyboard and "ZoInteractionPrompt" or "ZoFontGamepad36"
        originalStealthApplyPlatformStyle(RETICLE.stealthIcon, { font = font })
    end

    if useKeyboard then
        ApplyTrackerStyles(true)
    else
        ApplyTrackerStyles(false)
    end
end

local function ApplyAllKeyboardHudStyles()
    if not IsKeyboardHudEnabled() then
        return
    end

    InstallResourceBarAdapter()
    InstallCompassAdapter()
    InstallBossBarAdapter()
    InstallUnitFrameAdapter()
    InstallTrackerAdapter()
    InstallEquipmentStatusAdapter()
    InstallSynergyAdapter()
    InstallBuffDebuffAdapter()
    InstallReticleAdapter()
    ApplyActionBarPresentation(true)
    ApplyAdditionalHudStyles(true)

    if PLAYER_ATTRIBUTE_BARS then
        PLAYER_ATTRIBUTE_BARS:ApplyStyle()
        if PLAYER_ATTRIBUTE_BARS.attributeVisualizer then
            WithPlatformStyle(true, function()
                PLAYER_ATTRIBUTE_BARS.attributeVisualizer:ApplyPlatformStyle()
            end)
        end
    end
    if COMPASS_FRAME then
        COMPASS_FRAME:ApplyStyle()
    end
    if BOSS_BAR then
        BOSS_BAR:ApplyStyle()
    end
    if UnitFrames and UnitFrames.ApplyVisualStyle then
        UnitFrames:ApplyVisualStyle()
    end

    ApplyKeyboardHudAnchors()
end

local function OnActionBarLayoutChanged()
    if IsKeyboardHudEnabled() then
        ApplyActionBarPresentation(true)
    end
end

local function OnHudSettingsReady()
    if hudSettingsReady then
        return
    end
    hudSettingsReady = true
    ApplyAllKeyboardHudStyles()
    HUD_MANAGER:RegisterCallback("PropagateSettings", ApplyAllKeyboardHudStyles)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, OnActionBarLayoutChanged)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, OnActionBarLayoutChanged)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, OnActionBarLayoutChanged)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ACTIVE_COMPANION_STATE_CHANGED, OnActionBarLayoutChanged)
end

local function CreateSettings()
    local panelName = "HybridUIOptions"

    LibAddonMenu2:RegisterAddonPanel(panelName,
    {
        type = "panel",
        name = "HybridUI",
        displayName = "HybridUI",
        author = "@ZOSPlsFix",
        version = "2.3.0",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    LibAddonMenu2:RegisterOptionControls(panelName,
    {
        {
            type = "description",
            text = "Keeps ESO in native Gamepad mode and applies Keyboard presentation to supported gameplay HUD elements only. Menus, inventory, map, dialogue, interactions, input handling and scene routing remain native Gamepad.",
        },
        {
            type = "checkbox",
            name = "Keyboard HUD presentation",
            tooltip = "Uses ESO's Keyboard HUD anchors and platform templates for supported HUD elements. Disable to restore native Gamepad HUD presentation.",
            getFunc = function()
                return savedVariables.keyboardHud
            end,
            setFunc = function(value)
                savedVariables.keyboardHud = value
                if value then
                    ApplyAllKeyboardHudStyles()
                else
                    -- Reapply the original native Gamepad styles and anchors.
                    if PLAYER_ATTRIBUTE_BARS and originalAttributeApplyStyle then
                        originalAttributeApplyStyle(PLAYER_ATTRIBUTE_BARS)
                        if PLAYER_ATTRIBUTE_BARS.attributeVisualizer then
                            PLAYER_ATTRIBUTE_BARS.attributeVisualizer:ApplyPlatformStyle()
                        end
                    end
                    if COMPASS_FRAME and originalCompassApplyStyle then
                        originalCompassApplyStyle(COMPASS_FRAME)
                    end
                    if BOSS_BAR and originalBossBarApplyStyle then
                        originalBossBarApplyStyle(BOSS_BAR)
                    end
                    if UnitFrames and UnitFrames.ApplyVisualStyle then
                        UnitFrames:ApplyVisualStyle()
                    end
                    ApplyActionBarPresentation(false)
                    ApplyAdditionalHudStyles(false)
                    if HUD_MANAGER then
                        HUD_MANAGER:PropagateSettings()
                    end
                end
            end,
            default = DEFAULTS.keyboardHud,
        },
    })
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME or initialized then
        return
    end

    initialized = true
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    savedVariables = ZO_SavedVars:NewAccountWide(
        "HybridUI_SavedVariables",
        3,
        nil,
        DEFAULTS
    )

    if HUD_MANAGER then
        HUD_MANAGER:RegisterCallback("SavedVarsReady", OnHudSettingsReady)
        if HUD_MANAGER.savedVars then
            OnHudSettingsReady()
        end
    end

    CreateSettings()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
