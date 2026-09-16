class_name DebugPanelsAutoload
extends Node
## Dev-only debug panel (docs/systems/debug_panel.md). Registered as the `DebugPanels` autoload so the
## panel covers every screen, the corridor testbed and the combat sandbox. It owns the world material
## that the corridor is drawn through: the corridor look shader, with its world palette clamp
## (docs/systems/corridor_look.md, docs/systems/palette_clamp.md).
##
## F1 toggles the panel, F2 the look panel and F3 the print panel, in debug builds only. Choices last for the session
## only, unless saved as a look file or palette combo. Panel text is English on purpose:
## `tools/extract_pot.gd` skips `src/debug/`.

## Emitted after an interface palette is applied or reset, so nodes that copied `Colours` when built
## can copy them again.
signal interface_palette_changed

const PALETTE_ROOT: String = 'res://assets/palettes'
const SHORTLIST_DIR: String = 'res://assets/palettes/shortlist'
const PALETTE_COMBO_DIR: String = 'res://assets/palette_combos'
## Remembers the palette combo loaded at start-up, on this computer only.
const START_UP_PATH: String = 'user://debug_start_up.cfg'
## Start-up arguments that set palettes; any of them stops the start-up palette combo loading.
const PALETTE_ARGUMENTS: Array[String] = ['--world-palette=', '--ui-palette=', '--look=', '--palette-combo=']
const LOOK_DIR: String = 'res://assets/looks'
const PRINT_LOOK_DIR: String = 'res://assets/print_looks'
const FONT_DIR: String = 'res://assets/fonts/candidates'
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
## The interface palette file applied to `Colours` and the theme, or '' when none is.
var interface_palette: String = ''
## The font file chosen in the panel or with `--font=`, or '' for the game's default font.
var ui_font: String = ''

var _palette_paths: Array[String] = []   # item id - 1 -> palette path in the world palette option (id 0 = Off)
var _interface_palette_paths: Array[String] = []   # item id - 1 -> `.gpl` path in the interface palette option
var _font_paths: Array[String] = []   # item id - 1 -> font path in the font option (id 0 = game default)
var _default_font: Font = null   # the theme's own default font, kept so the panel can put it back
var _palettes_scanned: bool = false
var _perceptual: bool = false
var _dithering: bool = false
var _look_defaults: Dictionary = {}   # look shader uniform -> default value, read from its code

@onready var _look_layer: CanvasLayer = $LookLayer
@onready var _look_panel: LookPanel = $LookLayer/LookPanel
@onready var _print_layer: CanvasLayer = $PrintLayer
@onready var _print_panel: PrintPanel = $PrintLayer/PrintPanel
@onready var _panel_layer: CanvasLayer = $PanelLayer
@onready var _world_option: OptionButton = $PanelLayer/Panel/Rows/WorldPaletteRow/Option
@onready var _interface_option: OptionButton = $PanelLayer/Panel/Rows/InterfacePaletteRow/Option
@onready var _font_option: OptionButton = $PanelLayer/Panel/Rows/FontRow/Option
@onready var _matching_option: OptionButton = $PanelLayer/Panel/Rows/MatchingRow/Option
@onready var _dithering_check: CheckButton = $PanelLayer/Panel/Rows/DitheringRow/Check
@onready var _combo_name_edit: LineEdit = $PanelLayer/Panel/Rows/ComboSaveRow/NameEdit
@onready var _combo_save_button: Button = $PanelLayer/Panel/Rows/ComboSaveRow/SaveButton
@onready var _combo_option: OptionButton = $PanelLayer/Panel/Rows/ComboLoadRow/Option
@onready var _start_up_option: OptionButton = $PanelLayer/Panel/Rows/StartUpRow/Option


func _ready() -> void:
  _panel_layer.visible = false
  _look_layer.visible = false
  _print_layer.visible = false
  world_material.shader = LOOK_SHADER
  world_material.set_shader_parameter('dither_noise', BLUE_NOISE)
  _write_look_defaults()
  _write_palette(world_material, PackedColorArray())
  _world_option.item_selected.connect(_on_world_palette_selected)
  _interface_option.item_selected.connect(_on_interface_palette_selected)
  _font_option.item_selected.connect(_on_font_selected)
  _matching_option.item_selected.connect(_on_matching_selected)
  _dithering_check.toggled.connect(_on_dithering_toggled)
  _dithering_check.toggled.connect(func(_on: bool) -> void: _look_panel.refresh())
  _combo_save_button.pressed.connect(_on_combo_save_pressed)
  _combo_option.item_selected.connect(_on_combo_selected)
  _start_up_option.item_selected.connect(_on_start_up_selected)
  _sync_controls()
  _apply_start_up_palette_combo()
  _apply_command_line()


