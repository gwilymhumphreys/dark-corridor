class_name CharacterSelect
extends Control
## The character-select screen (#27 / docs/systems/game_manager.md) — one CharacterCard per catalog
## character, on the right half of the screen. One character is always selected, starting with the
## first; hovering a card or the `ui_left`/`ui_right` actions select (`MenuSelection`). The left half
## holds a pile of photos, one per character's `select_image`, each resting at its own tilt and shift
## (the `photo_*` print settings). Selecting a character slides its photo out of the pile and back in
## on top. Clicking a card or `ui_accept` picks and emits `picked(character_id)`; Back or `ui_cancel`
## emits `cancelled`. The title screen turns the page onto it from Start and routes the pick to
## Game.start_run(seed, id),
## so each run opens in the chosen character's pool + kit. Reads CharacterCatalog; writes
## nothing. Static text auto-translates from the .tscn; the cards localize via tr().

signal picked(character_id: String)
signal cancelled()

const CHARACTER_CARD: PackedScene = preload('res://src/scenes/screens/character_card.tscn')
const CHARACTER_PHOTO: PackedScene = preload('res://src/scenes/screens/character_photo.tscn')
## The sound folder played as a photo slides out of the pile.
const SLIDE_SOUND: String = 'ui/card_deal'

var _ids: Array = []
var _picked: bool = false
var _photos: Array[Control] = []    # one per character, in catalog order
var _slides: Dictionary = {}        # photo -> the Tween sliding it
var _placed: Vector2 = -Vector2.ONE   # the photo tilt and shift last applied

@onready var _cards: HBoxContainer = $Page/Cards
@onready var _back: Button = $Page/BackButton
@onready var _photo_pile: Control = $Photos
@onready var _selection: MenuSelection = $MenuSelection


func _ready() -> void:
  _back.pressed.connect(_on_back)
  _ids = CharacterCatalog.ids()
  var cards: Array[BaseButton] = []
  for id in _ids:
    var def: CharacterDef = CharacterCatalog.get_def(id)
    var card: CharacterCard = CHARACTER_CARD.instantiate()
    _cards.add_child(card)
    card.setup(def)
    card.pressed.connect(_on_card_pressed.bind(id))
    cards.append(card)
    _add_photo(def)
  _place_photos()
  _selection.setup(cards)
  _photo_pile.move_child(_photos[_selection.index], -1)
  _selection.selection_changed.connect(_on_selection_changed)


func _process(_delta: float) -> void:
  _place_photos()


func _unhandled_input(event: InputEvent) -> void:
  if event.is_action_pressed('ui_cancel') and not PageTurn.is_turning():
    get_viewport().set_input_as_handled()
    _on_back()


## Select character `id`, as hovering its card does.
func select_character(id: String) -> void:
  _selection.select(_ids.find(id))


## The selected character's id.
func selected_id() -> String:
  return _ids[_selection.index]


## The photo of character `id`.
func photo(id: String) -> Control:
  return _photos[_ids.find(id)]


func _add_photo(def: CharacterDef) -> void:
  var new_photo: Control = CHARACTER_PHOTO.instantiate()
  if def.select_image != '':
    (new_photo.get_node('Margin/Image') as TextureRect).texture = load(def.select_image)
  _photo_pile.add_child(new_photo)
  new_photo.offset_transform_enabled = true
  _photos.append(new_photo)


# Every photo not sliding is set to its resting tilt and shift, again whenever the settings change.
func _place_photos() -> void:
  var wanted: Vector2 = Vector2(PrintLook.print_setting('photo_tilt'), PrintLook.print_setting('photo_shift'))
  if wanted == _placed:
    return
  _placed = wanted
  for i: int in _photos.size():
    if not _is_sliding(_photos[i]):
      _photos[i].offset_transform_rotation = _rest_rotation(i)
      _photos[i].offset_transform_position = _rest_position(i)


func _rest_rotation(at: int) -> float:
  return deg_to_rad(_askew(at).x * float(PrintLook.print_setting('photo_tilt')))


func _rest_position(at: int) -> Vector2:
  var askew: Vector3 = _askew(at)
  return Vector2(askew.y, askew.z) * float(PrintLook.print_setting('photo_shift'))


# A photo's tilt and shift, each from -1 to 1, fixed by its place in the pile.
static func _askew(at: int) -> Vector3:
  var rng: RandomNumberGenerator = RandomNumberGenerator.new()
  rng.seed = 7919 + at
  return Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))


func _is_sliding(slid: Control) -> bool:
  var tween: Tween = _slides.get(slid)
  return tween != null and tween.is_valid()


# The selected photo slides out towards the outer edge of the page, goes on top of the pile at the far
# point, and slides back to its resting place. A photo no longer selected by the far point slides back
# in where it was.
func _on_selection_changed(at: int) -> void:
  var slid: Control = _photos[at]
  if _is_sliding(slid):
    (_slides[slid] as Tween).kill()
  var half: float = maxf(PrintLook.print_setting('photo_slide_time'), 0.05) * 0.5
  var out: Vector2 = _rest_position(at) + Vector2.LEFT * slid.size.x * float(PrintLook.print_setting('photo_slide_distance'))
  var tween: Tween = slid.create_tween()
  tween.tween_property(slid, 'offset_transform_position', out, half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  tween.tween_callback(_raise.bind(at))
  tween.tween_property(slid, 'offset_transform_position', _rest_position(at), half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
  tween.parallel().tween_property(slid, 'offset_transform_rotation', _rest_rotation(at), half)
  _slides[slid] = tween
  SfxManager.play_sound(SLIDE_SOUND)


func _raise(at: int) -> void:
  if at == _selection.index:
    _photo_pile.move_child(_photos[at], -1)


func _on_card_pressed(id: String) -> void:
  if _picked:
    return
  _picked = true
  picked.emit(id)


func _on_back() -> void:
  cancelled.emit()
