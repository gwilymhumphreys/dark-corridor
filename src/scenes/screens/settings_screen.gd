class_name SettingsScreen
extends Control
## The settings screen, in three tabs: Audio (volume sliders for Master / Music / Interface / Game and
## a mute-when-unfocused toggle), Display (fullscreen and a text size slider), and Controls (a
## `KeybindRow` per `Keybinds.ACTIONS` entry). The audio and display controls are bound to `Prefs`
## (which applies + persists each change); the key rows go through `Keybinds`. Each tab is a
## ScrollContainer so the screen stays usable at the largest text size.
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

const KEYBIND_ROW: PackedScene = preload('res://src/scenes/screens/keybind_row.tscn')

@onready var _tabs: TabContainer = $Panel/Tabs
@onready var _audio_rows: VBoxContainer = $Panel/Tabs/Audio/Rows
@onready var _display_rows: VBoxContainer = $Panel/Tabs/Display/Rows
@onready var _keys: VBoxContainer = $Panel/Tabs/Controls/Rows/Keys
@onready var _message: Label = $Panel/Tabs/Controls/Rows/Message
@onready var _reset_keys: Button = $Panel/Tabs/Controls/Rows/ResetButton
@onready var _back: Button = $Panel/BackButton


func _ready() -> void:
  # Tab titles come from node names, which the text extractor does not read, so they are set here.
  _tabs.set_tab_title(0, tr('Audio'))
  _tabs.set_tab_title(1, tr('Display'))
  _tabs.set_tab_title(2, tr('Controls'))
  for row_name in SLIDERS:
    _bind_slider(_audio_rows.get_node(row_name + '/Slider'), SLIDERS[row_name])
  _bind_text_size(_display_rows.get_node('TextSizeRow/Slider'))
  _bind_check(_display_rows.get_node('FullscreenRow/Check'), Prefs.is_fullscreen(), Prefs.set_fullscreen)
  _bind_check(_audio_rows.get_node('MuteRow/Check'), Prefs.mute_on_focus_lost(), Prefs.set_mute_on_focus_lost)
  _build_keybind_rows()
  _reset_keys.pressed.connect(_on_reset_keys)
  _tabs.tab_changed.connect(_on_tab_changed)
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


func _build_keybind_rows() -> void:
  for entry in Keybinds.ACTIONS:
    var row: KeybindRow = KEYBIND_ROW.instantiate()
    row.setup(entry['action'])
    _keys.add_child(row)
    row.capture_started.connect(_on_capture_started.bind(row))
    row.bound.connect(_on_key_bound)
    row.reserved_key_pressed.connect(_on_reserved_key)


func _keybind_rows() -> Array[KeybindRow]:
  var rows: Array[KeybindRow] = []
  for child in _keys.get_children():
    if child is KeybindRow:
      rows.append(child)
  return rows


# Only one row waits for a key at a time.
func _on_capture_started(capturing: KeybindRow) -> void:
  _message.text = ''
  for row in _keybind_rows():
    if row != capturing:
      row.cancel_capture()


# A bind can empty another action's slot, so every row is refreshed, and the message names the
# action that lost the key.
func _on_key_bound(taken_from: String) -> void:
  _message.text = ''
  for row in _keybind_rows():
    row.refresh()
    if taken_from != '' and row.action == taken_from:
      _message.text = tr('Removed from {0}').format([row.action_name()])


func _on_reserved_key() -> void:
  _message.text = tr('That key is kept for the game')


func _on_reset_keys() -> void:
  Keybinds.reset_all()
  _on_key_bound('')


func _on_tab_changed(_tab: int) -> void:
  for row in _keybind_rows():
    row.cancel_capture()
  _message.text = ''


func _on_back() -> void:
  closed.emit()