## Dev hooks for screenshots: `--world-palette=<res path>` sets the world clamp, `--perceptual` and `--dither` set
## the matching and dithering, `--look=<res path>` loads a saved look (applied first, so the other
## arguments can override it), `--print-look=<res path>` loads a saved print look and
## `--palette-combo=<res path>` a saved palette combo (also first),
## `--look-panel` opens the look panel, `--font=<res path>` sets the UI
## font, `--ui-palette=<res path>` applies an interface palette, `--background-set=uniform=value` sets a
## background wear setting, `--panel-set=uniform=value` sets a panel wear setting,
## `--print-set=name=value` sets a border, corridor overlay or layout setting, `--print-panel` opens the
## print panel.
func _apply_command_line() -> void:
  var args: PackedStringArray = OS.get_cmdline_user_args()
  for arg: String in args:
    if arg.begins_with('--look='):
      load_look(arg.substr(7))
    elif arg.begins_with('--print-look='):
      PrintLook.load_print_look(arg.substr(13))
    elif arg.begins_with('--palette-combo='):
      load_palette_combo(arg.substr(16))
  for arg: String in args:
    if arg.begins_with('--world-palette='):
      set_world_palette(arg.substr(16))
    elif arg.begins_with('--corridor-set='):
      var pair: PackedStringArray = arg.substr(15).split('=')
      if pair.size() == 2:
        corridor_settings[pair[0]] = str_to_var(pair[1])
    elif arg.begins_with('--monster-image='):
      MonsterImages.forced_path = arg.substr(16)
    elif arg.begins_with('--font='):
      set_ui_font(arg.substr(7))
    elif arg.begins_with('--ui-palette='):
      set_interface_palette(arg.substr(13))
    elif arg.begins_with('--background-set='):
      var setting: PackedStringArray = arg.substr(17).split('=')
      if setting.size() == 2 and PrintLook.background_defaults().has(setting[0]):
        PrintLook.background_material.set_shader_parameter(setting[0], str_to_var(setting[1]))
    elif arg.begins_with('--panel-set='):
      var panel_setting: PackedStringArray = arg.substr(12).split('=')
      if panel_setting.size() == 2 and PrintLook.panel_defaults().has(panel_setting[0]):
        PrintLook.panel_material.set_shader_parameter(panel_setting[0], str_to_var(panel_setting[1]))
    elif arg.begins_with('--print-set='):
      var print_pair: PackedStringArray = arg.substr(12).split('=')
      if print_pair.size() == 2:
        PrintLook.set_print_value(print_pair[0], str_to_var(print_pair[1]))
  if '--perceptual' in args:
    _on_matching_selected(1)
  if '--dither' in args:
    _on_dithering_toggled(true)
  if '--look-panel' in args:
    toggle_look_panel()
  if '--print-panel' in args:
    toggle_print_panel()
  _sync_controls()


func _exit_tree() -> void:
  _palette_paths.clear()
  _interface_palette_paths.clear()
  _font_paths.clear()
  InterfacePalette.reset()


func _input(event: InputEvent) -> void:
  if not OS.is_debug_build():
    return
  var key: InputEventKey = event as InputEventKey
  if key == null or not key.pressed or key.echo:
    return
  # Typing a look or palette combo name must not trigger the palette keys.
  if get_viewport().gui_get_focus_owner() is LineEdit and key.keycode not in [KEY_F1, KEY_F2, KEY_F3]:
    return
  match key.keycode:
    KEY_F1:
      toggle_panel()
    KEY_F2:
      toggle_look_panel()
    KEY_F3:
      toggle_print_panel()
    KEY_BRACKETLEFT:
      cycle_palette(-1)
    KEY_BRACKETRIGHT:
      cycle_palette(1)
    KEY_SEMICOLON:
      cycle_interface_palette(-1)
    KEY_APOSTROPHE:
      cycle_interface_palette(1)
    KEY_BACKSLASH:
      shortlist_palette()
    _:
      return
  get_viewport().set_input_as_handled()


func toggle_panel() -> void:
  if not _palettes_scanned:
    _scan_palettes()
  if _font_option.item_count <= 1:
    _scan_fonts()
  _panel_layer.visible = not _panel_layer.visible
  if _panel_layer.visible:
    _list_palette_combos()


