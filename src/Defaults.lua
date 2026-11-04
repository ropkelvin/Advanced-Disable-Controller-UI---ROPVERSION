-- ESO Hybrid UI
-- Native gamepad behavior with optional keyboard-style gameplay HUD.

local ADDON = _G.ESOHybridUI or {}
_G.ESOHybridUI = ADDON

ZO_CreateStringId("SI_KEYBINDINGS_CATEGORY_ESO_HYBRID_UI", "ESO Hybrid UI")
ZO_CreateStringId("SI_BINDING_NAME_ESOHYBRIDUI_TOGGLE_UI", "Toggle keyboard-style HUD")

ADDON.ADDON_NAME = "ESOHybridUI"
ADDON.SAVED_VARIABLES = "ESOHybridUI_SavedVariables"
ADDON.SAVED_VARIABLES_VERSION = 1
ADDON.VERSION = "3.4.0"

ADDON.defaults = {
    useControllerUI = true,
    useHybridUI = false,
    useGamepadButtons = true,
    fonts = {
        reticle = "ZoFontKeybindStripDescription",
        reticleContext = "ZoInteractionPrompt",
        stealthIcon = "ZoInteractionPrompt",
    },
    debugLoggingEnabled = false,
}

ADDON.runtime = {
    initialized = false,
    actionButtonHooksInstalled = false,
    logger = nil,
    debugLoggingEnabled = false,
}
