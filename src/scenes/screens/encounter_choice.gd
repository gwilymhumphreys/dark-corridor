class_name EncounterChoice
extends Control
## The choice of encounters before a fight (docs/plans/encounter_choice.md): up to three
## EncounterCards standing in the corridor where three enemies would stand, and a Walk past button
## that banks gold. The run screen adds it to the combat view's corridor area and keeps it hidden
## until reveal(), which it calls over the end of the walk up the corridor. A card emits
## `picked(index)` (→ RunManager.pick_path) and the button emits `skipped` (→ RunManager.skip_choice).
## Reads the offered ids; writes nothing.

signal picked(index: int)
signal skipped()

const ENCOUNTER_CARD: PackedScene = preload('res://src/scenes/screens/encounter_card.tscn')
## The share of the gap between two card positions a card may fill. A card wider than that is scaled
## down, as several enemies side by side are.
const CARD_FILL: float = 0.92

@onready var _cards: Control = $Cards
@onready var _skip_button: Button = $SkipButton

# (index, count) -> the global point a card's centre stands on (CombatView.encounter_slot).
var _slot_point: Callable
var _card_list: Array = []   # one EncounterCard per position, null for an empty one
var _revealed: bool = false


func _ready() -> void:
  _skip_button.text = tr('Walk past (+{0} gold)').format([Balance.ENCOUNTER_SKIP_GOLD])
  visible = false


func _exit_tree() -> void:
  _card_list.clear()


## One card per offered id, left to right; '' leaves its position empty. `slot_point` places them.
func setup(ids: Array, slot_point: Callable) -> void:
  _slot_point = slot_point
  for i in ids.size():
    if ids[i] == '':
      _card_list.append(null)
      continue
    var card: EncounterCard = ENCOUNTER_CARD.instantiate()
    _cards.add_child(card)
    card.setup(EncounterCatalog.get_def(ids[i]))
    card.pressed.connect(_on_card_pressed.bind(i))
    _card_list.append(card)
  _place_cards()


## Show the cards and the button, fading them up over `duration` seconds. Only acts the first time,
## so the run screen can call it every frame of the end of the walk.
func reveal(duration: float) -> void:
  if _revealed:
    return
  _revealed = true
  visible = true
  modulate.a = 0.0
  create_tween().tween_property(self, 'modulate:a', 1.0, maxf(duration, 0.01))


func is_revealed() -> bool:
  return _revealed


# The corridor's layout follows the window and the look settings, so the cards follow it each frame.
func _process(_delta: float) -> void:
  _place_cards()


func _place_cards() -> void:
  if not _slot_point.is_valid():
    return
  var count: int = _card_list.size()
  var gap: float = INF
  if count > 1:
    gap = absf((_slot_point.call(1, count) as Vector2).x - (_slot_point.call(0, count) as Vector2).x)
  for i in count:
    var card: EncounterCard = _card_list[i]
    if card == null:
      continue
    var fit: float = minf(1.0, gap * CARD_FILL / maxf(card.size.x, 1.0))
    card.scale = Vector2.ONE * fit   # UIJuice animates the offset transform, so this does not fight it
    card.global_position = _slot_point.call(i, count) - card.size * fit * 0.5


func _on_card_pressed(index: int) -> void:
  picked.emit(index)


func _on_skip_pressed() -> void:
  skipped.emit()
