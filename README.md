# HUI - ESO Hybrid UI

**AI-assisted development disclosure:** AI tools were used to generate and review portions of this addon. The implementation is still being audited and has not yet been fully verified in the live ESO client. Do not treat this development build as a stable release.

HUI is a clean rebuild of ESOHybridUI around one initial goal: keep ESO's native Gamepad input enabled while presenting the keyboard UI.

## Modes

- **Hybrid** (initial default): ESO's Gamepad Mode must be **On**. HUI changes the UI-preference query only while the player is active in the world, while preserving ESO's original query for checking the actual game setting. Gamepad keybind resolution and prompts are selected separately. Keyboard-style scenes receive LibMousePointer's pointer fragment. HUI disables its pointer and gamepad-prompt overrides on detected Crown Store/market, Scrying, and Tribute scenes. These exclusions still require live-client verification and ESOUI staff clarification before public release because the broad preferred-mode override must not affect restricted screens.
- **Pure Gamepad**: HUI restores ESO's original `IsInGamepadPreferredMode` function and leaves native Gamepad UI routing alone.

Only these two modes are exposed in this first stage. Additional modes can be added later.

## Requirements

- PC version of The Elder Scrolls Online.
- ESO Controls setting **Gamepad Mode: On**.
- [LibMousePointer](https://www.esoui.com/downloads/info4518-libmousepointer.html) by **Votan** is required for pointer support.
- LibAddonMenu-2.0 is optional; without it, use `/hui hybrid` and `/hui gamepad`.

## Controls

LibMousePointer provides the scene pointer fragment and an optional `UI_SHORTCUT_PRIMARY` click binding when that keybind is unused. If a screen already owns the shortcut, it needs a screen-specific click adapter. HUI does not replace protected ESO actions or synthesize keyboard/mouse events.

- `/hui` — show current mode and runtime state
- `/hui hybrid` — keyboard UI + controller input
- `/hui gamepad` — native Gamepad UI

After changing modes, close and reopen the active menu so ESO can select the matching keyboard or Gamepad scene.

## Research and attribution

- **Advanced Disable Controller UI (ADCUI)** by **Lionas**: studied for its global keyboard-presentation override and lockpicking exception. HUI is a clean implementation and does not copy ADCUI source code. [Source repository](https://github.com/Lionas/Advanced-Disable-Controller-UI).
- **LibMousePointer** by **Votan**: required external library providing the pointer fragment and cursor click API. [ESOUI page](https://www.esoui.com/downloads/info4518-libmousepointer.html).
- ESO UI source, published by ZeniMax for reference: [ESOUI source repository](https://github.com/esoui/esoui).

## Architecture

- `Bootstrap.lua`: addon lifecycle, account-wide SavedVariables, and in-world activation/deactivation.
- `Mode.lua`: two-mode state, active-world-only presentation override, and lockpick scene exception.
- `SceneController.lua`: pointer fragment attachment and directional-input ownership for the current top scene.
- `Prompts.lua`: gamepad keybind and glyph preference wrappers, installed only while the player is active in the world.
- `Settings.lua`: optional LibAddonMenu settings.

## Safety boundaries

HUI does not call private ESO functions, simulate protected actions, automate gameplay, or read/write external files. It uses ESO's UI scene and directional-input systems and LibMousePointer's documented fragment/click API. The broad keyboard-scene routing and controller behaviour still require live-client validation, especially inventory, map, crafting, bank/trade, dialogs, resurrection, and lockpicking. LibMousePointer's public documentation describes the fragment and click API but does not specify the exact left-stick input ownership implementation; HUI therefore only bypasses ESO's default stick consumption after the left stick is already consumed by an earlier UI input owner. If that has not happened, ESO retains its normal safety behaviour and consumes both sticks.

## Development status

Initial architecture and first implementation pass. This is not yet confirmed in-game. Automated Lua syntax, manifest and package checks are necessary but do not establish runtime correctness.