## Show or hide the look panel. Its controls are built the first time it opens.
func toggle_look_panel() -> void:
  _look_layer.visible = not _look_layer.visible
  if _look_layer.visible:
    _look_panel.open()


## Show or hide the print panel. Its controls are built the first time it opens.
func toggle_print_panel() -> void:
  _print_layer.visible = not _print_layer.visible
  if _print_layer.visible:
    _print_panel.open()


## Select the next (`step` 1) or previous (`step` -1) entry in the world palette list. Bound to ] and [.
func cycle_palette(step: int) -> void:
  _on_world_palette_selected(_step_option(_world_option, step))


## Select the next (`step` 1) or previous (`step` -1) entry in the interface palette list. Bound to '
## and ;.
func cycle_interface_palette(step: int) -> void:
  _on_interface_palette_selected(_step_option(_interface_option, step))


# Selects the next or previous entry in a palette option, skipping folder headings and wrapping
# through "Off". Returns the new index.
func _step_option(option: OptionButton, step: int) -> int:
  if not _palettes_scanned:
    _scan_palettes()
  var count: int = option.item_count
  var index: int = option.selected
  for i in count:
    index = posmod(index + step, count)
    if not option.is_item_separator(index):
      break
  option.select(index)
  return index


## Move the selected world palette into `SHORTLIST_DIR`, then rescan and keep it selected at its new
## path. Does nothing when "Off" is selected or the palette is already there. Bound to \.
func shortlist_palette() -> void:
  if not _palettes_scanned:
    return
  var id: int = _world_option.get_selected_id()
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
    _world_option.select(_world_option.get_item_index(new_id))
    _on_world_palette_selected(_world_option.selected)


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


## Save the palette choices to a text file at `path`: the world and interface palettes, colour
## matching and dithering.
func save_palette_combo(path: String) -> Error:
  var file: ConfigFile = ConfigFile.new()
  file.set_value('palettes', 'world_palette', world_palette)
  file.set_value('palettes', 'interface_palette', interface_palette)
  file.set_value('palettes', 'perceptual', _perceptual)
  file.set_value('palettes', 'dithering', _dithering)
  DirAccess.make_dir_recursive_absolute(path.get_base_dir())
  return file.save(path)


## Apply a palette combo saved by `save_palette_combo`. Returns false if the file cannot be read.
func load_palette_combo(path: String) -> bool:
  var file: ConfigFile = ConfigFile.new()
  if file.load(path) != OK:
    push_warning('[DebugPanels] could not read palette combo file %s' % path)
    return false
  set_world_palette(file.get_value('palettes', 'world_palette', ''))
  set_interface_palette(file.get_value('palettes', 'interface_palette', ''))
  _on_matching_selected(1 if file.get_value('palettes', 'perceptual', false) else 0)
  _on_dithering_toggled(file.get_value('palettes', 'dithering', false))
  _sync_controls()
  _look_panel.refresh()
  return true


## The file a palette combo named `combo_name` is saved in.
static func palette_combo_path(combo_name: String) -> String:
  return PALETTE_COMBO_DIR.path_join(combo_name + '.cfg')


## The name of the palette combo chosen in "Load at start-up", or '' for none.
static func start_up_palette_combo() -> String:
  var file: ConfigFile = ConfigFile.new()
  if file.load(START_UP_PATH) != OK:
    return ''
  return file.get_value('start_up', 'palette_combo', '')


## Load the palette combo named `combo_name` at start-up from now on, or none with ''.
static func set_start_up_palette_combo(combo_name: String) -> void:
  var file: ConfigFile = ConfigFile.new()
  file.load(START_UP_PATH)
  file.set_value('start_up', 'palette_combo', combo_name)
  file.save(START_UP_PATH)


## Whether the start-up palette combo may load. It does not in headless runs (tests, autotest),
## screenshot runs (`--shot`), or when an argument in `PALETTE_ARGUMENTS` sets the palettes, so those
## runs stay predictable.
static func start_up_combo_allowed(args: PackedStringArray, headless: bool) -> bool:
  if headless or '--shot' in args:
    return false
  for arg: String in args:
    for prefix: String in PALETTE_ARGUMENTS:
      if arg.begins_with(prefix):
        return false
  return true


func _apply_start_up_palette_combo() -> void:
  var args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
  if not OS.is_debug_build() or not start_up_combo_allowed(args, DisplayServer.get_name() == 'headless'):
    return
  var combo_name: String = start_up_palette_combo()
  if combo_name != '':
    load_palette_combo(palette_combo_path(combo_name))


