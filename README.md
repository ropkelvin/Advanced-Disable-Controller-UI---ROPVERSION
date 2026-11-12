# HUI - ESO Hybrid UI

**AI-assisted development disclosure:** AI tools were used to generate and review portions of this addon. The implementation is still being audited and has not yet been fully verified in the live ESO client. Do not treat this development build as a stable release.

**Required dependency:** [LibMousePointer by Votan](https://www.esoui.com/downloads/info4518-libmousepointer.html). **Optional dependency:** LibAddonMenu-2.0.

HUI is a clean rebuild of ESOHybridUI around one initial goal: keep ESO's native Gamepad input enabled while presenting the keyboard UI.

## Modes

- **Hybrid** (initial default): ESO's Gamepad Mode must be **On**. HUI verifies the actual Gamepad Mode setting is explicitly **On** (not Auto), then changes the UI-preference query only while the player is active in the world. ESO's original query is retained for safe fallback. Gamepad keybind resolution and prompts are selected separately. Keyboard-style scenes receive LibMousePointer's pointer fragment. HUI disables its pointer and gamepad-prompt overrides on detected Crown Store/market, Scrying, and Tribute scenes. During loading transitions it only changes internal active-state flags; global wrappers become pass-through and no scenes or controls are modified. These exclusions still require live-client verification and ESOUI staff clarification before public release because the broad preferred-mode override must not affect restricted screens.
- **Pure Gamepad**: HUI restores ESO's original `IsInGamepadPreferredMode` behaviour in-world and leaves native Gamepad UI routing alone. While outside the active world, HUI's wrapper is a pass-through; it does not change loading-screen or character-selection UI.

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
- [ESO scene manager](https://github.com/esoui/esoui/blob/live/esoui/ingame/scenes/ingamescenemanager.lua) — confirms ESO consumes both sticks in UI mode by default.
- [ESO directional input](https://github.com/esoui/esoui/blob/live/esoui/libraries/zo_directionalinput/zo_directionalinput.lua) — confirms the input-owner ordering and `IsAvailable`/`Consume` behaviour used by HUI's fail-safe.
- [ESO keybinding utilities](https://github.com/esoui/esoui/blob/live/esoui/libraries/utility/keybindingutils.lua) — confirms the three keybinding functions HUI wraps for controller prompts.
- [ESO HUD manager](https://github.com/esoui/esoui/blob/live/esoui/ingame/hud/hudmanager.lua) — confirms `HUD_MANAGER:PropagateSettings()` refreshes active HUD element anchors.
- ESO UI source, published by ZeniMax for reference: [ESOUI source repository](https://github.com/esoui/esoui).

## Architecture

- `Bootstrap.lua`: addon lifecycle, account-wide SavedVariables, and in-world activation/deactivation.
- `Mode.lua`: two-mode state, active-world-only presentation override, and lockpick scene exception.
- `SceneController.lua`: pointer fragment attachment and directional-input ownership for the current top scene.
- `Prompts.lua`: gamepad keybind and glyph preference wrappers, activated in-world and pass-through while inactive.
- `Settings.lua`: optional LibAddonMenu settings.

## Safety boundaries

HUI does not call private ESO functions, simulate protected actions, automate gameplay, or read/write external files. It uses ESO's UI scene and directional-input systems and LibMousePointer's documented fragment/click API. The broad keyboard-scene routing and controller behaviour still require live-client validation, especially inventory, map, crafting, bank/trade, dialogs, resurrection, and lockpicking. LibMousePointer's public documentation describes the fragment and click API but does not specify the exact left-stick input ownership implementation; HUI therefore only bypasses ESO's default stick consumption after the left stick is already consumed by an earlier UI input owner. If that has not happened, ESO retains its normal safety behaviour and consumes both sticks.

## Known implementation gaps

This branch is a foundation, not a feature-complete Hybrid release. The following work is still required before claiming full controller support:

- Screen-specific click handling when `UI_SHORTCUT_PRIMARY` is already occupied. The LibMousePointer automatic click binding is conditional.
- Dedicated controller glyph adapters for the action bar/ultimate, reticle, death and player-interaction prompts. Some ESO controls check `IsInGamepadPreferredMode()` directly, so the generic keybinding wrappers alone cannot cover every case.
- Audit of actual keybind dispatch, not just glyph display. ESO's `ZO_KeybindStrip:GetButtonOrEtherealDescriptorForKeybind` directly checks `IsInGamepadPreferredMode()` when choosing between duplicate keyboard/gamepad descriptors. The current wrappers change display preference but do not yet prove that every controller button invokes the intended keyboard-screen callback.
- Explicit quickslot-wheel and player-interaction-wheel bindings and behaviour. The old `Bindings.xml` and `UtilityWheel.lua` were intentionally not copied into this clean foundation.
- A complete screen-by-screen route and interaction audit for inventory, map, crafting, bank, trade, dialogs, loot, resurrection and housing.
- A verified LibMousePointer source review and live controller test. Its published page does not document enough detail to prove its exact left-stick consumption order.

## Development status

Initial audited foundation only. Not release-ready and not yet confirmed in-game. Automated Lua syntax, manifest and package checks are necessary but do not establish runtime correctness. The non-optional LibMousePointer dependency also needs its exact `## AddOnVersion` value so the manifest can use ESOUI's required versioned dependency syntax.
