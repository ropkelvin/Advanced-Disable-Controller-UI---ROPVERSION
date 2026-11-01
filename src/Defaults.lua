-- ESO Hybrid UI
-- ESO Hybrid UI Update 51 baseline and maintained configuration.

ESOHybridUI = ESOHybridUI or {}

if ZO_CreateStringId then
    ZO_CreateStringId("SI_KEYBINDINGS_CATEGORY_ESO_HYBRID_UI", "ESO Hybrid UI")
    ZO_CreateStringId("SI_BINDING_NAME_ESOHYBRIDUI_TOGGLE_UI", "Toggle keyboard / gamepad UI")
    ZO_CreateStringId("SI_BINDING_NAME_ESOHYBRIDUI_TOGGLE_BUTTONS", "Toggle gamepad button prompts")
    ZO_CreateStringId("SI_BINDING_NAME_ESOHYBRIDUI_TOGGLE_ACTION_BAR", "Toggle gamepad action bar")
    ZO_CreateStringId("SI_BINDING_NAME_ESOHYBRIDUI_TOGGLE_RESOURCE_BARS", "Toggle gamepad resource bars")
end

ESOHybridUI.ADDON_NAME = "ESOHybridUI"
ESOHybridUI.SAVED_VARIABLES = "ESOHybridUI_SavedVariables"
ESOHybridUI.SAVED_VARIABLES_VERSION = 1
ESOHybridUI.VERSION = "3.0.3"

ESOHybridUI.defaults = {
    -- Main behavior
    useControllerUI = false,
    useHybridUI = false,
    useGamepadButtons = true,
    useGamepadActionBar = false,
    useGamepadResourceBars = false,

    -- Reticle / stealth prompt fonts
    fonts = {
        reticle = "ZoFontKeybindStripDescription",
        reticleContext = "ZoInteractionPrompt",
        stealthIcon = "ZoInteractionPrompt",
    },

    useAccountWideSettings = false,
    debugLoggingEnabled = false,
}

ESOHybridUI.runtime = {
    originalIsInGamepadPreferredMode = nil,
    modeOverrideInstalled = false,
    forceNativeModeDepth = 0,
    isLockpicking = false,
    isRefreshing = false,
    initialized = false,
    actionBarHooksInstalled = false,
    resourceBarHooksInstalled = false,
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
