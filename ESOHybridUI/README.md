# HUI - ESO Hybrid UI 2.1.3

Keyboard-style ESO menus with controller input. ESO's **Gamepad Mode must be On** (not Auto). HUI includes its own pointer; LibAddonMenu-2.0 is optional.

## Controls

| Controller input | HUI action |
|---|---|
| Left stick | Move HUI's virtual cursor in supported keyboard-style menus |
| A / primary | Active screen's native keybind action, where provided |
| B / back | Active screen's native back/cancel action |
| Right stick | ESO's native UI directional-input handling; generic pointer scrolling is not implemented |
| LB / RB | Previous / next main-menu category while the native keyboard category bar is showing |
| LT / RT | Previous / next detected visible `ZO_MenuBar` tab; other tab implementations are not covered |

HUI owns its cursor and registers a high-priority directional-input owner. ESO's `DIRECTIONAL_INPUT:GetXY(ZO_DI_LEFT_STICK)` consumes the queried device for that update, so HUI does not issue a redundant second consume. ESO's native `ClientInput` owner propagates the consumed state to the game input layer. Ownership starts when the pointer fragment begins showing.

## Click safety

HUI does not copy LibMousePointer's arbitrary handler dispatch. Its published source calls control handlers such as `OnClicked`, `OnMouseDown` and `OnMouseUp` directly; that is not equivalent to trusted mouse input and can taint protected ESO actions. HUI provides pointer movement and hit-testing, but relies on each screen's native keybind for activation. Some mouse-only controls may need screen-specific native integration. Protected actions will not be bypassed.

## Commands

- `/hui` or `/hui status` — show mode and current scene.
- `/hui hybrid` — keyboard-style presentation with controller input.
- `/hui gamepad` — native Gamepad presentation.
- `/hui tabs` — inspect the detected tab bar.
- `/hui pointer` — trace HUI pointer ownership, stick input, cursor movement, and the timing of any UI-mode movement event for three seconds.
- `/huidebug` — capture 90 seconds of diagnostics. After it completes, run `/reloadui`, then upload `Documents/Elder Scrolls Online/live/SavedVariables/ESOHybridUI.lua`.

## Requirements and safety

- ESO Controls: **Gamepad Mode: On**.
- LibAddonMenu-2.0 is optional.
- Crown Store/market, Scrying, Tribute, Tamriel Tomes, reward previews and known special scenes are excluded from HUI pointer routing. Lockpicking retains ESO's native mode.
- HUI yields its preferred-mode wrapper if another addon already owns `IsInGamepadPreferredMode`.
- D-pad navigation, generic scrolling, drag/drop, all screen-specific actions, quickslot/player-interaction wheels, map-floor switching, crafting, bank/trade, resurrection and housing still require screen-by-screen testing.

## Development status

This is a development build, not a release-ready or 95%-verified addon. CI validates Lua 5.1 syntax, manifest paths, selected safety invariants and ZIP structure. Those checks cannot establish in-game behaviour. Use the generated ZIP from the HUI branch workflow; it contains the canonical `ESOHybridUI/` addon folder.