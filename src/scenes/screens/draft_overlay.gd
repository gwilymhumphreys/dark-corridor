class_name DraftOverlay
extends Control
## The draft overlay (docs/systems/ui_layout.md / docs/systems/draft.md): the 1-of-3 reward offer shown after a
## fight, as `RewardOption` buttons around the same ItemCell icons the board uses, on a panel placed
## in the corridor area of the combat view (the board, potions and portrait stay usable around it).
## Hovering an option shows the item tooltip (the run screen asks inspectable_at each frame) and the
## option's own border; clicking it emits
## `picked(index)` — a draft-pick intent the run screen forwards to RunManager.apply_draft_pick. The
## gold button emits `skipped` instead (bank gold; docs decision #33) → RunManager.apply_draft_skip.
## Reads the candidate defs; writes nothing.

signal picked(index: int)
signal skipped()

const REWARD_OPTION: PackedScene = preload('res://src/scenes/screens/reward_option.tscn')

@onready var _panel: Control = $Panel
@onready var _cards: HBoxContainer = $Panel/Cards
@onready var _skip_button: Button = $Panel/SkipButton

var _options: Array[RewardOption] = []


func _ready() -> void:
  _skip_button.text = tr('+{0} gold').format([Balance.GOLD_SKIP])


func _exit_tree() -> void:
  _options.clear()


## Each candidate is shown as a RewardOption — a button around the same ItemCell the board uses,
## bound to a fresh Item built from the def (no owner), so the icon, value pills and tooltip match
## the board exactly and the option answers the pointer like any other control the player picks.
func setup(candidates: Array) -> void:
  for i in candidates.size():
    var option: RewardOption = REWARD_OPTION.instantiate()
    option.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _cards.add_child(option)
    option.setup(Item.new(candidates[i]))
    option.pressed.connect(_on_option_pressed.bind(i))
    _options.append(option)


## The reward icon under `point` as {item, rect (global), side} for the tooltip cluster, or {}.
func inspectable_at(point: Vector2) -> Dictionary:
  for option: RewardOption in _options:
    if option.get_global_rect().has_point(point):
      return {'item': option.item(), 'rect': option.get_global_rect(), 'side': TooltipCluster.Side.LEFT}
  return {}


## True when `point` is over the reward panel (board items hidden behind it must not show tooltips).
func covers(point: Vector2) -> bool:
  return _panel.get_global_rect().has_point(point)


func _on_option_pressed(index: int) -> void:
  picked.emit(index)


func _on_skip_pressed() -> void:
  skipped.emit()
