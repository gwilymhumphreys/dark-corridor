class_name DebugPanelsAutoload
extends Node
## Dev-only debug panel (docs/systems/debug_panel.md). Registered as the `DebugPanels` autoload so the
## panel covers every screen, the corridor testbed and the combat sandbox. It owns the world material
## that the corridor is drawn through: the corridor look shader, with its world palette clamp
## (docs/systems/corridor_look.md, docs/systems/palette_clamp.md).
##
## One panel with a preset bar and four tabs: corridor look with its palette (F1), interface look with
## its palettes (F2), print look (F3) and background wear (F4); each key opens its tab, in
## debug builds only. Choices last for the session only, unless saved as a look preset
## (docs/systems/look_presets.md). The default preset loads at start-up.
## Panel text is English on purpose: `tools/extract_pot.gd` skips `src/debug/`.

## Emitted after an interface palette is applied or reset, so nodes that copied `Colours` when built
## can copy them again.
signal interface_palette_changed
## Emitted with true when the panel opens and false when it closes. The run screen pauses on it.
signal panels_open_changed(open: bool)

const PALETTE_ROOT: String = 'res://assets/palettes'
const SHORTLIST_DIR: String = 'res://assets/palettes/shortlist'
## `portrait_palette` values that follow another palette instead of naming a file.
const PORTRAIT_SAME_AS_CORRIDOR: String = 'corridor'
const PORTRAIT_SAME_AS_INTERFACE: String = 'interface'
## The first item id in the portrait palette option that names a palette file.
const PORTRAIT_FIRST_FILE_ID: int = 3
const MAX_COLOURS: int = 64   # must match MAX_COLOURS in palette_clamp.gdshaderinc
const LOOK_SHADER: Shader = preload('res://src/shaders/corridor_look.gdshader')
const PALETTE_INCLUDE: ShaderInclude = preload('res://src/shaders/palette_clamp.gdshaderinc')
const LOOK_EFFECTS_INCLUDE: ShaderInclude = preload('res://src/shaders/look_effects.gdshaderinc')
const BLUE_NOISE: Texture2D = preload('res://assets/textures/blue_noise_64.png')
## Palette clamp uniforms set from the palette rows and the palette sections of a preset, so they are
## not corridor look settings.
const PALETTE_UNIFORMS: Array[String] = ['colour_count', 'perceptual', 'dithering']
## Tab titles, by tab. The tabs are in `LookPresets.Part` order.
const TAB_TITLES: Dictionary = {
  LookPresets.Part.CORRIDOR: 'Corridor (F1)',
  LookPresets.Part.INTERFACE: 'Interface (F2)',
  LookPresets.Part.PRINT: 'Print (F3)',
  LookPresets.Part.BACKGROUND: 'Background (F4)',
}
## The tab each key opens.
const TAB_KEYS: Dictionary = {
  KEY_F1: LookPresets.Part.CORRIDOR,
  KEY_F2: LookPresets.Part.INTERFACE,
  KEY_F3: LookPresets.Part.PRINT,
  KEY_F4: LookPresets.Part.BACKGROUND,
}

## Corridor exports (property -> value), from `--corridor-set=property=value` arguments, the corridor
## tab and presets. Corridors apply them when built.
var corridor_settings: Dictionary = {}
## Properties of the corridor camera's Environment (property -> value), from the corridor tab and
## presets. Corridors apply them when built.
var environment_settings: Dictionary = {}
## The palette file the world clamp on the combat corridor uses, or '' when it is off.
var world_palette: String = ''
## The material every corridor is drawn through (corridor_look.gdshader). Its palette follows
## `world_palette`.
var world_material: ShaderMaterial = ShaderMaterial.new()
## The interface palette file applied to `Colours` and the theme, or '' when none is.
var interface_palette: String = ''
## What interface images are clamped to: '' for off, `PORTRAIT_SAME_AS_CORRIDOR`,
## `PORTRAIT_SAME_AS_INTERFACE`, or a palette file path.
var portrait_palette: String = PORTRAIT_SAME_AS_INTERFACE

