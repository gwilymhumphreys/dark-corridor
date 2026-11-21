class_name DebugPanelsAutoload
extends Node
## Dev-only debug panel (docs/systems/debug_panel.md). Registered as the `DebugPanels` autoload so the
## panel covers every screen, the corridor testbed and the combat sandbox. It owns the world material
## that the corridor is drawn through (the corridor look shader with its palette clamp) and the two
## palettes: the main palette, which the corridor, the pictures and the interface colours take, and the
## mechanic palette (docs/systems/interface_palette.md, docs/systems/palette_clamp.md).
##
## One panel with a preset bar and eight tabs, each holding one kind of setting: Colours (F1), Corridor
## (F2), Pictures (F3), Wear (F4), Layout (F5), Effects (F6), Motion (F7) and Icons (F8); each key
## opens its tab, in debug builds only.
## Choices last for the session only, unless saved as a look preset (docs/systems/look_presets.md).
## The default preset loads at start-up.
## Panel text is English on purpose: `tools/extract_pot.gd` skips `src/debug/`.

## Emitted after the palettes are applied, so nodes that copied `Colours` when built can copy them
## again.
signal colours_changed
## Emitted after an icon slot's icon changes, so nodes that copied one when built can take the new
## one.
signal icons_changed
## Emitted with true when the panel opens and false when it closes. The run screen pauses on it.
signal panels_open_changed(open: bool)

const PALETTE_ROOT: String = 'res://assets/palettes'
const SHORTLIST_DIR: String = 'res://assets/palettes/shortlist'
## The darkest colour setting's colour until one is picked.
const DEFAULT_DARKEST_COLOUR: Color = Color(0.04, 0.04, 0.04)
const MAX_COLOURS: int = 64   # must match MAX_COLOURS in palette_clamp.gdshaderinc
const LOOK_SHADER: Shader = preload('res://src/shaders/corridor_look.gdshader')
const PALETTE_INCLUDE: ShaderInclude = preload('res://src/shaders/palette_clamp.gdshaderinc')
const LOOK_EFFECTS_INCLUDE: ShaderInclude = preload('res://src/shaders/look_effects.gdshaderinc')
const BLUE_NOISE: Texture2D = preload('res://assets/textures/blue_noise_64.png')
## Palette clamp uniforms set from the palette settings, so they are not corridor look settings.
const PALETTE_UNIFORMS: Array[String] = ['colour_count', 'perceptual', 'dithering']
## The panel's tabs, in the order they sit in `debug_panels.tscn`. Every tab but Icons is the
## `LookPresets.Part` of the same position.
enum Tab { COLOURS, CORRIDOR, PICTURES, WEAR, LAYOUT, EFFECTS, MOTION, ICONS }
## Tab titles, by tab. The tabs sit in key order, F1 to F8 from the left, so the titles leave the keys out
## and all eight fit across the panel.
const TAB_TITLES: Dictionary = {
  Tab.COLOURS: 'Colours',
  Tab.CORRIDOR: 'Corridor',
  Tab.PICTURES: 'Pictures',
  Tab.WEAR: 'Wear',
  Tab.LAYOUT: 'Layout',
  Tab.EFFECTS: 'Effects',
  Tab.MOTION: 'Motion',
  Tab.ICONS: 'Icons',
}
## The tab each key opens.
const TAB_KEYS: Dictionary = {
  KEY_F1: Tab.COLOURS,
  KEY_F2: Tab.CORRIDOR,
  KEY_F3: Tab.PICTURES,
  KEY_F4: Tab.WEAR,
  KEY_F5: Tab.LAYOUT,
  KEY_F6: Tab.EFFECTS,
  KEY_F7: Tab.MOTION,
  KEY_F8: Tab.ICONS,
}
## The start-up argument that opens each tab.
const TAB_ARGUMENTS: Dictionary = {
  '--colours-panel': Tab.COLOURS,
  '--corridor-panel': Tab.CORRIDOR,
  '--pictures-panel': Tab.PICTURES,
  '--wear-panel': Tab.WEAR,
  '--layout-panel': Tab.LAYOUT,
  '--effects-panel': Tab.EFFECTS,
  '--motion-panel': Tab.MOTION,
  '--icon-panel': Tab.ICONS,
}

