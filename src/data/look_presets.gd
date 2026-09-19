class_name LookPresets
extends RefCounted
## Look presets (docs/systems/look_presets.md): one `ConfigFile` holding the whole look, in five parts
## (corridor look with its palette, interface look with its palettes and font, print look, background
## wear, control feedback). The default preset loads when the game starts; pressing Make default first
## copies the old default into the history folder.
##
## Each part's settings are written and read by the autoload that owns them, so a part can be loaded
## on its own. Reading a part starts from that part's defaults.

enum Part { CORRIDOR, INTERFACE, PRINT, BACKGROUND, FEEDBACK }

const PRESET_DIR: String = 'res://assets/presets'
const HISTORY_DIR: String = 'res://assets/presets/history'
const DEFAULT_NAME: String = 'default'
const ALL_PARTS: Array[Part] = [Part.CORRIDOR, Part.INTERFACE, Part.PRINT, Part.BACKGROUND, Part.FEEDBACK]
## The sections each part writes. The `preset` section holds details about the file, not settings.
const PART_SECTIONS: Dictionary = {
  Part.CORRIDOR: ['corridor_palette', 'corridor_shader', 'corridor_light', 'corridor_environment'],
  Part.INTERFACE: ['interface_palette', 'interface_shader', 'interface_glow'],
  Part.PRINT: ['print_panel', 'print_frame', 'print_layout'],
  Part.BACKGROUND: ['print_background'],
  Part.FEEDBACK: ['control_highlight', 'control_settings'],
}


## The current look as a preset file.
static func capture() -> ConfigFile:
  var file: ConfigFile = ConfigFile.new()
  DebugPanels.write_corridor_palette(file)
  DebugPanels.write_corridor_look(file)
  DebugPanels.write_interface_palettes(file)
  InterfaceLook.write_look(file)
  PrintLook.write_print_look(file)
  PrintLook.write_background_look(file)
  ControlFeedback.write_look(file)
  return file


## Set `parts` of the look from a preset file. Each part starts from its defaults, so settings the
## file leaves out go back to their defaults.
static func apply(file: ConfigFile, parts: Array[Part] = ALL_PARTS) -> void:
  if Part.CORRIDOR in parts:
    DebugPanels.read_corridor_look(file)
    DebugPanels.read_corridor_palette(file)
  if Part.INTERFACE in parts:
    InterfaceLook.read_look(file)
    DebugPanels.read_interface_palettes(file)
  if Part.PRINT in parts:
    PrintLook.read_print_look(file)
  if Part.BACKGROUND in parts:
    PrintLook.read_background_look(file)
  if Part.FEEDBACK in parts:
    ControlFeedback.read_look(file)


## Save the current look to `path`, replacing any file there.
static func save_preset(path: String) -> Error:
  DirAccess.make_dir_recursive_absolute(path.get_base_dir())
  return capture().save(path)


## Load `parts` of the look from the preset at `path`. Returns false if the file cannot be read.
static func load_preset(path: String, parts: Array[Part] = ALL_PARTS) -> bool:
  var file: ConfigFile = ConfigFile.new()
  if file.load(path) != OK:
    push_warning('[LookPresets] could not read preset %s' % path)
    return false
  apply(file, parts)
  return true


## Load the default preset from `folder`. Returns false if there is none.
static func load_default(folder: String = PRESET_DIR) -> bool:
  var path: String = preset_path(DEFAULT_NAME, folder)
  return FileAccess.file_exists(path) and load_preset(path)


## Make the current look the default in `folder`. The old default is first copied into `history_dir`,
## named with the date and time and the name of the preset it was made from. `source_name` is kept in
## the new default for the same purpose. Returns the history file's path, or '' if there was no old
## default.
static func make_default(source_name: String, folder: String = PRESET_DIR, history_dir: String = HISTORY_DIR) -> String:
  var default_path: String = preset_path(DEFAULT_NAME, folder)
  var history_path: String = ''
  var old: ConfigFile = ConfigFile.new()
  if old.load(default_path) == OK:
    var stamp: String = Time.get_datetime_string_from_system().replace('T', '_').replace(':', '').left(15)
    var old_source: String = old.get_value('preset', 'source', DEFAULT_NAME)
    history_path = history_dir.path_join('%s_%s.cfg' % [stamp, old_source])
    DirAccess.make_dir_recursive_absolute(history_dir)
    old.save(history_path)
  var file: ConfigFile = capture()
  file.set_value('preset', 'source', source_name)
  DirAccess.make_dir_recursive_absolute(folder)
  file.save(default_path)
  return history_path


## Delete the preset or history file at `path`. The default preset cannot be deleted, because the game
## starts from it.
static func delete_preset(path: String) -> Error:
  if path.get_file().get_basename() == DEFAULT_NAME and path.get_base_dir() != HISTORY_DIR:
    return ERR_UNAUTHORIZED
  if not FileAccess.file_exists(path):
    return ERR_FILE_NOT_FOUND
  return DirAccess.remove_absolute(path)


## The file a preset named `preset_name` is saved in.
static func preset_path(preset_name: String, folder: String = PRESET_DIR) -> String:
  return folder.path_join(preset_name + '.cfg')


## The names of the presets in `folder`, default first, then by name.
static func preset_names(folder: String = PRESET_DIR) -> PackedStringArray:
  var names: PackedStringArray = PackedStringArray()
  if not DirAccess.dir_exists_absolute(folder):
    return names
  for file_name: String in DirAccess.get_files_at(folder):
    if file_name.get_extension() == 'cfg' and file_name.get_basename() != DEFAULT_NAME:
      names.append(file_name.get_basename())
  names.sort()
  if FileAccess.file_exists(preset_path(DEFAULT_NAME, folder)):
    names.insert(0, DEFAULT_NAME)
  return names


## The file names (without `.cfg`) in the history folder, newest first. They start with the date and
## time, so sorting by name sorts by date.
static func history_names(history_dir: String = HISTORY_DIR) -> PackedStringArray:
  var names: PackedStringArray = PackedStringArray()
  if not DirAccess.dir_exists_absolute(history_dir):
    return names
  for file_name: String in DirAccess.get_files_at(history_dir):
    if file_name.get_extension() == 'cfg':
      names.append(file_name.get_basename())
  names.sort()
  names.reverse()
  return names


## Whether the current look matches the preset at `path`, comparing numbers and colours with a small
## tolerance. False if the file cannot be read.
static func matches(path: String) -> bool:
  var saved: ConfigFile = ConfigFile.new()
  if saved.load(path) != OK:
    return false
  var current: ConfigFile = capture()
  for part: Part in ALL_PARTS:
    for section: String in PART_SECTIONS[part]:
      var keys: PackedStringArray = current.get_section_keys(section) if current.has_section(section) else PackedStringArray()
      for key: String in keys:
        if not saved.has_section_key(section, key):
          return false
        if not _same_value(current.get_value(section, key), saved.get_value(section, key)):
          return false
  return true


static func _same_value(a: Variant, b: Variant) -> bool:
  if (a is float or a is int) and (b is float or b is int) and typeof(a) != typeof(b):
    return is_equal_approx(float(a), float(b))
  if typeof(a) != typeof(b):
    return false
  if a is float:
    return is_equal_approx(a, b)
  if a is Color:
    return (a as Color).is_equal_approx(b)
  return a == b
