# Plan: key bindings and a tabbed settings screen

**Status:** built (2026-10-02). Decision #63. The as-built description is in [keybindings.md](../systems/keybindings.md).

## What the owner decided (2026-10-02)

- The settings screen gets tabs, and one of them is a Controls tab where the player can change which key does what.
- Key bindings use Godot's input map (Project Settings → Input Map), and the player's changes are saved.
- The first actions on the Controls tab are slower and Faster battle speed, on `[` and `]` by default.
- The speed keys stop at the slowest and fastest speeds. They do not wrap around like the speed button does.
- The speed keys work outside a fight too. There they change the setting, which the next fight then uses; nothing else happens.

This is the start of all key bindings in the game, so the plan sets rules that later actions follow.

## Rules for every action

- Game code checks actions (`event.is_action_pressed('battle_speed_up')`), never key codes. Dev-only keys in `src/debug/` are the exception and stay hard-coded.
- Game keys are read in `_unhandled_input`, so a focused control, an open menu or the key capture on the Controls tab gets the key first.
- Default keys are set by key position (`physical_keycode`), not by the character on the key. `[` and `]` need AltGr on many European keyboards, so a binding by character would not work there. The interface shows the character printed on the player's own keyboard for that position.
- Every action the player can change is listed once in `Keybinds.ACTIONS` (below). An action that is not listed there cannot be changed and is not shown.
- Godot's built-in `ui_*` actions are not listed. Menus use them to move focus and go back.

## Actions

New actions in `project.godot`:

| Action | Default main key | Default spare key |
|--------|------------------|-------------------|
| `battle_speed_down` | `[` | none |
| `battle_speed_up` | `]` | none |

`toggle_pause` (Space) already exists and is added to the Controls tab. `move_forward` and `move_back` are only used by the corridor testbed and stay off it.

## `Keybinds` (new, `src/ui/keybinds.gd`)

A static class (`class_name Keybinds`, not an autoload). It holds the action list and turns stored bindings into input map events. `Prefs` keeps the stored data, as it does for every other setting.

**The action list:**

```gdscript
const ACTIONS: Array[Dictionary] = [
  {'action': 'battle_speed_down', 'group': 'run'},
  {'action': 'battle_speed_up', 'group': 'run'},
  {'action': 'toggle_pause', 'group': 'run'},
]
```

The order is the order on the Controls tab. A **group** is a set of actions that are active at the same time; two actions in the same group cannot share a key. All three are in one group now, because the run screen handles all three. The action's shown name is not stored here, because the text extractor only finds literals inside `tr()`; `KeybindRow.action_name()` has a `match` with one `tr('...')` per action.

**Slots:** each action has two slots, a main key (slot 0) and a spare key (slot 1). Either can be empty.

**A stored binding** is a small dictionary, not a Godot `InputEvent` object, so the prefs file stays readable:

- `{'kind': 'key', 'physical_keycode': 91}` for a key.
- `{}` for an empty slot.

Only keys can be bound now. The `kind` field lets mouse buttons or controller buttons be added later without changing existing data.

**Functions:**

- `slots(action: String) -> Array[Dictionary]`: the two slots, from `Prefs` if the player changed this action, otherwise from the project default (`ProjectSettings.get_setting('input/' + action)`). The Controls tab reads slots from here, not from `InputMap`, because the input map does not keep track of which slot an event came from.
- `apply(action: String)`: clears the action's events in `InputMap` and adds one `InputEventKey` per non-empty slot.
- `apply_all()`: `apply` for every listed action. `Prefs` calls it at start-up, after loading.
- `bind(action: String, slot: int, physical_keycode: int) -> String`: puts the key in the slot. If another action in the same group has that key, that slot is emptied. Stores both actions through `Prefs`, applies both, and returns the action that lost the key (empty if none), so the Controls tab can say so. Refuses a reserved key and returns without change.
- `clear(action: String, slot: int)`: empties the slot.
- `reset_all()`: removes every stored change and applies the defaults.
- `is_reserved(physical_keycode: int) -> bool`: Escape and F1 to F12. Escape goes back in menus and pauses a run; the F keys open the debug panels in dev builds.
- `key_label(action: String) -> String`: the main slot's key as printed on the player's keyboard (`DisplayServer.keyboard_get_keycode_from_physical`, then `OS.get_keycode_string`), or empty. For hints such as a tooltip on the speed button later.

If the same key ends up in both slots of one action, the second is dropped.

## `Prefs`

A new `input` section in the existing prefs file. One key per action the player changed, holding its two slots. Actions the player never changed have no entry, so a new action or a changed default in a later version reaches them with no extra work.

