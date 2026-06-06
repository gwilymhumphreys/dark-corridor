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
    return Color(0.4, 0.75, 0.45)
  match def.reward:
    EncounterDef.Reward.ELITE:
      return Color(0.7, 0.4, 0.9)
    EncounterDef.Reward.RELIC:
      return Color(0.85, 0.7, 0.3)
    _:
      return Color(0.7, 0.35, 0.35)
