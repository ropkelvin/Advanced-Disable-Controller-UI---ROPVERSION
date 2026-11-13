# HUI - ESO Hybrid UI 2.0.6

Keyboard-style ESO menus with controller input. ESO's **Gamepad Mode must be On** (not Auto). Requires LibMousePointer by Votan; LibAddonMenu-2.0 is optional.

## Controls

| Controller input | HUI action |
|---|---|
| Left stick | Move LibMousePointer cursor in supported keyboard-style menus |
| A / primary | LibMousePointer's native click action when the active screen leaves `UI_SHORTCUT_PRIMARY` free |
| Right-stick click | Context click through LibMousePointer's documented `InvokeClick(MOUSE_BUTTON_INDEX_RIGHT)` API, if the shortcut is free |
| Right stick movement | ESO's native UI directional-input fallback consumes it; generic pointer scrolling is not implemented |
| LB / RB | Previous / next main-menu category while the native keyboard category bar is showing |
| LT / RT | Previous / next detected visible `ZO_MenuBar` tab; other tab implementations are not covered |

LibMousePointer owns cursor creation, left-stick movement, hover and its primary-click descriptor. HUI does not implement a second cursor and does not call arbitrary `OnClicked`, `OnMouseDown` or `OnMouseUp` handlers. LibMousePointer registers a high-priority owner with ESO's `DIRECTIONAL_INPUT` system. Its `GetXY` call consumes the left stick; ESO's scene-manager owner runs later and consumes any remaining sticks in UI mode. HUI intentionally does not skip or replace that native fallback, so an input control that has priority over the pointer cannot leak stick movement into gameplay.

Pointer click is not guaranteed to perform every protected ESO action. Destructive inventory actions, trade, and other protected workflows must be tested individually; use the screen's native controller keybind when ESO rejects pointer activation. HUI does not bypass protected-action restrictions.

## Commands

- `/hui` or `/hui status` — show mode and current scene.
- `/hui hybrid` — keyboard-style presentation with controller input.
- `/hui gamepad` — native Gamepad presentation.
- `/hui tabs` — inspect the detected tab bar.
- `/hui pointer` — trace scene, fragment visibility, LibMousePointer ownership, left-stick input and cursor movement for three seconds.
- `/huidebug` — capture 90 seconds of diagnostics. After it completes, run `/reloadui`, then upload `Documents/Elder Scrolls Online/live/SavedVariables/ESOHybridUI.lua`.

## Requirements and safety

- ESO Controls: **Gamepad Mode: On**.
- [LibMousePointer by Votan](https://www.esoui.com/downloads/info4518-libmousepointer.html), AddOnVersion 10000 or later.
- Crown Store/market, Scrying, Tribute, Tamriel Tomes, reward previews and known special scenes are excluded from HUI pointer routing. Lockpicking retains ESO's native mode.
- HUI yields its preferred-mode wrapper if another addon already owns `IsInGamepadPreferredMode`; it will not overwrite another addon's wrapper.
- HUI registers callbacks on known scene objects and attaches the pointer fragment during SCENE_SHOWING, before the scene refreshes fragments. A lightweight poll discovers scenes registered later.
- D-pad navigation, generic scrolling, drag/drop, all screen-specific actions, quickslot/player-interaction wheels, map-floor switching, crafting, bank/trade, resurrection and housing still require screen-by-screen testing.

## Development status

This is a development build, not a release-ready or 95%-verified addon. CI validates Lua 5.1 syntax, manifest paths, selected safety invariants and ZIP structure. Those checks cannot establish in-game behaviour. Use the generated ZIP from the HUI branch workflow; it contains the canonical `ESOHybridUI/` addon folder.
