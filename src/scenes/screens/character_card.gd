class_name CharacterCard
extends Button
## One character on the select screen (#27): personal name + role subtitle and the character's
## portrait. A themed Button with UIJuice; the select overlay wires
## `pressed` to the character id. Reads a CharacterDef; writes nothing. Text is localized via tr().

@onready var _portrait: TextureRect = $Portrait/Image
@onready var _name: Label = $Name
@onready var _subtitle: Label = $Subtitle


func setup(def: CharacterDef) -> void:
  if def.portrait != '':
    _portrait.texture = load(def.portrait)
  _name.text = tr(def.name_key)
  _subtitle.text = tr(def.subtitle_key) if def.subtitle_key != '' else ''


func _exit_tree() -> void:
  _portrait.texture = null