# Saved palette combos are listed each time the panel opens, in both the load and start-up options.
func _list_palette_combos() -> void:
  _combo_option.clear()
  _start_up_option.clear()
  _combo_option.add_item('Load a combo...')
  _start_up_option.add_item('None')
  var start_up: String = start_up_palette_combo()
  if DirAccess.dir_exists_absolute(PALETTE_COMBO_DIR):
    for file: String in DirAccess.get_files_at(PALETTE_COMBO_DIR):
      if file.get_extension() != 'cfg':
        continue
      _combo_option.add_item(file.get_basename())
      _start_up_option.add_item(file.get_basename())
      if file.get_basename() == start_up:
        _start_up_option.select(_start_up_option.item_count - 1)
  _combo_option.select(0)


func _on_combo_save_pressed() -> void:
  var combo_name: String = _combo_name_edit.text.strip_edges().to_snake_case().validate_filename()
  if combo_name == '':
    return
  save_palette_combo(palette_combo_path(combo_name))
  _combo_name_edit.release_focus()
  _list_palette_combos()


func _on_combo_selected(index: int) -> void:
  if index <= 0:
    return
  var combo_name: String = _combo_option.get_item_text(index)
  if load_palette_combo(palette_combo_path(combo_name)):
    _combo_name_edit.text = combo_name


func _on_start_up_selected(index: int) -> void:
  set_start_up_palette_combo('' if index <= 0 else _start_up_option.get_item_text(index))


## Back to the defaults: world clamp off, no interface palette, every look effect off, no corridor
## settings, random enemy images. Used between tests.
func reset_settings() -> void:
  reset_look()
  PrintLook.reset_print_look()
  MonsterImages.forced_path = ''
  set_interface_palette('')
  if ui_font != '':
    restore_default_font()
  _font_option.select(0)
  _sync_controls()
  _look_panel.refresh()
  _print_panel.refresh()


## Every look shader uniform with a default in the shader code or its palette clamp include (uniform
## name -> value), except `PALETTE_UNIFORMS`.
func look_defaults() -> Dictionary:
  if _look_defaults.is_empty():
    _look_defaults = _uniform_defaults(LOOK_SHADER.code + '\n' + PALETTE_INCLUDE.code, PALETTE_UNIFORMS)
  return _look_defaults


