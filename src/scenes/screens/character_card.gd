class_name CharacterCard
extends Button
## One character on the select screen (#27): personal name + role subtitle + an identity blurb + a starting-kit hint
## (the board items read off the def) and the character's portrait. A themed Button with UIJuice; the select overlay wires
## `pressed` to the character id. Reads a CharacterDef; writes nothing. Text is localized via tr().

@onready var _portrait: TextureRect = $Portrait/Image
@onready var _name: Label = $Name
@onready var _subtitle: Label = $Subtitle
@onready var _blurb: Label = $Blurb
@onready var _kit: Label = $Kit


func setup(def: CharacterDef) -> void:
  if def.portrait != '':
    _portrait.texture = load(def.portrait)
  _name.text = tr(def.name_key)
  _subtitle.text = tr(def.subtitle_key) if def.subtitle_key != '' else ''
  _blurb.text = tr(def.blurb_key) if def.blurb_key != '' else ''
  _kit.text = _kit_hint(def)


func _exit_tree() -> void:
  _portrait.texture = null


## The starting board, item names joined — a concrete read of what the character opens with.
func _kit_hint(def: CharacterDef) -> String:
  var names: Array = []
  for id in def.starting_item_ids:
    names.append(tr(ItemCatalog.get_def(id).name_key))
  return tr('Starts with: {0}').format([', '.join(names)])
