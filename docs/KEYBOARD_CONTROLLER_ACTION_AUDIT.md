# Keyboard UI + Controller: native ESO action audit

Research snapshot: ESO's public `esoui/esoui` live branch, `esoui/ingame/globals/bindings.xml`.

This inventory covers **305 native action definitions** found in the global bindings file at the time of review. It is not a claim that ESO has only 305 possible UI actions: controls can register local keybind descriptors, scene-specific actions, protected callbacks and addon-defined actions outside this file.

## Input architecture findings

- ESO separates general gameplay actions, UI shortcut actions, and Gamepad UI shortcut actions into different action layers.
- `UI_SHORTCUT_PRIMARY/SECONDARY/...` dispatch through `ZO_KeybindStrip_HandleKeybindDown/Up`; they do not automatically give keyboard-template controls directional focus.
- Gamepad stick/D-pad input is arbitrated by `DIRECTIONAL_INPUT`. Its own update loop calls active input objects in visual-priority order; addon windows should activate/deactivate through this API rather than start competing per-frame loops.
- ESO's keyboard and Gamepad templates are not interchangeable. A glyph override changes only presentation; a keyboard control still needs a native keybind, directional-input handler, or mouse handler to become operable.
- Mouse-hit-testable controls can be reached through the optional LibMousePointer pointer fragment and its click API. Text entry, protected actions and controls without mouse handlers still need dedicated support.

## Implemented in this branch

- Native Gamepad input remains enabled; the new mode changes platform presentation, not the physical input device.
- Controller glyph preference is applied to keyboard-style keybind buttons and prompt strips.
- Main-menu LB/RB category cycling delegates to ESO's keyboard main-menu category handler.
- Keyboard quickslot wheel cycling bridges to ESO's native Gamepad cycle bindings.
- Optional LibMousePointer integration attaches its fragment to active keyboard-style scenes, excluding the base HUD. It exposes separately bindable left-click, right-click and reset actions; it never silently steals A/B/X/Y.
- Keyboard-style lockpicking reuses ESO's current native virtual-cursor calculation with the controller's left-stick input, following the narrow compatibility approach used by EnhancedGamepadUI.
- Existing native callbacks remain native. Protected inventory/resurrection functions are not reimplemented.

## Native global action inventory

### SI_KEYBINDINGS_LAYER_GENERAL

**SI_KEYBINDINGS_CATEGORY_MOVEMENT** (10)

`MOVE_FORWARD`, `MOVE_BACKWARD`, `TOGGLE_WALK`, `TURN_LEFT`, `TURN_RIGHT`, `MOVE_JUMPASCEND`, `AUTORUN`, `ROLL_DODGE`, `TOGGLE_MOUNT`, `GAMEPAD_JUMP_OR_INTERACT`

**SI_KEYBINDINGS_CATEGORY_COMBAT** (26)

`SPECIAL_MOVE_ATTACK`, `SPECIAL_MOVE_BLOCK`, `SPECIAL_MOVE_SPRINT`, `SPECIAL_MOVE_CROUCH`, `SPECIAL_MOVE_INTERRUPT`, `USE_SYNERGY`, `SPECIAL_MOVE_WEAPON_SWAP`, `SPECIAL_MOVE_WEAPON_SWAP_TO_SET_1`, `SPECIAL_MOVE_WEAPON_SWAP_TO_SET_2`, `ACTION_BUTTON_3`, `ACTION_BUTTON_4`, `ACTION_BUTTON_5`, `ACTION_BUTTON_6`, `ACTION_BUTTON_7`, `ACTION_BUTTON_8`, `GAMEPAD_SPECIAL_MOVE_SPRINT`, `GAMEPAD_MOVE_JUMPASCEND`, `GAMEPAD_ACTION_BUTTON_3`, `GAMEPAD_ACTION_BUTTON_4`, `GAMEPAD_ACTION_BUTTON_5`, `GAMEPAD_ACTION_BUTTON_6`, `GAMEPAD_ACTION_BUTTON_7`, `GAMEPAD_ACTION_BUTTON_8`, `ACTION_BUTTON_9`, `SHEATHE_WEAPON_TOGGLE`, `COMMAND_PET`

**SI_KEYBINDINGS_CATEGORY_TARGETING** (12)

