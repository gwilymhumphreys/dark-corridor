class_name EncounterChoice
extends Control
## The choice of encounters before a fight (docs/plans/encounter_choice.md), drawn as up to three
## EncounterCards dealt from a deck over the corridor (docs/plans/encounter_cards.md), and a Walk past
## button that banks gold. The run screen adds it to the combat view's corridor area and keeps it
## hidden until reveal(), which it calls over the end of the walk up the corridor: the deck slides
## down from the top edge, the cards are dealt face down and turn face up. Picking a card or walking
## past sends the cards back to the deck, then emits `picked(index)` (→ RunManager.pick_path) or
## `skipped` (→ RunManager.skip_choice). The deck is decoration only. Reads the offered ids; writes
## nothing.

signal picked(index: int)
signal skipped()

const ENCOUNTER_CARD: PackedScene = preload('res://src/scenes/screens/encounter_card.tscn')
## The space kept between the cards and the corridor area's edges, the deck and the Walk past button.
const MARGIN: float = 24.0
## How much the picked card grows as the others go back to the deck.
const FORWARD_GROW: float = 0.08

@onready var _cards: Control = $Cards
@onready var _deck: Control = $Deck
@onready var _skip_button: Button = $SkipButton

var _card_list: Array = []   # one EncounterCard per position, null for an empty one
var _revealed: bool = false
var _leaving: bool = false   # a card was picked or the player walked past: the cards are going back
var _picked_index: int = -1
# 0 = the deck is above the corridor area's top edge, 1 = its lower part shows.
var _deck_show: float = 0.0
# 0 = the picked card is at its place, 1 = it has grown forward.
var _forward: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
  _skip_button.text = tr('Walk past (+{0} gold)').format([Balance.ENCOUNTER_SKIP_GOLD])
  _skip_button.visible = false
  _rng.randomize()
  visible = false


func _exit_tree() -> void:
  _card_list.clear()


## One card per offered id, left to right; '' leaves its position empty.
func setup(ids: Array) -> void:
  var largest_tilt: float = PrintLook.print_setting('card_tilt')
  for i in ids.size():
    if ids[i] == '':
      _card_list.append(null)
      continue
    var card: EncounterCard = ENCOUNTER_CARD.instantiate()
    _cards.add_child(card)
    card.setup(EncounterCatalog.get_def(ids[i]))
    card.tilt = _rng.randf_range(-largest_tilt, largest_tilt)
    card.visible = false
    card.pressed.connect(_on_card_pressed.bind(i))
    _card_list.append(card)
  _place_cards()


