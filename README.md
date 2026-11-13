# HUI - ESO Hybrid UI

**Development status:** actively audited, not yet verified end-to-end in the live ESO client. Do not treat this branch as a stable public release.

**Canonical addon source:** `ESOHybridUI/`. The GitHub Actions workflow validates and packages this folder as `ESOHybridUI/ESOHybridUI.txt` plus its `src/` directory. The old root-level addon manifest and local SavedVariables capture have been removed to avoid packaging the wrong implementation.

## Goal

Keep ESO's **Gamepad Mode: On** setting enabled while presenting keyboard-style menus and providing controller navigation. HUI does not attempt to replace ESO's native UI actions with arbitrary simulated mouse events.

## Requirements

- PC version of The Elder Scrolls Online.
- ESO Controls setting **Gamepad Mode: On** (not Auto).
- [LibMousePointer by Votan](https://www.esoui.com/downloads/info4518-libmousepointer.html), AddOnVersion 10000 or later.
- LibAddonMenu-2.0 is optional.

LibMousePointer is a required dependency. Its published API provides a scene fragment, cursor-position/hit-testing helpers and `InvokeClick(button, desiredHandlers)`. HUI delegates cursor creation, movement, hover and primary click to that library rather than creating a second cursor or directly invoking arbitrary mouse handlers.

## Current controls

- **Left stick:** LibMousePointer's virtual cursor in supported keyboard-style menus.
- **Primary/select:** LibMousePointer's native `UI_SHORTCUT_PRIMARY` action when that shortcut is not already owned by the active screen. If a screen owns it, that screen's native action takes priority.
- **Right-stick click:** HUI's optional context-click descriptor, using LibMousePointer's documented `InvokeClick(MOUSE_BUTTON_INDEX_RIGHT)` API, when the shortcut is available.
- **LB/RB:** previous/next main-menu category while the native keyboard category bar is showing.
- **LT/RT:** previous/next detected visible `ZO_MenuBar` tab on the current menu screen. Screens using other tab implementations are not covered yet.
- **Right stick movement:** reserved while the pointer is active; generic scrolling is not implemented.

### Stick ownership

ESO's scene manager normally consumes both sticks while in UI mode. LibMousePointer is itself a `DIRECTIONAL_INPUT` owner and reads/consumes the left stick. HUI skips ESO's stock consume-both-sticks handler only while the pointer fragment is showing and the library is actively listening; HUI then reserves the right stick. When the pointer is not active, ESO's original handler is left untouched. This follows ESO's directional-input priority model and avoids running a second cursor implementation.

### Click safety

HUI no longer calls arbitrary `OnClicked`, `OnMouseDown` or `OnMouseUp` handlers itself. It delegates pointer clicks to LibMousePointer's public API and lets native screen keybinds take precedence. The library's click helper is still not a guarantee that every protected ESO action can be performed through a virtual pointer. Destructive inventory actions, trade operations and other protected workflows must be tested individually and should use their native keybind action if the game rejects pointer activation. HUI does not bypass ESO's secure/protected-action boundary.

## Modes and commands

- `/hui` — show current mode and scene state.
- `/hui hybrid` — keyboard-style presentation with controller input (requires Gamepad Mode: On).
- `/hui gamepad` — restore native Gamepad presentation.
- `/hui tabs` — report the detected visible menu bar.
- `/hui pointer` — report LibMousePointer availability and cursor position after five seconds.
- `/huidebug` — capture scene, pointer, keybind and mode diagnostics to account-wide SavedVariables. After capture completes, use `/reloadui` and upload `Documents/Elder Scrolls Online/live/SavedVariables/ESOHybridUISavedVariables.lua`.

Optional settings are available through LibAddonMenu-2.0.

## Safety and limitations

- HUI yields its preferred-mode override if another addon already owns `IsInGamepadPreferredMode`; it does not blindly replace another addon's wrapper.
- HUI preserves ESO's native lockpick presentation and excludes known restricted/special scenes such as Crown Store/market, Scrying, Tribute, Tamriel Tomes and reward-preview screens. New ESO scenes must be audited and added to the restricted list where appropriate.
- Scene tracking is polled to avoid wrapping the scene-transition stack. There can be a short transition interval before the next poll updates the active-scene flags.
- Main-menu category switching uses ESO's `ZO_MenuBar_SelectDescriptor` API. Individual tab discovery remains heuristic because not every ESO screen uses `ZO_MenuBar`.
- D-pad navigation, drag/drop, all screen-specific actions, quickslot/player-interaction wheels, map level switching, crafting, bank/trade, resurrection and housing still require screen-by-screen verification.
- Static CI checks validate Lua syntax, manifest paths, safety invariants and ZIP structure. They cannot establish live-client behaviour. No claim of 95% runtime functionality should be made until controller tests cover the supported screen matrix.

## Source research

- [ESO UI source repository](https://github.com/esoui/esoui) — reference source for scene manager and directional-input behaviour.
- [ESO UI API documentation](https://esoapi.uesp.net/) — API reference.
- [LibMousePointer documentation](https://www.esoui.com/downloads/info4518-libmousepointer.html) — documented cursor fragment and click API.
- [ADCUI by Lionas](https://github.com/Lionas/Advanced-Disable-Controller-UI) — studied as an architectural reference; HUI is a separate implementation.

## Development

Work on the `HUI` branch. The canonical manifest is `ESOHybridUI/ESOHybridUI.txt`; the release artifact is generated by `.github/workflows/validate.yml`. Install the generated ZIP's `ESOHybridUI` folder into the ESO AddOns directory.
