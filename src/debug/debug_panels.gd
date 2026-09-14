class_name DebugPanelsAutoload
extends Node
## Dev-only debug panel + the full-screen palette clamp (docs/systems/debug_panel.md,
## docs/systems/palette_clamp.md). Registered as the `DebugPanels` autoload so the panel and the
## clamp cover every screen, the corridor testbed and the combat sandbox. It also owns the world
## material that the corridor is drawn through: the corridor look shader, with its world palette
## clamp (docs/systems/corridor_look.md).
##
## F1 toggles the panel and F2 the look panel, in debug builds only. Choices last for the session
## only, unless saved as a look file. Panel text is English on purpose: `tools/extract_pot.gd` skips
## `src/debug/`.

const PALETTE_ROOT: String = 'res://assets/palettes'
const SHORTLIST_DIR: String = 'res://assets/palettes/shortlist'
const LOOK_DIR: String = 'res://assets/looks'
const MAX_COLOURS: int = 64   # must match MAX_COLOURS in palette_clamp.gdshaderinc
const LOOK_SHADER: Shader = preload('res://src/shaders/corridor_look.gdshader')
const PALETTE_INCLUDE: ShaderInclude = preload('res://src/shaders/palette_clamp.gdshaderinc')
const BLUE_NOISE: Texture2D = preload('res://assets/textures/blue_noise_64.png')
## Palette clamp uniforms set from the F1 panel and the palette section of a look file, so they are
## not look settings.
const PALETTE_UNIFORMS: Array[String] = ['colour_count', 'perceptual', 'dithering']

## Corridor exports (property -> value), from `--corridor-set=property=value` arguments, the look
## panel and look files. Corridors apply them when built.
var corridor_settings: Dictionary = {}
## Properties of the corridor camera's Environment (property -> value), from the look panel and look
## files. Corridors apply them when built.
var environment_settings: Dictionary = {}
## The palette file the world clamp on the combat corridor uses, or '' when it is off.
var world_palette: String = ''
## The material every corridor is drawn through (corridor_look.gdshader). Its palette follows
## `world_palette`.
var world_material: ShaderMaterial = ShaderMaterial.new()

var _palette_paths: Array[String] = []   # item id - 1 -> palette path, in both palette options (id 0 = Off)
var _palettes_scanned: bool = false
var _perceptual: bool = false
var _dithering: bool = false
var _look_defaults: Dictionary = {}   # look shader uniform -> default value, read from its code

@onready var _clamp_layer: CanvasLayer = $ClampLayer
@onready var _look_layer: CanvasLayer = $LookLayer
@onready var _look_panel: LookPanel = $LookLayer/LookPanel
@onready var _clamp_material: ShaderMaterial = $ClampLayer/ClampRect.material
@onready var _panel_layer: CanvasLayer = $PanelLayer
@onready var _palette_option: OptionButton = $PanelLayer/Panel/Rows/PaletteRow/Option
@onready var _world_option: OptionButton = $PanelLayer/Panel/Rows/WorldPaletteRow/Option
@onready var _matching_option: OptionButton = $PanelLayer/Panel/Rows/MatchingRow/Option
@onready var _dithering_check: CheckButton = $PanelLayer/Panel/Rows/DitheringRow/Check


func _ready() -> void:
  _clamp_layer.visible = false
  _panel_layer.visible = false
  _look_layer.visible = false
  world_material.shader = LOOK_SHADER
  world_material.set_shader_parameter('dither_noise', BLUE_NOISE)
  _clamp_material.set_shader_parameter('dither_noise', BLUE_NOISE)
  _write_look_defaults()
  _write_palette(world_material, PackedColorArray())
  _palette_option.item_selected.connect(_on_palette_selected)
  _world_option.item_selected.connect(_on_world_palette_selected)
  _matching_option.item_selected.connect(_on_matching_selected)
  _dithering_check.toggled.connect(_on_dithering_toggled)
  _dithering_check.toggled.connect(func(_on: bool) -> void: _look_panel.refresh())
  _sync_controls()
  _apply_command_line()


