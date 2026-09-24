class_name AllySlot
extends CharacterPanel
## A run-scoped ally / combat-scoped summon token in the framed combat view, in one of the
## slots flanking the player (docs/systems/ui_layout.md): a CharacterPanel (portrait, and beside it
## its name, HP bar, status row and board items) at a smaller size. setup() builds the item row.
## Reads the Actor; writes nothing. The VFX wall reads slot_centre / cell_centre.

const PORTRAIT_MAX_SIZE: float = 110.0   # the portrait's size when the row is tall enough
const PORTRAIT_MIN_SIZE: float = 40.0
const CELL_PX: float = 76.0              # compact — these slots flank the player
const CELL_MIN_PX: float = 24.0
const CELL_SEPARATION: float = 10.0      # the Items separation in character_panel.tscn
const ITEMS_WIDTH: float = 240.0         # the item row's budget under the HP bar; cells shrink to fit


## `timekeeper` drives the cells' fire recoil on the combat clock (null = no recoil).
func setup(target: Actor, timekeeper: Timekeeper = null) -> void:
  set_actor(target)
  show_name(tr(target.display_name) if target.display_name != '' else tr('Ally'))
  # The row sits under the HP bar, so the cells shrink to fit its width rather than widening the slot.
  var cell_px: float = CELL_PX
  if not target.board.is_empty():
    var n: float = float(target.board.size())
    cell_px = clampf((ITEMS_WIDTH - CELL_SEPARATION * (n - 1.0)) / n, CELL_MIN_PX, CELL_PX)
  build_items(timekeeper, cell_px)


## Shrink the portrait, keeping it square, so it fits in `height` less the panel's margins. It never
## grows past its size in the scene.
func fit_height(height: float) -> void:
  var room: float = height - get_theme_stylebox('panel').get_minimum_size().y
  var side: float = clampf(floorf(room), PORTRAIT_MIN_SIZE, PORTRAIT_MAX_SIZE)
  _portrait_frame.custom_minimum_size = Vector2(side, side)


func _process(_delta: float) -> void:
  # A downed (dead) run-scoped ally keeps its slot but reads as out — dim the whole slot.
  # Colours.ALLY_DOWNED darkens with alpha 1, not transparency.
  modulate = Colours.ALLY_DOWNED if (actor != null and not actor.is_alive()) else Color.WHITE


func slot_centre() -> Vector2:
  return global_position + size * 0.5
