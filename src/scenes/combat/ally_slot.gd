class_name AllySlot
extends HBoxContainer
## A run-scoped ally / combat-scoped summon token in the framed combat view, in one of the
## slots flanking the player (ui_layout_prd): a portrait + HP + name, with its board items
## beside it. Structure is authored in ally_slot.tscn; setup() builds the item row and HP
## reads each frame. Reads the Actor; writes nothing. The VFX wall reads slot_centre /
## cell_centre.

const ITEM_CELL: PackedScene = preload('res://src/scenes/combat/item_cell.tscn')
const DOWNED_TINT := Color(0.45, 0.45, 0.45)   # darken a downed (dead) ally — alpha 1, not transparency

var actor: Actor

@onready var _hp_fill: ColorRect = $Left/HP/Fill
@onready var _hp_label: Label = $Left/HP/Label
@onready var _name: Label = $Left/Name
@onready var _items: HBoxContainer = $Items

var _cells: Dictionary = {}   # Item -> ItemCell


func setup(target: Actor) -> void:
  actor = target
  _name.text = tr(actor.display_name) if actor.display_name != '' else tr('Ally')
  for item in actor.board:
    var cell: ItemCell = ITEM_CELL.instantiate()
    _items.add_child(cell)
    cell.set_cell_size(76.0)   # compact — these slots flank the player
    cell.setup(item)
    _cells[item] = cell
  _refresh_hp()


func _exit_tree() -> void:
  _cells.clear()
  actor = null


func _process(_delta: float) -> void:
  _refresh_hp()
  # A downed (dead) run-scoped ally keeps its slot but reads as out — dim the whole slot.
  modulate = DOWNED_TINT if (actor != null and not actor.is_alive()) else Color.WHITE


func _refresh_hp() -> void:
  if actor == null:
    return
  var ratio: float = clampf(actor.hp / actor.max_hp, 0.0, 1.0)
  _hp_fill.anchor_right = ratio
  _hp_fill.offset_right = 0.0
  _hp_label.text = '%d / %d' % [int(round(actor.hp)), int(round(actor.max_hp))]


func slot_centre() -> Vector2:
  return global_position + size * 0.5


func cell_centre(item: Item) -> Vector2:
  if _cells.has(item):
    return (_cells[item] as ItemCell).cell_centre()
  return Vector2.INF


func mouse_over(point: Vector2) -> bool:
  for cell in _cells.values():
    if (cell as ItemCell).get_global_rect().has_point(point):
      return true
  return false
