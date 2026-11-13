# HUI - ESO Hybrid UI 2.0.3

Keyboard-style ESO menus with controller input. ESO's **Gamepad Mode must be On** (not Auto). Requires LibMousePointer by Votan; LibAddonMenu-2.0 is optional.

## Controls

| Controller input | HUI action |
|---|---|
| Left stick | Move LibMousePointer cursor in supported keyboard-style menus |
| A / primary | LibMousePointer's native click action when the active screen leaves `UI_SHORTCUT_PRIMARY` free |
| Right-stick click | Context click through LibMousePointer's documented `InvokeClick(MOUSE_BUTTON_INDEX_RIGHT)` API, if the shortcut is free |
| Right stick movement | Reserved while pointer is active; generic scrolling is not implemented |
| LB / RB | Previous / next main-menu category while the native keyboard category bar is showing |
| LT / RT | Previous / next detected visible `ZO_MenuBar` tab; other tab implementations are not covered |

LibMousePointer owns cursor creation, left-stick movement, hover and its primary-click descriptor. HUI does not implement a second cursor and does not call arbitrary `OnClicked`, `OnMouseDown` or `OnMouseUp` handlers. ESO's stock scene-manager directional-input callback normally consumes both sticks in UI mode; while LibMousePointer is actively registered, HUI skips only that stock consume-both-sticks callback and reserves the right stick. The library then consumes the left stick through ESO's directional-input system. If the pointer is not registered, ESO's original input handling remains untouched.

Pointer click is not guaranteed to perform every protected ESO action. Destructive inventory actions, trade, and other protected workflows must be tested individually; use the screen's native controller keybind when ESO rejects pointer activation. HUI does not bypass protected-action restrictions.

## Commands

- `/hui` or `/hui status` — show mode and current scene.
- `/hui hybrid` — keyboard-style presentation with controller input.
- `/hui gamepad` — native Gamepad presentation.
- `/hui tabs` — inspect the detected tab bar.
- `/hui pointer` — report LibMousePointer and cursor state.
- `/huidebug` — capture 90 seconds of diagnostics. After it completes, run `/reloadui`, then upload `Documents/Elder Scrolls Online/live/SavedVariables/ESOHybridUISavedVariables.lua`.

## Requirements and safety

- ESO Controls: **Gamepad Mode: On**.
- [LibMousePointer by Votan](https://www.esoui.com/downloads/info4518-libmousepointer.html), AddOnVersion 10000 or later.
- Crown Store/market, Scrying, Tribute, Tamriel Tomes, reward previews and known special scenes are excluded from HUI pointer routing. Lockpicking retains ESO's native mode.
- HUI yields its preferred-mode wrapper if another addon already owns `IsInGamepadPreferredMode`; it will not overwrite another addon's wrapper.
- Scene polling is used to avoid wrapping scene-transition methods. There may be a short scene-transition interval before the new state is applied.
- D-pad navigation, generic scrolling, drag/drop, all screen-specific actions, quickslot/player-interaction wheels, map-floor switching, crafting, bank/trade, resurrection and housing still require screen-by-screen testing.

## Development status

This is a development build, not a release-ready or 95%-verified addon. CI validates Lua 5.1 syntax, manifest paths, selected safety invariants and ZIP structure. Those checks cannot establish in-game behaviour. Use the generated ZIP from the HUI branch workflow; it contains the canonical `ESOHybridUI/` addon folder.
