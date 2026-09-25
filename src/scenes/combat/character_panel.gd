class_name CharacterPanel
extends PanelContainer
## One character in the framed combat view (docs/systems/run_screen.md): a portrait, and beside it a
## column of the name and health bar, the status icons and the board items, placed by set_layout. The player's panel,
## each ally slot (AllySlot) and each enemy HUD (EnemyHud) are this scene, so they look the same;
## the enemy hides the portrait, and the player's items are on its board instead of the panel.
## The panel is drawn only with the `portrait_panel` print setting (set_panel_shown). The health bar
## and status row read the actor themselves. Reads the Actor; writes nothing.

const ITEM_CELL: PackedScene = preload('res://src/scenes/combat/item_cell.tscn')
const ITEM_COLUMN: PackedScene = preload('res://src/scenes/combat/item_column.tscn')
const ITEM_ROWS: int = 3   # cells per column in the item grid beside the name and bar

## Where the item cells go (the `item_layout` print setting). BESIDE: a grid ITEM_ROWS tall to the
## right of the name, bar and status column. UNDER: a row under the bar. NAME_ROW: a row on the
## name's line, right-aligned.
enum ItemLayout { BESIDE, UNDER, NAME_ROW }
## Where the status icons go (the `status_layout` print setting). BESIDE_BAR: a grid two tall to the
## right of the name and bar. UNDER_BAR: one row under the bar.
enum StatusLayout { BESIDE_BAR, UNDER_BAR }

var actor: Actor
## Whether the panel shows an item row. The player's panel turns it off: its items are on the board.
@export var show_items: bool = true

@onready var _portrait_frame: PanelContainer = $Row/Portrait
@onready var _portrait: TextureRect = $Row/Portrait/Image
@onready var _readout: VBoxContainer = $Row/Readout
@onready var _name: Label = $Row/Readout/Top/NameBar/NameRow/Name
@onready var _items_by_name: HBoxContainer = $Row/Readout/Top/NameBar/NameRow/ItemsByName
@onready var _health_bar: HealthBar = $Row/Readout/Top/NameBar/HealthBar
@onready var _statuses: StatusIcons = $Row/Readout/Top/Statuses
@onready var _items_beside_row: HBoxContainer = $Row/ItemsBeside
@onready var _statuses_under: StatusIcons = $Row/Readout/StatusesUnder
@onready var _items: HBoxContainer = $Row/Readout/Items

var _cells: Dictionary = {}   # Item -> ItemCell
# The layouts the scene is built in: items under the bar, statuses beside it.
var _item_layout: ItemLayout = ItemLayout.UNDER
var _status_layout: StatusLayout = StatusLayout.BESIDE_BAR
var _items_built: bool = false   # build_items has run, so a layout change rebuilds the cells
var _timekeeper: Timekeeper = null
var _cell_px: float = 0.0
var _cooldowns_shown: bool = false


func _ready() -> void:
  _readout.minimum_size_changed.connect(_fit_portrait)
  _items.visible = show_items
  _items_beside_row.visible = false
  _statuses_under.visible = false
  _fit_portrait()


## The portrait stays square and as tall as the column beside it (name, health bar, status row, and
## the item row when it shows), so it follows the text size and the bar and cell sizes by itself.
func _fit_portrait() -> void:
  if not _portrait_frame.visible:
    return
  var side: float = ceilf(_readout.get_combined_minimum_size().y)
  _portrait_frame.custom_minimum_size = Vector2(side, side)


## Point the health bar and status row at `target`, and show its portrait when the portrait is shown.
func set_actor(target: Actor) -> void:
  actor = target
  _health_bar.actor = target
  _statuses.actor = target if _status_layout == StatusLayout.BESIDE_BAR else null
  _statuses_under.actor = target if _status_layout == StatusLayout.UNDER_BAR else null
  if _portrait_frame.visible and target.portrait != '':
    _portrait.texture = load(target.portrait)


## The name above the health bar. The player's panel keeps the "You" written in its scene.
func show_name(text: String) -> void:
  _name.text = text


