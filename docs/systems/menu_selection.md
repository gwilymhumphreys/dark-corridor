# Menu selection

`MenuSelection` gives a row or column of buttons keyboard and controller input. One button is always
selected and shows the selected border ([control_feedback.md](control_feedback.md)). The title
screen's menu and character select use it.

**Location:** `src/ui/menu_selection.gd`, added as a node in each screen's scene.

## How it works

- The screen hands it its buttons in order with `setup()`, which selects the first one, or the one
  given.
- Hovering a button selects it. Leaving a button keeps it selected, so the last button the mouse was
  over stays selected.
- Godot's built-in `ui_up` and `ui_down` move the selection along a column, and `ui_left` and
  `ui_right` along a row (`vertical`). Moving stops at the ends, skips disabled buttons and plays the
  shared hover sound. Held keys repeat.
- `ui_accept` emits the selected button's `pressed`, so the button acts and its `UIJuice` plays the
  click sound and the release pulse as for a click.
- The actions are read in `_unhandled_input`. Godot's default `ui_*` actions already include the arrow
  keys, Enter, Space and Escape, and a controller's direction pad, left stick and face buttons, so
  `Keybinds` has no entries for them ([keybindings.md](keybindings.md)).
- Keys are ignored while a page turn is captured or plays (`PageTurn.is_turning()`,
  [page_turn.md](page_turn.md)), because the page turn's click blocker stops only the mouse.
- A screen covered by another switches its selection off with `set_process_unhandled_input(false)`.
  The title screen does this while character select or settings is open.

`ui_cancel` is not part of it; a screen that goes back on cancel reads it itself, as character select
does.

## Public API

| Member | Use |
|---|---|
| `setup(buttons, start := 0)` | Take the buttons in order and select the one at `start` |
| `select(at)` | Select a button; ignored for a disabled one or the one already selected |
| `selected()`, `index` | The selected button and its position |
| `vertical` | A column (up and down) or a row (left and right) |
| `selection_changed(index)` | Emitted when the selection moves |

Tests: `tests/ui/test_menu_selection.gd`, and the selection cases in
`tests/ui/test_character_select.gd`.
