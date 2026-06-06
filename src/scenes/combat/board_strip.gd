class_name BoardStrip
extends VBoxContainer
## One actor's board in the framed combat view (ui_layout_prd): an HP bar (fill +
## text) above a row of ItemCells. Structure is authored in board_strip.tscn; setup()
## builds the row from the live board and the strip reads HP each frame. Reads the
## actor; writes nothing.

const ITEM_CELL: PackedScene = preload('res://src/scenes/combat/item_cell.tscn')

var actor: Actor

@onready var _hp_fill: ColorRect = $HP/Fill
@onready var _hp_label: Label = $HP/Label
@onready var _row: HBoxContainer = $Row

var _cells: Dictionary = {}   # Item -> ItemCell


func setup(target: Actor) -> void:
  actor = target
  for item in actor.board:
    var cell: ItemCell = ITEM_CELL.instantiate()
    _row.add_child(cell)
    cell.setup(item)
    _cells[item] = cell
  _refresh_hp()


func _exit_tree() -> void:
  # CLAUDE.md runtime cleanup: drop the Item->cell map + the live-actor ref on free.
  _cells.clear()
  actor = null


func _process(_delta: float) -> void:
  _refresh_hp()


func _refresh_hp() -> void:
  if actor == null:
    return
  var ratio: float = clampf(actor.hp / actor.max_hp, 0.0, 1.0)
  _hp_fill.anchor_right = ratio
  _hp_fill.offset_right = 0.0
  _hp_label.text = '%d / %d' % [int(round(actor.hp)), int(round(actor.max_hp))]


## Centre of `item`'s cell in global (screen) space, or Vector2.INF if not on this
## board — the VFX wall reads it.
func cell_centre(item: Item) -> Vector2:
  if _cells.has(item):
    return (_cells[item] as ItemCell).cell_centre()
  return Vector2.INF


func mouse_over(point: Vector2) -> bool:
  for cell in _cells.values():
    if (cell as ItemCell).get_global_rect().has_point(point):
      return true
  return false
