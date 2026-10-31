-- Keep the keyboard map's default pan origin when opened with a controller.

local ADDON = ADCUI

local function ResetWorldMapOffset()
    local settings = ADDON:GetSettings()
    if not settings.centerWorldMap or not ZO_WorldMap_GetPanAndZoom then return end

    local map = ZO_WorldMap_GetPanAndZoom()
    if map and map.AddTargetOffsetDelta then
        map:AddTargetOffsetDelta(0, 0)
    end
end

function ADDON:ApplyWorldMap()
    if self.runtime.worldMapHooksInstalled then return end

    if ZO_WorldMapManager and ZO_WorldMapManager.RegisterCallback then
        ZO_WorldMapManager:RegisterCallback("Showing", ResetWorldMapOffset)
    end
    if WORLD_MAP_SCENE and WORLD_MAP_SCENE.RegisterCallback then
        WORLD_MAP_SCENE:RegisterCallback("StateChange", function(oldState, newState)
            if newState == SCENE_SHOWN then
                ResetWorldMapOffset()
            end
        end)
    end

    self.runtime.worldMapHooksInstalled = true
end
