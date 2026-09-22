# Board grid

A pencil-drawn grid behind the player's items, and item cells that shrink so the whole board always
fits in the items section.

## Why

The items section holds about 30 cells at full size, and a run ends with about 41 items
(`player-board-stays-uncapped` in memory). The owner chose shrinking over scrolling or moving the
split point (2026-09-22), and asked for the background to look like grid paper drawn in pencil.

## Layout

- In `combat_view_framed.tscn`, `PlayerItems` moves inside a new `Board` Control that takes the rest
  of the items column (`size_flags_vertical = 3`). `Board` holds a `Grid` ColorRect over its whole
  rectangle, drawn first, then `PlayerItems`.
- One grid square per cell: the square's side is the cell size plus the gap. `PlayerItems` sits half
  a gap in from the board's top left, so each line runs through the middle of a gap and each item
  sits inside one square.
- `CombatViewFramed._fit_board()` picks the largest cell size, at most `ItemCell.CELL_SIZE` and at
  least `MIN_CELL_SIZE`, at which every cell fits in the board's width and height. The gap scales with
  the cell. It sets the grid's columns, the gap and every cell's size, and gives the grid shader the
  square size.
- It runs each frame and returns at once unless the board's size or the number of cells changed, so
  it catches added, removed and fading cells and a moved split point. It replaces
  `_fit_item_columns`.
- `ItemCell.set_cell_size` rebuilds the value pills when the cell already holds an item, so a cell
  can be resized after `setup()`.
- A future board size limit only needs `_fit_board()` to fit `max(cell count, slot count)`. The board
  stays uncapped for now.

## The pencil grid

- New `src/shaders/board_grid.gdshader`, uniforms in a `board_grid` group: on, line width, darkness,
  wobble (how far a line drifts from straight, and over what length), pressure (how much the line's
  darkness varies along its length), grain, and squares per cell (finer paper, with every line at
  a cell edge).
- Pencil colour is `Colours.UI_BACKGROUND_WEAR_LIGHT`, drawn at partial alpha, so an interface
  palette recolours it with the rest of the print look.
- `PrintLook` gets a `grid_material`. `print_defaults()` also reads the grid shader, and
  `_print_material()` sends `board_grid_*` uniforms to it, so presets, reset and `--print-set=` work
  with no other change. The Print tab builds its sections from it.
- `rect_size`, `square_size` and `pencil_colour` are set by the view, so they join
  `PRINT_FRAME_UNIFORMS`.

## Tests

- `tests/ui/test_screen_sections.gd`: the columns test moves to the new node path and checks the
  fitted cells fit.
- New test: with enough items to overflow at full size, cells shrink and the grid's used rows fit in
  the board's height; with few items the cells stay at `CELL_SIZE`.
- `tests/ui/test_combat_view.gd`: node path update.

## Docs

`run_screen.md` (the player's board), `ui_layout.md` (the boards), `print_frame.md` (the grid group
and material).

## Review against the code

- Hover, tooltips and VFX read `cell.get_global_rect()` and `cell_centre()`, which use `cell_size`,
  so resized cells need no other change.
- The fire recoil scales the cell about `pivot_offset`, which `set_cell_size` already updates.
- `_fade_out_and_free` keeps a fading cell in the grid until it is freed, so the refit happens once,
  after the fade.
- The HUD and ally slot cells call `set_cell_size` before `setup()`, so the new pill rebuild does
  nothing for them.
