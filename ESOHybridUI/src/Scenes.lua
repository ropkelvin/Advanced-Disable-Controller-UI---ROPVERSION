-- Scene state tracking for mode exceptions and controller navigation.
-- ESO retains ownership of both sticks and its native directional navigation.
local ADDON = ESOHybridUI
local rt = ADDON.rt

local POLL_NAME = "ESOHybridUI_Scenes"
local POLL_MS = 100
local RESYNC_EVERY = 4

local NON_MENU = {
    hud = true, hudui = true, loot = true, loot_keyboard = true,
    loot_gamepad = true, loading = true, characterselect = true,
    lockpickkeyboard = true, lockpickgamepad = true,
}

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

    info = {
        restricted = restricted,
        lockpick = string.find(lowered, "lockpick", 1, true) ~= nil,
        menu = not restricted and not NON_MENU[lowered]
            and string.find(lowered, "lockpick", 1, true) == nil,
    }
    nameInfo[name] = info
    return info
end

local currentName
local tick = 0

function ADDON:ResetSceneState()
    currentName = nil
    rt.restricted = false
    rt.menuScene = false
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
