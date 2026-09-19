# Cursor

The stone pointer replaces the operating system's default mouse cursor. The same 32×32
stone-pointer art (`assets/ui/cursors/stone_pointer.png`, its point is the top-left pixel)
is shown everywhere, and a copy whose visible pixels are brightened slightly
(`CursorAutoload.HOVER_LIGHTEN`) is shown over anything the player can click, so hovering is
visible.

**Location:** `Cursor` (`src/autoloads/cursor.gd`, class `CursorAutoload`) and the
`mouse_default_cursor_shape` property on each clickable control's scene node.

## How it works

- `Cursor.apply()` builds both textures from the stone pointer art — the plain one and the
  brightened one, alpha left alone so the shape and its soft edge do not change — and
  registers them with `Input.set_custom_mouse_cursor()`: the plain pointer for the arrow shape
  and the brightened one for the pointing-hand shape, both with a (0, 0) hotspot.
- Godot switches the two on hover. A control shows the brightened pointer while the mouse is
  over it only when its `mouse_default_cursor_shape` is the pointing hand, so every clickable
  control sets that shape on its scene node. No hover signals or per-frame code.
- The combat board item cells are hover-only, not clickable, and keep the plain pointer. The
  draft overlay sets the shape on its reward cells in code
  (`draft_overlay.gd`).
- `apply()` is a no-op when the display server lacks
  `FEATURE_CUSTOM_CURSOR_SHAPE`, which covers the headless test and autotest runs.
- On exit the autoload unregisters both cursors and drops its references
  (`_exit_tree()`). The display server holds a reference to whatever was registered, so
  without this the two textures are freed after the rendering server has shut down and are
  reported as leaked at exit.

## Public API

| Member | Use |
|---|---|
| `Cursor.apply()` | Build both cursor textures and hand them to the display server; safe to call again |
| `CursorAutoload.TEXTURE_PATH`, `HOTSPOT`, `HOVER_LIGHTEN` | The cursor art, its (0, 0) hotspot, and how far the hover copy is moved towards white |

Tests: `tests/ui/test_cursor.gd`.
