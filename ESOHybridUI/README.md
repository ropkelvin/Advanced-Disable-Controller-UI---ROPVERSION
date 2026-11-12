# ESO Hybrid UI 4.2.3-beta

**AI-assisted development disclosure:** AI tools were used during development and review. The addon is maintained and tested by its author. Please report compatibility issues with the ESO game version and a diagnostic dump.

ESO Hybrid UI provides three controller-first interface modes while keeping ESO's Gamepad Mode enabled: native Gamepad, Hybrid, and Keyboard UI + Controller.

## Requirements

- The Elder Scrolls Online PC client.
- **LibAddonMenu-2.0 r43 or newer** (required).
- ESO's **Gamepad Mode must be set to On**, not Auto. Auto can switch input presentation unexpectedly.
- Optional: LibGamepadOptions for the native controller settings page.
- Optional: [LibMousePointer](https://www.esoui.com/downloads/info4518-LibMousePointer.html) for controller-operated pointer navigation and mouse clicks in keyboard-style UI scenes.
- Optional: LibDebugLogger (and DebugLogViewer) for persistent diagnostic logs.

## Installation

1. Install LibAddonMenu-2.0 r43 or newer.
2. Extract the `ESOHybridUI` folder into `Documents/Elder Scrolls Online/live/AddOns/`.
3. Start ESO and enable ESO Hybrid UI in the Add-Ons menu.
4. Open the addon settings and press **Apply settings** once. This applies the recommended controller, keybind-display and chat settings; it does not change them automatically on every login.
5. Choose **Hybrid** or **Keyboard UI + Controller** as the interface mode.

The addon folder must be named exactly `ESOHybridUI` and contain `ESOHybridUI.txt`.

## 4.2.3-beta changes

- Uses LibMousePointer's native left-stick cursor movement in Keyboard UI + Controller; leaves the right stick untouched for normal camera control.

## 4.2.2-beta changes

- Added optional LibMousePointer scene integration and configurable pointer left-click, right-click and reset actions.
- Added controller left-stick movement to the keyboard lockpick virtual cursor using ESO's current native lockpick calculation.
- Added a repository audit of all 305 action definitions in ESO's global bindings file.

## Interface modes

### Gamepad

Uses ESO's normal Gamepad UI without the Hybrid presentation policy.

### Hybrid

- Keeps the compact keyboard-layout HUD and action bar.
- Can display controller glyphs on the action bar and HUD prompts.
- Routes supported platform-selected menus and dialogs to ESO's native Gamepad UI.
- Keeps the native Gamepad world map, loot and lockpicking interfaces.
- Uses the keyboard-style quickslot wheel by default, with controller cycling bridged to ESO's native wheel actions.
- The player-interaction wheel also appears keyboard-style in the current Hybrid setup. This uses ESO's normal interaction path; the addon deliberately does not replace the resurrection interaction function.
- The built-in HUD layout editor edits the keyboard HUD layout.

The **Keyboard-style quickslot wheel** setting can be turned off to use ESO's native Gamepad quickslot radial instead. The player-interaction wheel has no separate setting.

The **Menus opened from the HUD** policy defaults to **Gamepad**. The **Legacy** option retains the older routing behaviour and is intended only as a compatibility fallback.

### Keyboard UI + Controller

- Keeps ESO's normal keyboard UI templates and layout for the HUD and menus.
- Does not route platform-selected menus, the map, loot or lockpicking to their native Gamepad UI.
- Keeps controller input active through ESO's Gamepad Mode setting.
- Forces controller glyph preference on keyboard-layout keybind buttons and HUD prompts.
- Uses the keyboard-style quickslot radial; assign a Gamepad secondary binding to Quickslot Wheel (ACTION_BUTTON_9) under Settings > Controls > Keybindings > Combat to open it from the controller.
- Uses the keyboard-style action bar; ESO's paired Gamepad action bindings remain responsible for combat actions.
- Uses ESO's left and right shoulder controller bindings to move backward and forward through the visible, enabled keyboard main-menu categories. The addon delegates each selection to ESO's keyboard main-menu handler, preserving its normal scene and confirmation flow.
- When LibMousePointer is installed and the setting is enabled, attaches its pointer fragment temporarily to active keyboard-style UI scenes (not the base HUD). The left stick moves the pointer through ESO's native directional-input arbitration while a keyboard-style UI scene is open; the right stick remains untouched for camera control. When the UI closes, the left stick returns to normal character movement. This provides mouse-style targeting for controls that expose mouse hit-testing.
- Reuses ESO's native lockpick virtual-cursor calculation with the controller's left stick, so keyboard-style lockpicking does not lose the native Gamepad movement input merely because the UI presentation is keyboard-style.
- Adds three unassigned actions under Settings > Controls > Keybindings > General: pointer left click, pointer right click and pointer reset. Assign buttons yourself; the addon does not steal A/B/X/Y or alter existing bindings.

This mode cannot manufacture a Gamepad action for a keyboard-only control. Keyboard UI controls are not universally focus-navigable: screens and third-party addons that do not expose controller keybinds or focus navigation may still require mouse/keyboard input. The optional LibMousePointer integration provides a cursor surrogate and hit-testing where supported; it does not turn text-entry fields, protected actions or every custom control into controller-native controls. The mode deliberately avoids replacing protected native callbacks or globally remapping unrelated controls.

## Settings

The keyboard Add-Ons panel is provided by LibAddonMenu. If LibGamepadOptions is installed, the same settings are also available from its native controller settings page.

- **Apply settings:** explicitly applies the recommended ESO input and chat settings.
- **Interface mode:** switches between Gamepad, Hybrid and Keyboard UI + Controller.
- **Menus opened from the HUD:** selects the default Gamepad routing policy or Legacy behaviour.
- **Account-wide settings:** shares the addon settings across characters on the current megaserver.
- **Keyboard-style quickslot wheel:** chooses the keyboard or native Gamepad quickslot radial in Hybrid. Keyboard UI + Controller always uses the keyboard radial.
- **Controller glyphs on the action bar:** enables or disables controller glyphs in Hybrid. Keyboard UI + Controller always uses controller glyphs.
- **HUD prompt fonts:** adjusts interaction and stealth prompt font sizes.
- **Advanced:** optional diagnostic logging, opt-in load announcement and command reference.
- **Donation mail:** opens a mail draft addressed to the author. It does not attach or transfer gold. The mail composer is keyboard-oriented and may not open correctly from every native Gamepad screen.

## Commands

- `/esohybrid` — cycle Gamepad → Hybrid → Keyboard UI + Controller.
- `/esohybrid_status` — show the current interface mode.
- `/esohybrid_policy gamepad|legacy` — change the menu-routing policy.
- `/esohybrid_settings` — open addon settings.
- `/esohybrid_debug on|off` — enable or disable diagnostic logging.
- `/esohybrid_dump` — print a diagnostic snapshot.
- `/esohybrid_trace on|off|report|reset` — trace platform queries, scenes and UI-system routing.
- `/esohybrid_sv` — show SavedVariables initialization status.

## Compatibility notes and known limitations

ESO's UI platform selection is handled through several internal systems. Hybrid uses targeted hooks around those selection points; a game update or another addon that replaces the same functions can affect compatibility.

- Not every special-purpose screen necessarily uses the same platform-selection path. The Event Pursuit HUD entry has been observed opening its keyboard presentation in Hybrid, even when the page opened directly from the Gamepad UI uses the native Gamepad presentation.
- Some prompt remaps refer to ESO-owned keybind descriptor positions. A game update can change those descriptors; diagnostic logging records the remaps.
- The quickslot controller bridge inherits ESO's own controller bindings. Custom controller rebinding should be checked after changing those bindings.
- Keyboard UI + Controller shoulder navigation intentionally targets the native keyboard main-menu category bar only; it does not assume addon-added categories are safe or that every keyboard menu supports directional focus.
- The menu policy and special-case screens should be retested after major ESO updates.

If reporting a problem, include the ESO API version, the action that triggered it, whether the issue occurs in Gamepad, Hybrid or Keyboard UI + Controller mode, and the output of `/esohybrid_dump`. For routing problems, enable `/esohybrid_trace on`, reproduce the issue, then include `/esohybrid_trace report`.

## Credits

ESO Hybrid UI is an AI-assisted revision inspired by **Advanced Disable Controller UI** by **Lionas**, with contributions by **jc28735250** and **DoriKyll**. Credit is given for the original addon concept and inspiration; this project is maintained as a separate implementation.
