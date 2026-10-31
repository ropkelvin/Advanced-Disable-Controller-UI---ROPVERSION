# Advanced Disable Controller UI

Modernized replacement for the original 1.5.3 addon.

## Target platform

- ESO live UI source: Update 51 / API 101051 (live source snapshot 12.1.6).
- LibAddonMenu-2.0: required dependency, minimum AddOnVersion 43.
- No LibStub usage in the new runtime; the historical 1.5.3 source is retained only for reference.
- Original SavedVariables name retained.
- Original 1.5.3 ZIP and extracted source remain under the repository root and `extracted/`.

## Features in the modernized addon

- Keep controller input while the UI reports keyboard mode.
- Optional native gamepad UI toggle.
- Optional gamepad button glyphs on keyboard-style keybind strips, reticle prompts and dialogs.
- Optional native gamepad action-bar styling while the rest of the interface remains keyboard-style.
- Optional native gamepad resource-bar styling, independently switchable from the action bar.
- Compact keyboard action bar and resource bars by default.
- Controller shoulder-button cycling for the current keyboard utility wheel.
- Optional gamepad lockpicking interface.
- Saved compass scale, dimensions, position and lock.
- LB/RB main-menu category navigation.
- Keyboard-style world-map pan reset.
- Character-specific or account-wide settings.
- In-game settings panel, slash commands and bindable actions.
- Optional LibDebugLogger integration, persistent debug-mode toggle and diagnostic state snapshots.

## Install

1. Install LibAddonMenu-2.0 r43 or newer separately through ESOUI/Minion.
2. For diagnostic logging, also install LibDebugLogger and DebugLogViewer from ESOUI. These are optional for normal addon use.
3. Copy the `AdvancedDisableControllerUI` folder into:
   `Documents/Elder Scrolls Online/live/AddOns/`
4. Keep the separate `LibAddonMenu-2.0` folder in AddOns. Do not install an old embedded LibStub copy for this addon.
5. Enable the addon and load a character.

## Debugging

1. Install **LibDebugLogger** and **DebugLogViewer** (LibDebugLogger is not a hard dependency).
2. In chat, enter `/adcui_debug on` or enable **Settings → AddOns → Advanced Disable Controller UI → Enable diagnostic logging**.
3. Reproduce the issue. Use `/adcui_dump` immediately after it happens to record a snapshot of UI mode, controller preference, settings and installed hooks.
4. Open the log viewer with `/logviewer`. Filter for the `ADCUI` tag and inspect errors/warnings and the surrounding events.
5. The log is stored in `Documents/Elder Scrolls Online/live/SavedVariables/LibDebugLogger.lua`. Log out normally or reload the UI to flush SavedVariables, then share the relevant ADCUI entries or the log file.

Turn logging off with `/adcui_debug off` when finished. Debug logging is off by default; normal informational and warning events remain available at the logger's default level. Avoid sharing the entire log publicly without checking it for account/character information.

## First-run behavior

The keyboard-style UI is enabled by default, gamepad button prompts are enabled, and both gamepad action-bar and resource-bar styling are disabled so the HUD stays compact. The original addon's large-action-bar default is migrated to **off** on first load. Gamepad lockpicking remains enabled. Each style can be changed independently in the settings panel.

## Commands

- `/adcui` — toggle native gamepad UI vs keyboard-style UI.
- `/adcui_settings` — open the addon settings panel.
- `/adcui_status` — print active mode, prompts, action-bar and resource-bar state.
- `/adcui_buttons` — toggle gamepad button prompts.
- `/adcui_actionbar` — toggle gamepad-style action bar.
- `/adcui_resourcebars` — toggle gamepad-style resource bars.
- `/adcui_compasslock` — lock/unlock compass position.
- `/adcui_debug on` / `/adcui_debug off` — enable/disable detailed addon logging.
- `/adcui_dump` — write a diagnostic snapshot of addon settings, mode state and installed hooks.

## Current architecture notes

The core overrides the UI-facing `IsInGamepadPreferredMode()` function while preserving the game's original function for input-mode checks. Action-bar styling is independently handled through the current `ZO_PlatformStyle`, `ZO_GetPlatformTemplate`, and `ActionButton` APIs. Other UI subsystems remain keyboard-style unless explicitly configured otherwise.

The original broad crafting/transmute callback hack was intentionally not carried forward; it fired a global callback unrelated to this addon's input/UI purpose. The old `QUICKSLOT_RADIAL_MANAGER` hook was also replaced: current ESO uses `INTERACTIVE_WHEEL_MANAGER` with separate keyboard/gamepad utility-wheel classes, so the modern addon bridges the current gamepad cycle actions through a temporary addon action layer rather than referencing the removed legacy manager.

## Verification

GitHub Actions performs Lua 5.1 syntax parsing and manifest/dependency checks. These do not emulate the ESO client. Runtime verification is still required for controller navigation in menus, action-bar updates, prompts, compass dragging, lockpicking, and addon conflicts.
