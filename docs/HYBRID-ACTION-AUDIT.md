# HUI Hybrid UI — action and input-routing audit

**Status:** source audit in progress; not release-ready. This document separates what the current code/source establishes from what still requires live controller testing. A scene receiving a pointer fragment is not proof that every action in that scene works.

## Design contract

- ESO's Controls setting must remain **Gamepad Mode: On** (not Auto).
- HUI may change UI presentation, but it must not synthesize gameplay input, call protected/private actions, automate interactions, or alter movement/combat.
- Native gamepad bindings remain responsible for gameplay. HUI's pointer is a UI-navigation aid only.
- Pure Gamepad mode must restore ESO's native presentation and leave native input routing alone.
- Loading/pregame, Crown Store/market, Scrying and Tribute must remain outside HUI's modifications.

## Findings from the uploaded diagnostic capture

The capture was complete (90 seconds, 151 samples).

- Hybrid active, explicit Gamepad Mode On, native preferred-mode query true, HUI effective query false.
- No preferred-mode hook conflict or restricted-scene state was recorded.
- LibMousePointer initialized and its cursor moved in Scribing, Retrait, Interact and Smithing samples.
- Scribing and Notifications produced POINTER_PRIMARY_CONFLICT; HUI removed the library's automatic UI_SHORTCUT_PRIMARY click descriptor to avoid colliding with the screen's native primary action. This preserves the native keybind but leaves pointer-click support absent on those screens.
- World Map had two GuiRoot directional-input owners in addition to LibMousePointer, and its cursor coordinates remained at the bottom-left edge for the captured samples. This is a strong lead for an input-priority conflict, not proof of its exact cause.
- Universal Deconstruction and Store only had one sample each during scene transitions. The pointer fragment was attached, but the cursor was not visible/registered in those samples. The capture does not distinguish a fragment that had not reached SHOWN from one already entering HIDING, so those samples are insufficient to call either screen broken.
- The log's original directionalHookInstalled=false exposed a definite code bug: HUI tried to hook ZO_IngameSceneManager, but ESO declares that class as a local, not a global. HUI now hooks the live SCENE_MANAGER instance's UpdateDirectionalInput method.
- The pointer refresh gate also now checks explicit Gamepad Mode: On, rather than the native preferred-mode query, so changing to Auto cannot leave HUI-owned pointer fragments attached in other scenes.
- Restricted scene detection now matches scrying and tribute tokens with scene suffixes, while keeping scribing distinct.

## Action-family compatibility matrix

| ESO action family | Native source path | HUI responsibility | Current assessment |
|---|---|---|---|
| Movement: move, turn, jump, roll dodge, sprint, crouch, mount | Native movement bindings | Do not intercept or synthesize | Must remain native; no HUI gameplay adapter |
| Combat: light/heavy attack, block, interrupt, skills, ultimate, weapon swap, synergy | Native combat/action-bar bindings | Do not intercept or synthesize | Must remain native; HUD glyph/layout audit still open |
| Companion commands and companion hotbar | Native companion/action bindings | Do not synthesize commands | Native path retained; not live-verified |
| Siege controls | Siege binding layer | Do not intercept | Native path retained; not live-verified |
| Targeting and target-marker wheel | Targeting bindings and Interactive Wheel Manager | Do not invoke wheel actions programmatically | Native path retained; not live-verified |
| Camera zoom/free-look/first-person | Camera bindings | Do not intercept | Native path retained |
| Game-camera interaction / fishing wheel | GAME_CAMERA_INTERACT, Interactive Wheel Manager | Preserve native Down/Up lifecycle | Native path retained; wheel presentation needs testing |
| Player-to-player interaction (trade/duel/emote wheel entry) | PLAYER_TO_PLAYER_INTERACT, PLAYER_TO_PLAYER | Preserve native Down/Up lifecycle | Native path retained; wheel presentation needs testing |
| Quickslot / utility wheel | ACTION_BUTTON_9, UI_SHORTCUT_QUICK_SLOTS, Interactive Wheel Manager | Preserve native binding and hold/release semantics | No HUI-specific wheel adapter yet |
| Main menu toggles: inventory, character, skills, champion, journal, collections, map, group, contacts, guilds, Alliance War, mail, notifications, Activity Finder, help | GamepadUIMode allowlist and menu bindings | Keep keyboard scenes navigable without replacing menu actions | Native toggles exist; each destination screen still needs testing |
| UI shortcuts: primary/secondary/tertiary/quaternary/quinary/negative/help/exit and directional shortcuts | UI shortcut binding layer + keybind strip | Ensure selected descriptor and actual callback agree with gamepad input | Known primary-key collision; full dispatch audit open |
| Inventory actions: use, equip, destroy, split, move, bank, trade | Screen keybind descriptors and protected ESO functions | Never directly call protected functions from pointer callbacks | High-risk; pointer click must not be treated as a secure native click |
| Dialogs, notifications, confirmations | ZO_Dialogs and screen keybind descriptors | Preserve native callbacks and safe focus/selection | Notifications primary conflict observed; no generic click adapter |
| Map, map-floor switching, quest pins, map panning | Keyboard map scene + directional input + map-specific handlers | Route sticks without leaking into player movement | World Map cursor stationary in capture; input-owner investigation open |
| Crafting, research, deconstruction, Scribing, stores, banks, guild stores | Scene-specific controllers and controls | Pointer plus native keyboard-scene navigation | Partial samples only; not verified end-to-end |
| Loot, resurrection/death, player interaction prompts | Reticle/HUD/prompt systems and screen-specific keybinds | Correct glyphs and native action dispatch | Dedicated adapters and live tests remain open |
| Lockpicking | Native lockpick scene selection | Restore native gamepad preference before ESO chooses lockpick scene | Explicit exception exists; needs live validation |
| Housing editor, radial menus, furniture placement | Housing-specific mode and interaction systems | Preserve native mode transitions; no automated placement | Not audited end-to-end |
| Chat/text entry | Native chat bindings | Do not send messages; only allow user typing and manual send | Native path retained |
| Crown Store/market, Scrying, Tribute | ESOUI restrictions | No HUI mode/prompt/pointer changes | Restricted scene guard exists; variants are now matched by token |
| Loading, character select, pregame | ESOUI restrictions and player activation lifecycle | No HUI UI changes | In-world active-state guard exists; transition test required |

