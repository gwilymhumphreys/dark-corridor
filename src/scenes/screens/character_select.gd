class_name CharacterSelect
extends Control
## The character-select screen (#27 / docs/systems/game_manager.md) — one CharacterCard per catalog
## character, on the right half of the screen. Hovering a card burns that character's large picture
## in on the left half (`PaperBurn`, backwards), and leaving it burns the picture away. Picking emits
## `picked(character_id)`; Back emits `cancelled`. The title screen turns the page onto it from
## Start and routes the pick to Game.start_run(seed, id),
## so each run opens in the chosen character's pool + kit. Reads CharacterCatalog; writes
## nothing. Static text auto-translates from the .tscn; the cards localize via tr().

signal picked(character_id: String)
signal cancelled()

const CHARACTER_CARD: PackedScene = preload('res://src/scenes/screens/character_card.tscn')

var _pictures_by_id: Dictionary = {}   # character id -> the Control holding its picture
var _burns: Dictionary = {}            # picture Control -> the PaperBurn running on it

@onready var _cards: HBoxContainer = $Page/Cards
@onready var _back: Button = $Page/BackButton
@onready var _pictures: Control = $Pictures
@onready var _picture_template: Control = $Pictures/Picture


func _ready() -> void:
  _back.pressed.connect(_on_back)
  _pictures.remove_child(_picture_template)
  for id in CharacterCatalog.ids():
    var def: CharacterDef = CharacterCatalog.get_def(id)
    var card: CharacterCard = CHARACTER_CARD.instantiate()
    _cards.add_child(card)
    card.setup(def)
    card.pressed.connect(_on_card_pressed.bind(id))
    card.mouse_entered.connect(show_picture.bind(id))
    card.mouse_exited.connect(hide_picture.bind(id))
    _add_picture(id, def)
  _picture_template.queue_free()


## Burn the large picture of character `id` in on the left half.
func show_picture(id: String) -> void:
  _burn(_pictures_by_id[id], true)


## Burn the large picture of character `id` away, if it is shown.
func hide_picture(id: String) -> void:
  var picture: Control = _pictures_by_id[id]
  if picture.modulate.a > 0.0:
    _burn(picture, false)


func _add_picture(id: String, def: CharacterDef) -> void:
  var picture: Control = _picture_template.duplicate()
  _pictures.add_child(picture)
  if def.select_image != '':
    (picture.get_node('Image') as TextureRect).texture = load(def.select_image)
  picture.modulate.a = 0.0
  _pictures_by_id[id] = picture


# A burn already running on the picture is freed first, which leaves the picture shown.
func _burn(picture: Control, backwards: bool) -> void:
  # A finished burn frees itself, so the entry can be a freed object.
  var running: Variant = _burns.get(picture)
  if is_instance_valid(running):
    running.free()
  _burns[picture] = PaperBurn.burn(picture, backwards)


func _on_card_pressed(id: String) -> void:
  picked.emit(id)


func _on_back() -> void:
  cancelled.emit()
