-- ESO Hybrid UI: the single shared addon table, string ids, defaults, runtime state.
-- User-facing strings live in lang/*.lua.

local ADDON = _G.ESOHybridUI or {}
_G.ESOHybridUI = ADDON

ADDON.ADDON_NAME = "ESOHybridUI"
ADDON.SAVED_VARIABLES = "ESOHybridUI_SavedVariables"
ADDON.SAVED_VARIABLES_VERSION = 1
ADDON.VERSION = "4.2.1-beta"

ADDON.MODE_GAMEPAD = "gamepad"
ADDON.MODE_HYBRID = "hybrid"

ADDON.POLICY_GAMEPAD = "gamepad"
ADDON.POLICY_LEGACY = "legacy"

ADDON.defaults = {
    mode = ADDON.MODE_HYBRID,
    -- Legacy policy is now the keyboard-template + controller-pointer path.
    -- The Gamepad policy remains available as a compatibility fallback.
    menuPolicy = ADDON.POLICY_LEGACY,

    hybridQuickslotWheel = true,
    hybridQuickslotBindingReminder = true,
    hybridActionBarGlyphs = true,
    keyboardControllerMousePointer = true,

    fonts = {
        reticle = "ZoFontKeybindStripDescription",
        reticleContext = "ZoInteractionPrompt",
        stealthIcon = "ZoInteractionPrompt",
    },

    announceLoaded = false,
    debugLoggingEnabled = false,
}

ADDON.runtime = {
    originalIsInGamepadPreferredMode = nil,
    modeOverrideInstalled = false,
    overrideFunction = nil,

    forceNativeModeDepth = 0,
    forceKeyboardWheelDepth = 0,
    forceKeyboardPresentationDepth = 0,

    hybrid = false,
    menusGamepad = false,

    isLockpicking = false,
    isRefreshing = false,
    platformDirty = false,
    platformRefreshScheduled = false,
    initialized = false,

    installed = {},
    attempts = {},
    retryRegistered = {},

    utilityWheelLayerActive = false,
    quickslotBindingReminderShown = false,

    mousePointerSceneHookInstalled = false,
    mousePointerSceneInputHookInstalled = false,
    mousePointerMissingLogged = false,

    promptOriginals = setmetatable({}, { __mode = "k" }),
    stackAllOriginals = setmetatable({}, { __mode = "k" }),

    logger = nil,
    debugLoggingEnabled = false,
    traceEnabled = false,
    trace = nil,
}
