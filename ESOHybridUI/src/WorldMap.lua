-- Keep direct world-map opens on ESO's native gamepad map in Hybrid.
--
-- The Map button already resolves the native gamepad main-menu object through
-- Core.lua's SYSTEMS:GetObject hook. Only direct calls to ESO's map helper need
-- this narrow compatibility hook.

local ADDON = ESOHybridUI

local function InstallMapSceneHook()
    local originalShowWorldMap = _G.ZO_WorldMap_ShowWorldMap
    if type(originalShowWorldMap) ~= "function" then
        return false
    end

    -- The native helper selects its scene from IsInGamepadPreferredMode().
    -- Run it under the real gamepad preference, without changing the HUD policy.
    ZO_PreHook("ZO_WorldMap_ShowWorldMap", function(...)
        if ADDON:IsHybrid() and ADDON:IsNativeGamepadMode() then
            ADDON:WithNativeGamepadMode(originalShowWorldMap, ...)
            return true
        end
        return false
    end)
    return true
end

function ADDON:ApplyWorldMap()
    self:InstallWhenReady("mapSceneHook", InstallMapSceneHook)
end
