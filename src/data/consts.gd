class_name Consts
## Shared structural / presentation constants that aren't gameplay tuning (those live in Balance)
## and aren't colours (those live in Colours) — the magic numbers that were floating at use sites
## and are shared across more than one file, gathered so they're consistent and editable in one place.

# The cooldown ring item_icon draws (the combat sandbox's placeholder board view). The framed
# combat view's ItemCell draws a cooldown fill instead (cooldown_fill.gdshader).
const COOLDOWN_RING_SEGMENTS := 48
const COOLDOWN_RING_WIDTH := 5.0

# The black outline stroke on an item panel (item_icon).
const PANEL_BORDER_WIDTH := 3.0

# UI pixel-scale (docs/systems/ui_theme.md). The window is a true high-res 2560x1440 canvas
# (stretch = canvas_items), but the UI is designed to READ as ~360p chunky pixels: a notional
# UI_BASE_RESOLUTION upscaled by UI_SCALE (1440 / 360 = 4) — without a low-res framebuffer, so
# fonts can still render smooth at full resolution. UI_SCALE is the SIZING UNIT (author chrome /
# icons / paddings in multiples of it), not a runtime Control.scale. Rule: at-rest layout lands on
# whole pixels (round computed rest offsets); animations may move sub-pixel (offset_transform is
# visual-only and returns to the integer rest pose).
const UI_BASE_RESOLUTION := Vector2i(640, 360)
const UI_SCALE: int = 4