## A cell per board item, each `cell_px` square. `timekeeper` drives the cells' fire recoil on the
## combat clock (null = no recoil). The cells go where the item layout puts them (set_layout).
func build_items(timekeeper: Timekeeper, cell_px: float) -> void:
  _timekeeper = timekeeper
  _cell_px = cell_px
  _items_built = true
  _build_cells()


func _build_cells() -> void:
  var column: Node = null
  for i in actor.board.size():
    var row: Node = _items if _item_layout == ItemLayout.UNDER else _items_by_name
    if _item_layout == ItemLayout.BESIDE:
      if i % ITEM_ROWS == 0:
        column = ITEM_COLUMN.instantiate()
        _items_beside_row.add_child(column)
      row = column
    var cell: ItemCell = ITEM_CELL.instantiate()
    row.add_child(cell)
    cell.set_cell_size(_cell_px)
    cell.setup(actor.board[i], _timekeeper)
    cell.show_cooldown = _cooldowns_shown
    _cells[actor.board[i]] = cell


## Place the item cells and the status icons, from the `item_layout` and `status_layout` print
## settings (`CombatViewFramed._set_token_styles`; see ItemLayout and StatusLayout). Every layout is
## built into the scene: this shows the ones in use, points the actor at the status icons in use,
## and rebuilds the item cells in their new place. Cells are rebuilt rather than moved, because an
## ItemCell that leaves the tree loses its item and icon.
func set_layout(item_layout: ItemLayout, status_layout: StatusLayout) -> void:
  if item_layout == _item_layout and status_layout == _status_layout:
    return
  var items_changed: bool = item_layout != _item_layout
  _item_layout = item_layout
  _status_layout = status_layout
  _items.visible = show_items and item_layout == ItemLayout.UNDER
  _items_beside_row.visible = show_items and item_layout == ItemLayout.BESIDE
  _items_by_name.visible = show_items and item_layout == ItemLayout.NAME_ROW
  var beside_bar: bool = status_layout == StatusLayout.BESIDE_BAR
  _statuses.visible = beside_bar
  _statuses_under.visible = not beside_bar
  _statuses.actor = actor if beside_bar else null
  _statuses_under.actor = actor if not beside_bar else null
  if _items_built and items_changed:
    for cell: Node in _cells.values():
      cell.get_parent().remove_child(cell)
      cell.queue_free()
    _cells.clear()
    for column: Node in _items_beside_row.get_children():
      _items_beside_row.remove_child(column)
      column.queue_free()
    _build_cells()


## Draw the panel (`PanelTokenWide`) or leave it out (`PanelBare`, which draws nothing), from the
## `portrait_panel` print setting (`CombatViewFramed._set_token_styles`).
func set_panel_shown(shown: bool) -> void:
  theme_type_variation = &'PanelTokenWide' if shown else &'PanelBare'


## The portrait's frame style: `PanelSlot`, or `PanelToken` when the portraits are cardboard tokens
## (`CombatViewFramed._set_token_styles`).
func set_portrait_style(style: StringName) -> void:
  _portrait_frame.theme_type_variation = style


## Show or hide the cooldown fill on the panel's item cells. Off until the fight starts, so the
## readouts can fade up during the walk without a frozen fill sitting over the icons.
func set_cooldowns_shown(shown: bool) -> void:
  _cooldowns_shown = shown
  for cell in _cells.values():
    (cell as ItemCell).show_cooldown = shown


func portrait_centre() -> Vector2:
  return _portrait_frame.global_position + _portrait_frame.size * 0.5


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


## `item`'s cell, for the hover highlight the tooltip poll drives (docs/systems/control_feedback.md).
func cell_at(item: Item) -> ItemCell:
  return _cells.get(item) as ItemCell


## The global rect of `item`'s cell — the tooltip's anchor (re-read each frame; enemy HUDs move).
func cell_rect(item: Item) -> Rect2:
  if _cells.has(item):
    return (_cells[item] as ItemCell).get_global_rect()
  return Rect2()


func _exit_tree() -> void:
  if _readout.minimum_size_changed.is_connected(_fit_portrait):
    _readout.minimum_size_changed.disconnect(_fit_portrait)
  _portrait.texture = null
  _cells.clear()
  _timekeeper = null
  actor = null
