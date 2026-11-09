**AI-assisted development disclosure:** This addon contains AI-assisted code that has not yet been verified in a live ESO client. Please treat this branch as an experimental development build, not a release.

# HybridUI

A clean implementation of the requested two-mode interface:

- **Native Gamepad UI** — leave ESO's normal Gamepad interface in control.
- **Hybrid UI** — native Gamepad menus, inventory, map, interactions and dialogues, with the original Keyboard platform style selected while ESO's base gameplay HUD scene is active.

The addon also provides an option to set ESO's Gamepad Mode preference to **On** (Always Gamepad), rather than Auto. The original setting is saved and restored if the option is disabled.

## Implementation approach

Hybrid mode uses ESO's own scene manager and platform-style selection path:

1. The preferred-mode query reports Keyboard only while the base HUD scene is active, so ESO's existing platform-style objects choose their native Keyboard styles for the HUD.
2. The HUD scene's requested-mode state is kept aligned with that HUD-only selection.
3. ESO system-object and root-scene selection is directed to the native Gamepad implementations while Hybrid mode is active.
4. Platform dialogs are routed to ESO's native Gamepad dialog path, and lockpicking opens ESO's native Gamepad lockpick scene.
5. After scene transitions, a temporary setting round-trip causes ESO's own platform-style manager to reapply styles. The user's actual Gamepad Mode setting is restored immediately.

No Keyboard HUD templates, controls, fonts, positions, textures, or layout formulas are recreated or edited by this addon.

## Dependencies

- **LibAddonMenu-2.0 r43 or newer** — required for the settings panel. Install it separately; it is not bundled.

## Current status

The implementation is committed to the `HybridUI` branch. It has been checked against the current public ESO UI source (API 101051) and the current ESOUI addon guidance, but it has **not** been exercised inside the live game client. In particular, the scene transitions, dialog edge cases, map/loot flows, and the platform-style refresh need in-client testing before this can be called complete or released.

## Development and compliance references

- [Official ESO UI source repository](https://github.com/esoui/esoui) — reference for native scenes, platform styles, UI system routing, and dialogs. No source files were copied into this addon.
- [ESOUI addon release best practices](https://www.esoui.com/forums/showthread.php?t=10790) — dependencies, API version, description, credits, and AI disclosure.
- [ESOUI addon policy / prohibited functionality](https://www.esoui.com/forums/showthread.php?t=9865).
- [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-libaddonmenu.html) — standalone dependency, current r43.

## Packaging checklist

- ZIP root must contain the `HybridUI` addon folder.
- Include only addon Lua/XML/texture assets and required project documentation.
- Do not bundle LibAddonMenu or unrelated addons.
- Keep the manifest APIVersion current with the live client.
- Keep the AI disclosure at the beginning of the ESOUI description until the code has been personally reviewed and validated.
- Verify all supported modes in the live client before release.
