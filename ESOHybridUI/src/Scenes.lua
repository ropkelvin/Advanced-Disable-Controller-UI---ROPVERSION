-- Scene tracking and early pointer-fragment attachment.
--
-- Register on each scene's StateChange callback, so the pointer fragment is
-- attached during SCENE_SHOWING, before that scene refreshes its fragments.
-- A post-show polling attach can miss the first directional-input frame and
-- let ESO interpret the left stick as new gameplay movement.
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

local RESTRICTED_TOKENS = {
    "scrying", "tribute", "market", "crown", "gildbarstore",
    "endeavorsealstore", "esoplusoffers", "giftinventory",
    "dailyloginrewards", "tamrieltomes", "rewardpreview",
    "promotional", "chapterupgrade", "dyestampconfirmation",
}

local nameInfo = {}
local trackedScenes = {}
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
        menu = not restricted and not lockpick and not NON_MENU[lowered],
    }
    nameInfo[name] = info
    return info
end

local function AttachPointer(scene, name)
    local info = GetInfo(name)
    local pointerFragment = ADDON.PointerFragment
    if info.menu and pointerFragment
        and not scene:HasFragment(pointerFragment) then
        scene:AddFragment(pointerFragment)
        ADDON:Record("POINTER_ATTACH", name, "state=", scene:GetState())
    end
end

local function TrackScene(name, scene)
    if not scene or trackedScenes[scene] then
        return
    end
    trackedScenes[scene] = true

    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            AttachPointer(scene, name)
        end
    end)

    -- Also cover a menu that was already showing when HUI initialized.
    if scene:IsShowing() then
        AttachPointer(scene, name)
    end
end

local currentName = nil
local tick = 0

function ADDON:ResetSceneState()
    currentName = nil
    rt.restricted = false
    rt.menuScene = false
end

function ADDON:RefreshPointerScenes()
    local pointerFragment = ADDON.PointerFragment
    if pointerFragment and pointerFragment.Refresh then
        pointerFragment:Refresh()
    end
end

local function Poll()
    if not rt.inWorld or not SCENE_MANAGER then
        return
    end

    -- Scene definitions may be registered by other addons after player
    -- activation. Track them before they are next opened.
    for name, scene in pairs(SCENE_MANAGER.scenes or {}) do
        TrackScene(name, scene)
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

    -- Attach callbacks to every scene already registered. The update below
    -- only discovers scenes registered later; it no longer waits until a
    -- scene is SHOWN before attaching the pointer fragment.
    for name, scene in pairs(SCENE_MANAGER.scenes or {}) do
        TrackScene(name, scene)
    end

    EVENT_MANAGER:RegisterForUpdate(POLL_NAME, POLL_MS, Poll)
    rt.scenesPolling = true
end
