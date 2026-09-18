class_name PresetBar
extends HBoxContainer
## The preset bar at the top of the debug panel (docs/systems/look_presets.md). The name field with its
## dropdown loads a preset or a past default; Save writes the whole look under the typed name, replacing
## a preset of that name; Make default makes the look the one the game starts with, keeping the old
## default in the history; Back to default loads the default again; Delete removes the named preset or
## history file after a second press. A note shows whether the look has changed since the preset was
## loaded or saved.

## Emitted after a preset is loaded, so the tabs show its settings.
signal preset_loaded
## Emitted when the button that moves the panel to the other side of the screen is pressed.
signal side_switched

const CHECK_INTERVAL: float = 0.5   # seconds between checks for changes while the bar is showing
const DELETE_TEXT: String = 'Delete'
const CONFIRM_DELETE_TEXT: String = 'Really delete?'

var _loaded_path: String = ''   # the preset last loaded or saved, which changes are measured against
var _check_timer: float = 0.0

@onready var _name_edit: LineEdit = $NameEdit
@onready var _menu: MenuButton = $PresetMenu
@onready var _changed_label: Label = $ChangedLabel
@onready var _save_button: Button = $SaveButton
@onready var _default_button: Button = $DefaultButton
@onready var _back_button: Button = $BackButton
@onready var _delete_button: Button = $DeleteButton
@onready var _side_button: Button = $SideButton


func _ready() -> void:
  _menu.get_popup().index_pressed.connect(_on_menu_index_pressed)
  _name_edit.text_submitted.connect(func(_text: String) -> void: _on_save_pressed())
  _save_button.pressed.connect(_on_save_pressed)
  _default_button.pressed.connect(_on_default_pressed)
  _back_button.pressed.connect(_on_back_pressed)
  _delete_button.pressed.connect(_on_delete_pressed)
  _name_edit.text_changed.connect(func(_text: String) -> void: _cancel_delete())
  _side_button.pressed.connect(func() -> void: side_switched.emit())
  if FileAccess.file_exists(LookPresets.preset_path(LookPresets.DEFAULT_NAME)):
    _loaded_path = LookPresets.preset_path(LookPresets.DEFAULT_NAME)
    _name_edit.text = LookPresets.DEFAULT_NAME


func _process(delta: float) -> void:
  if not is_visible_in_tree():
    return
  _check_timer -= delta
  if _check_timer <= 0.0:
    _update_changed()


## List the presets and show whether the look has changed. Called when the panel opens.
func open() -> void:
  _cancel_delete()
  _list_presets()
  _update_changed()


## Measure changes against no preset, after the look was set some other way (tests reset it).
func forget_loaded() -> void:
  _loaded_path = ''


## Measure changes against the preset at `path` and show its name, after it was loaded some other way
## (the `--preset=` start-up argument).
func remember_loaded(path: String) -> void:
  _loaded_path = path
  _name_edit.text = path.get_file().get_basename()


## How a history file name reads in a list: '2026-09-17_1432_candlelit' -> '2026-09-17 14:32  candlelit'.
static func history_label(history_name: String) -> String:
  if history_name.length() < 16:
    return history_name
  return '%s %s:%s  %s' % [history_name.left(10), history_name.substr(11, 2), history_name.substr(13, 2), history_name.substr(16)]


func _list_presets() -> void:
  var popup: PopupMenu = _menu.get_popup()
  popup.clear()
  for preset_name: String in LookPresets.preset_names():
    popup.add_item(preset_name)
    popup.set_item_metadata(popup.item_count - 1, LookPresets.preset_path(preset_name))
  var history: PackedStringArray = LookPresets.history_names()
  if not history.is_empty():
    popup.add_separator('History')
    for history_name: String in history:
      popup.add_item(history_label(history_name))
      popup.set_item_metadata(popup.item_count - 1, LookPresets.preset_path(history_name, LookPresets.HISTORY_DIR))


func _update_changed() -> void:
  _check_timer = CHECK_INTERVAL
  if _loaded_path == '':
    _changed_label.text = 'not saved'
  elif LookPresets.matches(_loaded_path):
    _changed_label.text = ''
  else:
    _changed_label.text = 'changed'


# The typed name as a file name, or '' if nothing usable was typed.
func _typed_name() -> String:
  return _name_edit.text.strip_edges().to_snake_case().validate_filename()


func _on_menu_index_pressed(index: int) -> void:
  var path: String = _menu.get_popup().get_item_metadata(index)
  if not LookPresets.load_preset(path):
    return
  _loaded_path = path
  _name_edit.text = path.get_file().get_basename()
  preset_loaded.emit()
  _update_changed()


func _on_save_pressed() -> void:
  _name_edit.release_focus()
  var preset_name: String = _typed_name()
  if preset_name == '':
    return
  # Saving over the default goes through Make default, so the old default is kept in the history.
  if preset_name == LookPresets.DEFAULT_NAME:
    _on_default_pressed()
    return
  _name_edit.text = preset_name
  _loaded_path = LookPresets.preset_path(preset_name)
  LookPresets.save_preset(_loaded_path)
  _list_presets()
  _update_changed()


func _on_default_pressed() -> void:
  _name_edit.release_focus()
  var source: String = _typed_name()
  LookPresets.make_default(source if source != '' else LookPresets.DEFAULT_NAME)
  _loaded_path = LookPresets.preset_path(LookPresets.DEFAULT_NAME)
  _list_presets()
  _update_changed()


# The first press asks for a second; the second deletes the preset named in the field, or the history
# file when that is what was loaded under this name.
func _on_delete_pressed() -> void:
  if _delete_button.text != CONFIRM_DELETE_TEXT:
    if _typed_name() != '' and _typed_name() != LookPresets.DEFAULT_NAME:
      _delete_button.text = CONFIRM_DELETE_TEXT
    return
  _cancel_delete()
  var path: String = LookPresets.preset_path(_typed_name())
  if _loaded_path.get_file().get_basename() == _name_edit.text:
    path = _loaded_path
  if LookPresets.delete_preset(path) != OK:
    return
  if path == _loaded_path:
    _loaded_path = ''
  _name_edit.text = ''
  _list_presets()
  _update_changed()


func _cancel_delete() -> void:
  _delete_button.text = DELETE_TEXT


func _on_back_pressed() -> void:
  var path: String = LookPresets.preset_path(LookPresets.DEFAULT_NAME)
  if not LookPresets.load_preset(path):
    return
  _loaded_path = path
  _name_edit.text = LookPresets.DEFAULT_NAME
  preset_loaded.emit()
  _update_changed()
