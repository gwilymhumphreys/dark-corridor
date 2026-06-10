class_name Consts
## Shared structural / presentation constants that aren't gameplay tuning (those live in Balance)
## and aren't colours (those live in Colours) — the magic numbers that were floating at use sites
## and are shared across more than one file, gathered so they're consistent and editable in one place.

# Cooldown-ring overlay, drawn identically by item_icon and item_cell (the radius offset differs
# per host, but the arc resolution + stroke width are shared).
const COOLDOWN_RING_SEGMENTS := 48
const COOLDOWN_RING_WIDTH := 5.0

# The black outline stroke on an item panel / cell (item_icon + item_cell).
const PANEL_BORDER_WIDTH := 3.0
