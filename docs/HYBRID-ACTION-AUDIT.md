# HUI 2.0.2 — controller and action audit

**Status:** source-reviewed development build. Not release-ready and not verified end-to-end in the live ESO client. Static checks cannot establish controller behaviour.

## Target behaviour

- ESO Controls remains **Gamepad Mode: On**, not Auto.
- Menus use keyboard-style scenes where ESO exposes them.
- The controller operates the UI without player movement or camera movement leaking through.
- Native ESO keybind descriptors and callbacks remain authoritative.
- HUI never invokes protected/private ESO actions directly or simulates arbitrary mouse events.
- Pure Gamepad mode, loading/pregame and known restricted feature screens retain native ESO behaviour.

## Current implementation

| Area | Current implementation | Remaining risk |
|---|---|---|
| Mode selection | `Mode.lua` changes `IsInGamepadPreferredMode` only while Hybrid is active and Gamepad Mode is explicitly On. It yields if another addon owns the global wrapper. | The preferred-mode query affects more than scene selection; some HUD/platform-style controls may still be mixed. |
| Lockpicking | Lockpick events and a pre-hook on `LOCK_PICK:SetHidden` temporarily restore native presentation. | Needs live testing on start, success, failure and cancellation. |
| Scene tracking | `Scenes.lua` polls the current scene every 50 ms and attaches the pointer fragment to keyboard-style scenes after they reach SHOWN. Known special/restricted scenes are excluded. | There is a short transition window. New ESO feature scenes must be added to the exclusion list when appropriate. |
| Cursor | LibMousePointer owns cursor creation, movement, hover, hit testing and its primary click descriptor. HUI does not build a second cursor. | The library's primary click is conditional on `UI_SHORTCUT_PRIMARY` being free. Its click helper is not guaranteed to work for protected actions. |
| Stick ownership | `Pointer.lua` pre-hooks the live `SCENE_MANAGER.UpdateDirectionalInput` instance. While LibMousePointer is actively registered, HUI skips ESO's consume-both-sticks callback and consumes the right stick. LibMousePointer consumes the left stick through ESO's directional-input API. | Requires physical-controller testing for every screen and transition; verify no left-stick movement/camera leak. |
| Primary click | HUI leaves LibMousePointer's native `UI_SHORTCUT_PRIMARY` descriptor intact. | A screen that claims primary before the pointer fragment appears prevents the library click descriptor from being added. Later dynamic keybind claims also need testing. |
| Context click | Right-stick click calls LibMousePointer's documented `InvokeClick(MOUSE_BUTTON_INDEX_RIGHT)` API through a HUI keybind-strip descriptor. | Context actions are screen-dependent; native descriptors take priority. |
| Main categories | LB/RB use `ZO_MenuBar_SelectDescriptor` to select adjacent enabled category descriptors in `MAIN_MENU_KEYBOARD.categoryBar`. | Hidden/disabled categories, screen-owned shoulder actions and overlays require live tests. |
| Screen tabs | LT/RT cycle the visible `ZO_MenuBar` candidate found in the visible UI tree. | This is heuristic; some screens use other tab systems and an overlay may contain a competing bar. |
| Prompts | `Prompts.lua` wraps selected ESO keybinding helper functions and temporarily restores native preferred-mode lookup while they resolve glyphs. | Not every prompt helper is covered. Correct glyphs do not prove the selected action descriptor invokes the correct callback. |
| Diagnostics | `/huidebug` records scene, pointer, mode and keybind state to account-wide SavedVariables. | Diagnostics are observational; they do not validate an action by themselves. |
| Packaging | CI validates the canonical `ESOHybridUI/` tree, Lua 5.1 syntax, manifest paths, safety invariants and ZIP layout. | CI does not run the ESO client or verify controller actions. |

## Directional-input research

ESO's API notes specify that gamepad sticks should be queried through `DIRECTIONAL_INPUT` and that a visible UI should register an input owner with `DIRECTIONAL_INPUT:Activate(owner, control)`. ESO's current in-game scene manager normally consumes both sticks in UI mode. LibMousePointer is itself a directional-input owner and consumes the left stick through `DIRECTIONAL_INPUT:GetXY(ZO_DI_LEFT_STICK)`. Since directional-input owners are ordered by control visual priority, ESO's stock consume-both-sticks callback can run first and starve the pointer. HUI therefore skips only that stock callback while the library is actively listening, and consumes the right stick. If the pointer is not active, the stock handler remains untouched.

