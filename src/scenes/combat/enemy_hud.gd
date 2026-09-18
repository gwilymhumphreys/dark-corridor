class_name EnemyHud
extends VBoxContainer
## An enemy in the framed combat view, floating above the corridor occupant (docs/systems/ui_layout.md):
## the enemy's name, then a status-icon row + HP bar, then its board items as cells. Structure is
## authored in enemy_hud.tscn; setup() builds the item row and HP reads each frame. The HUD is
## hidden through the approach and fade_in() brings it up when the fight starts. Reads the Actor;
## writes nothing. The VFX wall reads hud_centre / cell_centre.

const ITEM_CELL: PackedScene = preload('res://src/scenes/combat/item_cell.tscn')
const STATUS_ICON: PackedScene = preload('res://src/scenes/combat/status_icon.tscn')

var actor: Actor

@onready var _items: HBoxContainer = $Items
@onready var _statuses: HBoxContainer = $HpRow/Statuses
@onready var _status_numbers: StatusNumbers = $HpRow/StatusNumbers
@onready var _hp_fill: ColorRect = $HpRow/HP/Fill
@onready var _hp_label: Label = $HpRow/HP/Label
@onready var _name: Label = $Name

var _cells: Dictionary = {}   # Item -> ItemCell
var _fade: Tween


const CELL_PX: float = 90.0   # smaller than the player's prominent board
const CELL_SEPARATION: float = 8.0


## `timekeeper` drives the cells' fire recoil on the combat clock; `max_width` (>0)
## budgets the item row — cells shrink so a big loadout fits its share of the panel.
func setup(target: Actor, timekeeper: Timekeeper = null, max_width: float = 0.0) -> void:
  actor = target
  _status_numbers.actor = target
  _name.text = tr(actor.display_name) if actor.display_name != '' else ''
  var cell_px: float = CELL_PX
  if max_width > 0.0 and not actor.board.is_empty():
    var n: float = float(actor.board.size())
    cell_px = minf(CELL_PX, (max_width - CELL_SEPARATION * (n - 1.0)) / n)
  for item in actor.board:
    var cell: ItemCell = ITEM_CELL.instantiate()
    _items.add_child(cell)
    cell.set_cell_size(cell_px)
    cell.setup(item, timekeeper)
    _cells[item] = cell
  _refresh_hp()


func _exit_tree() -> void:
  if _fade != null:
    _fade.kill()
    _fade = null
  _cells.clear()
  _status_numbers.actor = null
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


## Status icons — one StatusIcon (the status's icon on its colour) per active OUTSIDE-set
## status (the mechanic statuses read off the StatusNumbers beside the HP bar). Rebuilt each
## frame since statuses accrue / expire during combat.
func _refresh_statuses() -> void:
  if actor == null:
    return
  var outside: Array[StatusEffect] = []
  for s in actor.statuses:
    if not MechanicRegistry.has(s.id):
      outside.append(s)
  var want: int = outside.size()
  while _statuses.get_child_count() > want:
    # Deferred frees for nodes (CLAUDE.md) — but remove from the tree NOW so the
    # child count this loop reads actually shrinks.
    var status_icon: Node = _statuses.get_child(_statuses.get_child_count() - 1)
    _statuses.remove_child(status_icon)
    status_icon.queue_free()
  while _statuses.get_child_count() < want:
    _statuses.add_child(STATUS_ICON.instantiate())
  for i in want:
    (_statuses.get_child(i) as StatusIcon).show_status(outside[i])


## Show this HUD, fading it up over `duration` seconds — the fight starting (the HUDs are hidden
## through the approach) or a summon appearing mid-fight.
func fade_in(duration: float) -> void:
  if _fade != null:
    _fade.kill()
  visible = true
  modulate.a = 0.0
  _fade = create_tween()
  _fade.tween_property(self, 'modulate:a', 1.0, duration)


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


## The Item whose cell is under `point` (the tooltip hover target), or null. Mirrors mouse_over.
func item_at(point: Vector2) -> Item:
  for item in _cells:
    if (_cells[item] as ItemCell).get_global_rect().has_point(point):
      return item
  return null


## The global rect of `item`'s cell — the tooltip's anchor (re-read each frame; HUDs move).
func cell_rect(item: Item) -> Rect2:
  if _cells.has(item):
    return (_cells[item] as ItemCell).get_global_rect()
  return Rect2()