## Corridor exports (property -> value), from `--corridor-set=property=value` arguments, the corridor
## tab and presets. Corridors apply them when built.
var corridor_settings: Dictionary = {}
## Properties of the corridor camera's Environment (property -> value), from the corridor tab and
## presets. Corridors apply them when built.
var environment_settings: Dictionary = {}
## The main palette file, or '' when there is none.
var main_palette: String = ''
## What the darkest colour setting does with `darkest_colour`: a `MainPalette.Darkest` value.
var darkest: int = MainPalette.Darkest.OFF
## The colour the darkest colour setting adds or swaps in.
var darkest_colour: Color = DEFAULT_DARKEST_COLOUR
## The mechanic palette file, or '' for the default mechanic colours.
var mechanic_palette: String = ''
## Whether the corridor, the pictures and the combat effects are snapped to the main palette.
var snap_corridor: bool = true
var snap_pictures: bool = true
var snap_effects: bool = true
## The material every corridor is drawn through (corridor_look.gdshader). Its palette is the main
## palette while `snap_corridor` is on.
var world_material: ShaderMaterial = ShaderMaterial.new()

var _main_file_colours: PackedColorArray = PackedColorArray()   # the main palette file's colours, without repeats
var _palette_paths: Array[String] = []   # item id - 1 -> palette path in the main palette option (id 0 = Off)
var _mechanic_palette_paths: Array[String] = []   # item id - 1 -> path in the mechanic palette option
var _palettes_scanned: bool = false
var _perceptual: bool = false
var _dithering: bool = false
var _interface_dithering: bool = false   # the pictures' and effects' dithering switch
var _look_defaults: Dictionary = {}   # look shader uniform -> default value, read from its code
var _scene_values: Array[Dictionary] = []   # the corridor scene's Light and Environment values, read once

@onready var _panel_layer: CanvasLayer = $PanelLayer
@onready var _panel: PanelContainer = $PanelLayer/Panel
@onready var _preset_bar: PresetBar = $PanelLayer/Panel/Rows/PresetBar
@onready var _tabs: TabContainer = $PanelLayer/Panel/Rows/Tabs
@onready var _colours_panel: ColoursPanel = $PanelLayer/Panel/Rows/Tabs/Colours
@onready var _look_panel: LookPanel = $PanelLayer/Panel/Rows/Tabs/Corridor
@onready var _interface_look_panel: InterfaceLookPanel = $PanelLayer/Panel/Rows/Tabs/Pictures
@onready var _wear_panel: WearPanel = $PanelLayer/Panel/Rows/Tabs/Wear
@onready var _layout_panel: LayoutPanel = $PanelLayer/Panel/Rows/Tabs/Layout
@onready var _effects_panel: EffectsPanel = $PanelLayer/Panel/Rows/Tabs/Effects
@onready var _motion_panel: MotionPanel = $PanelLayer/Panel/Rows/Tabs/Motion
@onready var _icon_panel: IconPanel = $PanelLayer/Panel/Rows/Tabs/Icons
@onready var _main_option: OptionButton = $PanelLayer/Panel/Rows/Tabs/Colours/PaletteRows/MainPaletteRow/Option
@onready var _matching_option: OptionButton = $PanelLayer/Panel/Rows/Tabs/Colours/PaletteRows/MatchingRow/Option
@onready var _mechanic_option: OptionButton = $PanelLayer/Panel/Rows/Tabs/Colours/PaletteRows/MechanicPaletteRow/Option

func _ready() -> void:
  _panel_layer.visible = false
  for tab: int in TAB_TITLES:
    _tabs.set_tab_title(tab, TAB_TITLES[tab])
  _tabs.tab_changed.connect(_on_tab_changed)
  _preset_bar.preset_loaded.connect(refresh_panels)
  _preset_bar.side_switched.connect(_switch_side)
  world_material.shader = LOOK_SHADER
  world_material.set_shader_parameter('dither_noise', BLUE_NOISE)
  for clamp_material: ShaderMaterial in InterfaceLook.clamp_materials:
    clamp_material.set_shader_parameter('dither_noise', BLUE_NOISE)
  _write_look_defaults()
  _write_palette(world_material, PackedColorArray())
  _main_option.item_selected.connect(_on_main_palette_selected)
  _mechanic_option.item_selected.connect(_on_mechanic_palette_selected)
  _matching_option.item_selected.connect(_on_matching_selected)
  _sync_controls()
  LookPresets.load_default()
  _apply_command_line()


