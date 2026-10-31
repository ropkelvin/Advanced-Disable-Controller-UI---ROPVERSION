-- Native Gamepad interactions that must remain controller-friendly in Hybrid Mode.

local ADDON = ESOHybridUI

local function ShouldUseHybridGamepadLoot()
    local settings = ADDON:GetSettings()
    return settings.useHybridUI == true
        and settings.useControllerUI ~= true
        and ADDON:IsNativeGamepadMode()
end

local function ShouldForceControllerPrompts()
    local settings = ADDON:GetSettings()
    return settings.useGamepadButtons == true
        and settings.useControllerUI ~= true
        and ADDON:IsNativeGamepadMode()
end

local function InstallLootUpdateHook()
    if ADDON.runtime.lootUpdateHookInstalled or not ZO_Loot
        or type(ZO_Loot.UpdateLootWindow) ~= "function" then
        return
    end

    local original = ZO_Loot.UpdateLootWindow
    ADDON.runtime.originalLootUpdateWindow = original

    ZO_Loot.UpdateLootWindow = function(self, name, actionName, isOwned, ...)
        if ShouldUseHybridGamepadLoot()
            and LOOT_COMMON_GAMEPAD
            and type(LOOT_COMMON_GAMEPAD.UpdateLootWindow) == "function" then
            -- ESO's Gamepad loot system handles pickup and inventory-loot scenes.
            return LOOT_COMMON_GAMEPAD:UpdateLootWindow(name, actionName, isOwned, ...)
        end
        return original(self, name, actionName, isOwned, ...)
    end

    ADDON.runtime.lootUpdateHookInstalled = true
end

local function RefreshSynergyPrompt(forceGamepad)
    if SYNERGY and SYNERGY.key and type(SYNERGY.key.SetKeybind) == "function" then
        -- Preserve the actual USE_SYNERGY action and the user's configured chord.
        SYNERGY.key:SetKeybind("USE_SYNERGY", false, nil, forceGamepad)
    end
end

local function RefreshDeathKeybinds(death, forceGamepad)
    if not death or type(death.types) ~= "table" then return end

    for _, deathType in pairs(death.types) do
        if type(deathType.buttons) == "table" then
            for _, button in ipairs(deathType.buttons) do
                if button and button.keybind and type(button.SetKeybind) == "function" then
                    button:SetKeybind(button.keybind, false, button.gamepadPreferredKeybind, forceGamepad)
                end
            end
        end

        local recap = deathType.deathRecapToggleButton
        if recap and recap.keybind and type(recap.SetKeybind) == "function" then
            recap:SetKeybind(recap.keybind, false, recap.gamepadPreferredKeybind, forceGamepad)
        end
    end
end

local function InstallDeathStyleHook()
    if ADDON.runtime.deathStyleHookInstalled or not DEATH
        or type(DEATH.ApplyStyle) ~= "function" then
        return
    end

    local original = DEATH.ApplyStyle
    ADDON.runtime.originalDeathApplyStyle = original

    DEATH.ApplyStyle = function(self)
        local forceGamepad = ShouldForceControllerPrompts()

        local function ApplyWithCorrectBindings()
            RefreshDeathKeybinds(self, forceGamepad)
            return original(self)
        end

        if forceGamepad then
            -- Death:ApplyStyle queries IsInGamepadPreferredMode(). Temporarily
            -- expose ESO's real Gamepad preference without changing the HUD mode.
            return ADDON:WithNativeGamepadMode(ApplyWithCorrectBindings)
        end
        return ApplyWithCorrectBindings()
    end

    ADDON.runtime.deathStyleHookInstalled = true
end

function ADDON:ApplyHybridInteractions()
    InstallLootUpdateHook()
    InstallDeathStyleHook()

    local forceGamepadPrompts = ShouldForceControllerPrompts()
    RefreshSynergyPrompt(forceGamepadPrompts)

    if DEATH and type(DEATH.ApplyStyle) == "function" then
        DEATH:ApplyStyle()
    end
end
