-- Advanced Disable Controller UI
-- Modernized core. Keep the original SavedVariables name and schema version
-- so existing 1.5.3 preferences are not discarded.

ADCUI = ADCUI or {}

ADCUI.ADDON_NAME = "AdvancedDisableControllerUI"
ADCUI.SAVED_VARIABLES = "AdvancedDisableControllerUI_SavedPrefs"
ADCUI.SAVED_VARIABLES_VERSION = 1

ADCUI.defaults = {
    -- Original 1.5.3 settings retained for SavedVariables compatibility.
    scale = 1,
    width = 550,
    height = 30,
    point = TOP,
    lockEnabled = false,
    anchorOffsetX = 0,
    anchorOffsetY = 40,
    pinLabelScale = 1,
    useAccountWideSettings = false,
    useControllerUI = false,
    useGamepadButtons = true,
    useGamepadActionBar = true,
    fonts = {
        reticle = "ZoFontKeybindStripDescription",
        reticleContext = "ZoInteractionPrompt",
        stealthIcon = "ZoInteractionPrompt",
    },
}

ADCUI.runtime = {
    originalIsInGamepadPreferredMode = nil,
    isLockpicking = false,
    isRefreshing = false,
    initialized = false,
}