## Dev hooks for screenshots, applied after the default preset: `--preset=<name or res path>` loads a
## preset (applied first, so the other arguments can override it), `--main-palette=<res path>` sets
## the main palette, `--mechanic-palette=<res path>` the mechanic palette, `--palette-set=name=value`
## any other palette setting or an interface colour's brightness (`set_palette_setting`),
## `--perceptual` and `--dither` set the matching and the corridor's dithering, `--interface-dither` the
## pictures' and effects', `--corridor-set=property=value` sets a corridor export,
## `--background-set=uniform=value` a background wear setting, `--panel-set=uniform=value` a panel wear
## setting, `--print-set=name=value` a border, corridor overlay or layout setting,
## `--interface-set=uniform=value` an interface look setting, `--feedback-set=name=value` a control
## feedback setting, `--feedback-demo=<amount>` holds every control at that much hover for a
## screenshot, `--glow-demo=<brightness>` makes every node drawn through a picture material glow. The
## arguments in `TAB_ARGUMENTS` open the panel on that tab.
func _apply_command_line() -> void:
  var args: PackedStringArray = DevArgs.all()
  for arg: String in args:
    if arg.begins_with('--preset='):
      var preset: String = arg.substr(9)
      var preset_path: String = preset if preset.begins_with('res://') else LookPresets.preset_path(preset)
      if LookPresets.load_preset(preset_path):
        _preset_bar.remember_loaded(preset_path)
  for arg: String in args:
    if arg.begins_with('--main-palette='):
      set_main_palette(arg.substr(15))
    elif arg.begins_with('--mechanic-palette='):
      set_mechanic_palette(arg.substr(19))
    elif arg.begins_with('--palette-set='):
      var palette_pair: PackedStringArray = arg.substr(14).split('=')
      if palette_pair.size() == 2:
        var parsed: Variant = str_to_var(palette_pair[1])
        set_palette_setting(palette_pair[0], parsed if parsed != null else palette_pair[1])
    elif arg.begins_with('--corridor-set='):
      var pair: PackedStringArray = arg.substr(15).split('=')
      if pair.size() == 2:
        corridor_settings[pair[0]] = str_to_var(pair[1])
    elif arg.begins_with('--monster-image='):
      MonsterImages.forced_path = arg.substr(16)
    elif arg.begins_with('--background-set='):
      var setting: PackedStringArray = arg.substr(17).split('=')
      if setting.size() == 2 and PrintLook.background_defaults().has(setting[0]):
        PrintLook.background_material.set_shader_parameter(setting[0], str_to_var(setting[1]))
    elif arg.begins_with('--panel-set='):
      var panel_setting: PackedStringArray = arg.substr(12).split('=')
      if panel_setting.size() == 2 and PrintLook.panel_defaults().has(panel_setting[0]):
        PrintLook.set_panel_setting(panel_setting[0], str_to_var(panel_setting[1]))
    elif arg.begins_with('--print-set='):
      var print_pair: PackedStringArray = arg.substr(12).split('=')
      if print_pair.size() == 2:
        PrintLook.set_print_value(print_pair[0], str_to_var(print_pair[1]))
    elif arg.begins_with('--interface-set='):
      var interface_pair: PackedStringArray = arg.substr(16).split('=')
      if interface_pair.size() == 2 and InterfaceLook.defaults().has(interface_pair[0]):
        InterfaceLook.set_setting(interface_pair[0], str_to_var(interface_pair[1]))
    elif arg.begins_with('--feedback-demo='):
      ControlFeedback.set_demo(arg.substr(16).to_float())
    elif arg.begins_with('--glow-demo='):
      InterfaceGlow.demo_brightness = arg.substr(12).to_float()
    elif arg.begins_with('--feedback-set='):
      var feedback_pair: PackedStringArray = arg.substr(15).split('=')
      if feedback_pair.size() == 2:
        ControlFeedback.set_setting(feedback_pair[0], str_to_var(feedback_pair[1]))
  if '--perceptual' in args:
    _on_matching_selected(1)
    apply_palettes()
  if '--dither' in args:
    _on_dithering_toggled(true)
  if '--interface-dither' in args:
    _on_interface_dithering_toggled(true)
  for argument: String in TAB_ARGUMENTS:
    if argument in args:
      toggle_tab(TAB_ARGUMENTS[argument])
      break
  _sync_controls()


