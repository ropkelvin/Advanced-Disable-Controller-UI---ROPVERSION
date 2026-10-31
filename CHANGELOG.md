# Changelog

## 2.1.0 — full feature pass
- Added independently configurable gamepad prompt styling, dialog glyphs and safe descriptor remapping.
- Added a controller-input bridge for the current keyboard utility wheel, copying the user's gamepad cycle bindings into a temporary addon action layer.
- Added gamepad action-bar styling through current platform-style and ActionButton hooks.
- Added an independent resource-bar style toggle; action bar and resource bars remain compact by default.
- Added compass sizing, scale, pin-label scale, drag positioning and lock.
- Added LB/RB main-menu category navigation.
- Restored keyboard-style map pan reset.
- Added lockpicking scene-exit cleanup.
- Added account-wide settings migration and bindable actions.
- Changed first-run action-bar default to compact keyboard style.
- Removed the obsolete broad crafting callback workaround.

## 2.0.0 — modernization milestone
- Added ESO API 101051 manifest and LibAddonMenu-2.0 native dependency.
- Removed LibStub access from the modern addon.
- Rebuilt gamepad-preference interception and slash commands.
- Preserved the original SavedVariables namespace.
