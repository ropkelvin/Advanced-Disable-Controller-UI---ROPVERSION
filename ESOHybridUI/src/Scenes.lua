-- Scene tracking by polling the current scene name. No hooks on
-- SCENE_MANAGER on purpose: a hook wrapped around Show/OnSceneStateChange sits
-- above the whole scene transition, so ESO treats every screen that opens
-- inside it (e.g. Tamriel Tomes calling a private store function) as
-- insecure code and throws. Polling is a leaf call and taints nothing.
local ADDON = ESOHybridUI
local rt = ADDON.rt

local POLL_NAME = "ESOHybridUI_Scenes"
local POLL_MS = 50
local RESYNC_EVERY = 4 -- polls

local NON_MENU = {
    hud = true, hudui = true, loot_gamepad = true, loading = true,
    characterselect = true, lockpickkeyboard = true, lockpickgamepad = true,
}

-- Matched as substrings so keyboard/gamepad variants are both covered.
-- "scrying" is deliberately distinct from "scribing".
local RESTRICTED_TOKENS = {
    "scrying", "tribute", "market", "crown", "gildbarstore",
    "endeavorsealstore", "esoplusoffers", "giftinventory", "dailyloginrewards",
}

local nameInfo = {}
local function GetInfo(name)
    local info = nameInfo[name]
    if info then
        return info
    end
    local lowered = string.lower(name)
    local restricted = false
    for i = 1, #RESTRICTED_TOKENS do
        if string.find(lowered, RESTRICTED_TOKENS[i], 1, true) then
            restricted = true
            break
        end
    end
    local lockpick = string.find(lowered, "lockpick", 1, true) ~= nil
    info = {
        restricted = restricted,
        lockpick = lockpick,
        menu = not restricted and not lockpick and not NON_MENU[lowered]
            and not string.find(lowered, "gamepad", 1, true),
    }
    nameInfo[name] = info
    return info
end

local currentName = nil
local attached = {}
local tick = 0

function ADDON:ResetSceneState()
    currentName = nil
    rt.restricted = false
    rt.menuScene = false
end

-- The pointer fragment is attached once per menu scene, only after that scene
-- is fully SHOWN (never mid-transition, where adding a fragment could finish
-- the transition inside our own call). After that, the fragment's conditional
-- decides whether it shows; Refresh() re-evaluates it.
function ADDON:RefreshPointerScenes()
    if MOUSE_POINTER_FRAGMENT and MOUSE_POINTER_FRAGMENT.Refresh then
        MOUSE_POINTER_FRAGMENT:Refresh()
    end
end

local function Poll()
    if not rt.inWorld or not SCENE_MANAGER then
        return
    end

    local name = SCENE_MANAGER:GetCurrentSceneName()
    if type(name) ~= "string" then
        return
    end
    local info = GetInfo(name)

    if name ~= currentName then
        currentName = name
        rt.menuScene = info.menu
        rt.lockPick = info.lockpick
        rt.restricted = info.restricted
        ADDON:Record("SCENE", name)
        ADDON:ApplyMode()
    end

    if info.menu and MOUSE_POINTER_FRAGMENT and not attached[name] then
        local scene = SCENE_MANAGER:GetScene(name)
        if scene and scene:GetState() == SCENE_SHOWN then
            attached[name] = true
            if not scene:HasFragment(MOUSE_POINTER_FRAGMENT) then
                scene:AddFragment(MOUSE_POINTER_FRAGMENT)
            end
        end
    end

    tick = tick + 1
    if tick >= RESYNC_EVERY then
        tick = 0
        ADDON:ResyncKeybinds()
    end
end

function ADDON:InitializeScenes()
    if rt.scenesPolling then
        return
    end
    EVENT_MANAGER:RegisterForUpdate(POLL_NAME, POLL_MS, Poll)
    rt.scenesPolling = true
end