func _exit_tree() -> void:
  _palette_paths.clear()
  _mechanic_palette_paths.clear()
  MainPalette.reset()
  MechanicPalette.reset()


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
  # The palette keys only work while the panel is open, so they never take a game key such as the
  # battle speed keys on [ and ].
  if not is_panel_open():
    return
  match key.keycode:
    KEY_BRACKETLEFT:
      cycle_palette(-1)
    KEY_BRACKETRIGHT:
      cycle_palette(1)
    KEY_SEMICOLON:
      cycle_mechanic_palette(-1)
    KEY_APOSTROPHE:
      cycle_mechanic_palette(1)
    KEY_BACKSLASH:
      shortlist_palette()
    KEY_BACKSPACE:
      set_dithering(not _dithering)
      _colours_panel.refresh()
    _:
      return
  get_viewport().set_input_as_handled()


## Open the panel on `tab` (a `Tab`), or close it if it is already showing that tab.
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
  if tab == Tab.COLOURS and not _palettes_scanned:
    _scan_palettes()
  _tab_panel(tab).open()


# The tab's panel.
func _tab_panel(tab: int) -> LookPanel:
  return [_colours_panel, _look_panel, _interface_look_panel, _wear_panel, _layout_panel, _effects_panel,
    _motion_panel, _icon_panel][tab]


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
  for tab: int in TAB_TITLES:
    if tab != Tab.ICONS:
      _tab_panel(tab).refresh()


## Rebuild the Corridor tab's controls after corridor look settings change elsewhere (the Pictures
## tab's copy button).
func refresh_look_panel() -> void:
  _look_panel.refresh()


## Select the next (`step` 1) or previous (`step` -1) entry in the main palette list. Bound to ] and [.
func cycle_palette(step: int) -> void:
  _on_main_palette_selected(_step_option(_main_option, step))


## Select the next (`step` 1) or previous (`step` -1) entry in the mechanic palette list. Bound to '
## and ;.
func cycle_mechanic_palette(step: int) -> void:
  _on_mechanic_palette_selected(_step_option(_mechanic_option, step))


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


## Move the selected main palette into `SHORTLIST_DIR`, then rescan and keep it selected at its new
## path. Does nothing when "Off" is selected or the palette is already there. Bound to \.
func shortlist_palette() -> void:
  if not _palettes_scanned:
    return
  var id: int = _main_option.get_selected_id()
  if id <= 0:
    return
  var old_path: String = _palette_paths[id - 1]
  if old_path.get_base_dir() == SHORTLIST_DIR:
    return
  var new_path: String = move_palette_file(old_path, SHORTLIST_DIR)
  if new_path == '':
    return
  replace_palette_path([LookPresets.PRESET_DIR, LookPresets.HISTORY_DIR], old_path, new_path)
  _scan_palettes()
  var new_id: int = _palette_paths.find(new_path) + 1
  if new_id > 0:
    _main_option.select(_main_option.get_item_index(new_id))
    _on_main_palette_selected(_main_option.selected)


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


## Every part of the look back to its defaults, with every effect off (not the default preset), and
## random enemy images. Used between tests.
func reset_settings() -> void:
  reset_look()
  PrintLook.reset_print_look()
  PrintLook.reset_background_look()
  InterfaceLook.reset()
  ControlFeedback.reset()
  VfxDriver.read_trials(ConfigFile.new())
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
  for property: String in LookPanel.corridor_properties():
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


## The main palette's colours: the palette file's, with the darkest colour setting applied. None when
## the main palette is off.
func main_colours() -> PackedColorArray:
  return MainPalette.palette_colours(_main_file_colours, darkest as MainPalette.Darkest, darkest_colour)


## Use the palette file at `path` as the main palette, or none with ''.
func set_main_palette(path: String) -> void:
  main_palette = path
  _main_file_colours = _distinct_colours(PaletteLoader.load_palette(path)) if path != '' else PackedColorArray()
  apply_palettes()


## Use the mechanic palette file at `path`, or the default mechanic colours with ''.
func set_mechanic_palette(path: String) -> void:
  mechanic_palette = path
  MechanicPalette.apply(path)
  apply_palettes()