`CYCLE_PREFERRED_ENEMY_TARGET`, `GAMEPAD_CYCLE_PREFERRED_ENEMY_TARGET`, `CLEAR_PREFERRED_ENEMY_TARGET`, `GAMEPAD_TARGET_MARKER_INTERACT`, `ASSIGN_TARGET_MARKER_FOUR`, `ASSIGN_TARGET_MARKER_THREE`, `ASSIGN_TARGET_MARKER_TWO`, `ASSIGN_TARGET_MARKER_ONE`, `ASSIGN_TARGET_MARKER_EIGHT`, `ASSIGN_TARGET_MARKER_SEVEN`, `ASSIGN_TARGET_MARKER_SIX`, `ASSIGN_TARGET_MARKER_FIVE`

**SI_KEYBINDINGS_CATEGORY_CAMERA** (4)

`CAMERA_ZOOM_OUT`, `CAMERA_ZOOM_IN`, `GAME_CAMERA_MOUSE_FREE_LOOK`, `GAME_CAMERA_GAMEPAD_ZOOM`

**SI_KEYBINDINGS_CATEGORY_INTERACTION** (2)

`GAME_CAMERA_INTERACT`, `PLAYER_TO_PLAYER_INTERACT`

**SI_KEYBINDINGS_CATEGORY_USER_INTERFACE** (35)

`TOGGLE_FULLSCREEN`, `TAKE_SCREENSHOT`, `START_CHAT_ENTER`, `START_CHAT_SLASH`, `CHAT_REPLY_TO_LAST_WHISPER`, `TOGGLE_SHOW_INGAME_GUI`, `TOGGLE_GAME_CAMERA_UI_MODE`, `TOGGLE_MARKET`, `TOGGLE_INVENTORY`, `TOGGLE_CHARACTER`, `TOGGLE_SKILLS`, `TOGGLE_CHAMPION`, `TOGGLE_JOURNAL`, `TOGGLE_COLLECTIONS_BOOK`, `TOGGLE_MAP`, `TOGGLE_GROUP`, `TOGGLE_CONTACTS`, `TOGGLE_GUILDS`, `TOGGLE_ALLIANCE_WAR`, `TOGGLE_MAIL`, `TOGGLE_NOTIFICATIONS`, `TOGGLE_ACTIVITY_FINDER`, `TOGGLE_CROWN_CRATES`, `TOGGLE_TAMRIEL_TOMES`, `TOGGLE_HELP`, `TOGGLE_SYSTEM`, `ASSIST_NEXT_TRACKED_QUEST`, `GAMEPAD_CYCLE_PINNED_HUD_ACTION`, `TOGGLE_ACTIVITY_HUD_TRACKER`, `TOGGLE_FIRST_PERSON`, `TOGGLE_HUD_UI`, `TOGGLE_GAMEPAD_MODE`, `TOGGLE_NAMEPLATES`, `TOGGLE_HEALTHBARS`, `CLEAR_ACTIVE_NARRATION`

### GamepadUIMode

**unnamed category** (1)

`GAMEPAD_UI_EXIT`

### SI_KEYBINDINGS_LAYER_USER_INTERFACE_SHORTCUTS

**SI_KEYBINDINGS_CATEGORY_GENERAL** (10)

`UI_SHORTCUT_PRIMARY`, `UI_SHORTCUT_SECONDARY`, `UI_SHORTCUT_TERTIARY`, `UI_SHORTCUT_QUATERNARY`, `UI_SHORTCUT_QUINARY`, `UI_SHORTCUT_NEGATIVE`, `UI_SHORTCUT_HELP`, `UI_SHORTCUT_QUICK_SLOTS`, `UI_SHORTCUT_SHOW_QUEST_ON_MAP`, `UI_SHORTCUT_EXIT`

**SI_KEYBINDINGS_CATEGORY_USER_INTERFACE_GAMEPAD** (18)

`UI_SHORTCUT_LEFT_STICK`, `UI_SHORTCUT_LEFT_STICK_UP`, `UI_SHORTCUT_LEFT_STICK_RIGHT`, `UI_SHORTCUT_LEFT_STICK_DOWN`, `UI_SHORTCUT_LEFT_STICK_LEFT`, `UI_SHORTCUT_INPUT_UP`, `UI_SHORTCUT_INPUT_RIGHT`, `UI_SHORTCUT_INPUT_DOWN`, `UI_SHORTCUT_INPUT_LEFT`, `UI_SHORTCUT_RIGHT_STICK`, `UI_SHORTCUT_RIGHT_STICK_UP`, `UI_SHORTCUT_RIGHT_STICK_RIGHT`, `UI_SHORTCUT_RIGHT_STICK_DOWN`, `UI_SHORTCUT_RIGHT_STICK_LEFT`, `UI_SHORTCUT_LEFT_SHOULDER`, `UI_SHORTCUT_RIGHT_SHOULDER`, `UI_SHORTCUT_LEFT_TRIGGER`, `UI_SHORTCUT_RIGHT_TRIGGER`

