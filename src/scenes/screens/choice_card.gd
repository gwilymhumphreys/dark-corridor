class_name ChoiceCard
extends Button
## One choice-point candidate (encounter_prd telegraph): the encounter's location frame +
## its category (Fight / Elite / Boss / Rest) + a reward hint — telegraph the category,
## not the contents (design). A themed Button with UIJuice; the overlay wires `pressed` to
## the pick index. Reads an EncounterDef; writes nothing. Player-facing text is localized.

@onready var _color: ColorRect = $Color
@onready var _category: Label = $Category
@onready var _frame: Label = $Frame
@onready var _reward: Label = $Reward


func setup(def: EncounterDef) -> void:
  _color.color = _category_color(def)
  _category.text = _category_name(def)
  _frame.text = tr(def.name_key)
  _reward.text = _reward_hint(def)


## The telegraphed category — derived from the encounter's type + reward (an elite is a
## fight with the richer relic+draft reward; a boss-tier fight rewards a relic).
func _category_name(def: EncounterDef) -> String:
  if def.type == EncounterDef.Type.REST:
    return tr('Rest')
  if def.type == EncounterDef.Type.EVENT:
    return tr('Event')
  match def.reward:
    EncounterDef.Reward.ELITE:
      return tr('Elite')
    EncounterDef.Reward.RELIC:
      return tr('Boss')
    _:
      return tr('Fight')


func _reward_hint(def: EncounterDef) -> String:
  match def.reward:
    EncounterDef.Reward.ELITE:
      return tr('Relic + item')
    EncounterDef.Reward.RELIC:
      return tr('Relic')
    EncounterDef.Reward.DRAFT:
      return tr('Item')
    _:
      return ''


func _category_color(def: EncounterDef) -> Color:
  if def.type == EncounterDef.Type.REST:
    return Colours.BEAT_REST
  if def.type == EncounterDef.Type.EVENT:
    return Colours.BEAT_EVENT
  match def.reward:
    EncounterDef.Reward.ELITE:
      return Colours.BEAT_BOSS
    EncounterDef.Reward.RELIC:
      return Colours.BEAT_RELIC
    _:
      return Colours.BEAT_COMBAT
