-- Owned-keybind manager. HUI adds a few controller actions to the keybind
-- strip; a screen's own binding for the same key always wins, and ours comes
-- back when the screen releases it.
local ADDON = ESOHybridUI
local rt = ADDON.rt

local ours = {}      -- descriptor -> true
local byKeybind = {} -- keybind name -> our descriptor
local wanted = {}    -- descriptor -> true while its feature is on

local function Unwrap(value)
    if type(value) == "userdata" then
        return value.keybindButtonDescriptor
    end
    return value
end

local function HeldByOther(descriptor)
    local keybinds = KEYBIND_STRIP and KEYBIND_STRIP.keybinds
    local held = Unwrap(keybinds and keybinds[descriptor.keybind])
    return held ~= nil and held ~= descriptor
end

-- The strip itself is the source of truth (HasKeybindButton), never a flag.
local function Sync(descriptor)
    if not KEYBIND_STRIP then
        return
    end
    local present = KEYBIND_STRIP:HasKeybindButton(descriptor)
    -- Remove HUI-owned descriptors during player deactivation as well; the
    -- keybind strip may still exist while the loading transition is underway.
    local should = rt.inWorld and wanted[descriptor] == true and not HeldByOther(descriptor)
    if should and not present then
        KEYBIND_STRIP:AddKeybindButton(descriptor)
    elseif not should and present then
        KEYBIND_STRIP:RemoveKeybindButton(descriptor)
    end
end

function ADDON:SetKeybind(descriptor, active)
    ours[descriptor] = true
    byKeybind[descriptor.keybind] = descriptor
    wanted[descriptor] = active and true or nil
    Sync(descriptor)
end

-- Safety net, called from the scene poll: picks up any claim or release the
-- hooks below did not see.
function ADDON:ResyncKeybinds()
    for descriptor in pairs(ours) do
        Sync(descriptor)
    end
end

function ADDON:InitializeKeybinds()
    if rt.keybindsHooked or not KEYBIND_STRIP then
        return
    end

    -- A screen claiming a key we hold: step aside before it is processed.
    -- (Leaf hook: AddKeybindButton never reaches protected game functions.)
    ZO_PreHook(KEYBIND_STRIP, "AddKeybindButton", function(strip, descriptor, stateIndex)
        if descriptor and not ours[descriptor] then
            local mine = byKeybind[descriptor.keybind]
            if mine and strip:HasKeybindButton(mine) then
                strip:RemoveKeybindButton(mine, stateIndex)
            end
        end
        return false
    end)

    rt.keybindsHooked = true
end