var _palette_paths: Array[String] = []   # item id - 1 -> palette path in the world palette option (id 0 = Off)
var _interface_palette_paths: Array[String] = []   # item id - 1 -> `.gpl` path in the interface palette option
var _palettes_scanned: bool = false
var _perceptual: bool = false
var _dithering: bool = false
var _interface_dithering: bool = false   # the interface clamp's dithering switch
var _look_defaults: Dictionary = {}   # look shader uniform -> default value, read from its code
var _scene_values: Array[Dictionary] = []   # the corridor scene's Light and Environment values, read once

@onready var _panel_layer: CanvasLayer = $PanelLayer
@onready var _panel: PanelContainer = $PanelLayer/Panel
@onready var _preset_bar: PresetBar = $PanelLayer/Panel/Rows/PresetBar
@onready var _tabs: TabContainer = $PanelLayer/Panel/Rows/Tabs
@onready var _look_panel: LookPanel = $PanelLayer/Panel/Rows/Tabs/Corridor
@onready var _interface_look_panel: InterfaceLookPanel = $PanelLayer/Panel/Rows/Tabs/Interface
@onready var _print_panel: PrintPanel = $PanelLayer/Panel/Rows/Tabs/Print
@onready var _background_panel: BackgroundPanel = $PanelLayer/Panel/Rows/Tabs/Background
@onready var _world_option: OptionButton = $PanelLayer/Panel/Rows/Tabs/Corridor/PaletteRows/WorldPaletteRow/Option
@onready var _matching_option: OptionButton = $PanelLayer/Panel/Rows/Tabs/Corridor/PaletteRows/MatchingRow/Option
@onready var _interface_option: OptionButton = $PanelLayer/Panel/Rows/Tabs/Interface/PaletteRows/InterfacePaletteRow/Option
@onready var _portrait_option: OptionButton = $PanelLayer/Panel/Rows/Tabs/Interface/PaletteRows/PortraitPaletteRow/Option

func _ready() -> void:
  _panel_layer.visible = false
  for tab: int in TAB_TITLES:
    _tabs.set_tab_title(tab, TAB_TITLES[tab])
  _tabs.tab_changed.connect(_on_tab_changed)
  _preset_bar.preset_loaded.connect(refresh_panels)
  _preset_bar.side_switched.connect(_switch_side)
  world_material.shader = LOOK_SHADER
  world_material.set_shader_parameter('dither_noise', BLUE_NOISE)
  InterfaceLook.material.set_shader_parameter('dither_noise', BLUE_NOISE)
  _write_look_defaults()
  _write_palette(world_material, PackedColorArray())
  _world_option.item_selected.connect(_on_world_palette_selected)
  _interface_option.item_selected.connect(_on_interface_palette_selected)
  _portrait_option.item_selected.connect(_on_portrait_palette_selected)
  _matching_option.item_selected.connect(_on_matching_selected)
  _sync_controls()
  LookPresets.load_default()
  _apply_command_line()