References:
- [ESO API patch notes: gamepad directional input](https://forums.elderscrollsonline.com/en/discussion/222240/orsinium-api-patch-notes-change-log-pts)
- [ESO source repository](https://github.com/esoui/esoui)
- [ESO scene manager source](https://github.com/esoui/esoui/blob/live/esoui/ingame/scenes/ingamescenemanager.lua)
- [LibMousePointer documentation](https://www.esoui.com/downloads/info4518-libmousepointer.html)

## Action-family support matrix

| Family | HUI policy | Verification status |
|---|---|---|
| Character movement, camera, sprint, jump, dodge, crouch, mount | Never intercept or synthesize gameplay input. | Must be tested for stick leakage with every pointer scene. |
| Combat, skills, ultimate, block, interrupt, synergy, weapon swap | Leave native gamepad bindings alone. | Not live-verified. |
| Companion commands and siege controls | Leave native gamepad bindings alone. | Not live-verified. |
| Targeting, target marker, quickslot and player-interaction wheels | Preserve native bindings and hold/release semantics. | No HUI-specific wheel adapter yet; not verified. |
| Main menu categories | Native menu-bar selection through HUI shoulder descriptors. | Implemented in source; live verification required. |
| Individual tabs | Native menu-bar selection through HUI trigger descriptors. | Only visible `ZO_MenuBar` implementations are candidates; heuristic. |
| Inventory use/equip/destroy/split/move, bank and trade | Do not invoke protected functions from HUI. Use native screen keybinds. | High risk; test each action. |
| Dialogs, notifications and confirmations | Preserve native keybind callbacks; pointer click only where safe. | Not verified across dialogs and overlays. |
| Map panning, pins and level switching | Use LibMousePointer and native map handlers; no fake gameplay input. | Not verified; map has historically shown directional-input contention. |
| Crafting, research, deconstruction, scribing, guild store | Native screen callbacks and keybinds; pointer as optional UI aid. | Not verified end-to-end. |
| Loot, resurrection, death and player prompts | Native screen actions; prompt wrappers are not a complete adapter. | Not verified. |
| Housing and furniture placement | Preserve native housing controls; no automated placement. | Not verified. |
| Chat/text entry | Preserve native typing and send controls. | Not verified. |
| Crown Store/market, Scrying, Tribute, Tamriel Tomes and reward previews | Exclude from HUI pointer/presentation routing where detected. | Exclusion tokens require checking against new scene names. |
| Loading and character selection | HUI's mode wrapper is pass-through outside the active world. | Needs transition testing. |

## Known unresolved architecture gaps

1. **Global preferred-mode query:** it is used by scene selection, keybind selection and platform-style controls. HUI now avoids overwriting another addon's wrapper, but a global false result can still select a keyboard path that lacks a complete controller adapter.
2. **Prompt/action mismatch:** selected glyph helpers are wrapped, but the actual keybind-strip descriptor and callback must be audited per screen.
3. **Primary click conflicts:** LibMousePointer adds its primary-click descriptor only when the shortcut is free. HUI does not currently implement a universal descriptor conflict manager for every dynamic screen state.
4. **Non-menu tab systems:** some screens do not use `ZO_MenuBar`; LT/RT cannot switch those tabs yet.
5. **D-pad focus navigation:** no general keyboard-focus graph or generic D-pad adapter exists. Native screen-specific focus systems must be audited rather than guessed.
6. **Scrolling and drag/drop:** right-stick scrolling and controller drag/drop are not implemented.
7. **Wheels and specialized UI:** quickslot, player-interaction, target-marker and housing wheels need dedicated source-reviewed integration if native input does not already operate them.
8. **Platform-style refresh:** HUD anchor propagation is not a universal refresh for all `ZO_PlatformStyle` controls. Compass, action bar, ultimate, boss bar, reticle, death UI and other prompts require targeted review.
9. **Restricted-scene completeness:** ESO adds scenes over time; the exclusion list must be checked against the current source before release.

## Required live verification

For every screen/action family, test with a physical controller:

1. Open and close the scene repeatedly, including overlays and confirmation dialogs.
2. Confirm the intended keyboard-style scene appears while Gamepad Mode remains On.
3. Move the left stick in all directions; the cursor moves and the player/camera remain still.
4. Confirm the right stick does not rotate the camera or move the player while the pointer is active.
5. Test D-pad focus, A/primary, B/back, X/Y, shoulders and triggers. Confirm each action fires exactly once.
6. Confirm the prompt glyph matches the physical controller action.
7. Test safe pointer clicks separately from protected actions. Do not try to bypass a protected-action rejection.
8. Close the menu and confirm normal movement and camera control return immediately.
9. Switch to Pure Gamepad and confirm native presentation/input returns.
10. Confirm restricted screens and loading/pregame remain untouched.
11. Check for Lua errors, duplicate descriptors, stuck directional owners, stale fragments and stuck consumed sticks.

A feature is not “supported” merely because a scene opens or a glyph appears. The full action lifecycle must pass. HUI should not be called 95% functional until this test matrix is completed on the live client.
