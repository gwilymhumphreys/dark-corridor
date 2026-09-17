class_name AllySlot
extends HBoxContainer
## A run-scoped ally / combat-scoped summon token in the framed combat view, in one of the
## slots flanking the player (docs/systems/ui_layout.md): a portrait + HP + name, with its board items
## beside it. Structure is authored in ally_slot.tscn; setup() builds the item row and HP
## reads each frame. Reads the Actor; writes nothing. The VFX wall reads slot_centre /
## cell_centre.

const ITEM_CELL: PackedScene = preload('res://src/scenes/combat/item_cell.tscn')
const PORTRAIT_MAX_SIZE: float = 110.0   # the portrait's size when the row is tall enough
const PORTRAIT_MIN_SIZE: float = 40.0

var actor: Actor

@onready var _left: VBoxContainer = $Left
@onready var _portrait_frame: Control = $Left/Portrait
@onready var _portrait: TextureRect = $Left/Portrait/Image
@onready var _hp: Control = $Left/HP
@onready var _hp_fill: ColorRect = $Left/HP/Fill
@onready var _hp_label: Label = $Left/HP/Label
@onready var _status_numbers: StatusNumbers = $Left/HP/StatusNumbers
@onready var _name: Label = $Left/Name
@onready var _items: HBoxContainer = $Items

var _cells: Dictionary = {}   # Item -> ItemCell


## `timekeeper` drives the cells' fire recoil on the combat clock (null = no recoil).
func setup(target: Actor, timekeeper: Timekeeper = null) -> void:
  actor = target
  _status_numbers.actor = target
  _name.text = tr(actor.display_name) if actor.display_name != '' else tr('Ally')
  if actor.portrait != '':
    _portrait.texture = load(actor.portrait)
  for item in actor.board:
    var cell: ItemCell = ITEM_CELL.instantiate()
    _items.add_child(cell)
    cell.set_cell_size(76.0)   # compact — these slots flank the player
    cell.setup(item, timekeeper)
    _cells[item] = cell
  _refresh_hp()


## Shrink the portrait, keeping it square, so the portrait, HP bar and name fit in `height`. It never
## grows past its size in the scene.
func fit_height(height: float) -> void:
  var gap: float = _left.get_theme_constant('separation')
  var side: float = floorf(height - _hp.custom_minimum_size.y - _name.get_combined_minimum_size().y - gap * 2.0)
  side = clampf(side, PORTRAIT_MIN_SIZE, PORTRAIT_MAX_SIZE)
  _portrait_frame.custom_minimum_size = Vector2(side, side)


## Show or hide the cooldown fill on this slot's item cells (hidden once the fight is over).
func set_cooldowns_shown(shown: bool) -> void:
  for cell in _cells.values():
    (cell as ItemCell).show_cooldown = shown


func _exit_tree() -> void:
  _portrait.texture = null
  _cells.clear()
  _status_numbers.actor = null
  actor = null


func _process(_delta: float) -> void:
  _refresh_hp()
  # A downed (dead) run-scoped ally keeps its slot but reads as out — dim the whole slot.
  # Colours.ALLY_DOWNED darkens with alpha 1, not transparency.
  modulate = Colours.ALLY_DOWNED if (actor != null and not actor.is_alive()) else Color.WHITE


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


## The Item whose cell is under `point` (the tooltip hover target), or null. Mirrors mouse_over.
func item_at(point: Vector2) -> Item:
  for item in _cells:
    if (_cells[item] as ItemCell).get_global_rect().has_point(point):
      return item
  return null


## The global rect of `item`'s cell — the tooltip's anchor.
func cell_rect(item: Item) -> Rect2:
  if _cells.has(item):
    return (_cells[item] as ItemCell).get_global_rect()
  return Rect2()
