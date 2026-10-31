# Advanced Disable Controller UI — modernization

This repository retains the original 1.5.3 archive and extracted source under
`extracted/`. The new addon lives in `AdvancedDisableControllerUI/`.

## Current target

- ESO live API: 101051 (Update 51 / October 2026 source snapshot).
- LibAddonMenu-2.0: native dependency, minimum AddOnVersion 43.
- No LibStub calls or bundled library copies.
- Original SavedVariables name and schema version are retained to avoid
  intentionally resetting existing user preferences.

## First modernization milestone

The new core focuses on the primary use case: keep physical gamepad input while
making ESO's UI report keyboard mode. The native gamepad UI can be restored
through the settings panel or `/adcui`.

The old action-bar/resource-bar overrides, gamepad prompt remapping, compass
customization, and main-menu shoulder navigation are not loaded by this rewrite.
They are preserved in `extracted/` for controlled reimplementation after their
current UI dependencies are checked against the live ESO source.

## Install for testing

Copy the `AdvancedDisableControllerUI` folder into:
`Documents/Elder Scrolls Online/live/AddOns/`

Install LibAddonMenu-2.0 separately and ensure version 43 or newer is enabled.

## In-game checks still required

1. Load with a controller connected and Gamepad Preferred enabled in ESO.
2. Confirm movement, combat, weapon swap, interaction, and menus still accept
   controller input while the keyboard-style UI is shown.
3. Toggle the native gamepad UI using `/adcui` and the settings checkbox.
4. Test lockpicking success, failure, and exiting the lockpicking UI.
5. Check bank, guild, inventory, map, journal, dialogs, and character select.
6. Check for conflicts with other addons that replace
   `IsInGamepadPreferredMode()`.

This is a code modernization milestone, not a claim of verified in-game
compatibility. The live game client is required for runtime validation.
