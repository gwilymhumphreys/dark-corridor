class_name EncounterChoice
extends Control
## The choice of encounters before a fight (docs/plans/encounter_choice.md), drawn as up to three
## EncounterCards dealt from a deck over the corridor (docs/plans/encounter_cards.md), and a Walk past
## button that banks gold. The run screen adds it to the combat view's corridor area and keeps it
## hidden until reveal(), which it calls over the end of the walk up the corridor: the deck slides
## down from the top edge, the cards are dealt face down and turn face up. Picking a card sends the
## others back to the deck, slides the deck away and moves the picked card up to where the deck was,
## then emits `picked(index)` (→ RunManager.pick_path); the picked card stays there while the
## encounter is shown, until the run screen tears down the view this sits in. Walking past sends every
## card back and the deck away, then emits `skipped` (→ RunManager.skip_choice). The deck is
## decoration only. Reads the offered ids; writes nothing.

signal picked(index: int)
signal skipped()
## The cards are face up and can be picked.
signal dealt()

const ENCOUNTER_CARD: PackedScene = preload('res://src/scenes/screens/encounter_card.tscn')
## The space kept between the cards and the corridor area's edges, the deck and the Walk past button.
const MARGIN: float = 24.0

@onready var _cards: Control = $Cards
@onready var _deck: Control = $Deck
@onready var _skip_button: Button = $SkipButton

var _card_list: Array = []   # one EncounterCard per position, null for an empty one
var _revealed: bool = false
var _leaving: bool = false   # a card was picked or the player walked past: the cards are going back
var _picked_index: int = -1
# 0 = the deck is above the corridor area's top edge, 1 = it is down (how far is `deck_peek`).
var _deck_show: float = 0.0
# 0 = the picked card is at its place in the row, 1 = it is where the deck was.
var _rise: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _held_below: Control = null   # the encounter's panel, kept under the picked card (hold_below)


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


## The global point where the deck's centre is once it is down, and where a picked card stays.
func deck_point() -> Vector2:
  return global_position + _deck_centre(1.0, _fit())


## Keep `panel` (an encounter's panel) under the picked card each frame, with the same gap between the
## card and the panel as between the corridor area's top edge and the card.
func hold_below(panel: Control) -> void:
  _held_below = panel
  _place_held()


# The corridor area follows the window and the look settings, so the cards and deck follow it each frame.
func _process(_delta: float) -> void:
  _place_cards()
  _place_held()


# The panel keeps its horizontal place; only its top moves. It never goes past the area's bottom edge.
func _place_held() -> void:
  if not is_instance_valid(_held_below):
    return
  var fit: float = _fit()
  var card_top: float = _deck_centre(1.0, fit).y - _card_size().y * fit * 0.5
  var gap: float = maxf(card_top, MARGIN)
  var top: float = card_top + _card_size().y * fit + gap
  top = minf(top, size.y - _held_below.size.y)
  _held_below.global_position = Vector2(_held_below.global_position.x, global_position.y + top)


func _place_cards() -> void:
  var fit: float = _fit()
  var card_size: Vector2 = _card_size()
  var deck_centre: Vector2 = _deck_centre(_deck_show, fit)
  var deck_home: Vector2 = _deck_centre(1.0, fit)
  _deck.pivot_offset = card_size * 0.5
  _deck.scale = Vector2.ONE * fit
  _deck.position = deck_centre - card_size * 0.5
  for i in _card_list.size():
    var card: EncounterCard = _card_list[i]
    if card == null:
      continue
    var rise: float = _rise if i == _picked_index else 0.0
    card.pivot_offset = card_size * 0.5
    card.scale = Vector2.ONE * fit
    card.rotation_degrees = card.tilt * card.travel * (1.0 - card.lift) * (1.0 - rise)
    var in_row: Vector2 = deck_centre.lerp(_rest_centre(i, fit), card.travel)
    card.position = in_row.lerp(deck_home, rise) - card_size * 0.5


# The scale that fits the deck's showing part, the row and the Walk past button into the corridor
# area, with a margin between each. Never above 1.
func _fit() -> float:
  var card_size: Vector2 = _card_size()
  var count: int = maxi(_card_list.size(), 1)
  var row_width: float = card_size.x * (count + (count - 1) * PrintLook.print_setting('card_spacing'))
  var fit_width: float = (size.x - 2.0 * MARGIN) / maxf(row_width, 1.0)
  var fit_height: float = (_skip_button.position.y - 3.0 * MARGIN) / maxf(card_size.y * (1.0 + PrintLook.print_setting('deck_peek')), 1.0)
  return clampf(minf(fit_width, fit_height), 0.01, 1.0)


func _rest_centre(index: int, fit: float) -> Vector2:
  var card_size: Vector2 = _card_size() * fit
  var count: int = _card_list.size()
  var step: float = card_size.x * (1.0 + PrintLook.print_setting('card_spacing'))
  var deck_bottom: float = card_size.y * PrintLook.print_setting('deck_peek') + MARGIN
  var x: float = size.x * 0.5 + (index - (count - 1) * 0.5) * step
  return Vector2(x, (deck_bottom + _skip_button.position.y) * 0.5)


# The deck's centre when it is `amount` of the way down: from just above the top edge to `deck_peek`
# of it showing, a margin below the edge.
func _deck_centre(amount: float, fit: float) -> Vector2:
  var height: float = _card_size().y * fit
  var top: float = -height + amount * (height * PrintLook.print_setting('deck_peek') + MARGIN)
  return Vector2(size.x * 0.5, top + height * 0.5)


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
  dealt.emit()


# Send every card but the picked one (all of them when `keep` is -1) back to the deck and slide the
# deck away; then move the picked card up to where the deck was, and call `done`.
func _leave(keep: int, done: Callable) -> void:
  _leaving = true
  _picked_index = keep
  _skip_button.disabled = true
  create_tween().tween_property(_skip_button, 'modulate:a', 0.0, PrintLook.print_setting('card_turn_time'))
  var deal_time: float = PrintLook.print_setting('card_deal_time')
  var turn_time: float = PrintLook.print_setting('card_turn_time')
  var tween: Tween = create_tween().set_parallel(true)
  for i in _card_list.size():
    var card: EncounterCard = _card_list[i]
    if card == null:
      continue
    card.pickable = false
    if i == keep:
      card.mouse_filter = Control.MOUSE_FILTER_IGNORE   # it stays over the corridor during the encounter
      continue
    tween.tween_property(card, 'face_up', 0.0, turn_time * card.face_up)
    tween.tween_property(card, 'travel', 0.0, deal_time).set_delay(turn_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
  tween.tween_callback(SfxManager.play_sound.bind('ui/card_deal')).set_delay(turn_time)
  tween.tween_property(self, '_deck_show', 0.0, deal_time).set_delay(turn_time + deal_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
  var finish: float = turn_time + deal_time * 2.0
  if keep >= 0:
    tween.tween_callback(SfxManager.play_sound.bind('ui/card_deal')).set_delay(finish)
    tween.tween_property(self, '_rise', 1.0, deal_time).set_delay(finish).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    finish += deal_time
  tween.tween_callback(done).set_delay(finish)


## Pick card `index` as a click on it does: the others go back, the picked card moves up, then
## `picked` is emitted.
func pick(index: int) -> void:
  if _leaving:
    return
  _leave(index, picked.emit.bind(index))


func _on_card_pressed(index: int) -> void:
  pick(index)


func _on_skip_pressed() -> void:
  if _leaving:
    return
  _leave(-1, skipped.emit)
