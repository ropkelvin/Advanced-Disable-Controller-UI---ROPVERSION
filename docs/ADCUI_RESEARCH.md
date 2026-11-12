# ADCUI and keyboard UI + controller research

## ADCUI implementation inspected

Source reviewed: Lionas, Advanced Disable Controller UI, repository `Lionas/Advanced-Disable-Controller-UI`, version 1.4.1.

ADCUI's central technique is a global replacement of `IsInGamepadPreferredMode()` which returns the saved `useControllerUI` flag, except during lockpicking where it returns true. This causes ESO to select keyboard UI templates while leaving controller hardware usable in the game. Its `Bindings.xml` only adds a toggle action; most of the behavior comes from that global platform override. It also adjusts the compass independently.

That technique proves the UI-platform query is a viable selection point, but the original implementation is too broad for this addon: it does not distinguish individual scenes, does not arbitrate pointer ownership, and can force keyboard templates into native/protected workflows. We therefore retain a scoped override and explicit native exceptions rather than copying ADCUI's unconditional global replacement.

## LibMousePointer findings

The LibMousePointer 1.0.0 public API provides `MOUSE_POINTER_FRAGMENT`, `ResetPosition()`, `GetCursorPosition()`, `GetControlAtCursor()` and `InvokeClick()`. Its fragment creates a top-level cursor control, brings that control to the top, registers itself with `DIRECTIONAL_INPUT`, and uses `DIRECTIONAL_INPUT:GetXY(ZO_DI_LEFT_STICK)`. The `GetXY` call consumes the left stick through the official directional-input arbitration system.

ESO's live `zo_directionalinput.lua` confirms that active input owners are processed in control visual-order priority. ESO's ingame scene manager also registers as a directional-input owner on `GuiRoot` and normally consumes both left and right sticks. The pointer overlay is brought above GuiRoot; its update consumes LEFT first. While the pointer fragment is visible, the addon suppresses only the scene manager's later both-stick consume, leaving RIGHT available to the camera. This is scoped to the pointer fragment and does not alter the HUD's normal movement.

## Scene routing strategy

- Keep the actual ESO Gamepad Mode setting ON.
- In Hybrid, keyboard templates are the default for ordinary menu scenes.
- Explicit native exceptions remain for lockpicking, loot, death/resurrection, and scenes whose names identify ESO's Gamepad implementation.
- The pointer fragment is attached only to keyboard-pointer scenes, including `hudui` while ESO is in UI mode; it is not attached to the gameplay `hud`.
- LB/RB category navigation delegates to the keyboard main menu's own category handler using ESO's existing shoulder bindings.
- Pointer click/right-click/reset actions are user-bindable and do not steal A/B/X/Y defaults.
- Unknown keyboard scene names default to keyboard-pointer presentation so new ESO menus are covered; known native scenes remain explicitly classified.

## Safety boundaries

- Do not call protected/private ESO operations directly from addon code.
- Do not replace the scene manager's entire input loop or poll raw XInput.
- Do not consume sticks globally. The only scene-manager input hook is active while the pointer fragment is visible.
- Do not use synthetic key events for protected actions. Mouse hit-testing uses LibMousePointer's published API; protected workflows stay on ESO's native scene/action path.
- Third-party addon windows may not use ESO's platform routing and require separate testing.

## Sources

- ADCUI source: https://github.com/Lionas/Advanced-Disable-Controller-UI
- ESO gamepad API notes: https://forums.elderscrollsonline.com/en/discussion/222240/orsinium-api-patch-notes-change-log-pts
- ESO live directional input: https://github.com/esoui/esoui/blob/live/esoui/libraries/zo_directionalinput/zo_directionalinput.lua
- ESO live scene manager: https://github.com/esoui/esoui/blob/live/esoui/ingame/scenes/ingamescenemanager.lua
- LibMousePointer API: https://www.esoui.com/downloads/info4518-libmousepointer.html
