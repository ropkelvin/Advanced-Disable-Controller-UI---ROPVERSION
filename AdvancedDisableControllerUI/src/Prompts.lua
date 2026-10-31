-- Gamepad glyphs on keyboard-style UI, without switching the entire UI platform.

local ADDON = ADCUI

local function SaveAndSet(object, key, value)
    if type(object) ~= "table" or object[key] == nil then
        return
    end
    local saved = ADDON.runtime.promptOriginals
    if saved[object] == nil then saved[object] = {} end
    if saved[object][key] == nil then
        saved[object][key] = object[key]
    end
    object[key] = value
end

local function RestoreSavedValues()
    for object, values in pairs(ADDON.runtime.promptOriginals) do
        for key, value in pairs(values) do
            object[key] = value
        end
    end
end

local function SetDescriptorKeybind(descriptor, keybind)
    if type(descriptor) ~= "table" or descriptor.keybind == nil then
        return
    end
    SaveAndSet(descriptor, "keybind", keybind)
end

local function RemapKnownDescriptors(enabled)
    local map = enabled and "UI_SHORTCUT_LEFT_STICK" or nil

    if not enabled then
        RestoreSavedValues()
        return
    end

    if QUEST_JOURNAL_KEYBOARD and QUEST_JOURNAL_KEYBOARD.keybindStripDescriptor then
        SetDescriptorKeybind(QUEST_JOURNAL_KEYBOARD.keybindStripDescriptor[2], "UI_SHORTCUT_SECONDARY")
    end
    if ZONE_STORIES_KEYBOARD and ZONE_STORIES_KEYBOARD.keybindStripDescriptor then
        SetDescriptorKeybind(ZONE_STORIES_KEYBOARD.keybindStripDescriptor, "UI_SHORTCUT_SECONDARY")
    end
    if GUILD_HOME and GUILD_HOME.keybindStripDescriptor then
        SetDescriptorKeybind(GUILD_HOME.keybindStripDescriptor[1], "UI_SHORTCUT_LEFT_STICK")
    end

    if PLAYER_INVENTORY then
        local groups = {
            { PLAYER_INVENTORY.bankWithdrawTabKeybindButtonGroup, 3 },
            { PLAYER_INVENTORY.bankDepositTabKeybindButtonGroup, 2 },
            { PLAYER_INVENTORY.houseBankWithdrawTabKeybindButtonGroup, 1 },
            { PLAYER_INVENTORY.houseBankDepositTabKeybindButtonGroup, 1 },
        }
        for _, entry in ipairs(groups) do
            if entry[1] then
                SetDescriptorKeybind(entry[1][entry[2]], map)
            end
        end
    end

    if LOCK_PICK and LOCK_PICK.keybindStripDescriptor then
        local descriptor = LOCK_PICK.keybindStripDescriptor[4]
        if descriptor then
            SaveAndSet(descriptor, "alignment", KEYBIND_STRIP_ALIGN_RIGHT)
        end
    end
end

local function HookStackAllMapping()
    if ADDON.runtime.promptHooksInstalled or not KEYBIND_STRIP then
        return
    end

    local function ProcessGroup(_, group)
        if type(group) ~= "table" then return end
        local settings = ADDON:GetSettings()
        local enabled = settings.useGamepadButtons and not settings.useControllerUI and ADDON:IsNativeGamepadMode()
        if not enabled then
            for _, descriptor in ipairs(group) do
                local original = ADDON.runtime.stackAllOriginals[descriptor]
                if original then
                    descriptor.keybind = original
                    ADDON.runtime.stackAllOriginals[descriptor] = nil
                end
            end
            return
        end

        local sceneName = SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName()
        if sceneName ~= "store" and sceneName ~= "inventory" and sceneName ~= "fence_keyboard" then
            return
        end

        for _, descriptor in ipairs(group) do
            if descriptor.keybind == "UI_SHORTCUT_STACK_ALL" then
                if ADDON.runtime.stackAllOriginals[descriptor] == nil then
                    ADDON.runtime.stackAllOriginals[descriptor] = descriptor.keybind
                end
                descriptor.keybind = "UI_SHORTCUT_LEFT_STICK"
            end
        end
    end

    if ZO_PreHook then
        ZO_PreHook(KEYBIND_STRIP, "AddKeybindButtonGroup", ProcessGroup)
        ZO_PreHook(KEYBIND_STRIP, "UpdateKeybindButtonGroup", ProcessGroup)
    end
    ADDON.runtime.promptHooksInstalled = true
end

local function ApplyReticleFonts(settings, forceGamepadPrompts)
    if settings.useControllerUI or not ADDON:IsNativeGamepadMode() then
        return
    end
    if RETICLE and RETICLE.ApplyPlatformStyle and ZO_ShallowTableCopy and KEYBIND_STRIP_STANDARD_STYLE then
        local keybindStyle = ZO_ShallowTableCopy(KEYBIND_STRIP_STANDARD_STYLE)
        keybindStyle.nameFont = settings.fonts.reticle
        keybindStyle.alwaysPreferGamepadMode = forceGamepadPrompts
        RETICLE:ApplyPlatformStyle({
            font = settings.fonts.reticleContext,
            keybindButtonStyle = keybindStyle,
        })
    end

    local stealthStyle = { font = settings.fonts.stealthIcon }
    if RETICLE and RETICLE.stealthIcon and RETICLE.stealthIcon.ApplyPlatformStyle then
        RETICLE.stealthIcon:ApplyPlatformStyle(stealthStyle)
    end
    if LOCK_PICK and LOCK_PICK.stealthIcon and LOCK_PICK.stealthIcon.ApplyPlatformStyle then
        LOCK_PICK.stealthIcon:ApplyPlatformStyle(stealthStyle)
    end
end

function ADDON:ApplyPrompts()
    local settings = self:GetSettings()
    if not KEYBIND_STRIP_STANDARD_STYLE then
        return
    end

    if not self.runtime.promptStyleOriginal then
        self.runtime.promptStyleOriginal = KEYBIND_STRIP_STANDARD_STYLE.alwaysPreferGamepadMode
    end

    local forceGamepadPrompts = settings.useGamepadButtons
        and not settings.useControllerUI
        and self:IsNativeGamepadMode()

    KEYBIND_STRIP_STANDARD_STYLE.alwaysPreferGamepadMode = forceGamepadPrompts
    RemapKnownDescriptors(forceGamepadPrompts)
    HookStackAllMapping()
    ApplyReticleFonts(settings, forceGamepadPrompts)

    if KEYBIND_STRIP and KEYBIND_STRIP.SetStyle then
        KEYBIND_STRIP:SetStyle(KEYBIND_STRIP_STANDARD_STYLE)
    end
end

function ADDON:RestorePromptStyles()
    if self.runtime.promptStyleOriginal ~= nil and KEYBIND_STRIP_STANDARD_STYLE then
        KEYBIND_STRIP_STANDARD_STYLE.alwaysPreferGamepadMode = self.runtime.promptStyleOriginal
    end
    RestoreSavedValues()
end