## Dev hooks for screenshots, applied after the default preset: `--preset=<name or res path>` loads a
## preset (applied first, so the other arguments can override it), `--world-palette=<res path>` sets
## the world clamp, `--perceptual` and `--dither` set the matching and the world clamp's dithering,
## `--interface-dither` the interface clamp's, `--ui-palette=<res path>` applies an interface palette,
## `--portrait-palette=<res path, corridor or interface>` sets the portrait palette,
## `--corridor-set=property=value` sets a corridor export, `--background-set=uniform=value` a background
## wear setting, `--panel-set=uniform=value` a panel wear setting, `--print-set=name=value` a border,
## corridor overlay or layout setting, `--interface-set=uniform=value` an interface look setting.
## `--look-panel`, `--interface-panel`, `--print-panel` and `--background-panel` open the panel on that
## tab.
func _apply_command_line() -> void:
  var args: PackedStringArray = OS.get_cmdline_user_args()
  for arg: String in args:
    if arg.begins_with('--preset='):
      var preset: String = arg.substr(9)
      var preset_path: String = preset if preset.begins_with('res://') else LookPresets.preset_path(preset)
      if LookPresets.load_preset(preset_path):
        _preset_bar.remember_loaded(preset_path)
  for arg: String in args:
    if arg.begins_with('--world-palette='):
      set_world_palette(arg.substr(16))
    elif arg.begins_with('--corridor-set='):
      var pair: PackedStringArray = arg.substr(15).split('=')
      if pair.size() == 2:
        corridor_settings[pair[0]] = str_to_var(pair[1])
    elif arg.begins_with('--monster-image='):
      MonsterImages.forced_path = arg.substr(16)
    elif arg.begins_with('--ui-palette='):
      set_interface_palette(arg.substr(13))
    elif arg.begins_with('--portrait-palette='):
      set_portrait_palette(arg.substr(19))
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
    elif arg.begins_with('--interface-set='):
      var interface_pair: PackedStringArray = arg.substr(16).split('=')
      if interface_pair.size() == 2 and InterfaceLook.defaults().has(interface_pair[0]):
        InterfaceLook.set_setting(interface_pair[0], str_to_var(interface_pair[1]))
  if '--perceptual' in args:
    _on_matching_selected(1)
  if '--dither' in args:
    _on_dithering_toggled(true)
  if '--interface-dither' in args:
    _on_interface_dithering_toggled(true)
  if '--look-panel' in args:
    toggle_tab(LookPresets.Part.CORRIDOR)
  elif '--interface-panel' in args:
    toggle_tab(LookPresets.Part.INTERFACE)
  elif '--print-panel' in args:
    toggle_tab(LookPresets.Part.PRINT)
  elif '--background-panel' in args:
    toggle_tab(LookPresets.Part.BACKGROUND)
  _sync_controls()


func _exit_tree() -> void:
  _palette_paths.clear()
  _interface_palette_paths.clear()
  InterfacePalette.reset()


func _input(event: InputEvent) -> void:
  if not OS.is_debug_build():
    return
  var key: InputEventKey = event as InputEventKey
  if key == null or not key.pressed or key.echo:
    return
  # Typing a preset name must not trigger the palette keys (Backspace included).
  if get_viewport().gui_get_focus_owner() is LineEdit and not TAB_KEYS.has(key.keycode):
    return
  if TAB_KEYS.has(key.keycode):
    toggle_tab(TAB_KEYS[key.keycode])
    get_viewport().set_input_as_handled()
    return
  match key.keycode:
    KEY_BRACKETLEFT:
      cycle_palette(-1)
    KEY_BRACKETRIGHT:
      cycle_palette(1)
    KEY_SEMICOLON:
      cycle_interface_palette(-1)
    KEY_APOSTROPHE:
      cycle_interface_palette(1)
    KEY_PERIOD:
      cycle_portrait_palette(1)
    KEY_COMMA:
      cycle_portrait_palette(-1)
    KEY_BACKSLASH:
      shortlist_palette()
    KEY_BACKSPACE:
      set_dithering(not _dithering)
      _look_panel.refresh()
    _:
      return
  get_viewport().set_input_as_handled()


## Open the panel on `tab` (a `LookPresets.Part`), or close it if it is already showing that tab.
func toggle_tab(tab: int) -> void:
  if _panel_layer.visible and _tabs.current_tab == tab:
    _panel_layer.visible = false
    panels_open_changed.emit(false)
    return
  var was_open: bool = _panel_layer.visible
  _panel_layer.visible = true
  if _tabs.current_tab == tab:
    _open_tab(tab)
  else:
    _tabs.current_tab = tab   # fills it through `_on_tab_changed`
  if not was_open:
    _preset_bar.open()
    panels_open_changed.emit(true)