### SI_KEYBINDINGS_LAYER_SIEGE

**unnamed category** (4)

`SIEGE_FIRE`, `SIEGE_RELEASE`, `SIEGE_PACK_UP`, `SIEGE_ESCAPE`

### SI_KEYBINDINGS_LAYER_DIALOG

**unnamed category** (6)

`DIALOG_PRIMARY`, `DIALOG_SECONDARY`, `DIALOG_TERTIARY`, `DIALOG_NEGATIVE`, `DIALOG_CLOSE`, `DIALOG_RESET`

### SI_KEYBINDINGS_LAYER_NOTIFICATIONS

**unnamed category** (2)

`PLAYER_TO_PLAYER_INTERACT_ACCEPT`, `PLAYER_TO_PLAYER_INTERACT_DECLINE`

### SI_KEYBINDINGS_LAYER_UTILITY_WHEEL

**SI_KEYBINDINGS_CATEGORY_UTILITY_WHEEL_KEYBOARD** (2)

`UTILITY_WHEEL_KEYBOARD_CYCLE_LEFT`, `UTILITY_WHEEL_KEYBOARD_CYCLE_RIGHT`

**SI_KEYBINDINGS_CATEGORY_UTILITY_WHEEL_GAMEPAD** (2)

`UTILITY_WHEEL_GAMEPAD_CYCLE_LEFT`, `UTILITY_WHEEL_GAMEPAD_CYCLE_RIGHT`

### SI_KEYBINDINGS_LAYER_ACCESSIBLE_QUICKWHEEL

**unnamed category** (11)

`ACCESSIBLE_WHEEL_HOTKEY_SLOT_1`, `ACCESSIBLE_WHEEL_HOTKEY_SLOT_2`, `ACCESSIBLE_WHEEL_HOTKEY_SLOT_3`, `ACCESSIBLE_WHEEL_HOTKEY_SLOT_4`, `ACCESSIBLE_WHEEL_HOTKEY_SLOT_5`, `ACCESSIBLE_WHEEL_HOTKEY_SLOT_6`, `ACCESSIBLE_WHEEL_HOTKEY_SLOT_7`, `ACCESSIBLE_WHEEL_HOTKEY_SLOT_8`, `ACCESSIBLE_WHEEL_HOTKEY_SLOT_9`, `ACCESSIBLE_WHEEL_HOTKEY_SLOT_10`, `ACCESSIBLE_WHEEL_HIDE`

### PlayerToPlayerAccessibleLayer

**unnamed category** (11)

`PLAYER_TO_PLAYER_ACCESSIBLE_WHEEL_HOTKEY_SLOT_1`, `PLAYER_TO_PLAYER_ACCESSIBLE_WHEEL_HOTKEY_SLOT_2`, `PLAYER_TO_PLAYER_ACCESSIBLE_WHEEL_HOTKEY_SLOT_3`, `PLAYER_TO_PLAYER_ACCESSIBLE_WHEEL_HOTKEY_SLOT_4`, `PLAYER_TO_PLAYER_ACCESSIBLE_WHEEL_HOTKEY_SLOT_5`, `PLAYER_TO_PLAYER_ACCESSIBLE_WHEEL_HOTKEY_SLOT_6`, `PLAYER_TO_PLAYER_ACCESSIBLE_WHEEL_HOTKEY_SLOT_7`, `PLAYER_TO_PLAYER_ACCESSIBLE_WHEEL_HOTKEY_SLOT_8`, `PLAYER_TO_PLAYER_ACCESSIBLE_WHEEL_HOTKEY_SLOT_9`, `PLAYER_TO_PLAYER_ACCESSIBLE_WHEEL_HOTKEY_SLOT_10`, `PLAYER_TO_PLAYER_ACCESSIBLE_WHEEL_HIDE`

### SI_KEYBINDINGS_LAYER_INSTANCE_KICK_WARNING

**unnamed category** (1)

`INSTANCE_KICK_LEAVE_INSTANCE`

### MouseUIMode

**unnamed category** (3)

`LEFT_MOUSE_IN_WORLD`, `LEFT_AND_RIGHT_MOUSE_IN_WORLD`, `RIGHT_MOUSE_IN_WORLD`

### SpectatorCameraMouse

