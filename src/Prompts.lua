-- Gamepad glyphs on keyboard-style UI, without switching the entire UI platform.

local ADDON = ESOHybridUI
local NIL_VALUE = {}

local function Pack(...)
    return { n = select("#", ...), ... }
end

local function SaveAndSet(object, key, value)
    if type(object) ~= "table" then
        return
    end
    local saved = ADDON.runtime.promptOriginals
    if saved[object] == nil then saved[object] = {} end
    if saved[object][key] == nil then
        saved[object][key] = object[key] == nil and NIL_VALUE or object[key]
    end
    object[key] = value
end

local function RestoreSavedValues()
    for object, values in pairs(ADDON.runtime.promptOriginals) do
        for key, value in pairs(values) do
            if value == NIL_VALUE then
                object[key] = nil
            else
                object[key] = value
            end
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

local function RestoreStackAllMappings()
    for descriptor, original in pairs(ADDON.runtime.stackAllOriginals) do
        descriptor.keybind = original
        ADDON.runtime.stackAllOriginals[descriptor] = nil
    end
end

local function HookStackAllMapping()
    if ADDON.runtime.promptHooksInstalled or not KEYBIND_STRIP then
        return
    end

    local function ProcessGroup(_, group)
        if type(group) ~= "table" then return end
        local settings = ADDON:GetSettings()
        local enabled = (settings.useHybridUI or settings.useGamepadButtons)
            and not settings.useControllerUI
            and ADDON:IsNativeGamepadMode()
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

local function ShouldForceControllerPrompts()
    local settings = ADDON:GetSettings()
    return (settings.useHybridUI == true or settings.useGamepadButtons == true)
        and settings.useControllerUI ~= true
        and ADDON:IsNativeGamepadMode()
end

local function InstallGlobalPromptHooks()
    local runtime = ADDON.runtime
    if runtime.globalPromptHooksInstalled then return end

    runtime.promptBindingRegistrations = runtime.promptBindingRegistrations or setmetatable({}, { __mode = "k" })

    local originalRegister = ZO_Keybindings_RegisterLabelForBindingUpdate
    if type(originalRegister) == "function" then
        runtime.originalRegisterPromptLabel = originalRegister
        ZO_Keybindings_RegisterLabelForBindingUpdate = function(label, actionName, showUnbound, gamepadActionName, callback, alwaysPreferGamepadMode, ...)
            local force = ShouldForceControllerPrompts()
            if label then
                runtime.promptBindingRegistrations[label] = {
                    register = originalRegister,
                    args = Pack(actionName, showUnbound, gamepadActionName, callback, alwaysPreferGamepadMode, ...),
                }
            end
            return originalRegister(label, actionName, showUnbound, gamepadActionName, callback, force or alwaysPreferGamepadMode, ...)
        end
    end

    local originalInline = ZO_Keybindings_RegisterLabelForInLineBindingUpdate
    if type(originalInline) == "function" then
        runtime.originalRegisterInlinePromptLabel = originalInline
        ZO_Keybindings_RegisterLabelForInLineBindingUpdate = function(label, actionName, showUnbound, gamepadActionName, callback, alwaysPreferGamepadMode, ...)
            local force = ShouldForceControllerPrompts()
            if label then
                runtime.promptBindingRegistrations[label] = {
                    register = originalInline,
                    args = Pack(actionName, showUnbound, gamepadActionName, callback, alwaysPreferGamepadMode, ...),
                }
            end
            return originalInline(label, actionName, showUnbound, gamepadActionName, callback, force or alwaysPreferGamepadMode, ...)
        end
    end

    if ZO_KeybindButtonMixin and type(ZO_KeybindButtonMixin.SetKeybind) == "function" then
        local originalSetKeybind = ZO_KeybindButtonMixin.SetKeybind
        runtime.originalKeybindButtonSetKeybind = originalSetKeybind
        ZO_KeybindButtonMixin.SetKeybind = function(button, keybind, showUnbound, gamepadPreferredKeybind, alwaysPreferGamepadMode, ...)
            local force = ShouldForceControllerPrompts()
            button.esoHybridPromptKeybind = {
                keybind, showUnbound, gamepadPreferredKeybind, alwaysPreferGamepadMode, ...
            }
            return originalSetKeybind(button, keybind, showUnbound, gamepadPreferredKeybind, force or alwaysPreferGamepadMode, ...)
        end
    end

    runtime.globalPromptHooksInstalled = true
end

local function RefreshRegisteredPromptLabels()
    local runtime = ADDON.runtime
    local registrations = runtime.promptBindingRegistrations
    local unregister = ZO_Keybindings_UnregisterLabelForBindingUpdate
    if not registrations or type(unregister) ~= "function" then return end

    local force = ShouldForceControllerPrompts()
    for label, registration in pairs(registrations) do
        if label and registration and registration.register then
            unregister(label)
            local args = registration.args
            registration.register(label, args[1], args[2], args[3], args[4], force or args[5], unpack(args, 6, args.n))
        end
    end
