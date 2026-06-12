class_name ChoiceOverlay
extends Control
## The choice-point overlay (docs/systems/encounter.md / docs/systems/ui_layout.md): the 2-3 candidate encounters
## at a fork, as ChoiceCards on an opaque panel. The pick emits `picked(index)` — a
## choice-point intent the run screen forwards to RunManager.pick_path (which creates the
## live Encounter). No skip — a pick always resolves. Reads candidate EncounterDef ids.

signal picked(index: int)

const CHOICE_CARD: PackedScene = preload('res://src/scenes/screens/choice_card.tscn')

@onready var _cards: HBoxContainer = $Panel/Cards


func setup(candidate_ids: Array) -> void:
  for i in candidate_ids.size():
    var card: ChoiceCard = CHOICE_CARD.instantiate()
    _cards.add_child(card)
    card.setup(EncounterCatalog.get_def(candidate_ids[i]))
    card.pressed.connect(_on_card_pressed.bind(i))


func _on_card_pressed(index: int) -> void:
  picked.emit(index)
