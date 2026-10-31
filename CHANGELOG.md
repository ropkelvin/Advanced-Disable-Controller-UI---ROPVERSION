# Changelog

## 2.0.0 — modernization milestone
- Added a clean addon entry point targeting ESO API 101051.
- Removed LibStub usage; LibAddonMenu-2.0 is declared as a versioned dependency
  and accessed through LibAddonMenu2.
- Preserved the original SavedVariables identifier and schema version.
- Rebuilt the central gamepad-preference override with guarded initialization.
- Added native gamepad UI toggle and slash commands.
- Kept original source and ZIP archive untouched under extracted/.
- Deferred legacy action-bar, resource-bar, button-prompt, compass, and
  main-menu overrides pending current-UI compatibility review.