**unnamed category** (3)

`SPECTATOR_LEFT_MOUSE_IN_WORLD`, `SPECTATOR_LEFT_AND_RIGHT_MOUSE_IN_WORLD`, `SPECTATOR_RIGHT_MOUSE_IN_WORLD`

### UIError

**unnamed category** (7)

`UI_ERROR_DISMISS`, `UI_ERROR_RELOAD_UI`, `UI_ERROR_SUPPRESS`, `UI_ERROR_COPY`, `UI_ERROR_MORE_INFO`, `UI_ERROR_PAGE_LEFT`, `UI_ERROR_PAGE_RIGHT`

### Conversation

**unnamed category** (12)

`CONVERSATION_OPTION_1`, `CONVERSATION_OPTION_2`, `CONVERSATION_OPTION_3`, `CONVERSATION_OPTION_4`, `CONVERSATION_OPTION_5`, `CONVERSATION_OPTION_6`, `CONVERSATION_OPTION_7`, `CONVERSATION_OPTION_8`, `CONVERSATION_OPTION_9`, `CONVERSATION_OPTION_10`, `CONVERSATION_OPTION_PRIMARY`, `CONVERSATION_OPTION_NEGATIVE`

### SceneChangeInterceptLayer

**unnamed category** (23)

`INTERCEPT_UI_SHORTCUT_EXIT`, `INTERCEPT_UI_SHORTCUT_NEGATIVE`, `INTERCEPT_TOGGLE_SYSTEM`, `INTERCEPT_TOGGLE_GAME_CAMERA_UI_MODE`, `INTERCEPT_TOGGLE_MARKET`, `INTERCEPT_TOGGLE_INVENTORY`, `INTERCEPT_TOGGLE_CHARACTER`, `INTERCEPT_TOGGLE_SKILLS`, `INTERCEPT_TOGGLE_CHAMPION`, `INTERCEPT_TOGGLE_JOURNAL`, `INTERCEPT_TOGGLE_COLLECTIONS_BOOK`, `INTERCEPT_TOGGLE_MAP`, `INTERCEPT_TOGGLE_GROUP`, `INTERCEPT_TOGGLE_CONTACTS`, `INTERCEPT_TOGGLE_GUILDS`, `INTERCEPT_TOGGLE_ALLIANCE_WAR`, `INTERCEPT_TOGGLE_MAIL`, `INTERCEPT_TOGGLE_NOTIFICATIONS`, `INTERCEPT_TOGGLE_ACTIVITY_FINDER`, `INTERCEPT_TOGGLE_CROWN_CRATES`, `INTERCEPT_TOGGLE_TAMRIEL_TOMES`, `INTERCEPT_TOGGLE_HELP`, `INTERCEPT_TOGGLE_ACTIVITY_HUD_TRACKER`

### PreviewInterceptLayer

**unnamed category** (6)

`INTERCEPT_SHEATHE_WEAPON_TOGGLE`, `INTERCEPT_AUTORUN`, `INTERCEPT_SPECIAL_MOVE_CROUCH`, `INTERCEPT_SPECIAL_WEAPON_SWAP`, `INTERCEPT_SPECIAL_WEAPON_SWAP_TO_SET_1`, `INTERCEPT_SPECIAL_WEAPON_SWAP_TO_SET_2`

### Guild

**unnamed category** (5)

`GUILD_1`, `GUILD_2`, `GUILD_3`, `GUILD_4`, `GUILD_5`

### SetGuildRankDialog

**unnamed category** (10)

`SET_GUILD_RANK_1`, `SET_GUILD_RANK_2`, `SET_GUILD_RANK_3`, `SET_GUILD_RANK_4`, `SET_GUILD_RANK_5`, `SET_GUILD_RANK_6`, `SET_GUILD_RANK_7`, `SET_GUILD_RANK_8`, `SET_GUILD_RANK_9`, `SET_GUILD_RANK_10`

### RadialMenu

### Death

**unnamed category** (6)

`DEATH_PRIMARY`, `DEATH_SECONDARY`, `DEATH_TERTIARY`, `DEATH_DECLINE`, `DEATH_RECAP_TOGGLE`, `DEATH_RECAP_HIDE`

### Loot

**unnamed category** (3)

`LOOT_ITEM`, `LOOT_ALL`, `LOOT_EXIT`

### GamepadChatSystem

**unnamed category** (3)

`SUBMIT_CHAT`, `CANCEL_CHAT`, `EXIT_CHAT`

### GameMenu

**unnamed category** (1)

