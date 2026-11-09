**AI-assisted development disclosure:** This addon contains AI-assisted code that has not yet been verified in a live ESO client. Treat this branch as an experimental development build, not a release.

# HybridUI

HybridUI is being rebuilt around a HUD-only rule:

- ESO stays in native Gamepad mode.
- Native Gamepad menus, inventory, map, interactions, dialogues, lockpicking, input handling and scene routing are not modified.
- The addon changes HUD presentation only.

## Current implementation scope

The first adapter styles the native Health, Magicka and Stamina resource bars with ESO's original Keyboard platform templates while retaining the native Gamepad resource-bar objects, power updates, visibility logic and combat behavior.

It scopes the Keyboard template selection to the resource-bar style pass. It does not override `IsInGamepadPreferredMode`, change the Gamepad Mode setting, patch scenes, route UI systems, force dialogs, or replace input handlers.

**This is a first HUD adapter, not yet a complete Keyboard-HUD replica.** Compass, action bar, target frame, group frames, buffs, interaction prompts and other HUD elements still need separate inspection and compatible HUD-only adapters. They must not be changed by global platform switching.

## Dependency

- LibAddonMenu-2.0 r43 or newer. Install separately; it is not bundled.

## Testing status

Static implementation only; not tested in a live ESO client. Verify the resource bars in Gamepad mode, then open and close menus and confirm the native Gamepad UI remains unchanged. Test resource values, low-resource warnings, shields, fading, mount/siege states and different resolutions.

## Development references

- [Official ESO UI source](https://github.com/esoui/esoui) — used to inspect the native HUD manager and player attribute bar templates. No ESO source files are copied into this addon.
- [ESOUI addon developer guidance](https://www.esoui.com/forums/showthread.php?t=10790).
- [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-libaddonmenu.html).

## Packaging

The ZIP root must contain the `HybridUI` folder. Do not bundle LibAddonMenu or unrelated addons. Keep the AI disclosure until the implementation has been personally reviewed and validated.
