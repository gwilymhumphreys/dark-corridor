class_name CharacterCard
extends Button
## One character on the select screen (#27): name + an identity blurb + a starting-kit hint
## (the board items read off the def). A themed Button with UIJuice; the select overlay wires
## `pressed` to the character id. Reads a CharacterDef; writes nothing. Text is localized via tr().

@onready var _name: Label = $Name
@onready var _blurb: Label = $Blurb
@onready var _kit: Label = $Kit


func setup(def: CharacterDef) -> void:
  _name.text = tr(def.name_key)
  _blurb.text = tr(def.blurb_key) if def.blurb_key != '' else ''
  _kit.text = _kit_hint(def)


## The starting board, item names joined — a concrete read of what the character opens with.
func _kit_hint(def: CharacterDef) -> String:
  var names: Array = []
  for id in def.starting_item_ids:
    names.append(tr(ItemCatalog.get_def(id).name_key))
  return tr('Starts with: {0}').format([', '.join(names)])