## Deal the cards: the deck slides down, then each card leaves it face down and turns face up once
## all have landed. Only acts the first time, so the run screen can call it every frame of the end of
## the walk.
func reveal() -> void:
  if _revealed:
    return
  _revealed = true
  visible = true
  var deal_time: float = PrintLook.print_setting('card_deal_time')
  var deal_gap: float = PrintLook.print_setting('card_deal_gap')
  var turn_time: float = PrintLook.print_setting('card_turn_time')
  var cards: Array[EncounterCard] = _present_cards()
  var tween: Tween = create_tween().set_parallel(true)
  tween.tween_property(self, '_deck_show', 1.0, deal_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  for k in cards.size():
    var start: float = deal_time + deal_gap * k
    tween.tween_callback(_start_deal.bind(cards[k])).set_delay(start)
    tween.tween_property(cards[k], 'travel', 1.0, deal_time).set_delay(start).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  var turn_start: float = deal_time * 2.0 + deal_gap * maxi(cards.size() - 1, 0)
  for k in cards.size():
    var start: float = turn_start + deal_gap * k
    tween.tween_callback(SfxManager.play_sound.bind('ui/card_turn')).set_delay(start)
    tween.tween_property(cards[k], 'face_up', 1.0, turn_time).set_delay(start)
  var dealt_at: float = turn_start + deal_gap * maxi(cards.size() - 1, 0) + turn_time
  tween.tween_callback(_on_dealt).set_delay(dealt_at)


func is_revealed() -> bool:
  return _revealed


## The global point where card `index` comes to rest in the row, whatever it is doing now.
func rest_point(index: int) -> Vector2:
  return global_position + _rest_centre(index, _fit())


# The corridor area follows the window and the look settings, so the cards and deck follow it each frame.
func _process(_delta: float) -> void:
  _place_cards()


func _place_cards() -> void:
  var fit: float = _fit()
  var card_size: Vector2 = _card_size()
  var deck_centre: Vector2 = Vector2(size.x * 0.5, card_size.y * fit * (_deck_show * PrintLook.print_setting('deck_peek') - 0.5))
  _deck.pivot_offset = card_size * 0.5
  _deck.scale = Vector2.ONE * fit
  _deck.position = deck_centre - card_size * 0.5
  for i in _card_list.size():
    var card: EncounterCard = _card_list[i]
    if card == null:
      continue
    var grow: float = 1.0 + FORWARD_GROW * _forward if i == _picked_index else 1.0
    card.pivot_offset = card_size * 0.5
    card.scale = Vector2.ONE * fit * grow
    card.rotation_degrees = card.tilt * card.travel * (1.0 - card.lift)
    card.position = deck_centre.lerp(_rest_centre(i, fit), card.travel) - card_size * 0.5


# The scale that fits the deck's showing part, the row and the Walk past button into the corridor
# area. Never above 1.
func _fit() -> float:
  var card_size: Vector2 = _card_size()
  var count: int = maxi(_card_list.size(), 1)
  var row_width: float = card_size.x * (count + (count - 1) * PrintLook.print_setting('card_spacing'))
  var fit_width: float = (size.x - 2.0 * MARGIN) / maxf(row_width, 1.0)
  var fit_height: float = (_skip_button.position.y - 2.0 * MARGIN) / maxf(card_size.y * (1.0 + PrintLook.print_setting('deck_peek')), 1.0)
  return clampf(minf(fit_width, fit_height), 0.01, 1.0)


func _rest_centre(index: int, fit: float) -> Vector2:
  var card_size: Vector2 = _card_size() * fit
  var count: int = _card_list.size()
  var step: float = card_size.x * (1.0 + PrintLook.print_setting('card_spacing'))
  var deck_bottom: float = card_size.y * PrintLook.print_setting('deck_peek')
  var x: float = size.x * 0.5 + (index - (count - 1) * 0.5) * step
  return Vector2(x, (deck_bottom + _skip_button.position.y) * 0.5)


func _card_size() -> Vector2:
  return _deck.get_combined_minimum_size()


func _present_cards() -> Array[EncounterCard]:
  var cards: Array[EncounterCard] = []
  for card: EncounterCard in _card_list:
    if card != null:
      cards.append(card)
  return cards


func _start_deal(card: EncounterCard) -> void:
  card.visible = true
  SfxManager.play_sound('ui/card_deal')


func _on_dealt() -> void:
  if _leaving:
    return
  for card: EncounterCard in _present_cards():
    card.pickable = true
  _skip_button.visible = true
  _skip_button.modulate.a = 0.0
  create_tween().tween_property(_skip_button, 'modulate:a', 1.0, PrintLook.print_setting('card_turn_time'))


# Send every card but the picked one (all of them when `keep` is -1) back to the deck, then slide the
# deck away and call `done`.
func _leave(keep: int, done: Callable) -> void:
  _leaving = true
  _picked_index = keep
  _skip_button.disabled = true
  var deal_time: float = PrintLook.print_setting('card_deal_time')
  var turn_time: float = PrintLook.print_setting('card_turn_time')
  var tween: Tween = create_tween().set_parallel(true)
  for i in _card_list.size():
    var card: EncounterCard = _card_list[i]
    if card == null:
      continue
    card.pickable = false
    if i == keep:
      continue
    tween.tween_property(card, 'face_up', 0.0, turn_time * card.face_up)
    tween.tween_property(card, 'travel', 0.0, deal_time).set_delay(turn_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
  tween.tween_callback(SfxManager.play_sound.bind('ui/card_deal')).set_delay(turn_time)
  if keep >= 0:
    tween.tween_property(self, '_forward', 1.0, turn_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  tween.tween_property(self, '_deck_show', 0.0, deal_time).set_delay(turn_time + deal_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
  tween.tween_callback(done).set_delay(turn_time + deal_time * 2.0)


func _on_card_pressed(index: int) -> void:
  if _leaving:
    return
  _leave(index, picked.emit.bind(index))


func _on_skip_pressed() -> void:
  if _leaving:
    return
  _leave(-1, skipped.emit)