`GAME_MENU_DO_NOTHING`

### KeybindWindow

**unnamed category** (2)

`KEYBINDS_LOAD_KEYBOARD_DEFAULTS`, `KEYBINDS_LOAD_GAMEPAD_DEFAULTS`

### Addons

**unnamed category** (2)

`ADDONS_PANEL_PRIMARY`, `ADDONS_PANEL_SECONDARY`

### OptionsWindow

**unnamed category** (2)

`OPTIONS_APPLY_CHANGES`, `OPTIONS_LOAD_DEFAULTS`

### ScreenAdjustActions

**unnamed category** (4)

`SCREEN_ADJUST_GROW`, `SCREEN_ADJUST_SHRINK`, `SCREEN_ADJUST_SAVE`, `SCREEN_ADJUST_CANCEL`

### SI_KEYBINDINGS_LAYER_HUD_HOUSING

**unnamed category** (1)

`SHOW_HOUSING_PANEL`

### SI_KEYBINDINGS_LAYER_BATTLEGROUNDS

**unnamed category** (7)

`TOGGLE_BATTLEGROUND_SCOREBOARD_DUMMY`, `LEAVE_BATTLEGROUND_DUMMY`, `BATTLEGROUND_SCOREBOARD_PREVIOUS_DUMMY`, `BATTLEGROUND_SCOREBOARD_NEXT_DUMMY`, `BATTLEGROUND_SCOREBOARD_PREVIOUS_ROUND_DUMMY`, `BATTLEGROUND_SCOREBOARD_NEXT_ROUND_DUMMY`, `BATTLEGROUND_SCOREBOARD_PLAYER_OPTIONS_DUMMY`

### BattlegroundHud

**unnamed category** (1)

`SHOW_BATTLEGROUND_SCOREBOARD`

### BattlegroundScoreboard

**unnamed category** (7)

`LEAVE_BATTLEGROUND`, `HIDE_BATTLEGROUND_SCOREBOARD`, `BATTLEGROUND_SCOREBOARD_PREVIOUS`, `BATTLEGROUND_SCOREBOARD_NEXT`, `BATTLEGROUND_SCOREBOARD_PREVIOUS_ROUND`, `BATTLEGROUND_SCOREBOARD_NEXT_ROUND`, `BATTLEGROUND_SCOREBOARD_PLAYER_OPTIONS`

### BattlegroundBlocking

### BattlegroundRoundRecap

**unnamed category** (2)

`BATTLEGROUND_RECAP_LEAVE`, `BATTLEGROUND_RECAP_SHOW_SCOREBOARD`

### ScreenshotMode

**unnamed category** (4)

`SCREENSHOT_MODE_EXIT`, `SCREENSHOT_MODE_SHOW_UI_1`, `SCREENSHOT_MODE_SHOW_UI_2`, `SCREENSHOT_MODE_TOGGLE_NAMEPLATES`

### SI_KEYBINDINGS_LAYER_HOUSING_EDITOR

**unnamed category** (16)

`HOUSING_EDITOR_PRIMARY_ACTION`, `HOUSING_EDITOR_NEGATIVE_ACTION`, `HOUSING_EDITOR_SECONDARY_ACTION`, `HOUSING_EDITOR_TERTIARY_ACTION`, `HOUSING_EDITOR_QUATERNARY_ACTION`, `HOUSING_EDITOR_QUINARY_ACTION`, `HOUSING_EDITOR_SENARY_ACTION`, `HOUSING_EDITOR_CYCLE_TARGET_ACTION`, `HOUSING_EDITOR_TOGGLE_NODE_SPEED`, `HOUSING_EDITOR_TOGGLE_NODE_DELAY`, `HOUSING_EDITOR_JUMP_TO_SAFE_LOC`, `DISABLE_HOUSING_EDITOR`, `HOUSING_EDITOR_UNDO_ACTION`, `HOUSING_EDITOR_REDO_ACTION`, `HOUSING_EDITOR_BEGIN_FURNITURE_LINKING`, `HOUSING_EDITOR_REPORT_HOUSE`

### SI_KEYBINDINGS_LAYER_HOUSING_EDITOR_PLACEMENT_MODE

**unnamed category** (9)

`HOUSING_EDITOR_YAW_LEFT`, `HOUSING_EDITOR_YAW_RIGHT`, `HOUSING_EDITOR_PITCH_FORWARD`, `HOUSING_EDITOR_PITCH_BACKWARD`, `HOUSING_EDITOR_ROLL_LEFT`, `HOUSING_EDITOR_ROLL_RIGHT`, `HOUSING_EDITOR_PUSH_FORWARD`, `HOUSING_EDITOR_PULL_BACKWARD`, `HOUSING_EDITOR_ALIGN_TO_SURFACE`