# Reads `uniform <type> <name> ... = <value>;` defaults from shader code, because the rendering server
# does not report them when running headless.
static func _uniform_defaults(code: String, skip: Array[String]) -> Dictionary:
  var defaults: Dictionary = {}
  var pattern: RegEx = RegEx.create_from_string('uniform\\s+(\\w+)\\s+(\\w+)[^=;]*=\\s*([^;]+);')
  for found: RegExMatch in pattern.search_all(code):
    var text: String = found.get_string(3).strip_edges()
    if found.get_string(2) in skip:
      continue
    match found.get_string(1):
      'bool':
        defaults[found.get_string(2)] = text == 'true'
      'int':
        defaults[found.get_string(2)] = text.to_int()
      'float':
        defaults[found.get_string(2)] = text.to_float()
      'vec3':
        var parts: PackedStringArray = text.trim_prefix('vec3(').trim_suffix(')').split(',')
        defaults[found.get_string(2)] = Color(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
  return defaults


## Every corridor look effect back to its shader default, no corridor or environment settings, world
## palette off, RGB matching, no dithering. Corridors on screen go back to their scene values. The print
## look is unchanged.
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
  _sync_controls()


## Turn dithering on or off for the world clamp, keeping the F1 panel's switch in step.
func set_dithering(on: bool) -> void:
  _on_dithering_toggled(on)
  _sync_controls()


func is_dithering() -> bool:
  return _dithering


## Apply `corridor_settings` and `environment_settings` to every corridor on screen.
func apply_corridor_settings() -> void:
  for corridor: Corridor3D in get_tree().get_nodes_in_group(Corridor3D.GROUP):
    corridor.apply_settings(corridor_settings, environment_settings)


## Save the current corridor look to a text file at `path`: the look shader settings, the corridor and
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
  _sync_controls()
  return true


# Every uniform is set explicitly, so a saved look lists every one of them.
func _write_look_defaults() -> void:
  var defaults: Dictionary = look_defaults()
  for uniform: String in defaults:
    world_material.set_shader_parameter(uniform, defaults[uniform])


func _section_keys(file: ConfigFile, section: String) -> PackedStringArray:
  return file.get_section_keys(section) if file.has_section(section) else PackedStringArray()


## Use the font file at `path` as the project theme's default font, for comparing fonts. It replaces
## the theme's own default font until `restore_default_font()` puts that back.
func set_ui_font(path: String) -> void:
  var font: Font = load(path) as Font
  if font == null:
    push_warning('[DebugPanels] could not load font %s' % path)
    return
  var theme: Theme = load(Prefs.THEME_PATH) as Theme
  if _default_font == null:
    _default_font = theme.default_font
  theme.set_default_font(font)
  ui_font = path


## Put the theme's own default font back, undoing `set_ui_font()`.
func restore_default_font() -> void:
  ui_font = ''
  if _default_font != null:
    (load(Prefs.THEME_PATH) as Theme).set_default_font(_default_font)


## Apply the interface palette file at `path` to `Colours` and the theme, or go back to the default
## colours with ''. Statuses in the current fight are recoloured, and `interface_palette_changed` tells
## nodes that copied colours when built.
func set_interface_palette(path: String) -> void:
  interface_palette = path
  if path == '':
    InterfacePalette.reset()
  else:
    InterfacePalette.apply(path)
  _recolour_fight_statuses()
  PrintLook.push_wear_colours()
  interface_palette_changed.emit()


# Statuses copy their colour from `Colours` when created, so each one in the current fight takes the
# colour a new status of its class would have.
func _recolour_fight_statuses() -> void:
  if Game.run == null or Game.run.combat_manager() == null:
    return
  var fight: CombatManager = Game.run.combat_manager()
  for actor: Actor in [fight.player] + fight.enemies + fight.allies:
    if actor == null:
      continue
    var statuses: Array[StatusEffect] = actor.statuses.duplicate()
    for item: Item in actor.board:
      statuses.append_array(item.statuses)
    for status: StatusEffect in statuses:
      status.color = ((status.get_script() as GDScript).new() as StatusEffect).color


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
  _world_option.clear()
  _interface_option.clear()
  _palette_paths.clear()
  _interface_palette_paths.clear()
  _world_option.add_item('Off', 0)
  _interface_option.add_item('Off', 0)
  var groups: Dictionary = PaletteLoader.find_palettes(PALETTE_ROOT)
  for folder: String in groups:
    if folder != '':
      _world_option.add_separator(folder)
    for path: String in groups[folder]:
      _palette_paths.append(path)
      var palette_name: String = path.get_file().get_basename()
      _world_option.add_item(palette_name, _palette_paths.size())
      if InterfacePalette.is_interface_palette(path):
        _interface_palette_paths.append(path)
        _interface_option.add_item(folder.path_join(palette_name), _interface_palette_paths.size())
  _sync_controls()


# Shows the current choices in the panel's controls, without applying anything.
func _sync_controls() -> void:
  _matching_option.select(1 if _perceptual else 0)
  _dithering_check.set_pressed_no_signal(_dithering)
  if _palettes_scanned:
    _world_option.select(maxi(_world_option.get_item_index(_palette_paths.find(world_palette) + 1), 0))
    _interface_option.select(maxi(_interface_option.get_item_index(_interface_palette_paths.find(interface_palette) + 1), 0))


func _on_world_palette_selected(index: int) -> void:
  var id: int = _world_option.get_item_id(index)
  set_world_palette('' if id <= 0 else _palette_paths[id - 1])


func _on_interface_palette_selected(index: int) -> void:
  var id: int = _interface_option.get_item_id(index)
  set_interface_palette('' if id <= 0 else _interface_palette_paths[id - 1])


# The font folder is scanned when the panel first opens, like the palettes. Deleting a font file
# removes its option.
func _scan_fonts() -> void:
  _font_option.clear()
  _font_paths.clear()
  _font_option.add_item('Game default', 0)
  if DirAccess.dir_exists_absolute(FONT_DIR):
    for file: String in DirAccess.get_files_at(FONT_DIR):
      if file.get_extension().to_lower() in ['ttf', 'otf']:
        _font_paths.append(FONT_DIR.path_join(file))
        _font_option.add_item(file.get_basename(), _font_paths.size())
  _font_option.select(maxi(_font_option.get_item_index(_font_paths.find(ui_font) + 1), 0))


# "Game default" (id 0) puts back the theme's own font.
func _on_font_selected(index: int) -> void:
  var id: int = _font_option.get_item_id(index)
  if id <= 0:
    restore_default_font()
    return
  set_ui_font(_font_paths[id - 1])


func _on_matching_selected(index: int) -> void:
  _perceptual = index == 1
  world_material.set_shader_parameter('perceptual', _perceptual)


func _on_dithering_toggled(on: bool) -> void:
  _dithering = on
  world_material.set_shader_parameter('dithering', _dithering)
