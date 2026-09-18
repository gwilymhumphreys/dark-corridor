class_name PresetPartRow
extends HBoxContainer
## The row at the top of a debug panel tab that loads that tab's part of the look from a preset, or
## turns every setting in the part off (docs/systems/look_presets.md). The rest of the look is unchanged.

@export var part: LookPresets.Part = LookPresets.Part.CORRIDOR

@onready var _option: OptionButton = $Option


func _ready() -> void:
  _option.item_selected.connect(_on_item_selected)


## List the presets and the history. The first item is a prompt that loads nothing.
func list_presets() -> void:
  _option.clear()
  _option.add_item('Choose a preset...')
  _option.add_item('Everything off')
  for preset_name: String in LookPresets.preset_names():
    _option.add_item(preset_name)
    _option.set_item_metadata(_option.item_count - 1, LookPresets.preset_path(preset_name))
  var history: PackedStringArray = LookPresets.history_names()
  if not history.is_empty():
    _option.add_separator('History')
    for history_name: String in history:
      _option.add_item(PresetBar.history_label(history_name))
      _option.set_item_metadata(_option.item_count - 1, LookPresets.preset_path(history_name, LookPresets.HISTORY_DIR))
  _option.select(0)


func _on_item_selected(index: int) -> void:
  if index <= 0:
    return
  var parts: Array[LookPresets.Part] = [part]
  if index == 1:
    LookPresets.apply(ConfigFile.new(), parts)
  else:
    LookPresets.load_preset(_option.get_item_metadata(index), parts)
  _option.select(0)
  DebugPanels.refresh_panels()
