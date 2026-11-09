## HybridUI

A clean, original ESO addon implementation targeting two modes:

- **Native Gamepad UI** — ESO's complete native Gamepad interface.
- **Hybrid UI** — native Gamepad menus, inventory, map, interactions and dialogues, with the original Keyboard gameplay HUD completely unchanged.

The addon includes an option to set ESO's Gamepad Mode preference to **On** (Always Gamepad), rather than Auto.

## Current development status

The clean branch currently contains the addon manifest, account-wide settings, a LibAddonMenu configuration panel, the two-mode selector, and the supported ESO setting call for Always Gamepad.

**The HUD-only Hybrid behavior is not implemented yet.** This is intentional: overriding ESO's global `IsInGamepadPreferredMode()` also changes how ESO chooses menu and interaction scenes, so it cannot safely satisfy the requirement. The next implementation step is to integrate with the native HUD fragments/platform selection without modifying the Keyboard HUD itself, then validate all scene transitions in a live client. This branch is not release-ready yet.

## Dependencies

- LibAddonMenu-2.0 version 43 or newer.

## ESOUI compliance checklist

- No executables or bundled third-party libraries.
- Account-wide SavedVariables.
- Minimal local Lua scope; only ESO's required event registration is global.
- Update APIVersion against the live client before release.
- AI-assisted development disclosed; generated code must be reviewed and tested before publication.
- Package the ZIP with the HybridUI folder at the archive root and remove hidden files/folders.

## Install for development

Place the HybridUI folder in Documents/Elder Scrolls Online/live/AddOns/ and install the required LibAddonMenu-2.0 library.
