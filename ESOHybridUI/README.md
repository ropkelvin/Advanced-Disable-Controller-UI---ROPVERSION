# ESO Hybrid UI 4.2.1-beta

**AI-assisted development disclosure:** AI tools were used during development and review. The addon is maintained by its author. In-game validation is required for every supported scene and ESO update.

ESO Hybrid UI keeps ESO's actual Gamepad Mode enabled while selecting keyboard-layout UI for ordinary menus. In Hybrid mode, the left stick moves a controller-operated pointer in keyboard scenes; on the gameplay HUD it returns to normal character movement. The right stick remains camera control.

## Requirements

- The Elder Scrolls Online PC client.
- **LibAddonMenu-2.0 r43 or newer** (required).
- ESO **Gamepad Mode: On**, not Auto.
- **LibMousePointer** (optional but recommended; provides the cursor, hit-testing and click support).
- LibGamepadOptions (optional native controller settings page).
- LibDebugLogger (optional persistent diagnostic logs).

## Installation

1. Install LibAddonMenu-2.0 r43 or newer.
2. Install LibMousePointer for controller pointer support.
3. Extract the `ESOHybridUI` folder into `Documents/Elder Scrolls Online/live/AddOns/`.
4. Enable ESO Hybrid UI and its optional libraries in the Add-Ons menu.
5. Open addon settings and press **Apply settings** once.
6. Select **Hybrid**.

## Interface modes

### Gamepad

Uses ESO's normal native Gamepad UI without the Hybrid presentation policy.

### Hybrid

- Keeps the compact keyboard-layout HUD and controller glyphs.
- Selects keyboard-layout UI for ordinary menu scenes.
- Attaches LibMousePointer to keyboard-pointer scenes; left stick moves the cursor and the library supplies hit-testing and click behavior.
- Leaves right-stick camera control available while the pointer is active.
- Uses keyboard-style world map and menu presentation, with the native scene retained as a fallback for explicitly Gamepad-only routes.
- Retains native ESO handling for loot, lockpicking, death/resurrection and other protected workflows.
- Uses the keyboard-style quickslot wheel by default with controller cycling; the player-interaction wheel retains its current keyboard-style presentation.
- Keeps LB/RB category navigation for the keyboard main menu.
- Does not synthesize protected inventory, trade or resurrection operations.

The **Menu presentation** setting selects either **Keyboard UI + controller pointer** (default) or **Native Gamepad menus** as a compatibility fallback. The **Controller pointer in keyboard menus** setting can disable pointer attachment. The keyboard-style quickslot wheel can be disabled separately.

## Controller pointer controls

LibMousePointer adds a controller select action when `UI_SHORTCUT_PRIMARY` is available in the active keybind strip. If another screen already uses that action, use the addon's user-bindable actions under Settings > Controls > Keybindings:

- Pointer click
- Pointer right-click
- Reset pointer position

These actions do not take over A/B/X/Y by default. Main-menu LB/RB category actions inherit ESO's existing shoulder bindings.

## Settings

- **Apply settings:** explicitly applies recommended ESO input and chat settings.
- **Interface mode:** switches between Gamepad and Hybrid.
- **Menu presentation:** selects keyboard-pointer menus or the native Gamepad fallback.
- **Controller pointer in keyboard menus:** enables or disables LibMousePointer attachment.
- **Account-wide settings:** shares configuration across characters on the current megaserver.
- **Keyboard-style quickslot wheel:** selects the keyboard or native Gamepad radial.
- **Controller glyphs on the action bar:** toggles controller glyphs in Hybrid.
- **HUD prompt fonts:** adjusts interaction and stealth prompt fonts.
- **Advanced:** diagnostic logging, load announcement and command reference.

## Commands

- `/esohybrid` — toggle Gamepad / Hybrid.
- `/esohybrid_status` — show current interface mode.
- `/esohybrid_policy gamepad|legacy` — select native Gamepad or keyboard-pointer menu routing.
- `/esohybrid_settings` — open addon settings.
- `/esohybrid_debug on|off` — enable or disable diagnostic logging.
- `/esohybrid_dump` — print a diagnostic snapshot.
- `/esohybrid_pointer` — print pointer and directional-input diagnostics.
- `/esohybrid_trace on|off|report|reset` — trace platform queries, scenes and UI-system routing.
- `/esohybrid_sv` — show SavedVariables initialization status.

## Compatibility and validation

ESO chooses platform-specific UI through several separate paths: `IsInGamepadPreferredMode()`, UI-system routing, `SYSTEMS:GetObject()`, root-scene lookup, direct scene opens and scene-specific fragments. Hybrid scopes the platform query rather than copying ADCUI's unconditional global override.

Keyboard scenes can still contain controls that are focus-driven, keyboard-only, protected, or not mouse-hit-testable. LibMousePointer makes mouse-enabled controls operable, but it does not magically convert every focus model or protected callback. Unknown keyboard scenes receive pointer presentation by default; special native scenes remain explicitly classified. Third-party addon windows may need their own adapter.

When reporting a problem, include the ESO API version, the scene/action, `/esohybrid_dump`, `/esohybrid_pointer`, and `/esohybrid_trace report` after reproducing the issue. This branch has passed automated Lua syntax, manifest and ZIP packaging checks; it still requires in-game validation with a controller.

## Credits

ESO Hybrid UI is inspired by **Advanced Disable Controller UI** by **Lionas**, with contributions by **jc28735250** and **DoriKyll**. The original ADCUI source was reviewed for its platform-selection technique; this project uses a separate scene-aware implementation.
