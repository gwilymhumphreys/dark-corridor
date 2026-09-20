class_name SettingsScreen
extends Control
## The settings screen — audio volume sliders (Master / Music / Interface / Game), a mute-when-unfocused
## toggle and a fullscreen toggle, all bound to `Prefs` (which applies + persists each change).
## Opened from the title screen and the in-run pause menu; Close emits `closed` (the opener frees
## it). Static labels auto-translate from the .tscn; this only wires the controls. Reads/writes
## Prefs only.
##
## Each control is seeded from its stored value BEFORE its signal is connected, so seeding never
## fires a spurious write back to Prefs.

signal closed()

# Each slider node name → its Prefs audio key.
const SLIDERS: Dictionary = {
  'MasterRow': 'master',
  'MusicRow': 'music',
  'InterfaceRow': 'interface',
  'GameRow': 'game',
}

@onready var _rows: VBoxContainer = $Panel/Rows
@onready var _back: Button = $Panel/BackButton


func _ready() -> void:
  for row_name in SLIDERS:
    _bind_slider(_rows.get_node(row_name + '/Slider'), SLIDERS[row_name])
  _bind_check(_rows.get_node('FullscreenRow/Check'), Prefs.is_fullscreen(), Prefs.set_fullscreen)
  _bind_check(_rows.get_node('MuteRow/Check'), Prefs.mute_on_focus_lost(), Prefs.set_mute_on_focus_lost)
  _back.pressed.connect(_on_back)


func _bind_slider(slider: HSlider, key: String) -> void:
  slider.min_value = 0.0
  slider.max_value = 100.0
  slider.step = 1.0
  slider.value = Prefs.volume(key) * 100.0
  slider.value_changed.connect(_on_volume_changed.bind(key))


func _on_volume_changed(value: float, key: String) -> void:
  Prefs.set_volume(key, value / 100.0)


## A bool toggle: seed `pressed` from the stored value, then route `toggled` straight to the setter.
func _bind_check(check: CheckButton, value: bool, setter: Callable) -> void:
  check.button_pressed = value
  check.toggled.connect(setter)


func _on_back() -> void:
  closed.emit()
