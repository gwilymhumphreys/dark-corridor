class_name CharacterSelect
extends Control
## The character-select screen (#27 / docs/systems/game_manager.md) — one CharacterCard per catalog
## character on an opaque panel. Picking emits `picked(character_id)`; Back emits `cancelled`.
## The title screen raises it from Start Run and routes the pick to Game.start_run(seed, id),
## so each run opens in the chosen character's pool + kit. Reads CharacterCatalog; writes
## nothing. Static text auto-translates from the .tscn; the cards localize via tr().

signal picked(character_id: String)
signal cancelled()

const CHARACTER_CARD: PackedScene = preload('res://src/scenes/screens/character_card.tscn')

@onready var _cards: HBoxContainer = $Panel/Cards
@onready var _back: Button = $Panel/BackButton


func _ready() -> void:
  _back.pressed.connect(_on_back)
  for id in CharacterCatalog.ids():
    var card: CharacterCard = CHARACTER_CARD.instantiate()
    _cards.add_child(card)
    card.setup(CharacterCatalog.get_def(id))
    card.pressed.connect(_on_card_pressed.bind(id))


func _on_card_pressed(id: String) -> void:
  picked.emit(id)


func _on_back() -> void:
  cancelled.emit()
