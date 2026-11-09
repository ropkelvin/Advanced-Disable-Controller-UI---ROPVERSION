**AI-assisted development disclosure:** This addon contains AI-assisted code that has not yet been verified in a live ESO client. Treat this branch as an experimental development build, not a release.

# HybridUI

HybridUI keeps ESO in native Gamepad mode and applies Keyboard-style presentation to gameplay HUD elements only.

## Current implementation

- Reuses ESO's Keyboard HUD element anchors for controls registered as both Keyboard and Gamepad HUD elements. This includes the native HUD positioning definitions and existing Keyboard saved positions.
- Applies ESO's Keyboard resource-bar templates to the native player attribute bars.
- Applies the Keyboard compass frame template and Keyboard compass anchor.
- Applies the Keyboard boss-bar template.
- Keeps the original ESO HUD controls, resource/event logic, and Gamepad mode active.
- Adds one setting to enable or disable Keyboard HUD presentation.

## Explicitly untouched

- `IsInGamepadPreferredMode` is not persistently overridden.
- The Gamepad Mode setting is not changed.
- No scene, menu, inventory, map, dialogue, interaction, lockpicking, UI-system or input routing is patched.
- No Keyboard menu is forced into Gamepad scenes or vice versa.

The platform helper overrides used for individual style passes are temporary and restored immediately after the relevant native HUD style function returns.

## Important limitations

This is an incremental HUD implementation, not yet a complete pixel-identical Keyboard HUD. The action bar still needs a dedicated Keyboard geometry/style adapter; group and target frames still need their full Keyboard-specific styling, not just the Keyboard HUD anchor positions. Other HUD components need individual review before being added. Gamepad prompts and keybind glyphs must be checked in the client before claiming parity.

## Dependency

- LibAddonMenu-2.0 r43 or newer. Install separately; it is not bundled.

## Testing status

Static implementation only; not tested in a live ESO client. Test resource bars, compass, boss bar, group/target frames, action bar, prompt glyphs, combat visibility, boss transitions, screen resizing, and menu open/close transitions.

## Development references

- [Official ESO UI source](https://github.com/esoui/esoui) — inspected for the native HUD manager, platform templates, resource bars, compass, boss bar and action bar layout.
- [ESOUI addon developer guidance](https://www.esoui.com/forums/showthread.php?t=10790).
- [Fancy Action Bar+](https://www.esoui.com/downloads/info3938-190624.html) — reference for the separation of Keyboard and Gamepad action-bar presentation and configuration.

No ESO source files are copied into this addon. The source repository is used as API and layout reference only.

## Packaging

The ZIP root must contain the `HybridUI` folder. Do not bundle LibAddonMenu or unrelated addons. Keep the AI disclosure until the implementation has been personally reviewed and validated.
