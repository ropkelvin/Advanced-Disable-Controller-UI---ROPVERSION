**AI-assisted development disclosure:** This addon contains AI-assisted code that has not yet been verified in a live ESO client. Treat this branch as an experimental development build, not a release.

# HybridUI

HybridUI keeps ESO in native Gamepad mode and applies the original Keyboard presentation to gameplay HUD elements only.

## Implemented Keyboard HUD adapters

- **HUD positioning:** Reuses ESO's own Keyboard HUD-manager elements and their saved/default anchors for controls that register both Keyboard and Gamepad elements.
- **Player resource bars:** Uses native Keyboard templates for Health, Magicka and Stamina while retaining ESO's existing bar controls, values, events and visibility behaviour.
- **Action bar:** Applies the official Keyboard layout constants: 483-pixel width, Keyboard anchor, slot spacing, ultimate offset, weapon-swap position, quickslot position, back-bar offsets and Keyboard button templates. Individual native action-button objects are adapted so later slot/ability updates continue to select Keyboard templates.
- **Compass:** Uses the Keyboard compass frame template, overlays and Keyboard HUD anchor.
- **Boss bar:** Uses the Keyboard boss-bar template.
- **Group and target frames:** Uses ESO's native unit-frame Keyboard style pass, including Keyboard frame templates, bar layout, dimensions, fonts and visualizer styling.

The implementation uses ESO's native controls and data/event logic. It does not replace combat actions or create a second set of resource/action bars.

## Explicitly untouched

- ESO remains in native Gamepad mode.
- No persistent override of `IsInGamepadPreferredMode`; temporary scoped presentation contexts are restored immediately after the individual HUD style pass.
- The Gamepad Mode setting is not changed.
- No scene, menu, inventory, map, dialogue, interaction, lockpicking, UI-system or input routing is patched.
- Gamepad controls remain the source of gameplay input.

## Remaining work before claiming exact parity

The HUD is not yet certified pixel-identical. Additional HUD elements still need individual review and adapters where their Keyboard presentation differs: synergy prompts, reticle/crosshair, buffs and debuffs, HUD trackers, equipment status, subtitles, alerts, score meters and contextual prompts. Button/keybind glyphs also require live controller testing to confirm that Keyboard artwork does not accidentally expose PC key labels.

## Dependency

- LibAddonMenu-2.0 r43 or newer. Install separately; it is not bundled.

## Testing status

Static implementation only; not tested in a live ESO client. Test resource bars, action-bar slots after skill swaps, ultimate and companion ultimate, quickslot, weapon swap, compass, boss bar, group/target frames, Gamepad glyphs, screen resizing, combat visibility and menu open/close transitions.

## Development references

- [Official ESO UI source](https://github.com/esoui/esoui) — inspected for the native HUD manager, player attribute bars, action bar, compass, boss bar and unit-frame layout/style APIs.
- [Fancy Action Bar+](https://www.esoui.com/downloads/info3938-190624.html) — reference for the distinction between Keyboard and Gamepad action-bar styling and positioning.
- [ESOUI addon developer guidance](https://www.esoui.com/forums/showthread.php?t=10790).

No ESO source files are copied into this addon. The source repository is used as an API and layout reference only.

## Packaging

The ZIP root must contain the `HybridUI` folder. Do not bundle LibAddonMenu or unrelated addons. Keep the AI disclosure until the implementation has been personally reviewed and validated.
