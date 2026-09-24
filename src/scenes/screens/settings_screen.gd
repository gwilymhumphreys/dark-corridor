class_name SettingsScreen
extends Control
## The settings screen — audio volume sliders (Master / Music / Interface / Game), a text size slider,
## a mute-when-unfocused toggle and a fullscreen toggle, all bound to `Prefs` (which applies +
## persists each change). The rows sit in a ScrollContainer so the screen stays usable at the
## largest text size.
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

## The text size slider is a percentage of the `TextSize` ladder, stepped so a drag lands on whole
## multiples of a pixel rather than on a size that rounds to the same one.
const TEXT_STEP: float = 5.0

@onready var _rows: VBoxContainer = $Panel/Scroll/Rows
@onready var _back: Button = $Panel/BackButton


func _ready() -> void:
  for row_name in SLIDERS:
    _bind_slider(_rows.get_node(row_name + '/Slider'), SLIDERS[row_name])
  _bind_text_size(_rows.get_node('TextSizeRow/Slider'))
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


## The text size slider, in whole percent of the ladder (rounded, so the stored scale is always a
## whole percent). Dragging it resizes this screen too, since Prefs writes the new sizes straight into the theme every Control is reading.
func _bind_text_size(slider: HSlider) -> void:
  slider.min_value = TextSize.MIN_SCALE * 100.0
  slider.max_value = TextSize.MAX_SCALE * 100.0
  slider.step = TEXT_STEP
  slider.value = Prefs.text_scale() * 100.0
  slider.value_changed.connect(_on_text_size_changed)


func _on_text_size_changed(value: float) -> void:
  Prefs.set_text_scale(roundi(value) / 100.0)


## A bool toggle: seed `pressed` from the stored value, then route `toggled` straight to the setter.
func _bind_check(check: CheckButton, value: bool, setter: Callable) -> void:
  check.button_pressed = value
  check.toggled.connect(setter)


func _on_back() -> void:
  closed.emit()
