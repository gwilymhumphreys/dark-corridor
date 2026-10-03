# Plan: a selected character on character select

Character select always has one character selected. The selected character's large picture fills the
left page. Changing the selection burns the current picture away, which shows the newly selected
character's picture underneath it. The mouse, the keyboard and a controller all change the selection
the same way.

**Location:** `src/scenes/screens/character_select.gd` + `.tscn`, `src/autoloads/page_turn.gd`.

## Selection

- The screen holds the selected character's index. It opens with the first character in
  `CharacterCatalog.ids()` selected, its picture already whole, so the page turn shows it.
- The selected card shows the selected border through `ControlFeedback.set_selected`, the same call
  as the map's current square. Hover keeps its own border, so the two can differ for a moment while
  a key moves the selection away from the card under the mouse.
- **Mouse.** Hovering a card selects it. Leaving a card changes nothing, so the last hovered character
  stays selected. Clicking a card picks it.
- **Keyboard and controller.** Godot's built-in `ui_left` and `ui_right` move the selection, without
  wrapping at the ends. `ui_accept` picks the selected character and `ui_cancel` is Back. These actions
  already include the arrow keys, Enter, Escape, the controller's direction pad and left stick, and its
  bottom and right face buttons, so `Keybinds` does not change ([keybindings.md](../systems/keybindings.md)
  already leaves menu movement to the `ui_*` actions). They are read in `_unhandled_input`.
- A key selection plays the shared hover sound (`SfxManager.play_ui_hover()`), as a mouse hover does.
- A pick is taken once. Keys are ignored while a page turn plays. This needs a small public
  `PageTurn.is_turning()`, because the page turn's click blocker stops only the mouse.

## Pictures

The left page holds a stack of picture layers. The bottom layer is always the selected character.
Every layer above it is burning away.

- When the selection changes, a new layer for the new character goes in at the bottom of the stack,
  and the layer that was the selected one starts burning away (`PaperBurn.burn`, forwards). A layer
  frees itself when its burn finishes.
- Moving quickly across the cards therefore stacks several burns at once, each on its own layer, and
  they finish one after another. Selecting a character whose picture is still burning on top works the
  same way: it gets a new layer at the bottom.
- Each layer is a copy of the scene's picture template, as now: a plain Control holding the picture
  through the portrait material, with `PortraitBreath`.

The backwards burn added to `PaperBurn` for the current version is no longer used. It is removed,
with its test, unless it is kept for something else (question 3).

## Tests

`tests/ui/test_character_select.gd`, replacing the hover tests:

- The first character is selected on open, with one layer showing its picture.
- Hovering another card selects it: two layers, the old one burning, the new one at the bottom.
- `ui_right` and `ui_left` move the selection and stop at the ends.
- `ui_accept` emits `picked` with the selected id once; `ui_cancel` emits `cancelled`.
- A finished burn leaves one layer.

## Docs

`run_screen.md` (character select), `paper_burn.md` (Uses; drop Backwards if removed),
`page_turn.md` (`is_turning`), `dev_tools.md` (`--hover=ID` becomes "selects character ID").

## Questions

1. Should leaving a card with the mouse keep the selection, as planned, or go back to the character
   selected before the hover?
2. The title screen's menu takes no keyboard or controller input yet, so a controller cannot reach
   character select. Should the title menu get the same treatment in this change, or later?
3. Should the backwards burn be removed, or kept as an F7 choice so the two looks can be compared?