## True while the panel is showing.
func is_panel_open() -> bool:
  return _panel_layer.visible


# Fill a tab when it shows: its controls, and the palette lists the first time.
func _open_tab(tab: int) -> void:
  match tab:
    LookPresets.Part.CORRIDOR:
      if not _palettes_scanned:
        _scan_palettes()
      _look_panel.open()
    LookPresets.Part.INTERFACE:
      if not _palettes_scanned:
        _scan_palettes()
      _interface_look_panel.open()
    LookPresets.Part.PRINT:
      _print_panel.open()
    LookPresets.Part.BACKGROUND:
      _background_panel.open()


func _on_tab_changed(tab: int) -> void:
  if _panel_layer.visible:
    _open_tab(tab)


# Move the panel to the other side of the screen, so it does not cover what is being changed.
func _switch_side() -> void:
  var width: float = _panel.offset_right - _panel.offset_left
  var on_right: bool = _panel.anchor_left > 0.5
  _panel.anchor_left = 0.0 if on_right else 1.0
  _panel.anchor_right = _panel.anchor_left
  _panel.offset_left = 24.0 if on_right else -24.0 - width
  _panel.offset_right = _panel.offset_left + width


## Show the current settings in every tab, after a preset or part of one is loaded.
func refresh_panels() -> void:
  _sync_controls()
  _look_panel.refresh()
  _interface_look_panel.refresh()
  _print_panel.refresh()
  _background_panel.refresh()


## Rebuild the Corridor tab's controls after corridor look settings change elsewhere (the Interface
## tab's copy button).
func refresh_look_panel() -> void:
  _look_panel.refresh()


## Select the next (`step` 1) or previous (`step` -1) entry in the world palette list. Bound to ] and [.
func cycle_palette(step: int) -> void:
  _on_world_palette_selected(_step_option(_world_option, step))


## Select the next (`step` 1) or previous (`step` -1) entry in the interface palette list. Bound to '
## and ;.
func cycle_interface_palette(step: int) -> void:
  _on_interface_palette_selected(_step_option(_interface_option, step))


## Select the next (`step` 1) or previous (`step` -1) entry in the portrait palette list. Bound to .
## and ,.
func cycle_portrait_palette(step: int) -> void:
  _on_portrait_palette_selected(_step_option(_portrait_option, step))


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
  replace_palette_path([LookPresets.PRESET_DIR, LookPresets.HISTORY_DIR], old_path, new_path)
  if portrait_palette == old_path:
    portrait_palette = new_path
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


## Rewrite `old_path` to `new_path` in every `.cfg` file in `folders`, so saved presets still find a
## palette after it is moved.
static func replace_palette_path(folders: Array[String], old_path: String, new_path: String) -> void:
  for folder: String in folders:
    if not DirAccess.dir_exists_absolute(folder):
      continue
    for file_name: String in DirAccess.get_files_at(folder):
      if file_name.get_extension() != 'cfg':
        continue
      var file_path: String = folder.path_join(file_name)
      var text: String = FileAccess.get_file_as_string(file_path)
      if not text.contains('"%s"' % old_path):
        continue
      var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
      if file == null:
        push_warning('[DebugPanels] could not update palette path in %s' % file_path)
        continue
      file.store_string(text.replace('"%s"' % old_path, '"%s"' % new_path))
      file.close()


## Write the corridor's palette choices into a preset's corridor part: the world palette, colour
## matching and dithering.
func write_corridor_palette(file: ConfigFile) -> void:
  file.set_value('corridor_palette', 'world_palette', world_palette)
  file.set_value('corridor_palette', 'perceptual', _perceptual)
  file.set_value('corridor_palette', 'dithering', _dithering)