## Set one setting of the `palette` section by name, or an interface colour's brightness by its name in
## lower case ('ui_background'), and apply the palettes. `darkest` takes a `MainPalette.Darkest` value
## or its name in lower case. Unknown names give a warning.
func set_palette_setting(setting: String, value: Variant) -> void:
  match setting:
    'main_palette':
      set_main_palette(value)
    'mechanic_palette':
      set_mechanic_palette(value)
    'darkest':
      darkest = MainPalette.Darkest.keys().find((value as String).to_upper()) if value is String else int(value)
      darkest = maxi(darkest, 0)
      apply_palettes()
    'darkest_colour':
      darkest_colour = value
      apply_palettes()
    'perceptual':
      _on_matching_selected(1 if value else 0)
    'snap_corridor':
      snap_corridor = value
      apply_palettes()
    'snap_pictures':
      snap_pictures = value
      apply_palettes()
    'snap_effects':
      snap_effects = value
      apply_palettes()
    'corridor_dithering':
      set_dithering(value)
    'picture_dithering':
      set_interface_dithering(value)
    _:
      if not MainPalette.is_interface_colour(setting.to_upper()):
        push_warning('[DebugPanels] no palette setting called %s' % setting)
        return
      MainPalette.set_brightness(setting.to_upper(), float(value))
      apply_palettes()


## Apply both palettes everywhere: the interface colours and the theme from the main palette, its
## colours to the corridor and the pictures and, with the mechanic colours, to the combat effects, each
## when its snap switch is on. Statuses in the current fight are recoloured, the wear, feedback and
## cursor colours pushed again, and `colours_changed` tells nodes that copied colours when built.
func apply_palettes() -> void:
  var colours: PackedColorArray = main_colours()
  MainPalette.apply(colours)
  _write_palette(world_material, colours if snap_corridor else PackedColorArray())
  for picture_material: ShaderMaterial in InterfaceLook.picture_materials:
    _write_palette(picture_material, colours if snap_pictures else PackedColorArray())
  var effects_colours: PackedColorArray = PackedColorArray()
  if snap_effects and not colours.is_empty():
    effects_colours = _distinct_colours(colours + MechanicPalette.colours())
  _write_palette(InterfaceLook.effects_material, effects_colours)
  _recolour_fight_statuses()
  PrintLook.push_wear_colours()
  InterfaceLook.push_wear_colours()
  ControlFeedback.push_colours()
  Cursor.apply()
  colours_changed.emit()


## Write the palette choices into a preset's colours part: the `palette` section, and the brightness of
## every interface colour in `interface_colours`.
func write_palettes(file: ConfigFile) -> void:
  file.set_value('palette', 'main_palette', main_palette)
  file.set_value('palette', 'darkest', darkest)
  file.set_value('palette', 'darkest_colour', darkest_colour)
  file.set_value('palette', 'perceptual', _perceptual)
  file.set_value('palette', 'snap_corridor', snap_corridor)
  file.set_value('palette', 'snap_pictures', snap_pictures)
  file.set_value('palette', 'snap_effects', snap_effects)
  file.set_value('palette', 'corridor_dithering', _dithering)
  file.set_value('palette', 'picture_dithering', _interface_dithering)
  file.set_value('palette', 'mechanic_palette', mechanic_palette)
  for variable: String in MainPalette.names():
    file.set_value('interface_colours', variable.to_lower(), MainPalette.brightness(variable))


## Set the palette choices from a preset file written by `write_palettes`. Choices the file leaves out
## go back to their defaults.
func read_palettes(file: ConfigFile) -> void:
  main_palette = file.get_value('palette', 'main_palette', '')
  _main_file_colours = _distinct_colours(PaletteLoader.load_palette(main_palette)) if main_palette != '' else PackedColorArray()
  darkest = file.get_value('palette', 'darkest', MainPalette.Darkest.OFF)
  darkest_colour = file.get_value('palette', 'darkest_colour', DEFAULT_DARKEST_COLOUR)
  snap_corridor = file.get_value('palette', 'snap_corridor', true)
  snap_pictures = file.get_value('palette', 'snap_pictures', true)
  snap_effects = file.get_value('palette', 'snap_effects', true)
  _perceptual = file.get_value('palette', 'perceptual', false)
  _write_matching()
  _on_dithering_toggled(file.get_value('palette', 'corridor_dithering', false))
  _on_interface_dithering_toggled(file.get_value('palette', 'picture_dithering', false))
  MainPalette.reset_brightness()
  for key: String in _section_keys(file, 'interface_colours'):
    if MainPalette.is_interface_colour(key.to_upper()):
      MainPalette.set_brightness(key.to_upper(), file.get_value('interface_colours', key))
  mechanic_palette = file.get_value('palette', 'mechanic_palette', '')
  MechanicPalette.apply(mechanic_palette)
  apply_palettes()
  _sync_controls()
  _look_panel.refresh()
  _interface_look_panel.refresh()
  _colours_panel.refresh()


