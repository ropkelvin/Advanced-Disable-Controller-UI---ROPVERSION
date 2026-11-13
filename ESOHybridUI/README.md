# HUI - ESO Hybrid UI 2.2.0

Keyboard-style ESO UI with controller input. ESO's **Gamepad Mode must be On** (not Auto). HUI leaves controller sticks and native navigation to ESO; LibAddonMenu-2.0 is optional.

## Controls

| Controller input | HUI action |
|---|---|
| Left stick / D-pad | ESO-native UI navigation and input ownership |
| A / primary | Active screen's native keybind action, where provided |
| B / back | Active screen's native back/cancel action |
| Right stick | ESO-native UI directional-input handling |
| LB / RB | Previous / next main-menu category while the native keyboard category bar is showing |
| LT / RT | Previous / next detected visible `ZO_MenuBar` tab; other tab implementations are not covered |

HUI does not register a custom directional-input owner, consume either stick, or create a virtual cursor. ESO retains control of movement and UI navigation.

## Commands

- `/hui` or `/hui status` — show mode and current scene.
- `/hui hybrid` — keyboard-style presentation with controller input.
- `/hui gamepad` — native Gamepad presentation.
- `/hui tabs` — inspect the detected tab bar.
- `/huidebug` — capture 90 seconds of diagnostics. After it completes, run `/reloadui`, then upload `Documents/Elder Scrolls Online/live/SavedVariables/ESOHybridUI.lua`.

## Requirements and safety

- ESO Controls: **Gamepad Mode: On**.
- LibAddonMenu-2.0 is optional.
- Crown Store/market, Scrying, Tribute, Tamriel Tomes and reward previews retain ESO's native mode handling. Lockpicking retains ESO's native mode.
- HUI yields its preferred-mode wrapper if another addon already owns `IsInGamepadPreferredMode`.
- Screen-specific navigation and actions—including map-floor switching, crafting, bank/trade, resurrection and housing—still require screen-by-screen testing.

## Development status

This is a development build, not a release-ready or 95%-verified addon. CI validates Lua 5.1 syntax, manifest paths, selected safety invariants and ZIP structure. Those checks cannot establish in-game behaviour. Use the generated ZIP from the HUI branch workflow; it contains the canonical `ESOHybridUI/` addon folder.