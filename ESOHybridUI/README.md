# ESO Hybrid UI 4.1.5-beta

**AI-assisted development.** This is an AI-assisted revision of ESO Hybrid UI by ZOSPlsFix,
inspired by Advanced Disable Controller UI (Lionas; contributions: jc28735250, DoriKyll). The compact Hybrid action-bar layout and quickslot-wheel cycle/select flow have been confirmed in game. The remaining test matrix below is still required before every menu and edge case can be considered verified.

If you publish it, keep the AI disclosure at the start of the ESOUI description and the
credits above (ESOUI requires both).

## What Hybrid does

ESO's Gamepad Mode stays **On** (controller is the input device). In Hybrid:

* the HUD uses the keyboard layout (action bar, reticle, prompts) with controller glyphs;
* the quickslot wheel and the player-interaction wheel use the keyboard presentation; each can be disabled independently under Settings > Hybrid HUD;
* common UI-system menus and registered root scenes are routed to native gamepad versions; the map, loot, lockpicking, eligible dialogs and death prompt have their own native handling. ESO screens that bypass these platform-selection APIs still need individual verification.

Switch with `/esohybrid`, the keybind, or the settings panel (keyboard Add-Ons panel or the
native controller page if LibGamepadOptions is installed).

Install: copy the `ESOHybridUI` folder into `Documents/Elder Scrolls Online/live/AddOns`.
Requires LibAddonMenu-2.0 r43+. Optional: LibGamepadOptions, LibDebugLogger (+ DebugLogViewer).
Then press "Apply settings" once in the addon settings.

## New in 4.1.5 (read this first)

**Menu policy (Settings > "Menus opened from the HUD", or `/esohybrid_policy gamepad|legacy`).**
ESO picks the keyboard or gamepad version of a menu, shop, bank, crafting station, housing
editor or photo mode at the moment it is opened, and that moment is normally spent on the
base HUD (`ZO_UISystemManager:OpenPlatformUISystem`, `SYSTEMS:GetObject`). 3.x/4.0 answered
"keyboard" on the HUD, so those could open as KEYBOARD versions (3.x even carries remaps for
keyboard store/inventory/bank scenes). The default, `gamepad`, keeps the base HUD keyboard-style while the addon's platform-routing
hooks resolve `SYSTEMS` UI objects, registered root scenes and `ZO_UISystemManager` requests
as native gamepad versions. Dialogs that declare `gamepadInfo` are sent to the gamepad dialog
template unless the caller explicitly requests keyboard. The quickslot and player wheels are
built inside short keyboard scopes. ESO code that bypasses these selectors may still need a
dedicated hook; the test plan covers those special-case entry points.
`legacy` keeps the older 3.x prompt-remapping behavior, with the housing editor and screenshot
HUD treated as native contexts.
Which one is right for HUD stability is decided by testing: use `/esohybrid_policy` to A/B.

**Localization.** All user-facing text is in `lang/en.lua` (string ids `SI_ESOHYBRIDUI_*`).
To add a language: copy it to `lang/<code>.lua`, use `SafeAddString(ID, "text", 1)` instead of
`ZO_CreateStringId`, translate, and add `lang/$(language).lua` after `lang/en.lua` in the
manifest. Chat commands and `/esohybrid_dump` / `/esohybrid_trace` output stay English.

**Wheel bridge bindings now follow the player.** Changes to the gamepad cycle bindings are
mirrored onto the bridge actions as they happen (`EVENT_KEYBINDING_SET/CLEARED` +
`BindKeyToAction`/`UnbindKeyFromAction`). The wheel cycle/select flow has been confirmed in game; automatic binding mirroring after rebinding still needs a dedicated test. ESO limits saved changed bindings.

**Scene discovery.** `/esohybrid_trace on` now also records every scene shown and the answer
ESO received, so unknown scene names (housing, photo mode, companion, crafting) can be read
from `/esohybrid_trace report`.

## Changes from 3.3.8

Structure
* New `Policy.lua`: one decision function, hot-path flags cached, one depth API
  (`WithNativeGamepadMode` / `WithKeyboardWheelMode`) that restores state on any error.
* `mode = "gamepad"|"hybrid"` replaces the redundant booleans (old profiles migrate once).
* Every hook installs through `InstallWhenReady` (bounded retry) instead of ad-hoc retries.
* Each apply step is isolated with pcall; one failing module no longer stops the others.
* Per-feature switches: quickslot wheel, player wheel, action bar glyphs.

Behavior
* Platform refresh no longer runs on every menu close: only when an overlay scene was shown
  (dirty flag), and never while a wheel is open (ESO cancels the open wheel on that event).
* The wheel bridge no longer reads the private `INTERACTIVE_WHEEL_MANAGER.gamepad` field.
* The world-map check also covers `GAMEPAD_WORLD_MAP_SCENE` when it exists.
* Account-wide copy rewritten (`CopyLeaves`): reads through the saved-vars table, never
  writes into a shared defaults table. Fonts go through `GetFont`/`SetFont`.
* Welcome dialog is marked as seen only after it really showed.
* Action-bar glyph controls are reused by name instead of colliding.

ESOUI rules applied (esoui.com "rules & best practice")
* Manifest: two APIVersions (101050 101051), `AddOnVersion`, `DependsOn LibAddonMenu-2.0>=43`,
  `OptionalDependsOn LibDebugLogger` (without it LibDebugLogger loads after this addon and the
  logger is never found), AI disclosure at the start of the description.
* No chat output at load. Chat is used only for errors and things the user asked for; "announce
  load" is an opt-in setting. Info/warn logs go to LibDebugLogger or stay silent.
* One global table; saved variables server-namespaced for the account-wide profile.

New diagnostics
* `/esohybrid_trace on|off|report|reset`: counts which ESO code paths ask
  `IsInGamepadPreferredMode()` and what was answered.
* `/esohybrid_dump`: mode, scene, depth counters, installed hooks, library status.
* `/esohybrid_debug on|off`.

## Known limits / unverified (please test)

1. Quickslot wheel radial-stick selection and the cycle/select flow have been confirmed in game.
   Automatic bridge-binding mirroring after changing controller bindings still needs a dedicated test.
2. Some keybind-strip remaps in `Prompts.lua` use positions in ESO-owned descriptor arrays
   and can shift in a game patch. `/esohybrid_debug on` logs each remap. The Zone Stories
   descriptor is a single descriptor object, not an array, so its remap is applied directly.
3. Bridge binding mirroring after rebinding is not yet runtime-verified; if it misbehaves, rebind
   the bridge actions in Controls > Add-Ons.
4. The preferred-mode flip is still used to restyle the HUD. If you see flicker, send the
   tracer report.
5. The donation button calls the keyboard mail composer, which may not open in gamepad UI.

## Test plan

Do the list once per menu policy (gamepad, then `/esohybrid_policy legacy`).
Gamepad <-> Hybrid switch on the HUD and inside a menu; housing editor (enter, place, exit);
photo/screenshot mode (enter and exit with the controller); companion menu and companion
ultimate glyph; crafting stations, store, bank, guild bank, fence; open/close inventory, map, mail,
crafting, store, bank; loot; lockpick; quickslot wheel (cycle, select, close); player wheel;
dialogs; death; alt-tab; /reloadui; combat while opening a menu; a second addon that also
overrides IsInGamepadPreferredMode.
