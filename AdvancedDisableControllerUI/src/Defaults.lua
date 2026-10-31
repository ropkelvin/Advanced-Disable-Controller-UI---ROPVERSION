-- Advanced Disable Controller UI
-- Modern Update 51 baseline. The original SavedVariables namespace is retained.

ADCUI = ADCUI or {}

ADCUI.ADDON_NAME = "AdvancedDisableControllerUI"
ADCUI.SAVED_VARIABLES = "AdvancedDisableControllerUI_SavedPrefs"
ADCUI.SAVED_VARIABLES_VERSION = 1
ADCUI.VERSION = "2.1.0"

ADCUI.defaults = {
    -- Main behavior
    useControllerUI = false,
    useGamepadButtons = true,
    useGamepadActionBar = false,
    useGamepadLockpicking = true,
    enableMainMenuShoulderButtons = true,
    centerWorldMap = true,

    -- Compass
    enableCompassCustomization = true,
    scale = 1.0,
    width = 550,
    height = 30,
    point = TOP,
    anchorOffsetX = 0,
    anchorOffsetY = 40,
    lockEnabled = false,
    pinLabelScale = 1.0,

    -- Reticle / stealth prompt fonts
    fonts = {
        reticle = "ZoFontKeybindStripDescription",
        reticleContext = "ZoInteractionPrompt",
        stealthIcon = "ZoInteractionPrompt",
    },

    useAccountWideSettings = false,
}

ADCUI.runtime = {
    originalIsInGamepadPreferredMode = nil,
    forceNativeModeDepth = 0,
    isLockpicking = false,
    isRefreshing = false,
    initialized = false,
    actionBarHooksInstalled = false,
    promptHooksInstalled = false,
    compassHooksInstalled = false,
    mainMenuHooksInstalled = false,
    worldMapHooksInstalled = false,
    utilityWheelHooksInstalled = false,
    utilityWheelDefaultsCopied = false,
    utilityWheelLayerActive = false,
    menuGroupActive = false,
    promptOriginals = {},
    stackAllOriginals = setmetatable({}, { __mode = "k" }),
    compassOriginal = nil,
}
