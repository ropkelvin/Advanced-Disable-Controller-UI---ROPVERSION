# Changelog

## 3.4.0 — Native gamepad architecture

- Keep ESO's native Gamepad Mode active; remove the global `IsInGamepadPreferredMode` replacement.
- Remove temporary preferred-input setting flips previously used to refresh platform styles.
- Remove global dialog interception.
- Remove player-interaction and utility-wheel method replacements and the custom utility-wheel action-layer bridge.
- Remove world-map scene-routing overrides.
- Stop globally replacing ESO keybinding helper functions and stop remapping unrelated menu descriptors.
- Apply keyboard-style reticle typography locally while preferring the controller binding for that HUD keybind control.
- Use ESO's native action-bar keybinding label registration for configured controller actions.
- Leave player and companion ultimate prompts to ESO's native templates rather than displaying hard-coded shoulder glyphs.
- Simplify diagnostics to report the real native gamepad preference and current HUD style.

This release prioritizes reliable native controls and interactions over visual imitation. Any further HUD styling must be isolated to presentation and must not spoof platform mode or replace gameplay handlers.
