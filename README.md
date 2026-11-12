# HUI - ESO Hybrid UI

HUI is a clean rebuild of ESOHybridUI around one initial goal: **keep ESO's native Gamepad input enabled while presenting the keyboard UI**.

## Modes

- **Hybrid** (initial default): ESO's Gamepad Mode must be **On**. HUI changes the UI-preference query to select keyboard layouts, while preserving the original gamepad-mode query for controller state. Gamepad keybind resolution and prompts are selected separately. Keyboard-style scenes receive LibMousePointer's pointer fragment.
- **Pure Gamepad**: HUI restores ESO's original `IsInGamepadPreferredMode` function and leaves native Gamepad UI routing alone.

Only these two modes are exposed in this first stage. Additional modes can be added later.

## Requirements

- PC version of The Elder Scrolls Online.
- ESO Controls setting **Gamepad Mode: On**.
- [LibMousePointer](https://www.esoui.com/downloads/info4518-libmousepointer.html) for left-stick pointer navigation and click support.
- LibAddonMenu-2.0 is optional; without it, use `/hui hybrid` and `/hui gamepad`.

## Controls

LibMousePointer adds its pointer fragment to keyboard-style scenes. Its documented API adds a click binding for `UI_SHORTCUT_PRIMARY` when that keybind is not already occupied. A screen that already owns that shortcut may need a dedicated click adapter; this first pass does not blindly invoke a second callback on an occupied shortcut. HUI does not replace protected ESO actions or synthesize keyboard/mouse events.

Research references:
- [ADCUI source](https://github.com/Lionas/Advanced-Disable-Controller-UI/blob/master/AdvancedDisableControllerUI/AdvancedDisableControllerUI.lua) — established the keyboard-presentation override and the lockpicking exception.
- [LibMousePointer API](https://www.esoui.com/downloads/info4518-libmousepointer.html) — provides the pointer fragment, cursor position, hit testing and click invocation.
- [ESO scene manager source](https://esodata.uesp.net/101050/src/ingame/scenes/ingamescenemanager.lua.html) — confirms that the default UI-mode update consumes both sticks, so HUI must coordinate input ownership rather than let both systems process the same stick.
- [ESO scene source](https://esodata.uesp.net/101050/src/libraries/zo_scene/zo_scene.lua.html) — scene fragments can be added and removed through the scene lifecycle.

- `/hui` — show current mode
- `/hui hybrid` — keyboard UI + controller input
- `/hui gamepad` — native Gamepad UI

After changing modes, close and reopen the active menu so ESO can select the matching keyboard or Gamepad scene.

## Architecture

- `Bootstrap.lua`: addon lifecycle, account-wide saved variables, capture of ESO's original mode query.
- `Mode.lua`: two-mode state and scoped presentation override; lockpicking temporarily retains native Gamepad mode.
- `SceneController.lua`: pointer fragment attachment to keyboard scenes and directional-input ownership.
- `Prompts.lua`: separates keyboard layout selection from gamepad keybind resolution and glyph presentation.
- `Settings.lua`: optional LibAddonMenu settings.

## Safety boundaries

HUI does not call private ESO functions, simulate protected actions, or globally replace scene implementations. It uses the documented LibMousePointer fragment/click API and ESO's directional-input ownership API. The broad keyboard-scene routing and controller behaviour must still be verified in the live client, especially inventory, map, crafting, bank/trade, dialogs, resurrection, and lockpicking.

## Development status

Initial architecture and first implementation pass. This is not yet confirmed in-game. Automated Lua syntax, manifest, and package checks should run before a test release.
