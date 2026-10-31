# ESO Hybrid UI

**Keyboard HUD. Gamepad controls. Native controller menus.**

ESO Hybrid UI lets you keep the compact keyboard-style gameplay HUD while using your controller, controller button prompts, and ESO's native gamepad menus.

## Features

- Hybrid mode: compact keyboard HUD during gameplay, native gamepad menus when navigating.
- Keyboard, Gamepad, and Hybrid interface modes.
- Controller glyphs for skill-bar actions and contextual prompts.
- Dedicated Map button opens the native gamepad world map in Hybrid mode.
- Player interaction prompts use the configured controller binding.
- Independently selectable action-bar and resource-bar presentation.
- Optional gamepad lockpicking, compass customization, and shoulder-button menu navigation.
- Diagnostic logging and in-game status commands.

## Install

1. Download the latest release ZIP.
2. Extract the `ESOHybridUI` folder into `Documents/Elder Scrolls Online/live/AddOns/`.
3. Ensure LibAddonMenu-2.0 (version 43 or later) is installed and enabled.
4. Enable **ESO Hybrid UI** in the ESO Add-Ons menu.
5. Open Settings > Addon Settings > ESO Hybrid UI.

The addon targets ESO Update 51 (API 101051).

## Quick commands

- `/esohybrid` — toggle interface mode
- `/esohybrid_status` — show current mode
- `/esohybrid_buttons` — toggle controller prompts
- `/esohybrid_actionbar` — toggle gamepad-style action bar
- `/esohybrid_resourcebars` — toggle gamepad-style resource bars
- `/esohybrid_settings` — open addon settings

The previous `/adcui` command family remains available as compatibility aliases.

## Project history and attribution

This repository is maintained by RopKelvin. It contains a substantial Update 51 modernization and additional Hybrid-mode functionality built on the history of the Advanced Disable Controller UI addon. Historical authorship and licensing information are documented in [NOTICE.md](NOTICE.md).

## Disclaimer

ESO Hybrid UI is an independent community addon and is not affiliated with, endorsed by, or sponsored by ZeniMax Media or Bethesda Softworks. The Elder Scrolls Online and related marks belong to their respective owners.