## Set the corridor's palette choices from a preset file written by `write_corridor_palette`. Choices
## the file leaves out go back to their defaults.
func read_corridor_palette(file: ConfigFile) -> void:
  set_world_palette(file.get_value('corridor_palette', 'world_palette', ''))
  _on_matching_selected(1 if file.get_value('corridor_palette', 'perceptual', false) else 0)
  _on_dithering_toggled(file.get_value('corridor_palette', 'dithering', false))
  _sync_controls()
  _look_panel.refresh()


## Write the interface's palette choices into a preset's interface part: the interface and portrait
## palettes and the interface clamp's dithering switch.
func write_interface_palettes(file: ConfigFile) -> void:
  file.set_value('interface_palette', 'interface_palette', interface_palette)
  file.set_value('interface_palette', 'portrait_palette', portrait_palette)
  file.set_value('interface_palette', 'dithering', _interface_dithering)


## Set the interface's palette choices from a preset file written by `write_interface_palettes`.
## Choices the file leaves out go back to their defaults.
func read_interface_palettes(file: ConfigFile) -> void:
  set_interface_palette(file.get_value('interface_palette', 'interface_palette', ''))
  set_portrait_palette(file.get_value('interface_palette', 'portrait_palette', PORTRAIT_SAME_AS_INTERFACE))
  _on_interface_dithering_toggled(file.get_value('interface_palette', 'dithering', false))
  _sync_controls()
  _interface_look_panel.refresh()


## Palettes back to their defaults: world clamp off, no interface palette, portrait palette same as
## interface, RGB matching, no dithering in either clamp.
func reset_palettes() -> void:
  read_corridor_palette(ConfigFile.new())
  read_interface_palettes(ConfigFile.new())


## Every part of the look back to its defaults, with every effect off (not the default preset), and
## random enemy images. Used between tests.
func reset_settings() -> void:
  reset_look()
  PrintLook.reset_print_look()
  PrintLook.reset_background_look()
  InterfaceLook.reset()
  MonsterImages.forced_path = ''
  reset_palettes()
  _preset_bar.forget_loaded()
  refresh_panels()


## Every look shader uniform with a default in the shader code, its shared effects include or its
## palette clamp include (uniform name -> value), except `PALETTE_UNIFORMS`.
func look_defaults() -> Dictionary:
  if _look_defaults.is_empty():
    var code: String = LOOK_SHADER.code + '\n' + LOOK_EFFECTS_INCLUDE.code + '\n' + PALETTE_INCLUDE.code
    _look_defaults = _uniform_defaults(code, PALETTE_UNIFORMS)
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


## Every corridor look effect back to its shader default, and no corridor or environment settings.
## Corridors on screen go back to their scene values. The palettes and the other parts are unchanged.
func reset_look() -> void:
  _write_look_defaults()
  corridor_settings.clear()
  environment_settings.clear()
  var corridors: Array[Node] = get_tree().get_nodes_in_group(Corridor3D.GROUP)
  for corridor: Corridor3D in corridors:
    corridor.apply_settings(scene_values()[0], scene_values()[1])


## Turn dithering on or off for the world clamp. The Corridor tab's Dithering switch shows it after a
## refresh.
func set_dithering(on: bool) -> void:
  _on_dithering_toggled(on)


func is_dithering() -> bool:
  return _dithering


## Turn dithering on or off for the interface clamp, which is separate from the corridor's. The
## Interface tab's Dithering switch shows it after a refresh.
func set_interface_dithering(on: bool) -> void:
  _on_interface_dithering_toggled(on)


func is_interface_dithering() -> bool:
  return _interface_dithering


## Apply `corridor_settings` and `environment_settings` to every corridor on screen.
func apply_corridor_settings() -> void:
  for corridor: Corridor3D in get_tree().get_nodes_in_group(Corridor3D.GROUP):
    corridor.apply_settings(corridor_settings, environment_settings)


## The corridor scene's own values for the Light and Environment properties, as
## [corridor property -> value, environment property -> value]. Read from the scene once.
func scene_values() -> Array[Dictionary]:
  if _scene_values.is_empty():
    _scene_values = LookPanel.scene_values()
  return _scene_values


