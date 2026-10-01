class_name CharacterPanel
extends PanelContainer
## One character in the framed combat view (docs/systems/run_screen.md): a portrait, and beside it a
## column of the name and health bar, the status icons and the board items, placed by set_layout. The player's panel,
## each ally slot (AllySlot) and each enemy HUD (EnemyHud) are this scene, so they look the same;
## the enemy hides the portrait, and the player's items are on its board instead of the panel.
## The panel's background is drawn only for the panels the `panel_background` print setting names (set_panel_shown). The health bar
## and status row read the actor themselves. Reads the Actor; writes nothing.

const ITEM_CELL: PackedScene = preload('res://src/scenes/combat/item_cell.tscn')
const ITEM_COLUMN: PackedScene = preload('res://src/scenes/combat/item_column.tscn')
const ITEM_ROWS: int = 3   # cells per column in the item grid beside the name and bar

## Where the item cells go (the `item_layout` print setting). BESIDE: a grid ITEM_ROWS tall to the
## right of the name, bar and status column. UNDER: a row under the bar. NAME_ROW: a row on the
## name's line, right-aligned.
enum ItemLayout { BESIDE, UNDER, NAME_ROW }
## Where the status icons go (the `status_layout` print setting). BESIDE_BAR: a grid two tall to the
## right of the name and bar. UNDER_BAR: one row under the bar. UNDER_ITEMS: one row under the item
## row (under the bar when the items are elsewhere).
enum StatusLayout { BESIDE_BAR, UNDER_BAR, UNDER_ITEMS }
## Which character panels draw their background (the `panel_background` print setting).
enum PanelBackground { NONE, PLAYER_AND_ALLIES, ENEMIES, ALL }

var actor: Actor
## Whether the panel shows an item row. The player's panel turns it off: its items are on the board.
@export var show_items: bool = true
## Whether the panel keeps one size through the fight: the status icons keep their full height with no
## statuses, so a status added or removed does not resize the panel. The player's panel turns it on;
## its width is set by the combat view (CombatViewFramed._stack_portraits).
@export var fixed_size: bool = false
## Whether the name line is replaced by "Name:" and "Class:" fields written on underlines, like a
## character sheet (show_sheet_fields). The player's panel turns it on.
@export var sheet_fields: bool = false

@onready var _portrait_frame: PanelContainer = $Row/Portrait
@onready var _portrait: TextureRect = $Row/Portrait/Image
@onready var _readout: VBoxContainer = $Row/Readout
@onready var _name: Label = $Row/Readout/Top/NameBar/NameRow/Name
@onready var _name_row: HBoxContainer = $Row/Readout/Top/NameBar/NameRow
@onready var _fields: GridContainer = $Row/Readout/Fields
@onready var _name_field: Label = $Row/Readout/Fields/NameField/Text
@onready var _class_field: Label = $Row/Readout/Fields/ClassField/Text
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
  _name_row.visible = not sheet_fields
  _fields.visible = sheet_fields
  _items_beside_row.visible = false
  _statuses_under.visible = false
  _statuses.reserve_height = fixed_size
  _statuses_under.reserve_height = fixed_size
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
  _statuses_under.actor = target if _status_layout != StatusLayout.BESIDE_BAR else null
  if _portrait_frame.visible and target.portrait != '':
    _portrait.texture = load(target.portrait)


## The centre of the health bar in global coordinates, where shield lands (the VFX wall reads it).
func health_bar_centre() -> Vector2:
  return _health_bar.bar_centre()


## Where the status `id` has its icon on this panel, or will have it once applied, in global
## coordinates (the VFX wall flies a status application's projectile there).
func status_centre(id: String) -> Vector2:
  var icons: StatusIcons = _statuses if _status_layout == StatusLayout.BESIDE_BAR else _statuses_under
  return icons.slot_centre(id)


## The name above the health bar. The player's panel shows its sheet fields instead (show_sheet_fields).
func show_name(text: String) -> void:
  _name.text = text


## Write the character's name and class in the sheet fields (shown with `sheet_fields`).
func show_sheet_fields(character_name: String, character_class: String) -> void:
  _name_field.text = character_name
  _class_field.text = character_class


## A cell per relic and board item (relics first), each `cell_px` square. `timekeeper` drives the cells' fire recoil on the
## combat clock (null = no recoil). The cells go where the item layout puts them (set_layout).
func build_items(timekeeper: Timekeeper, cell_px: float) -> void:
  _timekeeper = timekeeper
  _cell_px = cell_px
  _items_built = true
  _build_cells()


