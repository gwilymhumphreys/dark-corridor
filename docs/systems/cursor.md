# Cursor

The operating system's cursor is hidden and a pointing hand is drawn in its place, on a
`CanvasLayer` above everything else. Because it is drawn rather than handed to the display server,
it is sized in canvas pixels, so it grows and shrinks with the window like the rest of the
interface, and it goes through the same material as the item and status icons, so the
[interface look](interface_look.md)'s effects and the [palette clamp](palette_clamp.md) apply to
it. It also appears in screenshots.

The cost is one frame of lag: a drawn cursor can only be as fresh as the last frame, where the
display server's cursor is moved by the operating system.

**Location:** `Cursor` (`src/scenes/ui/mouse_cursor.tscn`, `src/autoloads/cursor.gd`, class
`CursorAutoload`) and the `mouse_default_cursor_shape` property on each clickable control's scene
node.

## The three hands

| When | Art |
|---|---|
| Anywhere | The 32×32 hand, `assets/ui/cursors/hand_pointer.png`, fingertip at pixel (7, 0) |
| Over anything the player can click | The same hand with an outline round its edge |
| While the left mouse button is held | `assets/ui/cursors/hand_pointer_pressed.png`, the hand with its finger curled, outlined too when over something clickable |

The pressed art uses the same hotspot, which is above the curled finger rather than on it, so the
hand does not jump when the button goes down.

## How it works

- The `Hand` node is a `TextureRect` on a `CanvasLayer` at layer 128, above the debug panel. Its
  size, in canvas pixels on the 2560×1440 canvas, is set in the scene; the hotspot is scaled by
  the ratio between that size and `CursorAutoload.ART_SIZE`. The `canvas_items` stretch mode does
  the rest, so the cursor keeps its size relative to the window.
- `_process` moves the node to `get_viewport().get_mouse_position()` less the scaled hotspot, and
  picks the hand to draw, every frame. The hand is picked every frame because the shape a control
  asks for changes without an event of its own.
- Which hand is drawn comes from `Input.get_current_cursor_shape()`: the pointing-hand shape gets
  the outlined art, every other shape gets the plain art. Clickable controls still say when to
  show it through `mouse_default_cursor_shape`, exactly as they did with a display-server cursor.
  No hover signals.
- The press state comes from `_input`, which runs before the controls see the click, so a button
  that handles the press still gets the curled hand.
- `Cursor.apply()` builds the four textures, one per piece of art and hover state. The body is
  recoloured by brightness onto `CursorAutoload.BODY_COLOURS`, the `Colours` text colours from
  dark to light, blending between the two nearest. The art's shading is kept, its hues become the
  interface's. The text colours are used, not the panel colours, so the hand reads against the
  dark screens.
- The outline is drawn in the `CursorAutoload.OUTLINE_COLOUR` colour on every visible pixel that
  touches a pixel outside the hand, which is the outermost solid ring plus the soft edge around
  it. It is drawn inside the shape, so the hand keeps its size and its hotspot. The outline colour
  is dark because the hand is light; it reads on pale panels as well as on the dark background,
  which a brighter cursor on hover did not.
- Alpha is left alone throughout, so the shape and its soft edge do not change.
- `Colours` is read on every `apply()`, and `DebugPanels.set_interface_palette` calls `apply()`, so
  an interface palette applied at runtime changes the cursor with everything else. That is on top
  of the palette clamp in the material, which is a separate thing, driven by the portrait palette
  choice ([interface_palette.md](interface_palette.md#images)).
- The combat board item cells are hover-only, not clickable, and keep the plain hand. The draft
  overlay sets the shape on its reward cells in code (`draft_overlay.gd`).
- The operating system's cursor is hidden with `Input.mouse_mode`, and given back while the window
  is not focused and before the game closes. A run with no mouse, which covers the headless test
  and autotest runs, is left alone.

## Public API

| Member | Use |
|---|---|
| `Cursor.apply()` | Rebuild the cursor textures on the current `Colours`; safe to call again |
| `CursorAutoload.TEXTURE_PATH`, `PRESSED_TEXTURE_PATH`, `HOTSPOT`, `ART_SIZE` | The two pieces of art, the fingertip hotspot, and the art's width the drawn size is measured against |
| `CursorAutoload.BODY_COLOURS`, `OUTLINE_COLOUR` | The `Colours` variables the hand's brightness is placed on, dark to light, and the one the outline is drawn in |

Tests: `tests/ui/test_cursor.gd`.
