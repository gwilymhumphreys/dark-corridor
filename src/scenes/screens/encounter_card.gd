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
    EncounterDef.Type.RELIC:
      return tr('Relic')
  return tr('Fight')


func _hint_text(def: EncounterDef) -> String:
  match def.type:
    EncounterDef.Type.REST:
      return tr('Recover health')
    EncounterDef.Type.RELIC:
      return tr('Choose a relic')
  return ''


func _kind_color(def: EncounterDef) -> Color:
  match def.type:
    EncounterDef.Type.EVENT:
      return Colours.BEAT_EVENT
    EncounterDef.Type.REST:
      return Colours.BEAT_REST
    EncounterDef.Type.RELIC:
      return Colours.BEAT_RELIC
  return Colours.BEAT_COMBAT