## Dev hooks for screenshots: `--palette=<res path>` starts with that palette clamped,
## `--world-palette=<res path>` sets the world clamp, `--perceptual` and `--dither` set
## the matching and dithering, `--look=<res path>` loads a saved look (applied first, so the other
## arguments can override it), `--look-panel` opens the look panel.
func _apply_command_line() -> void:
  var args: PackedStringArray = OS.get_cmdline_user_args()
  for arg: String in args:
    if arg.begins_with('--look='):
      load_look(arg.substr(7))
  for arg: String in args:
    if arg.begins_with('--palette='):
      set_palette(PaletteLoader.load_palette(arg.substr(10)))
    elif arg.begins_with('--world-palette='):
      set_world_palette(arg.substr(16))
    elif arg.begins_with('--corridor-set='):
      var pair: PackedStringArray = arg.substr(15).split('=')
      if pair.size() == 2:
        corridor_settings[pair[0]] = str_to_var(pair[1])
    elif arg.begins_with('--monster-image='):
      MonsterImages.forced_path = arg.substr(16)
  if '--perceptual' in args:
    _on_matching_selected(1)
  if '--dither' in args:
    _on_dithering_toggled(true)
  if '--look-panel' in args:
    toggle_look_panel()
  _sync_controls()


func _exit_tree() -> void:
  _palette_paths.clear()


func _input(event: InputEvent) -> void:
  if not OS.is_debug_build():
    return
  var key: InputEventKey = event as InputEventKey
  if key == null or not key.pressed or key.echo:
    return
  # Typing a look name must not trigger the palette keys.
  if get_viewport().gui_get_focus_owner() is LineEdit and key.keycode not in [KEY_F1, KEY_F2]:
    return
  match key.keycode:
    KEY_F1:
      toggle_panel()
    KEY_F2:
      toggle_look_panel()
    KEY_BRACKETLEFT:
      cycle_palette(-1)
    KEY_BRACKETRIGHT:
      cycle_palette(1)
    KEY_APOSTROPHE:
      shortlist_palette()
    _:
      return
  get_viewport().set_input_as_handled()


func toggle_panel() -> void:
  if not _palettes_scanned:
    _scan_palettes()
  _panel_layer.visible = not _panel_layer.visible


## Show or hide the look panel. Its controls are built the first time it opens.
func toggle_look_panel() -> void:
  _look_layer.visible = not _look_layer.visible
  if _look_layer.visible:
    _look_panel.open()


## Select the next (`step` 1) or previous (`step` -1) entry in the full-screen palette list,
## skipping folder headings and wrapping through "Off". Bound to ] and [.
func cycle_palette(step: int) -> void:
  if not _palettes_scanned:
    _scan_palettes()
  var count: int = _palette_option.item_count
  var index: int = _palette_option.selected
  for i in count:
    index = posmod(index + step, count)
    if not _palette_option.is_item_separator(index):
      break
  _palette_option.select(index)
  _on_palette_selected(index)


## Move the selected full-screen palette into `SHORTLIST_DIR`, then rescan and keep it selected at
## its new path. Does nothing when "Off" is selected or the palette is already there. Bound to '.
func shortlist_palette() -> void:
  if not _palettes_scanned:
    return
  var id: int = _palette_option.get_selected_id()
  if id <= 0:
    return
  var old_path: String = _palette_paths[id - 1]
  if old_path.get_base_dir() == SHORTLIST_DIR:
    return
  var new_path: String = move_palette_file(old_path, SHORTLIST_DIR)
  if new_path == '':
    return
  _scan_palettes()
  var new_id: int = _palette_paths.find(new_path) + 1
  if new_id > 0:
    _palette_option.select(_palette_option.get_item_index(new_id))
    _on_palette_selected(_palette_option.selected)


## Move a palette file, and its `.import` file if there is one, into `folder`. Returns the new path,
## or '' if the move failed or a file of that name is already there.
static func move_palette_file(path: String, folder: String) -> String:
  var new_path: String = folder.path_join(path.get_file())
  if FileAccess.file_exists(new_path):
    push_warning('[DebugPanels] %s already exists; palette not moved' % new_path)
    return ''
  DirAccess.make_dir_recursive_absolute(folder)
  if DirAccess.rename_absolute(path, new_path) != OK:
    push_warning('[DebugPanels] could not move %s to %s' % [path, folder])
    return ''
  if FileAccess.file_exists(path + '.import'):
    DirAccess.rename_absolute(path + '.import', new_path + '.import')
  return new_path


