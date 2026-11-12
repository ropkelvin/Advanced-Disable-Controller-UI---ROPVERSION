# Implementation update — 12 November 2026

The conservative Phase A plan below was the initial research baseline. The active implementation has since adopted a broader default: ordinary keyboard scene names use keyboard-pointer presentation, while known Gamepad-only/protected workflows remain native. The keyboard world map is now included in that broad routing rather than being forced to the native map. See `docs/ADCUI_RESEARCH.md` for the ADCUI source review and the implemented directional-input ownership design. Unknown keyboard scenes now default to keyboard-pointer presentation; this increases coverage but also makes in-game validation essential.

---

# Keyboard UI + Controller architecture research

## Decision

Keep ESO's real Gamepad Mode enabled. Treat keyboard-style presentation as a per-scene UI choice, not as a global switch to keyboard input mode.

The controller remains the input device and ESO remains responsible for protected actions, native movement, camera, and native Gamepad scenes. The addon may choose keyboard templates for explicitly supported scenes and provide a controller pointer for those scenes.

## Research findings

### 1. Directional input is arbitrated, not read globally

ZOS's Gamepad API guidance says analog-stick and D-pad input should be read through `DIRECTIONAL_INPUT`. A visible window activates its input owner with `DIRECTIONAL_INPUT:Activate(owner, control)`; the control's render order determines precedence. This is the intended way to prevent two UI systems from consuming the same stick.

Source: https://forums.elderscrollsonline.com/en/discussion/222240/orsinium-api-patch-notes-change-log-pts/p1

### 2. ESO's in-game scene manager consumes both sticks in UI mode

The current ESO scene-manager source implements `ZO_IngameSceneManager:UpdateDirectionalInput()` by consuming both `ZO_DI_LEFT_STICK` and `ZO_DI_RIGHT_STICK` while in UI mode. The manager activates itself against `GuiRoot` on entry to UI mode and deactivates on exit.

Source: https://esodata.uesp.net/101050/src/ingame/scenes/ingamescenemanager.lua.html

Implication: merely attaching a pointer fragment is not sufficient to guarantee left-stick pointer movement. The scene manager's UI-mode owner and the pointer's owner compete through directional-input priority. We must solve this using the documented ownership model and validate the actual live manager instance. Avoid raw gamepad polling and global stick interception.

### 3. LibMousePointer is the correct cursor primitive, with a caveat

LibMousePointer exposes `MOUSE_POINTER_FRAGMENT`, cursor position, hit testing, and click invocation. Its documented integration is to attach the fragment to the target scene. It can add a primary-click keybind when that binding is not already used; otherwise the integrating addon must own click behavior.

Source: https://www.esoui.com/downloads/info4518-libmousepointer.html

The library author explicitly notes that they did not have a controller for testing. Therefore, library presence is not evidence that our exact ESO scene/input arrangement works. Treat it as a cursor/hit-test implementation, not as a complete input-routing solution.

### 4. IsInGamepadPreferredMode is a UI-selection decision point

ESO source shows many separate Gamepad and keyboard implementations querying `IsInGamepadPreferredMode()`. The function is used in both platform-specific system routing and shared UI code. A global override therefore has broad consequences beyond changing artwork.

Source: https://esodata.uesp.net/101050/data/i/s/i/IsInGamepadPreferredMode.html

Implication: do not replace the global answer with an indiscriminate keyboard answer. Keep the existing scoped policy model, and make each presentation decision at a known scene/system boundary. Preserve the original function in native Gamepad contexts and avoid executing protected native actions inside protected-call boundaries.

### 5. Existing addon baseline

The CLD branch already has:
- A scoped mode policy in `Policy.lua`.
- Native platform routing hooks in `Core.lua` for `ZO_UI_SYSTEM_MANAGER:OpenPlatformUISystem`, `SYSTEMS:GetObject`, and `SYSTEMS:GetRootScene`.
- A native Gamepad world-map path and keybind refresh handling in `WorldMap.lua`.
- Keyboard-style quickslot wheel handling in `UtilityWheel.lua`, with a narrow inherited-binding bridge.
- Native prompt/dialog/action-bar handling and diagnostic tracing.

These are existing working behaviors and should be preserved unless a specific scene is deliberately moved to keyboard presentation.

## Target architecture

1. **Gamepad mode remains ON.** Do not globally force ESO into keyboard input mode.
2. **Scene policy is explicit.** Every supported scene is classified as one of:
   - `native_gamepad`: ESO's own Gamepad implementation and input.
   - `keyboard_pointer`: keyboard presentation plus controller-driven pointer.
   - `special_native`: ESO-owned special interaction that must not be rewritten.
3. **Presentation is selected before scene construction.** Use the existing scoped platform-selection boundaries, not a late global toggle after the scene is visible.
4. **Pointer is an input owner.** Attach LibMousePointer only to keyboard-pointer scenes. Use DIRECTIONAL_INPUT ownership and scene/control render order; release it on every hide, transition, focus loss, and mode change.
5. **Input is scene-local.** Left stick moves the pointer only while a keyboard-pointer scene is active. In the HUD it moves the character. Right stick remains the camera where ESO permits it; never consume it globally.
6. **Clicks/back are explicit.** Use existing ESO keybind actions where safe. Add a click binding only where LibMousePointer does not already own one. Do not call protected native actions through addon wrappers.
7. **Unknown scenes default to native.** No broad guesses based on scene-name substrings. Add a scene only after tracing its actual scene name, fragments, platform route, and input owner.
8. **Keep the existing wheels.** Quickslot and player-interaction wheels retain their current CLD behavior until separately tested.

## Implementation sequence

- Phase A: establish this branch from the exact current CLD head; add scene-policy infrastructure and diagnostics without changing current scene behavior.
- Phase B: audit actual scene names and native/keyboard fragments for Inventory, Character, Skills, Collections, Journal, Map, crafting, bank, trade, housing, and dialogs against current ESO source and live traces.
- Phase C: enable one low-risk keyboard-pointer scene as a vertical slice. Validate pointer movement, hit testing, click, Back, camera, and return-to-HUD movement before expanding.
- Phase D: migrate further scenes individually, with native fallbacks and regression tests.

## Non-goals

- No raw XInput polling or direct global gamepad polling.
- No global replacement of ESO's scene manager input method without a proven, narrowly scoped ownership design.
- No reimplementation of ESO's protected inventory/trade/resurrection actions.
- No changes to master or CLD from this feature branch.
- No mass conversion of every scene in one pass.
