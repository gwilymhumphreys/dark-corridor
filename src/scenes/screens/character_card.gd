class_name CharacterCard
extends Button
## One character on the select screen (#27): personal name, class and the character's
## portrait. A themed Button with UIJuice; the select overlay wires
## `pressed` to the character id. Reads a CharacterDef; writes nothing. Text is localized via tr().

@onready var _portrait: TextureRect = $Portrait/Image
@onready var _name: Label = $Name
@onready var _class: Label = $Class


func setup(def: CharacterDef) -> void:
  if def.portrait != '':
    _portrait.texture = load(def.portrait)
  _name.text = tr(def.name_key)
  _class.text = tr(def.class_key) if def.class_key != '' else ''


func _exit_tree() -> void:
  _portrait.texture = null

