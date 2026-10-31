-- Keep the keyboard map's default pan origin when opened with a controller.

local ADDON = ADCUI

local function ResetWorldMapOffset()
    local settings = ADDON:GetSettings()
    if not settings.centerWorldMap or not ZO_WorldMap_GetPanAndZoom then return end

    local map = ZO_WorldMap_GetPanAndZoom()
    if map then
        -- Clear the previous pan/lock target, then establish the map's
        -- normal centered offset for the current window dimensions.
        if map.ClearLockPoint then map:ClearLockPoint() end
        if map.ClearTargetOffset then map:ClearTargetOffset() end
        if map.AddTargetOffsetDelta then map:AddTargetOffsetDelta(0, 0) end
    end
end

local function InstallHybridMapCategoryHook()
    if ADDON.runtime.hybridMapCategoryHookInstalled or not ZO_PreHook then
        return
    end

    local mainMenu = MAIN_MENU_KEYBOARD
    if not mainMenu or type(mainMenu.ToggleCategory) ~= "function" then
        return
    end

    ZO_PreHook(mainMenu, "ToggleCategory", function(_, category)
        local settings = ADDON:GetSettings()
        if settings.useHybridUI and ADDON:IsNativeGamepadMode() and category == MENU_CATEGORY_MAP then
            -- The dedicated Map button is routed through the keyboard main-menu
            -- object in Hybrid mode. Bypass its keyboard scene selection.
            ADDON:WithNativeGamepadMode(function()
                SCENE_MANAGER:Show("gamepad_worldMap")
            end)
            return true
        end
        return false
    end)

    ADDON.runtime.hybridMapCategoryHookInstalled = true
end

local function InstallHybridWorldMapSceneHook()
    if ADDON.runtime.hybridWorldMapHookInstalled or type(ZO_WorldMap_ShowWorldMap) ~= "function" then
        return
    end

    local originalShowWorldMap = ZO_WorldMap_ShowWorldMap
    ADDON.runtime.originalShowWorldMap = originalShowWorldMap
    ZO_WorldMap_ShowWorldMap = function(...)
        local settings = ADDON:GetSettings()
        if settings.useHybridUI and ADDON:IsNativeGamepadMode() then
            -- ESO chooses between "worldMap" and "gamepad_worldMap" inside
            -- this function. Force the native platform only for that choice;
            -- gameplay immediately returns to the compact keyboard HUD.
            return ADDON:WithNativeGamepadMode(originalShowWorldMap, ...)
        end
        return originalShowWorldMap(...)
    end

    ADDON.runtime.hybridWorldMapHookInstalled = true
end

function ADDON:ApplyWorldMap()
    InstallHybridWorldMapSceneHook()
    InstallHybridMapCategoryHook()
    if self.runtime.worldMapHooksInstalled then return end

    if WORLD_MAP_SCENE and WORLD_MAP_SCENE.RegisterCallback then
        WORLD_MAP_SCENE:RegisterCallback("StateChange", function(oldState, newState)
            if newState == SCENE_SHOWN then
                ResetWorldMapOffset()
            end
        end)
    end

    self.runtime.worldMapHooksInstalled = true
end