func _build_cells() -> void:
  var column: Node = null
  var items: Array[Item] = []
  items.append_array(actor.relics)   # an enemy's relics come before its items
  items.append_array(actor.board)
  for i in items.size():
    var row: Node = _items if _item_layout == ItemLayout.UNDER else _items_by_name
    if _item_layout == ItemLayout.BESIDE:
      if i % ITEM_ROWS == 0:
        column = ITEM_COLUMN.instantiate()
        _items_beside_row.add_child(column)
      row = column
    var cell: ItemCell = ITEM_CELL.instantiate()
    row.add_child(cell)
    cell.set_cell_size(_cell_px)
    cell.setup(items[i], _timekeeper)
    cell.show_cooldown = _cooldowns_shown
    _cells[items[i]] = cell


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
  # The one row of icons sits just under the bar, or last in the column, under the item row.
  var under_bar_index: int = _statuses.get_parent().get_index() + 1   # just after Top, which holds the bar
  _readout.move_child(_statuses_under, -1 if status_layout == StatusLayout.UNDER_ITEMS else under_bar_index)
  if _items_built and items_changed:
    for cell: Node in _cells.values():
      cell.get_parent().remove_child(cell)
      cell.queue_free()
    _cells.clear()
    for column: Node in _items_beside_row.get_children():
      _items_beside_row.remove_child(column)
      column.queue_free()
    _build_cells()


## Make the status icons `px` square (the `status_size` print setting).
func set_status_size(px: float) -> void:
  _statuses.set_icon_size(px)
  _statuses_under.set_icon_size(px)


## Resize the item cells already built to `cell_px`, keeping them where they are.
func resize_items(cell_px: float) -> void:
  _cell_px = cell_px
  for cell: ItemCell in _cells.values():
    cell.set_cell_size(cell_px)


## Draw the panel (`PanelTokenWide`) or leave it out (`PanelBare`, which draws nothing), from the
## `panel_background` print setting (`CombatViewFramed._set_token_styles`).
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


## Whether `point` is over an item cell or a status icon (the slow-mo hover surface).
func mouse_over(point: Vector2) -> bool:
  for cell in _cells.values():
    if (cell as ItemCell).get_global_rect().has_point(point):
      return true
  return status_icon_at(point) != null


## The status icon under `point` (the status tooltip's hover target), or null.
func status_icon_at(point: Vector2) -> StatusIcon:
  var icon: StatusIcon = _statuses.icon_at(point)
  return icon if icon != null else _statuses_under.icon_at(point)


## The Item whose cell is under `point` (the tooltip hover target), or null. Mirrors mouse_over.
func item_at(point: Vector2) -> Item:
  for item in _cells:
    if (_cells[item] as ItemCell).get_global_rect().has_point(point):
      return item
  return null


## Burn each shown part of the panel away separately where it stands, with the paper burn
## (docs/systems/paper_burn.md): the portrait, the name, the health bar, each status icon and each item
## cell. The panel itself is see-through, so burning it whole would show a rectangle around the parts.
## The status rows stop refreshing, so they do not rebuild the icons that are burning. Returns the
## burns; the caller frees the panel when they have all finished. An empty array means nothing was
## shown.
func burn_away() -> Array[PaperBurn]:
  mouse_filter = Control.MOUSE_FILTER_IGNORE
  _statuses.set_process(false)
  _statuses_under.set_process(false)
  var parts: Array[Control] = [_portrait_frame, _health_bar]
  parts.append_array(_statuses.icons())
  parts.append_array(_statuses_under.icons())
  for cell: ItemCell in _cells.values():
    parts.append(cell)
  var burns: Array[PaperBurn] = []
  for label: Label in [_name, _name_field, _class_field]:
    if label.is_visible_in_tree() and label.text != '':
      burns.append(PaperBurn.burn(_hold_in_place(label)))
  for part: Control in parts:
    if part.is_visible_in_tree():
      part.mouse_filter = Control.MOUSE_FILTER_IGNORE
      burns.append(PaperBurn.burn(part))
  return burns


# Put `label` inside a plain Control that takes its place in its container, since a Label draws
# itself and the paper burn cannot burn it directly. Returns a Control inside that, covering only
# the text: a label stretched across its row would otherwise spend most of the burn on empty space.
func _hold_in_place(label: Label) -> Control:
  var holder: Control = Control.new()
  holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
  holder.custom_minimum_size = label.size
  holder.size_flags_horizontal = label.size_flags_horizontal
  holder.size_flags_vertical = label.size_flags_vertical
  var parent: Node = label.get_parent()
  parent.add_child(holder)
  parent.move_child(holder, label.get_index())
  var text_width: float = minf(label.get_minimum_size().x, label.size.x)
  var text_x: float = 0.0
  match label.horizontal_alignment:
    HORIZONTAL_ALIGNMENT_CENTER:
      text_x = (label.size.x - text_width) * 0.5
    HORIZONTAL_ALIGNMENT_RIGHT:
      text_x = label.size.x - text_width
  var text_box: Control = Control.new()
  text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
  holder.add_child(text_box)
  text_box.position = Vector2(text_x, 0.0)
  text_box.size = Vector2(text_width, label.size.y)
  var label_size: Vector2 = label.size
  label.reparent(text_box, false)
  label.position = Vector2(-text_x, 0.0)
  label.size = label_size
  return text_box


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
