# Advanced Disable Controller UI

Modernized replacement for the original 1.5.3 addon.

## Target platform

- ESO live UI source: Update 51 / API 101051 (live source snapshot 12.1.6).
- LibAddonMenu-2.0: required dependency, minimum AddOnVersion 43.
- No LibStub usage.
- Original SavedVariables name retained.
- Original 1.5.3 ZIP and extracted source remain under the repository root and `extracted/`.

## Features in the modernized addon

- Keep controller input while the UI reports keyboard mode.
- Optional native gamepad UI toggle.
- Optional gamepad button glyphs on keyboard-style keybind strips and reticle prompts.
- Optional native gamepad action-bar styling while the rest of the interface remains keyboard-style.
- Compact keyboard action bar and resource bars by default.
- Optional gamepad lockpicking interface.
- Saved compass scale, dimensions, position and lock.
- LB/RB main-menu category navigation.
- Keyboard-style world-map pan reset.
- Character-specific or account-wide settings.
- In-game settings panel, slash commands and bindable actions.

## Install

1. Install LibAddonMenu-2.0 r43 or newer separately through ESOUI/Minion.
2. Copy the `AdvancedDisableControllerUI` folder into:
   `Documents/Elder Scrolls Online/live/AddOns/`
3. Keep the separate `LibAddonMenu-2.0` folder in AddOns. Do not install an old embedded LibStub copy for this addon.
4. Enable the addon and load a character.

## First-run behavior

The original addon's default enabled the large gamepad action bar. The modernized addon migrates that one setting to **off** on first load, so the default HUD is compact. You can turn it back on independently in the settings panel.

## Commands

- `/adcui` — toggle native gamepad UI vs keyboard-style UI.
- `/adcui_status` — print active mode and prompt/action-bar state.
- `/adcui_buttons` — toggle gamepad button prompts.
- `/adcui_actionbar` — toggle gamepad-style action bar.
- `/adcui_compasslock` — lock/unlock compass position.

## Current architecture notes

The core overrides the UI-facing `IsInGamepadPreferredMode()` function while preserving the game's original function for input-mode checks. Action-bar styling is independently handled through the current `ZO_PlatformStyle`, `ZO_GetPlatformTemplate`, and `ActionButton` APIs. Other UI subsystems remain keyboard-style unless the native gamepad UI option is selected.

The original broad crafting/transmute callback hack was intentionally not carried forward; it fired a global callback unrelated to this addon's input/UI purpose. The old `QUICKSLOT_RADIAL_MANAGER` hook was also replaced: current ESO uses `INTERACTIVE_WHEEL_MANAGER` with separate keyboard/gamepad utility-wheel classes, so the modern addon bridges the current gamepad cycle actions through a temporary addon action layer rather than referencing the removed legacy manager.

## Verification

GitHub Actions performs Lua 5.1 syntax parsing and manifest/dependency checks. These do not emulate the ESO client. Runtime verification is still required for controller navigation in menus, action-bar updates, prompts, compass dragging, lockpicking, and addon conflicts.
