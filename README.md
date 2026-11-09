## HybridUI

A fresh ESO addon implementation with two requested modes:

- **Native Gamepad UI** — leave ESO's native Gamepad UI in control.
- **Hybrid UI** — native Gamepad menus and a Keyboard-style gameplay HUD.

The addon also offers an option to set ESO's Gamepad Mode preference to **On** (Always Gamepad), rather than Auto.

## Development status

This is an initial implementation scaffold. The mode selector, account-wide saved settings, LibAddonMenu settings panel, and Always Gamepad preference are implemented. The Hybrid HUD handoff is an early scene-level implementation and is **not yet verified in a live ESO client**. It must not be considered release-ready until the HUD is confirmed to be the unmodified native Keyboard HUD and all menus/interactions are confirmed to remain native Gamepad UI.

## Dependencies

- LibAddonMenu-2.0 version 43 or newer.

## ESOUI compliance

- No executable files or bundled third-party libraries.
- Uses account-wide SavedVariables.
- Keeps addon globals limited to ESO's required event registration and local implementation state.
- API version must be checked against the live client before release.
- AI-assisted code is disclosed here; all generated code must be reviewed and tested before publication.

## Install

Place the HybridUI folder in Documents/Elder Scrolls Online/live/AddOns/ and install the required LibAddonMenu-2.0 library.
