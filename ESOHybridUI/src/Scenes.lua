-- Scene tracking. Polling avoids wrapping the scene transition stack (which
-- can taint calls into protected ESO UI code). Known restricted/native-special
-- scenes never get HUI's pointer fragment. Other keyboard scenes are treated
-- as menu scenes; newly introduced restricted screens must be added below.
local ADDON = ESOHybridUI
local rt = ADDON.rt

local POLL_NAME = "ESOHybridUI_Scenes"
local POLL_MS = 50
local RESYNC_EVERY = 4

local NON_MENU = {
    hud = true, hudui = true, loot = true, loot_keyboard = true,
    loot_gamepad = true, loading = true, characterselect = true,
    lockpickkeyboard = true, lockpickgamepad = true,
}

-- These screens deliberately retain ESO's native flow. Keep the list broad:
-- new/special monetization, reward and feature scenes should fail closed.
local RESTRICTED_TOKENS = {
    "scrying", "tribute", "market", "crown", "gildbarstore",
    "endeavorsealstore", "esoplusoffers", "giftinventory",
    "dailyloginrewards", "tamrieltomes", "rewardpreview",
    "promotional", "chapterupgrade", "dyestampconfirmation",
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
    local isGamepad = string.find(lowered, "gamepad", 1, true) ~= nil
    info = {
        restricted = restricted,
        lockpick = lockpick,
        menu = not restricted and not lockpick and not NON_MENU[lowered] and not isGamepad,
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
