# Plan: items and portraits as cardboard tokens

The owner wants the items on the board to look like cardboard tokens lying on the pencil grid, and
is unsure whether the player portrait, or the portrait with its name and HP bar, should share the
look. This builds the look as Print tab settings so the options can be compared in screenshots.

## Current state

- Item cells, potion slots, portraits and keyword chip icons all use the `PanelSlot` frame: a
  `WornStyleBox` wrapping a `PaletteStyleBox` filled with `UI_BACKGROUND`, 6 px margins, no border
  and no shadow. The fill is close to the paper colour, so items read as icons, not objects.
- The player portrait, name and HP bar sit bare on the paper in `Portraits/PlayerPortrait`
  (an `HBoxContainer`). `_fit_portraits` sizes the portrait to the section's full height.

## Changes

1. **Theme.** Add `PanelToken` (6 px margins, for item cells and portraits) and `PanelTokenWide`
   (16 px margins, for the portrait panel), each a `WornStyleBox` wrapping its own
   `PaletteStyleBox` on `UI_BACKGROUND`. Add `PanelBare` (the existing empty style) for the portrait
   panel when it is off.
2. **Settings** in `PrintLook.PRINT_SETTING_DEFAULTS`, shown in the Print tab's Layout group:
   - `token_shadow_size`: the shadow's blur in pixels.
   - `token_shadow_offset`: how far the shadow falls down and to the right, in pixels.
   - `token_shadow_darkness`: the shadow's opacity.
   - `token_portraits` (bool): the player and ally portraits use `PanelToken` instead of `PanelSlot`.
   - `portrait_panel` (bool): the player portrait, name and HP bar sit in one `PanelTokenWide` panel.
3. **`PrintLook.apply_token_style()`** writes the shadow settings onto the two token styles'
   wrapped boxes, then calls `emit_changed()` on each wrapper so controls redraw. Called from
   `_ready`, `set_print_value`, `reset_print_look`, `read_print_look` and `push_wear_colours` (the shadow
   colour comes from `Colours`, which changes with the interface palette). The Print tab's Layout
   rows call `set_print_value` instead of writing `print_settings` directly.
4. **Panel wear shader.** The shadow is drawn outside the panel's rectangle. Apply wear and the
   control highlight only inside `panel_rect`, so the shadow stays a plain shadow.
5. **Item cells.** `item_cell.tscn` `Frame` uses `PanelToken`, so items are tokens everywhere (the
   boards, enemy items, draft rewards). The askew transform on the cell moves the shadow with it.
6. **Portraits and panel.** Insert a `PanelContainer` called `PlayerPanel` between `Portraits` and
   `PlayerPortrait`. `CombatViewFramed` switches its `theme_type_variation` between `PanelBare` and
   `PanelTokenWide` from `portrait_panel`, and switches the player portrait's and each ally
   portrait's between `PanelSlot` and `PanelToken` from `token_portraits`, only when a setting
   changed (like `_set_items_askew`). `_fit_portraits` subtracts the panel's vertical margins from the
   portrait size. The character select card portraits are left on `PanelSlot`.
7. **Paths.** Update the `@onready` paths in `combat_view_framed.gd` and the node paths in
   `tests/debug/test_interface_look.gd` and `tests/ui/test_screen_sections.gd`.

## Tests

- `apply_token_style` writes the shadow onto both token styles, and the styles have no border.
- With `portrait_panel` on, the panel uses `PanelTokenWide` and the portrait still fits the section.
- With `token_portraits` on, the player portrait uses `PanelToken`.

## Screenshot comparison

Shots at `--board-items 12` and `--board-items 41` of: the current look (for reference), items as
tokens, items and portraits as tokens, and items as tokens with the portrait panel. Captions describe,
not rank.

## Docs

`panel_wear.md` (shadow outside the rectangle), `print_frame.md` (the token settings),
`ui_theme.md` (the new styles), `ui_layout.md` or `run_screen.md` (the portrait panel),
`build_log.md`.

## Review against the code

- `Theme` re-emits its own `changed` when a stylebox it holds emits `changed`, which reaches every
  control using the theme. `WornStyleBox` does not forward its `base`'s signal, hence step 3's
  explicit `emit_changed()` on the wrapper.
- `StyleBoxFlat` keeps explicit content margins, so a shadow does not change a cell's layout.
- `InterfacePalette` recolours a `PaletteStyleBox`'s `bg_color` only, so it leaves the shadow colour
  alone; `apply_token_style` sets that from `Colours` after a palette change.
- `--print-set=` already goes through `set_print_value`, and `str_to_var('true')` gives a bool,
  which the Layout group shows as a check box.

## Built (2026-09-22)

- A light border setting was built first. The owner said the borders did not look good and asked to
  keep the worn edge from the panel wear shader, so the border settings were removed.
- Changing the portrait panel's style left the portrait row at the panel's old size until
  `_portraits_part.queue_sort()` was added.
- `WornStyleBox` kept a panel's drawing at its old size when the panel was resized and drawn again in
  the same frame. `PrintLook.panel_wear_child` now also clears when the rectangle changes.

## Token fill and Tokens tab (2026-09-22)

The owner asked for a card-coloured fill as an option to try in the debug panel, and for the token
settings to have their own tab. `token_fill_colour` and `token_fill_amount` blend the `PanelToken` and
`PanelTokenWide` fill from `Colours.UI_BACKGROUND` towards the card colour in `apply_token_style()`.
That runs after an interface palette sets the fill, so the blend survives palette changes. The amount
defaults to 0. All token settings moved from the Print tab's Layout group to a new Tokens tab (F7,
`TokensPanel`); they stay print frame settings, so presets save them with the Print part.