## Every palette choice back to its default: no main or mechanic palette, darkest colour off, every
## snap switch on, default brightness, RGB matching and no dithering.
func reset_palettes() -> void:
  read_palettes(ConfigFile.new())


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


## Choose the icon for `slot` (docs/systems/mechanics.md). Saves the choice, writes it into the
## shared Mechanic instances, and tells anything holding a copy to take the new one.
func set_slot_icon(slot: String, path: String) -> void:
  IconSlots.set_icon(slot, path)
  MechanicRegistry.refresh_icons()
  _refresh_fight_status_icons()
  icons_changed.emit()


# Statuses copy their icon from their mechanic's icon when created, so each one in the current fight
# takes the icon a new status of its class would have.
func _refresh_fight_status_icons() -> void:
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
      status.icon = ((status.get_script() as GDScript).new() as StatusEffect).icon


# `colours` without repeats, in their first order. Interface palettes name the same colour for several
# variables, and each repeat would cost the clamp another comparison per pixel.
static func _distinct_colours(colours: PackedColorArray) -> PackedColorArray:
  var result: PackedColorArray = PackedColorArray()
  for colour: Color in colours:
    if not result.has(colour):
      result.append(colour)
  return result


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
# runs do no extra work. The mechanic palettes folder is listed in the mechanic palette option only.
func _scan_palettes() -> void:
  _palettes_scanned = true
  _main_option.clear()
  _mechanic_option.clear()
  _palette_paths.clear()
  _mechanic_palette_paths.clear()
  _main_option.add_item('Off', 0)
  _mechanic_option.add_item('Default', 0)
  var groups: Dictionary = PaletteLoader.find_palettes(PALETTE_ROOT)
  for folder: String in groups:
    var mechanic_folder: bool = PALETTE_ROOT.path_join(folder) == MechanicPalette.FOLDER
    if folder != '' and not mechanic_folder:
      _main_option.add_separator(folder)
    for path: String in groups[folder]:
      if mechanic_folder:
        if MechanicPalette.is_mechanic_palette(path):
          _mechanic_palette_paths.append(path)
          _mechanic_option.add_item(path.get_file().get_basename(), _mechanic_palette_paths.size())
        continue
      _palette_paths.append(path)
      _main_option.add_item(path.get_file().get_basename(), _palette_paths.size())
  _sync_controls()


# Shows the current palette and matching choices in the tabs' controls, without applying anything.
func _sync_controls() -> void:
  _matching_option.select(1 if _perceptual else 0)
  if _palettes_scanned:
    _main_option.select(maxi(_main_option.get_item_index(_palette_paths.find(main_palette) + 1), 0))
    _mechanic_option.select(maxi(_mechanic_option.get_item_index(_mechanic_palette_paths.find(mechanic_palette) + 1), 0))


func _on_main_palette_selected(index: int) -> void:
  var id: int = _main_option.get_item_id(index)
  set_main_palette('' if id <= 0 else _palette_paths[id - 1])


func _on_mechanic_palette_selected(index: int) -> void:
  var id: int = _mechanic_option.get_item_id(index)
  set_mechanic_palette('' if id <= 0 else _mechanic_palette_paths[id - 1])


func _on_matching_selected(index: int) -> void:
  _perceptual = index == 1
  _write_matching()


# Writes the colour matching to the corridor material and every interface clamp material.
func _write_matching() -> void:
  world_material.set_shader_parameter('perceptual', _perceptual)
  for clamp_material: ShaderMaterial in InterfaceLook.clamp_materials:
    clamp_material.set_shader_parameter('perceptual', _perceptual)


func _on_dithering_toggled(on: bool) -> void:
  _dithering = on
  world_material.set_shader_parameter('dithering', _dithering)


func _on_interface_dithering_toggled(on: bool) -> void:
  _interface_dithering = on
  for clamp_material: ShaderMaterial in InterfaceLook.clamp_materials:
    clamp_material.set_shader_parameter('dithering', _interface_dithering)
