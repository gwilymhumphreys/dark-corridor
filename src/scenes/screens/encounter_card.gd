class_name EncounterCard
extends Button
## One encounter offered before a fight (docs/plans/encounter_choice.md), a card button standing in
## the corridor: the encounter's kind, its name (the location frame) and a hint at what it gives. A
## themed Button, so it takes the worn panel and the control feedback, with UIJuice for the press,
## hover and sound. EncounterChoice wires `pressed` to the pick. Reads an EncounterDef; writes
## nothing. Player-facing text is localized.

@onready var _color: ColorRect = $Color
@onready var _kind: Label = $Kind
@onready var _frame: Label = $Frame
@onready var _hint: Label = $Hint


func setup(def: EncounterDef) -> void:
  _color.color = _kind_color(def)
  _kind.text = _kind_name(def)
  _frame.text = tr(def.name_key)
  _hint.text = _hint_text(def)


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