end

local function InstallDeathPromptHook()
    local runtime = ADDON.runtime
    if runtime.deathPromptHookInstalled or not DEATH or type(DEATH.ApplyStyle) ~= "function" then
        return
    end

    local originalApplyStyle = DEATH.ApplyStyle
    runtime.originalDeathApplyStyle = originalApplyStyle
    DEATH.ApplyStyle = function(death, ...)
        if ShouldForceControllerPrompts() then
            -- ESO's death screen selects its keyboard button templates because
            -- Hybrid mode intentionally reports keyboard UI during gameplay.
            -- Temporarily expose the real native Gamepad preference while
            -- the death screen applies its own platform templates.
            return ADDON:WithNativeGamepadMode(originalApplyStyle, death, ...)
        end
        return originalApplyStyle(death, ...)
    end
    runtime.deathPromptHookInstalled = true
end

local function RefreshReticlePrompt()
    if not RETICLE or not RETICLE.interactKeybindButton then return end
    local button = RETICLE.interactKeybindButton
    if type(button.SetKeybind) == "function" then
        button:SetKeybind("GAME_CAMERA_INTERACT", false, "GAMEPAD_JUMP_OR_INTERACT", ShouldForceControllerPrompts())
    end
end

local function RefreshSynergyPrompt()
    if not ShouldForceControllerPrompts() or not SYNERGY or not SYNERGY.action
        or type(ZO_Keybindings_GetHighestPriorityBindingStringFromAction) ~= "function" then
        return
    end

    -- USE_SYNERGY is the shared action name for keyboard and controller.
    -- Its controller binding is a chord (Y+B by default), so ask ESO's
    -- keybinding formatter to prefer the gamepad binding explicitly.
    local bindingText = ZO_Keybindings_GetHighestPriorityBindingStringFromAction(
        "USE_SYNERGY",
        KEYBIND_TEXT_OPTIONS_FULL_NAME,
        KEYBIND_TEXTURE_OPTIONS_EMBED_MARKUP,
        true
    )
    if bindingText then
        SYNERGY.action:SetText(bindingText)
    end
end

local function InstallSynergyPromptHook()
    if ADDON.runtime.synergyPromptHookInstalled or not SYNERGY
        or type(SYNERGY.OnSynergyAbilityChanged) ~= "function" or type(ZO_PostHook) ~= "function" then
        return
    end

    ZO_PostHook(SYNERGY, "OnSynergyAbilityChanged", RefreshSynergyPrompt)
    ADDON.runtime.synergyPromptHookInstalled = true
end

local function RefreshPlayerInteractionPrompt()
    if not PLAYER_TO_PLAYER or not PLAYER_TO_PLAYER.actionKeybindButton then return end
    local button = PLAYER_TO_PLAYER.actionKeybindButton
    if type(button.SetKeybind) == "function" then
        -- Keep the same action so ESO resolves the user's actual configured
        -- gamepad binding (including hold/chord combinations) instead of
        -- displaying the generic A-button glyph from GAMEPAD_JUMP_OR_INTERACT.
        button:SetKeybind("PLAYER_TO_PLAYER_INTERACT", false, nil, ShouldForceControllerPrompts())
    end
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

    -- Hybrid's defining contract is a keyboard HUD with controller glyphs.
    -- The standalone prompt toggle must not accidentally turn those glyphs
    -- back into keyboard labels while Hybrid is active.
    local forceGamepadPrompts = (settings.useHybridUI or settings.useGamepadButtons)
        and not settings.useControllerUI
        and self:IsNativeGamepadMode()

    InstallGlobalPromptHooks()
    KEYBIND_STRIP_STANDARD_STYLE.alwaysPreferGamepadMode = forceGamepadPrompts
    if not forceGamepadPrompts then
        RestoreStackAllMappings()
    end
    RemapKnownDescriptors(forceGamepadPrompts)
    HookStackAllMapping()
    ApplyReticleFonts(settings, forceGamepadPrompts)
    InstallSynergyPromptHook()
    InstallDeathPromptHook()
    RefreshRegisteredPromptLabels()
    RefreshReticlePrompt()
    RefreshPlayerInteractionPrompt()
    RefreshSynergyPrompt()

    if KEYBIND_STRIP and KEYBIND_STRIP.SetStyle then
        KEYBIND_STRIP:SetStyle(KEYBIND_STRIP_STANDARD_STYLE)
    end
end

function ADDON:RestorePromptStyles()
    if self.runtime.promptStyleOriginal ~= nil and KEYBIND_STRIP_STANDARD_STYLE then
        KEYBIND_STRIP_STANDARD_STYLE.alwaysPreferGamepadMode = self.runtime.promptStyleOriginal
    end
    RestoreSavedValues()
    RefreshRegisteredPromptLabels()
    RefreshReticlePrompt()
    RefreshPlayerInteractionPrompt()
end
