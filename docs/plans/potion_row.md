# Plan: potions built like items, on a three-square pencil grid

The owner wants potions and items to look and work the same way, because items may be clicked or
dragged later. The potions also get a one-row pencil grid of three squares, one per potion slot,
matching the item board (`docs/design/game_design.md`: three potion slots).

## Current state

- `potion_slot.tscn` is a `Button` (theme button body) with a `PanelSlot` frame inset inside it and
  the icon beside the frame, on `interface_look_material`, fixed at 96 px, not askew. `UIJuice`
  (ICON preset) gives it the press squash, click sound and hover highlight on the button body.
- An item is an `ItemCell`: a `PanelToken` frame with the icon inside it on
  `interface_framed_material`, sized by the board fit, askew. Board items take no mouse events; the
  tooltip poll sets `ItemCell.hovered`.
- `reward_option.tscn` already shows how a clickable item is built: a `ButtonBare` button wrapping an
  `ItemCell`, with `UIJuice` drawing its highlight on the cell's frame (`highlight_target`).
- The potions sit in `Items/Potions`, an `HBoxContainer` with a fixed height, with no grid.
- The code does not limit the number of potions; the three-slot limit is design only.

## Changes

1. **Potion slot = a button wrapping an item cell**, built like `reward_option.tscn`: `PotionSlot`
   stays a `Button` (so `pressed`, the cursor and the combat view's wiring are unchanged), uses
   `ButtonBare`, and holds an `ItemCell` instance called `Cell`. `UIJuice` keeps the ICON preset with
   `highlight_target` on `Cell/Frame`. The old `Frame` and `Icon` nodes go.
2. **`ItemCell.show_picture(texture)`**: shows an icon with no `Item` (no pills, no cooldown fill, no
   "Temporary" tag). `ItemCell` already treats a null `item` as idle.
3. **Potion row in the scene**: `Items/Potions` becomes `Items/PotionBoard`, a `Control` holding a
   `Grid` `ColorRect` on `PrintLook.grid_material` and the `Potions` `HBoxContainer`, laid out like
   `Items/Board`.
4. **The grid shader reads the rectangle's own pixels** (`VERTEX` passed to `fragment`) instead of
   the `rect_size` uniform, so the board grid and the potion grid share one material. `rect_size` goes
   from the shader, `PRINT_FRAME_UNIFORMS` and `_draw_grid`.
5. **The fit covers both rows.** `board_cell_size` takes `extra_rows` (default 0): the potion row
   counts as one more row of squares. `_fit_board` passes the height left after the labels and spacer,
   sets the potion row's height to one square, its grid to `POTION_SLOTS` (3, or the number of potions
   if more) squares wide, the potion row's gap and position like the board's, and each potion cell to
   the board's cell size. The potion count is part of what `_fitted` compares.
6. **Potions sit askew** with the same `token_tilt` and `token_shift` as the board items.
7. **Board items stay unclickable for now.** When clicking or dragging items is designed, a board item
   is wrapped in a button the same way as a potion; nothing else about the cell changes.

## Tests

- A potion slot's cell uses `PanelToken`, its icon the framed material, and it has no pills.
- The potion grid is three squares wide and one square tall, and the potion cells take the board's
  cell size.
- With a full board, the potion row and the board together fit the items section.
- Existing: the potion throw test, the cursor test, the interface look scene list (the potion icon
  moves to the framed material).

## Docs

`run_screen.md` and `ui_layout.md` (the potion row), `print_frame.md` (the potion grid, the shader
change), `interface_look.md` (the potion icon's material), `ui_theme.md` (`PanelSlot` no longer on
potions), `control_feedback.md` (unchanged driver, highlight now on the cell frame), `build_log.md`.

## Open question for the owner

- More than three potions: the code does not stop it. The grid grows to fit rather than hiding a
  potion. Enforcing the limit (the drop-one choice in the design) is a separate design task.

## Built (2026-09-22)

Built as planned, plus a `--potions N` screenshot hook in `run_screen.gd`. Shots at 12 and 41 items
with two and three potions drew correctly with no errors.
