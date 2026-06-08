class_name SettingsScreen
extends Control
## The settings screen — audio volume sliders (Master / Music / Effects) bound to `Prefs`,
## which applies them to the AudioServer buses and persists them to disk. Opened from the
## title screen and the in-run pause menu; Close emits `closed` (the opener frees it). Static
## labels auto-translate from the .tscn; this only wires the sliders. Reads/writes Prefs only.

signal closed()

# Each slider node name → its Prefs audio key.
const SLIDERS: Dictionary = {
  'MasterRow': 'master',
  'MusicRow': 'music',
  'EffectsRow': 'effects',
}

@onready var _rows: VBoxContainer = $Panel/Rows
@onready var _back: Button = $Panel/BackButton


func _ready() -> void:
  for row_name in SLIDERS:
    _bind(_rows.get_node(row_name + '/Slider'), SLIDERS[row_name])
  _back.pressed.connect(_on_back)


## Seed the slider from the stored level, THEN connect — so the initial set doesn't fire a write.
func _bind(slider: HSlider, key: String) -> void:
  slider.min_value = 0.0
  slider.max_value = 100.0
  slider.step = 1.0
  slider.value = Prefs.volume(key) * 100.0
  slider.value_changed.connect(_on_volume_changed.bind(key))


func _on_volume_changed(value: float, key: String) -> void:
  Prefs.set_volume(key, value / 100.0)


func _on_back() -> void:
  closed.emit()
