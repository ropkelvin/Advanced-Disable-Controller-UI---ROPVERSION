# HUI - ESO Hybrid UI

**Development status:** actively audited, not yet verified end-to-end in the live ESO client. Do not treat this branch as a stable public release.

**Canonical addon source:** `ESOHybridUI/`. GitHub Actions validates and packages this folder as `ESOHybridUI/ESOHybridUI.txt` plus its `src/` directory. The old root-level addon manifest and local SavedVariables capture have been removed.

## Goal

Keep ESO's **Gamepad Mode: On** setting enabled while presenting keyboard-style menus and providing controller navigation. HUI owns its pointer implementation and does not require LibMousePointer.

## Requirements

- PC version of The Elder Scrolls Online.
- ESO Controls setting **Gamepad Mode: On** (not Auto).
- LibAddonMenu-2.0 is optional.

## Current controls

- **Left stick:** move HUI's virtual cursor in supported keyboard-style menus. HUI registers its own high-priority `DIRECTIONAL_INPUT` owner; ESO's `GetXY` call consumes the queried stick for that update, and ESO's `ClientInput` owner propagates the consumed state to the game input layer.
- **A / primary:** uses the active screen's native keybind action when that screen exposes one. HUI does not synthesize a mouse click or invoke arbitrary control handlers.
- **B / back:** uses the active screen's native back/cancel action.
- **LB/RB:** previous/next main-menu category while the native keyboard category bar is showing.
- **LT/RT:** previous/next detected visible `ZO_MenuBar` tab on the current menu screen. Screens using other tab implementations are not covered yet.
- **Right stick:** remains under ESO's native UI directional-input handling; generic pointer scrolling is not implemented.

## Pointer input and click safety

The standalone pointer uses ESO's `DIRECTIONAL_INPUT:Activate`, `IsAvailable` and `GetXY` APIs, plus the native virtual-cursor and hit-testing APIs. ESO's `GetXY` implementation consumes the queried input device for the current update, including a neutral reading; an extra `Consume` call is redundant. HUI activates its owner as the pointer fragment starts showing, before the transition completes.

HUI deliberately does not reproduce LibMousePointer's `InvokeClick` implementation. Its published source directly calls a control's `OnClicked`, `OnMouseDown` or `OnMouseUp` handler. Those calls are not equivalent to trusted mouse input and can violate ESO's protected-action restrictions. This is particularly important for destructive inventory and other secure workflows.

A virtual cursor can safely provide movement and hit-testing, but ESO's public addon API does not provide a general trusted way for an addon to inject arbitrary mouse clicks into every keyboard-style control. HUI therefore relies on native screen keybinds for activation. Some mouse-only controls may remain non-activatable until a screen-specific native keybind/navigation integration is implemented. HUI will not bypass the protected-action boundary.

## Modes and commands

- `/hui` — show current mode and scene state.
- `/hui hybrid` — keyboard-style presentation with controller input (requires Gamepad Mode: On).
- `/hui gamepad` — restore native Gamepad presentation.
- `/hui tabs` — report the detected visible menu bar.
- `/hui pointer` — trace HUI pointer ownership, stick input, cursor movement, and the timing of any UI-mode movement event for three seconds.
- `/huidebug` — capture scene, pointer, keybind and mode diagnostics to account-wide SavedVariables. After capture completes, use `/reloadui` and upload `Documents/Elder Scrolls Online/live/SavedVariables/ESOHybridUI.lua`.

Optional settings are available through LibAddonMenu-2.0.

## Safety and limitations

- HUI yields its preferred-mode override if another addon already owns `IsInGamepadPreferredMode`; it does not blindly replace another addon's wrapper.
- HUI preserves ESO's native lockpick presentation and excludes known restricted/special scenes such as Crown Store/market, Scrying, Tribute, Tamriel Tomes and reward-preview screens.
- Scene tracking registers callbacks on known scenes and attaches the pointer fragment during `SCENE_SHOWING`. A lightweight poll discovers scenes registered later.
- Main-menu category switching uses ESO's `ZO_MenuBar_SelectDescriptor` API. Individual tab discovery remains heuristic because not every ESO screen uses `ZO_MenuBar`.
- D-pad navigation, drag/drop, all screen-specific actions, quickslot/player-interaction wheels, map level switching, crafting, bank/trade, resurrection and housing still require screen-by-screen verification.
- Static CI checks validate Lua syntax, manifest paths, safety invariants and ZIP structure. They cannot establish live-client behaviour. No claim of 95% runtime functionality should be made until controller tests cover the supported screen matrix.

## Source research

- [ESO UI source repository](https://github.com/esoui/esoui) — reference source for scene manager and directional-input behaviour.
- [ESO UI API documentation](https://esoapi.uesp.net/) — API reference.
- [LibMousePointer source by Votan](https://github.com/votan73/ESO/tree/e312543ba8a392dfcfd1365457707d841191dd30/Addons/LibMousePointer) — audited to identify input-consumption and click-safety limitations.
- [ADCUI by Lionas](https://github.com/Lionas/Advanced-Disable-Controller-UI) — studied as an architectural reference; HUI is a separate implementation.

## Development

Work on the `HUI` branch. The canonical manifest is `ESOHybridUI/ESOHybridUI.txt`; the release artifact is generated by `.github/workflows/validate.yml`. Install the generated ZIP's `ESOHybridUI` folder into the ESO AddOns directory.