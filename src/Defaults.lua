-- ESO Hybrid UI
-- ESO Hybrid UI Update 51 baseline and maintained configuration.

-- Keep one shared addon table under the exact global name used by every module.
-- Accept the legacy all-caps alias so existing sessions/profiles remain compatible.
local ADDON = _G.ESOHybridUI or _G.ESOHYBRIDUI or {}
_G.ESOHybridUI = ADDON
_G.ESOHYBRIDUI = ADDON
ESOHYBRIDUI = ADDON

ZO_CreateStringId("SI_KEYBINDINGS_CATEGORY_ESO_HYBRID_UI", "ESO Hybrid UI")
ZO_CreateStringId("SI_BINDING_NAME_ESOHYBRIDUI_TOGGLE_UI", "Toggle gamepad / hybrid UI")

ADDON.ADDON_NAME = "ESOHybridUI"
ADDON.SAVED_VARIABLES = "ESOHybridUI_SavedVariables"
ADDON.SAVED_VARIABLES_VERSION = 1
ADDON.VERSION = "3.1.1"

ADDON.defaults = {
    -- Main behavior
    useControllerUI = true,
    useHybridUI = false,
    useGamepadButtons = true,

    -- Reticle / stealth prompt fonts
    fonts = {
        reticle = "ZoFontKeybindStripDescription",
        reticleContext = "ZoInteractionPrompt",
        stealthIcon = "ZoInteractionPrompt",
    },

    useAccountWideSettings = false,
    debugLoggingEnabled = false,
}

ADDON.runtime = {
    originalIsInGamepadPreferredMode = nil,
    modeOverrideInstalled = false,
    forceNativeModeDepth = 0,
    isLockpicking = false,
    isRefreshing = false,
    initialized = false,
    actionBarHooksInstalled = false,
    promptHooksInstalled = false,
    worldMapHooksInstalled = false,
    utilityWheelHooksInstalled = false,
    utilityWheelDefaultsCopied = false,
    utilityWheelLeftCopied = false,
    utilityWheelRightCopied = false,
    utilityWheelLayerActive = false,
    promptOriginals = {},
    stackAllOriginals = setmetatable({}, { __mode = "k" }),
    logger = nil,
    debugLoggingEnabled = false,
}
