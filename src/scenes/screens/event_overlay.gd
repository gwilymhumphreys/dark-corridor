class_name EventOverlay
extends Control
## The event overlay (docs/systems/encounter.md / docs/systems/ui_layout.md): a non-combat EVENT's prose + its
## available options as buttons. A pick emits option_picked(index), the option's index in the
## event's authored list, which the run screen forwards to RunManager.pick_event_option (which
## applies the option's effects + resolves the beat). Reads the live Encounter; writes nothing.
## Text localized.

signal option_picked(index: int)

@onready var _title: Label = $Panel/Title
@onready var _prose: Label = $Panel/Prose
@onready var _options: VBoxContainer = $Panel/Options


## `available` holds the indices of the options to show (RunManager.available_event_options); an
## option whose conditions do not hold is not shown.
func setup(enc: Encounter, available: Array[int]) -> void:
  _title.text = tr(enc.def.name_key)
  _prose.text = tr(enc.def.prose_key)
  var options: Array = enc.event_options()
  for i: int in available:
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
