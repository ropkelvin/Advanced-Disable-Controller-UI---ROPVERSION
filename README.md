# ESO Hybrid UI

Controller-first interface addon for The Elder Scrolls Online. It provides native Gamepad mode and a compact Hybrid mode with controller prompts.

## Dependency

- **Required:** LibAddonMenu-2.0 version 43 or newer.
- The dependency is declared in `ESOHybridUI.txt` with `## DependsOn: LibAddonMenu-2.0>=43`.

## Recommended ESO settings

Open the addon's settings and click **Apply settings** once. This saves the following ESO preferences:

- Gamepad Mode: On
- Keybind Display Mode: Gamepad
- Use Keyboard Chat: On
- Return Cursor on Chat Focus: On

The addon does not silently reapply these preferences on login. The button can be clicked again if the player later changes them.

## Installation archive structure

The installable ZIP must contain the addon folder matching the manifest name:

```
ESOHybridUI.zip
└── ESOHybridUI/
    ├── ESOHybridUI.txt
    ├── Bindings.xml
    └── src/
        └── *.lua
```

Do not zip the repository root directly. The GitHub Actions workflow packages the correct folder and uploads an `ESOHybridUI.zip` artifact on pushes to `master`.

## SavedVariables

Character-specific settings use ESO character IDs, which are unique across megaservers. Account-wide settings are namespaced by `GetWorldName()` so EU, NA, and PTS profiles do not overwrite each other. On first load after this change, the addon copies the previous un-namespaced account-wide profile into the current megaserver profile and leaves the legacy data intact.

## Credits and attribution

- **The Elder Scrolls Online / ZeniMax Online Studios:** game, UI framework, and addon API.
- **LibAddonMenu-2.0:** required third-party settings-library dependency; it is distributed and maintained separately by its ESOUI authors.
- **Advanced Disable Controller UI:** historical project lineage, originally by Lionas, with contributions from jc28735250 and subsequent maintenance by DoriKyll. See [NOTICE.md](NOTICE.md) for attribution context.
- **AI-assisted development:** AI tools contributed to portions of the code and documentation. The maintainer is responsible for reviewing, testing, and maintaining this addon.

This repository does not bundle LibAddonMenu-2.0. Install it separately through ESOUI. Any directly reused third-party code or assets must retain the original license and attribution.

## In-game actions and donations

The optional donation shortcut only opens a mail draft addressed to @ZOSPlsFix. The player must manually choose whether to attach gold and the amount. The addon never attaches or modifies mail gold, sends mail, trades, automates combat, or performs other player actions.

## AI disclosure

AI-assisted development: AI tools have contributed to portions of this addon's code and documentation. The maintainer is responsible for reviewing changes, validating behavior in ESO, and maintaining the addon.