## Write the corridor look part of a preset: every look shader setting, and every Light and Environment
## setting, changed or not.
func write_corridor_look(file: ConfigFile) -> void:
  for uniform: String in look_defaults():
    file.set_value('corridor_shader', uniform, world_material.get_shader_parameter(uniform))
  for property: String in LookPanel.CORRIDOR_PROPERTIES:
    file.set_value('corridor_light', property, corridor_settings.get(property, scene_values()[0][property]))
  for property: String in LookPanel.environment_properties():
    file.set_value('corridor_environment', property, environment_settings.get(property, scene_values()[1][property]))


## Set the corridor look from a preset file written by `write_corridor_look`, starting from the
## defaults.
func read_corridor_look(file: ConfigFile) -> void:
  reset_look()
  var defaults: Dictionary = look_defaults()
  for uniform: String in _section_keys(file, 'corridor_shader'):
    if defaults.has(uniform):
      world_material.set_shader_parameter(uniform, file.get_value('corridor_shader', uniform))
  for property: String in _section_keys(file, 'corridor_light'):
    corridor_settings[property] = file.get_value('corridor_light', property)
  for property: String in _section_keys(file, 'corridor_environment'):
    environment_settings[property] = file.get_value('corridor_environment', property)
  apply_corridor_settings()


# Every uniform is set explicitly, so a saved preset lists every one of them.
func _write_look_defaults() -> void:
  var defaults: Dictionary = look_defaults()
  for uniform: String in defaults:
    world_material.set_shader_parameter(uniform, defaults[uniform])


func _section_keys(file: ConfigFile, section: String) -> PackedStringArray:
  return file.get_section_keys(section) if file.has_section(section) else PackedStringArray()


## Apply the interface palette file at `path` to `Colours` and the theme, or go back to the default
## colours with ''. Interface images are clamped to the portrait palette's colours through
## `InterfaceLook.material`. Statuses in the current fight are recoloured, and
## `interface_palette_changed` tells nodes that copied colours when built.
func set_interface_palette(path: String) -> void:
  interface_palette = path
  if path == '':
    InterfacePalette.reset()
  else:
    InterfacePalette.apply(path)
  _apply_portrait_palette()
  _recolour_fight_statuses()
  PrintLook.push_wear_colours()
  InterfaceLook.push_wear_colours()
  interface_palette_changed.emit()


## Set what interface images are clamped to: '' for off, `PORTRAIT_SAME_AS_CORRIDOR` for the world
## palette, `PORTRAIT_SAME_AS_INTERFACE` for the interface palette, or a palette file path. The
## colours are written into `InterfaceLook.material`.
func set_portrait_palette(choice: String) -> void:
  portrait_palette = choice
  _apply_portrait_palette()


# Writes the portrait palette's colours into `InterfaceLook.material`: the world palette's colours
# for `PORTRAIT_SAME_AS_CORRIDOR`, the interface palette's for `PORTRAIT_SAME_AS_INTERFACE`, the
# named file's otherwise, and none for ''.
func _apply_portrait_palette() -> void:
  var file: String = portrait_palette
  if file == PORTRAIT_SAME_AS_CORRIDOR:
    file = world_palette
  elif file == PORTRAIT_SAME_AS_INTERFACE:
    file = interface_palette
  _write_palette(InterfaceLook.material, _distinct_colours(PaletteLoader.load_palette(file)) if file != '' else PackedColorArray())


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


# `colours` without repeats, in their first order. Interface palettes name the same colour for several
# variables, and each repeat would cost the clamp another comparison per pixel.
static func _distinct_colours(colours: PackedColorArray) -> PackedColorArray:
  var result: PackedColorArray = PackedColorArray()
  for colour: Color in colours:
    if not result.has(colour):
      result.append(colour)
  return result


