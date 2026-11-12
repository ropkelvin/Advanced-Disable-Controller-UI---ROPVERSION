-- World map follows the selected scene presentation like other menus.
-- In Hybrid the keyboard map is selected and receives LibMousePointer. We do not
-- force the Gamepad map here: doing so would mix keyboard HUD and native map state.

local ADDON = ESOHybridUI

function ADDON:ApplyWorldMap()
    -- No map hooks required. ScenePolicy and MousePointer handle the keyboard map.
end
