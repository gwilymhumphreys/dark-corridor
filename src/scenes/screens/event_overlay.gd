class_name EventOverlay
extends Control
## The event overlay (encounter_prd / ui_layout_prd): a non-combat EVENT's prose + its
## binary choice as option buttons. A pick emits option_picked(index) — the tier-2 event
## intent the run screen forwards to Encounter.pick_event_option (which applies the chosen
## outcome + resolves the beat). Reads the live Encounter; writes nothing. Text localized.

signal option_picked(index: int)

@onready var _title: Label = $Panel/Title
@onready var _prose: Label = $Panel/Prose
@onready var _options: VBoxContainer = $Panel/Options


func setup(enc: Encounter) -> void:
  _title.text = tr(enc.def.name_key)
  _prose.text = tr(enc.def.event_prose_key)
  var options: Array = enc.event_options()
  for i in options.size():
    var btn := Button.new()
    btn.text = tr(options[i].label_key)
    btn.custom_minimum_size = Vector2(0, 72)
    btn.focus_mode = Control.FOCUS_NONE
    var juice := UIJuice.new()   # CLAUDE.md: new interactive UI gets the juice node
    juice.preset = UIJuice.Preset.BUTTON
    btn.add_child(juice)
    _options.add_child(btn)
    btn.pressed.connect(_on_option.bind(i))


func _on_option(index: int) -> void:
  option_picked.emit(index)