## Back to the defaults: both clamps off, every look effect off, no corridor settings, random enemy
## images. Used between tests.
func reset_settings() -> void:
  reset_look()
  MonsterImages.forced_path = ''
  set_palette(PackedColorArray())
  if _palettes_scanned:
    _palette_option.select(0)
  _look_panel.refresh()


## Every look shader uniform with a default in the shader code or its palette clamp include (uniform
## name -> value), except `PALETTE_UNIFORMS`.
func look_defaults() -> Dictionary:
  if _look_defaults.is_empty():
    var pattern: RegEx = RegEx.create_from_string('uniform\\s+(\\w+)\\s+(\\w+)[^=;]*=\\s*([^;]+);')
    for found: RegExMatch in pattern.search_all(LOOK_SHADER.code + '\n' + PALETTE_INCLUDE.code):
      var text: String = found.get_string(3).strip_edges()
      if found.get_string(2) in PALETTE_UNIFORMS:
        continue
      match found.get_string(1):
        'bool':
          _look_defaults[found.get_string(2)] = text == 'true'
        'int':
          _look_defaults[found.get_string(2)] = text.to_int()
        'float':
          _look_defaults[found.get_string(2)] = text.to_float()
        'vec3':
          var parts: PackedStringArray = text.trim_prefix('vec3(').trim_suffix(')').split(',')
          _look_defaults[found.get_string(2)] = Color(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
  return _look_defaults


## Every look effect back to its shader default, no corridor or environment settings, world palette
## off, RGB matching, no dithering. Corridors on screen go back to their scene values.
func reset_look() -> void:
  _write_look_defaults()
  corridor_settings.clear()
  environment_settings.clear()
  var corridors: Array[Node] = get_tree().get_nodes_in_group(Corridor3D.GROUP)
  if not corridors.is_empty():
    var scene_values: Array[Dictionary] = LookPanel.scene_values()
    for corridor: Corridor3D in corridors:
      corridor.apply_settings(scene_values[0], scene_values[1])
  set_world_palette('')
  _on_matching_selected(0)
  _on_dithering_toggled(false)
  if _palettes_scanned:
    _world_option.select(0)
  _sync_controls()


## Turn dithering on or off for both clamps, keeping the F1 panel's switch in step.
func set_dithering(on: bool) -> void:
  _on_dithering_toggled(on)
  _sync_controls()


func is_dithering() -> bool:
  return _dithering


## Apply `corridor_settings` and `environment_settings` to every corridor on screen.
func apply_corridor_settings() -> void:
  for corridor: Corridor3D in get_tree().get_nodes_in_group(Corridor3D.GROUP):
    corridor.apply_settings(corridor_settings, environment_settings)


## Save the current look to a text file at `path`: the look shader settings, the corridor and
## environment settings, the world palette, matching and dithering.
func save_look(path: String) -> Error:
  var file: ConfigFile = ConfigFile.new()
  for uniform: String in look_defaults():
    file.set_value('shader', uniform, world_material.get_shader_parameter(uniform))
  for property: String in corridor_settings:
    file.set_value('corridor', property, corridor_settings[property])
  for property: String in environment_settings:
    file.set_value('environment', property, environment_settings[property])
  file.set_value('palette', 'world_palette', world_palette)
  file.set_value('palette', 'perceptual', _perceptual)
  file.set_value('palette', 'dithering', _dithering)
  DirAccess.make_dir_recursive_absolute(path.get_base_dir())
  return file.save(path)


## Load a look saved by `save_look`, starting from the defaults. Returns false if the file cannot be
## read.
func load_look(path: String) -> bool:
  var file: ConfigFile = ConfigFile.new()
  if file.load(path) != OK:
    push_warning('[DebugPanels] could not read look file %s' % path)
    return false
  reset_look()
  var defaults: Dictionary = look_defaults()
  for uniform: String in _section_keys(file, 'shader'):
    if defaults.has(uniform):
      world_material.set_shader_parameter(uniform, file.get_value('shader', uniform))
  for property: String in _section_keys(file, 'corridor'):
    corridor_settings[property] = file.get_value('corridor', property)
  for property: String in _section_keys(file, 'environment'):
    environment_settings[property] = file.get_value('environment', property)
  apply_corridor_settings()
  set_world_palette(file.get_value('palette', 'world_palette', ''))
  _on_matching_selected(1 if file.get_value('palette', 'perceptual', false) else 0)
  _on_dithering_toggled(file.get_value('palette', 'dithering', false))
  if _palettes_scanned:
    _world_option.select(maxi(_world_option.get_item_index(_palette_paths.find(world_palette) + 1), 0))
  _sync_controls()
  return true


# Every look uniform is set explicitly, so a saved look lists every one of them.
func _write_look_defaults() -> void:
  var defaults: Dictionary = look_defaults()
  for uniform: String in defaults:
    world_material.set_shader_parameter(uniform, defaults[uniform])


func _section_keys(file: ConfigFile, section: String) -> PackedStringArray:
  return file.get_section_keys(section) if file.has_section(section) else PackedStringArray()


## Clamp the screen to `colours`, or turn the clamp off with an empty array.
func set_palette(colours: PackedColorArray) -> void:
  _clamp_layer.visible = _write_palette(_clamp_material, colours)


## Clamp the combat corridor to the palette file at `path`, or turn the world clamp off with ''.
func set_world_palette(path: String) -> void:
  world_palette = path
  var colours: PackedColorArray = PaletteLoader.load_palette(path) if path != '' else PackedColorArray()
  _write_palette(world_material, colours)


# Writes `colours` into a clamp material's palette textures. Returns false (and sets no colours)
# for an empty array.
func _write_palette(material: ShaderMaterial, colours: PackedColorArray) -> bool:
  if colours.is_empty():
    material.set_shader_parameter('colour_count', 0)
    return false
  if colours.size() > MAX_COLOURS:
    push_warning('[DebugPanels] palette has %d colours; only the first %d are used' % [colours.size(), MAX_COLOURS])
  var count: int = mini(colours.size(), MAX_COLOURS)
  var rgb: Image = Image.create_empty(MAX_COLOURS, 1, false, Image.FORMAT_RGBA8)
  var lab: Image = Image.create_empty(MAX_COLOURS, 1, false, Image.FORMAT_RGBF)
  for i in count:
    rgb.set_pixel(i, 0, colours[i])
    var oklab: Vector3 = PaletteLoader.to_oklab(colours[i])
    lab.set_pixel(i, 0, Color(oklab.x, oklab.y, oklab.z))
  material.set_shader_parameter('palette_rgb', ImageTexture.create_from_image(rgb))
  material.set_shader_parameter('palette_lab', ImageTexture.create_from_image(lab))
  material.set_shader_parameter('colour_count', count)
  return true


# The palette folder is scanned on first open, not at startup, so headless tests and autotest
# runs do no extra work.
func _scan_palettes() -> void:
  _palettes_scanned = true
  _palette_option.clear()
  _world_option.clear()
  _palette_paths.clear()
  _palette_option.add_item('Off', 0)
  _world_option.add_item('Off', 0)
  var groups: Dictionary = PaletteLoader.find_palettes(PALETTE_ROOT)
  for folder: String in groups:
    if folder != '':
      _palette_option.add_separator(folder)
      _world_option.add_separator(folder)
    for path: String in groups[folder]:
      _palette_paths.append(path)
      var palette_name: String = path.get_file().get_basename()
      _palette_option.add_item(palette_name, _palette_paths.size())
      _world_option.add_item(palette_name, _palette_paths.size())
  _palette_option.select(0)
  _world_option.select(0)


func _sync_controls() -> void:
  _matching_option.select(1 if _perceptual else 0)
  _dithering_check.set_pressed_no_signal(_dithering)


func _on_palette_selected(index: int) -> void:
  var id: int = _palette_option.get_item_id(index)
  if id <= 0:
    set_palette(PackedColorArray())
    return
  set_palette(PaletteLoader.load_palette(_palette_paths[id - 1]))


func _on_world_palette_selected(index: int) -> void:
  var id: int = _world_option.get_item_id(index)
  set_world_palette('' if id <= 0 else _palette_paths[id - 1])


# Matching and dithering apply to both clamps.
func _on_matching_selected(index: int) -> void:
  _perceptual = index == 1
  _clamp_material.set_shader_parameter('perceptual', _perceptual)
  world_material.set_shader_parameter('perceptual', _perceptual)


func _on_dithering_toggled(on: bool) -> void:
  _dithering = on
  _clamp_material.set_shader_parameter('dithering', _dithering)
  world_material.set_shader_parameter('dithering', _dithering)
