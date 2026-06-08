class_name EnemyHud
extends VBoxContainer
## An enemy in the framed combat view, floating over the corridor occupant (ui_layout_prd):
## its board items as cells (top), a status-icon row + HP bar, and the enemy's name (bottom).
## Structure is authored in enemy_hud.tscn; setup() builds the item row and HP reads each
## frame. Reads the Actor; writes nothing. The VFX wall reads hud_centre / cell_centre.

const ITEM_CELL: PackedScene = preload('res://src/scenes/combat/item_cell.tscn')

var actor: Actor

@onready var _items: HBoxContainer = $Items
@onready var _statuses: HBoxContainer = $HpRow/Statuses
@onready var _hp_fill: ColorRect = $HpRow/HP/Fill
@onready var _hp_label: Label = $HpRow/HP/Label
@onready var _name: Label = $Name

var _cells: Dictionary = {}   # Item -> ItemCell


func setup(target: Actor) -> void:
  actor = target
  _name.text = tr(actor.display_name) if actor.display_name != '' else ''
  for item in actor.board:
    var cell: ItemCell = ITEM_CELL.instantiate()
    _items.add_child(cell)
    cell.setup(item)
    _cells[item] = cell
  _refresh_hp()


func _exit_tree() -> void:
  _cells.clear()
  actor = null


func _process(_delta: float) -> void:
  _refresh_hp()
  _refresh_statuses()


func _refresh_hp() -> void:
  if actor == null:
    return
  var ratio: float = clampf(actor.hp / actor.max_hp, 0.0, 1.0)
  _hp_fill.anchor_right = ratio
  _hp_fill.offset_right = 0.0
  _hp_label.text = '%d / %d' % [int(round(actor.hp)), int(round(actor.max_hp))]


## Status icons — one swatch per active actor-targeted status (placeholder colour; real icons
## are content). Rebuilt each frame since statuses accrue / expire during combat.
func _refresh_statuses() -> void:
  if actor == null:
    return
  var want: int = actor.statuses.size()
  while _statuses.get_child_count() > want:
    _statuses.get_child(_statuses.get_child_count() - 1).free()
  while _statuses.get_child_count() < want:
    var swatch := ColorRect.new()
    swatch.custom_minimum_size = Vector2(28, 28)
    _statuses.add_child(swatch)
  for i in want:
    (_statuses.get_child(i) as ColorRect).color = _status_color(actor.statuses[i])


func _status_color(status) -> Color:
  match status.type:
    StatusDef.Type.BLOCK:
      return Color(0.55, 0.7, 0.95)
    StatusDef.Type.POISON:
      return Color(0.5, 0.8, 0.35)
    _:
      return Color(0.85, 0.55, 0.4)


func hud_centre() -> Vector2:
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
