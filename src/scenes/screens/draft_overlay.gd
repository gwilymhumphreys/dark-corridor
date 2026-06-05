class_name DraftOverlay
extends Control
## The draft overlay (ui_layout_prd / draft_prd): the 1-of-3 reward offer shown after a
## fight, as DraftCards on an opaque panel. The pick emits `picked(index)` — a draft-pick
## intent the run screen forwards to RunManager.apply_draft_pick. No skip (a pick always
## resolves). Reads the candidate defs; writes nothing.

signal picked(index: int)

const DRAFT_CARD: PackedScene = preload('res://src/scenes/screens/draft_card.tscn')

@onready var _cards: HBoxContainer = $Panel/Cards


func setup(candidates: Array) -> void:
  for i in candidates.size():
    var card: DraftCard = DRAFT_CARD.instantiate()
    _cards.add_child(card)
    card.setup(candidates[i])
    card.pressed.connect(_on_card_pressed.bind(i))


func _on_card_pressed(index: int) -> void:
  picked.emit(index)
