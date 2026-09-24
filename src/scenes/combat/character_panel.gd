class_name CharacterPanel
extends PanelContainer
## One character in the framed combat view (docs/systems/run_screen.md): a portrait, and beside it a
## column of the name, the health bar, the status-icon row and the board items. The player's panel,
## each ally slot (AllySlot) and each enemy HUD (EnemyHud) are this scene, so they look the same;
## the enemy hides the portrait, and the player's items are on its board instead of the panel.
## The panel is drawn only with the `portrait_panel` print setting (set_panel_shown). The health bar
## and status row read the actor themselves. Reads the Actor; writes nothing.

const ITEM_CELL: PackedScene = preload('res://src/scenes/combat/item_cell.tscn')

var actor: Actor

@onready var _portrait_frame: PanelContainer = $Row/Portrait
@onready var _portrait: TextureRect = $Row/Portrait/Image
@onready var _name: Label = $Row/Readout/Name
@onready var _health_bar: HealthBar = $Row/Readout/HealthBar
@onready var _statuses: StatusIcons = $Row/Readout/Statuses
@onready var _items: HBoxContainer = $Row/Readout/Items

var _cells: Dictionary = {}   # Item -> ItemCell


## Point the health bar and status row at `target`, and show its portrait when the portrait is shown.
func set_actor(target: Actor) -> void:
  actor = target
  _health_bar.actor = target
  _statuses.actor = target
  if _portrait_frame.visible and target.portrait != '':
    _portrait.texture = load(target.portrait)


## The name above the health bar. The player's panel keeps the "You" written in its scene.
func show_name(text: String) -> void:
  _name.text = text


## A cell per board item in the panel's item row, each `cell_px` square. `timekeeper` drives the
## cells' fire recoil on the combat clock (null = no recoil).
func build_items(timekeeper: Timekeeper, cell_px: float) -> void:
  for item in actor.board:
    var cell: ItemCell = ITEM_CELL.instantiate()
    _items.add_child(cell)
    cell.set_cell_size(cell_px)
    cell.setup(item, timekeeper)
    _cells[item] = cell


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
  _portrait.texture = null
  _cells.clear()
  actor = null