### SpecialToggleHelp

**unnamed category** (1)

`GAMEPAD_SPECIAL_TOGGLE_HELP`

### ScryingActions

### AntiquityDiggingActions

**unnamed category** (1)

`ANTIQUITY_DIGGING_MORE_INFO`

### PreviewStateNavigation

**unnamed category** (4)

`PREVIEW_NEXT_VARIATION`, `PREVIEW_PREVIOUS_VARIATION`, `PREVIEW_NEXT_ACTION`, `PREVIEW_PREVIOUS_ACTION`

### PathNodeRotationBlockCrouchLayer

### CloseActionsInterceptLayer

**unnamed category** (3)

`CLOSE_INTERCEPT_TOGGLE_SYSTEM`, `CLOSE_INTERCEPT_TOGGLE_GAME_CAMERA_UI_MODE`, `CLOSE_INTERCEPT_GAMEPAD_UI_EXIT`

### PromotionalEventPersonalCampaignAnnouncementInterceptLayer

## How the action families map to controller support

| Native action family | Intended handling in Keyboard UI + Controller |
|---|---|
| Movement, combat, weapon swap, synergy, targeting and camera | Preserve ESO's native Gamepad gameplay actions. Do not synthesize combat calls or replace secure input callbacks. |
| UI category toggles | Keep ESO's native toggle actions pointed at the keyboard main-menu object; LB/RB navigate the keyboard category bar. |
| UI shortcut primary/secondary/tertiary/etc. | These dispatch through the active keybind strip. Glyph preference alone is insufficient; each keyboard descriptor needs a matching controller action or mouse click. |
| Dialogs, conversations, loot and menus | Use the keyboard scene's existing mouse handlers through the optional pointer, or add a screen-specific safe descriptor mapping. |
| Radial menus and quickslot wheel | Preserve ESO's radial-menu `DIRECTIONAL_INPUT` path; keyboard radial selection should be tested separately from its open/cycle bindings. |
| Lockpicking | Use ESO's native lockpick virtual-cursor math with left-stick input, because the keyboard template normally gates this on the preferred-mode query. |
| Housing editor, antiquities, special preview and third-party panels | Treat as screen-specific until their keybind descriptors, focus behavior and protected callbacks are audited. |

## Coverage rules for the remaining work

1. **Native action already exists:** bind to or delegate to the ESO action; do not duplicate its gameplay logic.
2. **Keybind-strip action exists:** keep its callback and descriptor intact; only change the displayed preferred binding or add a deliberate alias where it cannot double-fire.
3. **Keyboard control has mouse handlers:** use LibMousePointer hit-testing and explicit click actions.
4. **Keyboard control is focus-driven:** register a scene/control-scoped `DIRECTIONAL_INPUT` object, and deactivate it when hidden. Do not globally consume sticks.
5. **Keyboard control has neither mouse handlers nor focus navigation:** it requires a screen-specific adapter or remains keyboard/mouse-only. Do not claim universal controller support.
6. **Protected/private native operation:** invoke only through ESO's own secure binding/callback path. Never call protected functions from a new addon wrapper.

## Known areas requiring in-game validation

The global binding inventory identifies action names, but cannot prove that each scene's keyboard template is operable. The remaining validation matrix must cover inventory/equipment, bank and guild bank, merchant/fence, crafting, map, journal/quest lists, collections, skills/champion, group/guild/mail, dialogs/conversations, loot, death/resurrection, lockpicking, housing editor, antiquities, stores/preview, battleground interfaces and third-party addon windows.

## Research references

- ESO global bindings: https://github.com/esoui/esoui/blob/live/esoui/ingame/globals/bindings.xml
- ESO directional-input implementation: https://github.com/esoui/esoui/blob/live/esoui/libraries/zo_directionalinput/zo_directionalinput.lua
- ADCUI: https://www.esoui.com/downloads/info1433-AdvancedDisableControllerUI.html
- EnhancedGamepadUI: https://github.com/AdeonMaster/EnhancedGamepadUI
- LibMousePointer: https://www.esoui.com/downloads/info4518-LibMousePointer.html
- ESO Gamepad API notes: https://forums.elderscrollsonline.com/en/discussion/222240/orsinium-api-patch-notes-change-log-pts