## Important architectural risks

### 1. Presentation preference is a global query

HUI wraps IsInGamepadPreferredMode() while active in Hybrid. That query is consulted by more than menu scene selection: platform-style controls, keybind-strip presentation, HUD elements and some feature-specific scene selection can also depend on it. A global false result can therefore create mixed layouts or force a keyboard path for a scene that only has a gamepad implementation. This needs a scene-family audit; do not solve it by blindly firing ESO's internal mode-changed event.

### 2. Prompt selection is not proof of action dispatch

Prompts.lua wraps ZO_Keybindings_ShouldUseGamepadAction, ZO_Keybindings_GetPreferredKeyType and ZO_Keybindings_ShouldShowGamepadKeybind. Those wrappers influence prompt/key type selection. They do not prove that every keyboard scene's selected keybind descriptor has a working callback for the gamepad UI shortcut action. Each screen's actual KEYBIND_STRIP descriptor and callback must be audited.

### 3. Pointer click is not equivalent to trusted hardware input

LibMousePointer's InvokeClick obtains a control and directly calls its OnClicked, OnMouseDown or OnMouseUp handler. Those callbacks may eventually invoke protected ESO functions. An addon-originated callback can therefore fail with the insecure/protected-function error previously observed for inventory destruction. HUI must not claim universal click compatibility or attempt to bypass ESO's secure-action restrictions. Use native gamepad keybind callbacks where available; treat unsupported protected clicks as a hard limitation, not something to work around with fake input.

### 4. Directional-input ownership is ordered and exclusive

ESO's gamepad API requires controls to register through DIRECTIONAL_INPUT so multiple UI systems do not consume the same stick. LibMousePointer consumes the left stick through GetXY(ZO_DI_LEFT_STICK). ESO's in-game scene manager consumes both sticks in its default UI-mode handler. HUI hooks the SCENE_MANAGER instance. The original availability check was order-dependent: if the scene manager's directional-input callback ran before LibMousePointer, the left stick was still available and ESO consumed both sticks before the pointer got its turn. HUI now checks that LibMousePointer is registered, skips only the stock consume-both-sticks callback, and consumes the right stick itself. LibMousePointer's own GetXY call claims the left stick, including zero-magnitude frames; if the pointer is not registered, ESO's original handler remains in control. It must never allow a stick to leak into player movement.

### 5. Pointer fragment attachment does not prove fragment activation

The diagnostic capture now records the current scene state, whether the scene is showing, whether the pointer fragment is showing, the actual scene-manager directional method, and more detailed directional-input owner identities. These fields are needed to distinguish an attached-but-not-shown fragment from an input owner that is active but losing priority.

### 6. Platform-style refresh is incomplete

HUI does not yet have a verified, supported way to refresh every already-created ZO_PlatformStyle control after its preferred-mode query changes. HUD_MANAGER:PropagateSettings() is not a universal platform-style refresh. Action-bar, ultimate, reticle, death, boss-bar, compass and prompt visuals require individual source review and live checks.

## ESOUI / ZOS safety boundary

ESOUI's published addon guidance prohibits changing the UI at loading/pregame and in Crown Store/market, Scrying and Tribute; it also prohibits addons from moving/jumping/crouching/swimming/blocking, casting skills, pressing movement/combat keybinds, starting interactions automatically, or automating gameplay. HUI must remain a presentation/input-routing addon and must not cross those boundaries. When a controller action is a native gameplay action, ESO's own binding must handle it.

## Verification required before calling an action supported

For each scene/action, verify all of the following with a physical controller in the live client:

1. Scene opens from the expected native menu action.
2. Correct keyboard-style scene is selected (or native gamepad fallback if no keyboard scene exists).
3. Left stick moves the pointer or navigates the control without moving the character.
4. D-pad and right stick behave as expected and never leak to camera/player movement.
5. Native UI shortcut invokes the correct callback exactly once.
6. Pointer click works only for safe controls; protected actions remain on native secure paths.
7. Back/exit, overlays, confirmation dialogs and scene-stack restoration work.
8. Prompt glyphs match the actual controller action.
9. No Lua error, stuck directional owner, orphaned fragment or stale keybind descriptor remains after closing/reopening.
10. Pure Gamepad mode restores native behaviour; loading and restricted screens remain untouched.

A screen is not verified merely because it appeared in the diagnostic capture. HUI should only be described as fully compatible after this checklist has been exercised across the screen families above.

## Primary source references

- ESO live keybinding definitions: https://github.com/esoui/esoui/blob/live/esoui/ingame/globals/bindings.xml
- ESO live in-game scene manager: https://github.com/esoui/esoui/blob/live/esoui/ingame/scenes/ingamescenemanager.lua
- ESO directional-input API: https://github.com/esoui/esoui/blob/live/esoui/libraries/zo_directionalinput/zo_directionalinput.lua
- LibMousePointer by Votan: https://www.esoui.com/downloads/info4518-libmousepointer.html
- ESOUI addon rules: https://www.esoui.com/forums/showthread.php?t=9865
- ESO gamepad API notes on directional-input ownership: https://forums.elderscrollsonline.com/en/discussion/222240/orsinium-api-patch-notes-change-log-pts