## Clamp the combat corridor to the palette file at `path`, or turn the world clamp off with ''.
func set_world_palette(path: String) -> void:
  world_palette = path
  var colours: PackedColorArray = PaletteLoader.load_palette(path) if path != '' else PackedColorArray()
  _write_palette(world_material, colours)
  _apply_portrait_palette()


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
  _portrait_option.clear()
  _palette_paths.clear()
  _interface_palette_paths.clear()
  _world_option.add_item('Off', 0)
  _interface_option.add_item('Off', 0)
  _portrait_option.add_item('Off', 0)
  _portrait_option.add_item('Same as corridor', 1)
  _portrait_option.add_item('Same as interface', 2)
  var groups: Dictionary = PaletteLoader.find_palettes(PALETTE_ROOT)
  for folder: String in groups:
    if folder != '':
      _world_option.add_separator(folder)
      _portrait_option.add_separator(folder)
    for path: String in groups[folder]:
      _palette_paths.append(path)
      var palette_name: String = path.get_file().get_basename()
      _world_option.add_item(palette_name, _palette_paths.size())
      _portrait_option.add_item(palette_name, _palette_paths.size() + PORTRAIT_FIRST_FILE_ID - 1)
      if InterfacePalette.is_interface_palette(path):
        _interface_palette_paths.append(path)
        _interface_option.add_item(folder.path_join(palette_name), _interface_palette_paths.size())
  _sync_controls()


# Shows the current palette and matching choices in the tabs' controls, without applying anything.
func _sync_controls() -> void:
  _matching_option.select(1 if _perceptual else 0)
  if _palettes_scanned:
    _world_option.select(maxi(_world_option.get_item_index(_palette_paths.find(world_palette) + 1), 0))
    _interface_option.select(maxi(_interface_option.get_item_index(_interface_palette_paths.find(interface_palette) + 1), 0))
    var portrait_id: int = _portrait_palette_id()
    _portrait_option.select(maxi(_portrait_option.get_item_index(portrait_id), 0))


# The item id in the portrait palette option for the current `portrait_palette`: 0 for off, 1 for
# the corridor, 2 for the interface, or the palette file's id.
func _portrait_palette_id() -> int:
  match portrait_palette:
    '':
      return 0
    PORTRAIT_SAME_AS_CORRIDOR:
      return 1
    PORTRAIT_SAME_AS_INTERFACE:
      return 2
  var index: int = _palette_paths.find(portrait_palette)
  return index + PORTRAIT_FIRST_FILE_ID if index >= 0 else 0


func _on_world_palette_selected(index: int) -> void:
  var id: int = _world_option.get_item_id(index)
  set_world_palette('' if id <= 0 else _palette_paths[id - 1])


func _on_interface_palette_selected(index: int) -> void:
  var id: int = _interface_option.get_item_id(index)
  set_interface_palette('' if id <= 0 else _interface_palette_paths[id - 1])


func _on_portrait_palette_selected(index: int) -> void:
  var id: int = _portrait_option.get_item_id(index)
  match id:
    0:
      set_portrait_palette('')
    1:
      set_portrait_palette(PORTRAIT_SAME_AS_CORRIDOR)
    2:
      set_portrait_palette(PORTRAIT_SAME_AS_INTERFACE)
    _:
      set_portrait_palette(_palette_paths[id - PORTRAIT_FIRST_FILE_ID])


func _on_matching_selected(index: int) -> void:
  _perceptual = index == 1
  world_material.set_shader_parameter('perceptual', _perceptual)
  InterfaceLook.material.set_shader_parameter('perceptual', _perceptual)


func _on_dithering_toggled(on: bool) -> void:
  _dithering = on
  world_material.set_shader_parameter('dithering', _dithering)


func _on_interface_dithering_toggled(on: bool) -> void:
  _interface_dithering = on
  InterfaceLook.material.set_shader_parameter('dithering', _interface_dithering)