- `keybind_slots(action: String) -> Variant`: the stored slots, or null if not changed.
- `set_keybind_slots(action: String, slots: Array)` and `clear_keybinds()`: store and save, like the other setters.
- `_ready` calls `Keybinds.apply_all()` after `load_prefs()`.

Unknown actions and badly formed entries in the file are ignored, and that action uses its default.

## Battle speed keys

**`Game.step_battle_speed(direction: int, wrap_around: bool = true)`.** With `wrap_around` false the index is clamped to the ends of `Balance.BATTLE_SPEEDS` instead of wrapping. The speed button keeps wrapping; only the keys pass false.

**`RunScreen._unhandled_input`** handles `battle_speed_down` and `battle_speed_up` while a run is live and not paused, beside the existing `toggle_pause` handling. Held keys do not repeat (`is_action_pressed` ignores echo by default). Outside a fight the dial changes and the speed button's label updates; `_on_battle_speed_changed` already does nothing when there is no fight, and the next fight takes the dial on entry. The pause menu and the settings screen pause the run, so the keys do nothing behind them.

## Debug panel keys

`DebugPanels._input` uses `[` and `]` to cycle palettes and marks the key handled, so the game would never see them in a dev build. The palette and dithering keys (`[` `]` `;` `'` `,` `.` `\` Backspace) will only work while a debug panel is open. Opening a panel pauses the run, so they no longer overlap with game keys. The F keys are unchanged.

## Settings screen tabs

`settings_screen.tscn`: the single `Scroll` is replaced by a `TabContainer` with three tabs, each its own `ScrollContainer` so the largest text size still fits:

| Tab | Contents |
|-----|----------|
| Audio | the four volume sliders, mute when unfocused |
| Display | fullscreen, text size |
| Controls | the key bindings |

- Tab styles (selected, unselected, hovered, panel, font colours) go in `dark_corridor.tres`, made from the existing panel and button styleboxes. The tab text size follows the text ladder; check during building whether `TextSize.apply` needs to write the `TabContainer` font size or whether a type variation is enough.
- Tab titles must be translated. Check whether `TabBar` translates node-name titles on its own in our Godot version; if not, set them with `set_tab_title(i, tr('Audio'))` and so on.
- The tab last shown is not remembered.

## Controls tab

- A header row (Action, Main key, Spare key) and one row per listed action, instanced from a new `keybind_row.tscn` (a name label and two binding buttons, with the UI juice node).
- A binding button shows the key's printed label, or a dash when empty.
- Clicking it puts that button into capture: it shows "Press a key", and the next key press is taken in the button's `_input` and marked handled so nothing else reacts to it. Escape cancels. A reserved key leaves capture on and shows "That key is kept for the game". A mouse click anywhere cancels. Only one button captures at a time.
- Right-clicking a binding button empties that slot, as right-clicking the speed button steps the other way.
- After a bind that took a key from another action, a message line under the rows says "Removed from {action}".
- A Reset keys button at the bottom of the tab calls `Keybinds.reset_all()` and refreshes the rows.
- Changes apply at once; there is no Apply button.

Group headings are left out while there is only one group.

## Tests

`tests/ui/test_keybinds.gd`, with `Prefs.disabled` set by `TestCleanup`:

- Defaults match `project.godot`, and `apply_all` puts them in `InputMap`.
- `bind` stores, applies, and a key taken from another action in the group empties that action's slot and returns that action.
- A reserved key is refused.
- `clear` and `reset_all`.
- An empty main slot with a filled spare slot keeps its positions.
- Unknown actions and badly formed entries in the stored data are ignored.

`tests/run/test_game_manager.gd`: `step_battle_speed(1, false)` stops at the fastest speed and `(-1, false)` at the slowest.

`TestCleanup.reset_all_managers` calls `Prefs.clear_keybinds()` in memory and `InputMap.load_from_project_settings()`, so a test that rebinds a key does not affect later tests.

## Docs

- New `docs/systems/keybindings.md` (the rules for every action, `Keybinds`, storage, the Controls tab), added to `docs/index.md`.
- `run_screen.md`: the Settings paragraph describes the tabs.
- `ui_layout.md`: the input layer points to `keybindings.md`.
- `debug_panel.md`: the palette keys only work while a panel is open.
- `audio.md` (its Prefs section): the `input` section.
- `decision_log.md`: a new decision for the owner's points above.
- Run `tools/pot.sh` for the new strings.

## Building order

1. Actions in `project.godot`, `Keybinds`, `Prefs` storage, `TestCleanup`, tests.
2. `Game.step_battle_speed` wrap_around flag, the run screen keys, the debug panel key change.
3. Tabs on the settings screen and the theme styles.
4. The Controls tab.
5. Docs and translation strings.
