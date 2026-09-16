class_name DraftOverlay
extends Control
## The draft overlay (docs/systems/ui_layout.md / docs/systems/draft.md): the 1-of-3 reward offer shown after a
## fight, as the same ItemCell icons the board uses, on a panel placed in the corridor area of the
## combat view (the board, potions and portrait stay usable around it). Hovering an icon shows the
## item tooltip (the run screen asks inspectable_at each frame). Clicking an icon emits
## `picked(index)` — a draft-pick intent the run screen forwards to RunManager.apply_draft_pick. The
## gold button emits `skipped` instead (bank gold; docs decision #33) → RunManager.apply_draft_skip.
## Reads the candidate defs; writes nothing.

signal picked(index: int)
signal skipped()

const ITEM_CELL: PackedScene = preload('res://src/scenes/combat/item_cell.tscn')

@onready var _panel: Control = $Panel
@onready var _cards: HBoxContainer = $Panel/Cards
@onready var _skip_button: Button = $Panel/SkipButton

var _cells: Array[ItemCell] = []


func _ready() -> void:
  _skip_button.text = tr('+{0} gold').format([Balance.GOLD_SKIP])


func _exit_tree() -> void:
  _cells.clear()


## Each candidate is shown as an ItemCell bound to a fresh Item built from its def (no owner), so the
## icon, value pills and tooltip match the board exactly.
func setup(candidates: Array) -> void:
  for i in candidates.size():
    var cell: ItemCell = ITEM_CELL.instantiate()
    cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _cards.add_child(cell)
    var item := Item.new(candidates[i])
    item.cooldown.accum = item.cooldown.threshold   # shown charged, so no cooldown fill covers the icon
    cell.setup(item)
    cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    cell.gui_input.connect(_on_cell_input.bind(i))
    var juice := UIJuice.new()
    juice.preset = UIJuice.Preset.ICON
    cell.add_child(juice)
    _cells.append(cell)


## The reward icon under `point` as {item, rect (global), side} for the tooltip cluster, or {}.
func inspectable_at(point: Vector2) -> Dictionary:
  for cell: ItemCell in _cells:
    if cell.get_global_rect().has_point(point):
      return {'item': cell.item, 'rect': cell.get_global_rect(), 'side': TooltipCluster.Side.LEFT}
  return {}


## True when `point` is over the reward panel (board items hidden behind it must not show tooltips).
func covers(point: Vector2) -> bool:
  return _panel.get_global_rect().has_point(point)


func _on_cell_input(event: InputEvent, index: int) -> void:
  var click := event as InputEventMouseButton
  if click != null and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
    picked.emit(index)


func _on_skip_pressed() -> void:
  skipped.emit()
