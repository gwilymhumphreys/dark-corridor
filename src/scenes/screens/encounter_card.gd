class_name EncounterCard
extends Button
## One encounter offered before a fight (docs/plans/encounter_cards.md), drawn as a playing card
## dealt from a deck: the front shows the encounter's name, its picture, its kind and a hint at what it
## gives; the back is the deck's card back. EncounterChoice places it, deals it and turns it over through
## `travel` and `face_up`; hovering lifts it. A bare Button, so the card's own panels draw it, with
## UIJuice for the press, sound and the highlight on the front. EncounterChoice wires `pressed` to the
## pick. Reads an EncounterDef; writes nothing. Player-facing text is localized.

## The picture for an encounter with no `image` of its own, by kind. Placeholders for the owner.
const DEFAULT_IMAGES: Dictionary = {
  EncounterDef.Type.FIGHT: 'res://assets/encounters/bone_golem.jpg',
  EncounterDef.Type.EVENT: 'res://assets/encounters/hermit.jpg',
  EncounterDef.Type.REST: 'res://assets/encounters/blue_light.jpg',
  EncounterDef.Type.REWARD: 'res://assets/encounters/treasure_box.jpg',
  EncounterDef.Type.SHOP: 'res://assets/encounters/goblin_merchant_b.jpg',
}
## How far a hovered card rises, in pixels, and how much it grows.
const LIFT_RISE: float = 18.0
const LIFT_GROW: float = 0.06
const LIFT_TIME: float = 0.15

## 0 = in the deck, 1 = at its place in the row. EncounterChoice reads it to place the card.
var travel: float = 0.0
## The angle in degrees the card lands at in the row; EncounterChoice turns it in as it travels.
var tilt: float = 0.0
## 0 = face down, 1 = face up. Between the two the card is part way through turning over.
var face_up: float = 0.0:
  set = set_face_up
## 0 = resting, 1 = lifted by the pointer. EncounterChoice straightens the card as it rises.
var lift: float = 0.0:
  set = set_lift
## The card can be picked: it is face up and no card has been picked yet. EncounterChoice sets it.
var pickable: bool = false:
  set = set_pickable

var _lift_tween: Tween

@onready var _lift: Control = $Lift
@onready var _card: Control = $Lift/Card
@onready var _front: Control = $Lift/Card/Front
@onready var _back: Control = $Lift/Card/Back
@onready var _title: Label = $Lift/Card/Front/Rows/Title
@onready var _image: TextureRect = $Lift/Card/Front/Rows/Picture/Image
@onready var _kind_band: ColorRect = $Lift/Card/Front/Rows/KindBand
@onready var _kind: Label = $Lift/Card/Front/Rows/KindBand/Kind
@onready var _hint: Label = $Lift/Card/Front/Rows/Hint


func _ready() -> void:
  _lift.offset_transform_enabled = true
  _card.offset_transform_enabled = true
  disabled = true
  mouse_entered.connect(_on_mouse_entered)
  mouse_exited.connect(_on_mouse_exited)
  set_face_up(face_up)


func setup(def: EncounterDef) -> void:
  _kind_band.color = _kind_color(def)
  _kind.text = _kind_name(def)
  _title.text = tr(def.name_key)
  _hint.text = _hint_text(def)
  _image.texture = load(image_path(def)) as Texture2D


## The picture an encounter's card shows: its own `image`, or its kind's default.
static func image_path(def: EncounterDef) -> String:
  if def.image != '':
    return def.image
  return DEFAULT_IMAGES[def.type]


## Turning over is a squash to no width and back: the back shows for the first half, the front for
## the second.
func set_face_up(value: float) -> void:
  face_up = value
  if not is_node_ready():
    return
  _card.offset_transform_scale = Vector2(absf(cos(PI * value)), 1.0)
  _front.visible = value >= 0.5
  _back.visible = value < 0.5


func set_lift(value: float) -> void:
  lift = value
  if not is_node_ready():
    return
  _lift.offset_transform_position = Vector2(0.0, -LIFT_RISE * value)
  _lift.offset_transform_scale = Vector2.ONE * (1.0 + LIFT_GROW * value)


func set_pickable(value: bool) -> void:
  pickable = value
  disabled = not value
  if not value:
    _lift_to(0.0)
  elif is_hovered():
    _lift_to(1.0)


func _on_mouse_entered() -> void:
  if pickable:
    _lift_to(1.0)


func _on_mouse_exited() -> void:
  _lift_to(0.0)


func _lift_to(value: float) -> void:
  if _lift_tween and _lift_tween.is_valid():
    _lift_tween.kill()
  if not is_inside_tree():
    return
  _lift_tween = create_tween()
  _lift_tween.tween_property(self, 'lift', value, LIFT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _kind_name(def: EncounterDef) -> String:
  match def.type:
    EncounterDef.Type.EVENT:
      return tr('Event')
    EncounterDef.Type.REST:
      return tr('Rest')
    EncounterDef.Type.REWARD:
      return tr('Reward')
    EncounterDef.Type.SHOP:
      return tr('Shop')
  return tr('Fight')


func _hint_text(def: EncounterDef) -> String:
  match def.type:
    EncounterDef.Type.REST:
      return tr('Recover health')
    EncounterDef.Type.REWARD:
      return _reward_hint(def.stock)
    EncounterDef.Type.SHOP:
      return tr('Spend your gold')
  return ''


# What a reward encounter's card promises: the kind of goods when there is only one kind.
func _reward_hint(stock: Array[StockEntry]) -> String:
  var kinds: Array[int] = []
  for entry: StockEntry in stock:
    if not entry.kind in kinds:
      kinds.append(entry.kind)
  if kinds.size() != 1:
    return tr('Choose a reward')
  match kinds[0]:
    StockEntry.Kind.RELIC:
      return tr('Choose a relic')
    StockEntry.Kind.POTION:
      return tr('Choose a potion')
  return tr('Choose an item')


func _kind_color(def: EncounterDef) -> Color:
  match def.type:
    EncounterDef.Type.EVENT:
      return Colours.BEAT_EVENT
    EncounterDef.Type.REST:
      return Colours.BEAT_REST
    EncounterDef.Type.REWARD:
      return Colours.BEAT_RELIC
    EncounterDef.Type.SHOP:
      return Colours.BEAT_SHOP
  return Colours.BEAT_COMBAT
