# Key bindings

The keys the player can change, how they are stored, and the Controls tab of the settings screen. Every game key in the game goes through this system.

**Location:** `src/ui/keybinds.gd` (`Keybinds`), `src/autoloads/prefs.gd` (storage), `src/scenes/screens/keybind_row.tscn` and `settings_screen.tscn` (the Controls tab). Plan: [plans/keybindings.md](../plans/keybindings.md).

## Rules for every action

- Game code checks actions (`event.is_action_pressed('battle_speed_up')`), never key codes. Dev-only keys in `src/debug/` are the exception.
- Game keys are read in `_unhandled_input`, so a focused control, an open menu or a key capture on the Controls tab gets the key first.
- Default keys are set in `project.godot` by key position (`physical_keycode`), not by character, so they sit in the same place on every keyboard layout. The interface shows the character printed on the player's own keyboard.
- An action the player can change is listed in `Keybinds.ACTIONS`, with a shown name in `KeybindRow.action_name()` (a `tr()` literal, so the text extractor finds it). Actions not listed cannot be changed.
- Godot's built-in `ui_*` actions are not listed; menus read them to move the selection, accept and go back ([menu_selection.md](menu_selection.md)).
- Escape and F1 to F12 cannot be bound (`Keybinds.is_reserved`). Escape goes back and pauses; the F keys open the [debug panels](debug_panel.md) in dev builds.

## Actions

| Action | Default | Handled by |
|--------|---------|------------|
| `battle_speed_down` | `[` | `RunScreen`: one notch slower, stopping at the slowest |
| `battle_speed_up` | `]` | `RunScreen`: one notch faster, stopping at the fastest |
| `toggle_pause` | Space | `RunScreen`: pause without the menu ([run_screen.md](run_screen.md)) |

The speed keys work whenever a run is live and not paused. Between fights they change the dial and the speed button, and the next fight starts at that speed. The speed button itself still wraps around (`Game.step_battle_speed(direction, wrap_around)`).

## Slots and groups

- Each action has two slots: a main key (0) and a spare key (1). Either can be empty.
- A **group** is a set of actions that are active at the same time. Binding a key that another action in the same group holds empties that action's slot. All current actions are in the `run` group.
- The same key never sits in both slots of one action.

## Storage

`Prefs` holds the bindings in the `input` section of the prefs file: one entry per action the player changed, holding its two slots. Actions the player never changed have no entry and use the `project.godot` default, so a new action or a changed default reaches them with no extra work.

A stored slot is a small dictionary: `{'kind': 'key', 'physical_keycode': 91}`, or `{}` for an empty slot. Only keys can be bound now; the `kind` field leaves room for mouse or controller buttons. Unknown actions and badly formed entries are ignored.

`Prefs._ready` calls `Keybinds.apply_all()`, which writes each listed action's slots into `InputMap`. Read slots through `Keybinds.slots()`, not `InputMap`, which does not keep track of which slot an event came from.

## Controls tab

One `KeybindRow` per listed action: the action's name and a button per slot.

- Clicking a button waits for the next key press and binds it. Escape or a mouse click cancels. Only one row waits at a time.
- Right-clicking a button empties that slot.
- A message under the rows names an action that lost its key to a new binding, or says a key is kept for the game.
- Reset keys puts every action back on its default.
- Changes apply at once.

## API

| `Keybinds` | |
|------------|---|
| `slots(action)` | The two slots, stored or default. |
| `bind(action, slot, physical_keycode)` | Binds the key; returns the action that lost it, or `''`. Refuses reserved keys. |
| `clear(action, slot)` | Empties a slot. |
| `reset_all()` | Removes every change and applies the defaults. |
| `apply_all()` | Writes every listed action into `InputMap`. |
| `key_label(action)` / `slot_label(slot)` | The key as printed on the player's keyboard, for hints. |

`TestCleanup.reset_all_managers()` clears the stored bindings in memory and reloads `InputMap` from the project, so a test that rebinds a key does not affect later tests.
