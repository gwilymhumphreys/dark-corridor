class_name PrintLookAutoload
extends Node
## Owns the print look (docs/systems/print_frame.md, docs/systems/panel_wear.md): background wear,
## panel wear, the print border and the corridor overlay — their materials, settings, defaults and
## save/load/reset. Registered as the `PrintLook` autoload, before `DebugPanels`, which keeps the F5
## panel UI and the `--print-look=`, `--print-set=`, `--background-set=`, `--panel-set=` start-up
## arguments and delegates to this autoload.
##
## Also hands out and frees the per-control canvas items `WornStyleBox` draws panel wear into, so the
## registry survives an F5 panel rebuild and is freed in one place at exit.

const BACKGROUND_SHADER: Shader = preload('res://src/shaders/background_wear.gdshader')
const PANEL_SHADER: Shader = preload('res://src/shaders/panel_wear.gdshader')
const BORDER_SHADER: Shader = preload('res://src/shaders/print_border.gdshader')
const OVERLAY_SHADER: Shader = preload('res://src/shaders/corridor_overlay.gdshader')
const BACKGROUND_SETTINGS_INCLUDE: ShaderInclude = preload('res://src/shaders/background_wear_settings.gdshaderinc')
const DEFAULT_PRINT_LOOK: String = 'res://assets/print_looks/default.cfg'
## Background wear uniforms set from `Colours` or the current screen by `ScreenBackground`, or from the
## layout by `PrintFrame`, so they are not look settings.
const BACKGROUND_COLOUR_UNIFORMS: Array[String] = [
  'wear_dark_colour',
  'wear_light_colour',
  'print_corridor_rect',
  'folds_shown',
]
## Panel wear uniforms set from `Colours` or per control by `PrintLook`, so they are not look settings.
const PANEL_COLOUR_UNIFORMS: Array[String] = ['wear_dark_colour', 'wear_light_colour', 'panel_rect', 'panel_seed']
## Border and corridor overlay uniforms set by `PrintFrame`, so they are not look settings.
const PRINT_FRAME_UNIFORMS: Array[String] = ['border_colour', 'border_wear_colour', 'rect_size', 'paper_colour']
## Print frame settings that are not shader uniforms (setting -> default), from the print panel, look
## files and `--print-set=`. The corridor margin is in pixels on the interface canvas.
const PRINT_SETTING_DEFAULTS: Dictionary = {
  'corridor_margin': 40.0,
}

## The material every screen background is drawn through (background_wear.gdshader).
var background_material: ShaderMaterial = ShaderMaterial.new()
## The material every worn UI panel is drawn through (panel_wear.gdshader). One shared material; each
## panel gets its own child canvas item with instance uniforms for its rect and seed.
var panel_material: ShaderMaterial = ShaderMaterial.new()
## The border around the combat corridor (print_border.gdshader), drawn by `PrintFrame`.
var border_material: ShaderMaterial = ShaderMaterial.new()
## The wear and worn edge drawn over the combat corridor (corridor_overlay.gdshader), by `PrintFrame`.
var overlay_material: ShaderMaterial = ShaderMaterial.new()
## Print frame settings changed from their defaults (setting -> value); see `print_setting()`.
var print_settings: Dictionary = {}

var _background_defaults: Dictionary = {}   # background wear uniform -> default value, read from its code
var _panel_defaults: Dictionary = {}   # panel wear uniform -> default value, read from its code
var _print_defaults: Dictionary = {}   # border and corridor overlay uniform -> default value
var _panel_children: Dictionary = {}   # parent canvas item RID -> [child RID, frame last cleared]
var _panel_seed_count: int = 0


func _ready() -> void:
  background_material.shader = BACKGROUND_SHADER
  panel_material.shader = PANEL_SHADER
  border_material.shader = BORDER_SHADER
  overlay_material.shader = OVERLAY_SHADER
  _write_print_defaults()
  push_wear_colours()
  if FileAccess.file_exists(DEFAULT_PRINT_LOOK):
    load_print_look(DEFAULT_PRINT_LOOK)
  get_tree().node_removed.connect(_on_node_removed)


func _exit_tree() -> void:
  for entry: Array in _panel_children.values():
    RenderingServer.free_rid(entry[0])
  _panel_children.clear()


## The canvas item `WornStyleBox` draws a control's worn panel background into, creating it the first
## time it is asked for a given `parent` (the control's own canvas item RID). Cleared once per process
## frame, so a control drawing several styles in one frame (e.g. normal then focus) keeps both, and a
## resize leaves nothing from an earlier frame.
func panel_wear_child(parent: RID) -> RID:
  if not _panel_children.has(parent):
    var child: RID = RenderingServer.canvas_item_create()
    RenderingServer.canvas_item_set_parent(child, parent)
    RenderingServer.canvas_item_set_draw_behind_parent(child, true)
    RenderingServer.canvas_item_set_material(child, panel_material.get_rid())
    _panel_seed_count += 1
    RenderingServer.canvas_item_set_instance_shader_parameter(child, 'panel_seed', float(_panel_seed_count))
    _panel_children[parent] = [child, -1]
  var entry: Array = _panel_children[parent]
  var frame: int = Engine.get_process_frames()
  if entry[1] != frame:
    RenderingServer.canvas_item_clear(entry[0])
    entry[1] = frame
  return entry[0]


# A control's canvas item is freed when it leaves the tree; free its worn-panel child with it.
func _on_node_removed(node: Node) -> void:
  if node is not CanvasItem:
    return
  var rid: RID = (node as CanvasItem).get_canvas_item()
  if _panel_children.has(rid):
    RenderingServer.free_rid(_panel_children[rid][0])
    _panel_children.erase(rid)


## Push `Colours.UI_PANEL_WEAR` / `UI_PANEL_WEAR_LIGHT` (and the background's own mark colours) into
## `panel_material`. Called at start, and by `DebugPanels` after an interface palette is applied or
## reset.
func push_wear_colours() -> void:
  panel_material.set_shader_parameter('wear_dark_colour', Colours.UI_PANEL_WEAR)
  panel_material.set_shader_parameter('wear_light_colour', Colours.UI_PANEL_WEAR_LIGHT)


## Every background wear uniform with a default in the shader code or its settings include (uniform
## name -> value), except `BACKGROUND_COLOUR_UNIFORMS`.
func background_defaults() -> Dictionary:
  if _background_defaults.is_empty():
    _background_defaults = _uniform_defaults(BACKGROUND_SHADER.code + '\n' + BACKGROUND_SETTINGS_INCLUDE.code, BACKGROUND_COLOUR_UNIFORMS)
  return _background_defaults


## Every panel wear uniform with a default in its shader code (uniform name -> value), except
## `PANEL_COLOUR_UNIFORMS`.
func panel_defaults() -> Dictionary:
  if _panel_defaults.is_empty():
    _panel_defaults = _uniform_defaults(PANEL_SHADER.code, PANEL_COLOUR_UNIFORMS)
  return _panel_defaults


## Every border and corridor overlay uniform with a default in their own shader code (uniform name ->
## value), except `PRINT_FRAME_UNIFORMS`. The overlay's copy of the background wear settings is not
## included.
func print_defaults() -> Dictionary:
  if _print_defaults.is_empty():
    _print_defaults = _uniform_defaults(BORDER_SHADER.code + '\n' + OVERLAY_SHADER.code, PRINT_FRAME_UNIFORMS)
  return _print_defaults


## A print frame setting's current value: changed in `print_settings`, otherwise its default.
func print_setting(setting: String) -> Variant:
  return print_settings.get(setting, PRINT_SETTING_DEFAULTS[setting])


## Set a border or corridor overlay uniform, a panel wear uniform, or a print frame setting, by name.
## Unknown names are ignored.
func set_print_value(setting: String, value: Variant) -> void:
  if print_defaults().has(setting):
    _print_material(setting).set_shader_parameter(setting, value)
  elif panel_defaults().has(setting):
    panel_material.set_shader_parameter(setting, value)
  elif PRINT_SETTING_DEFAULTS.has(setting):
    print_settings[setting] = value


func _print_material(uniform: String) -> ShaderMaterial:
  return border_material if uniform.begins_with('print_border') else overlay_material


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


## Every background wear, panel wear, border and corridor overlay effect back to its shader default,
## and no print frame settings.
func reset_print_look() -> void:
  _write_print_defaults()
  print_settings.clear()


## Save the current print look to a text file at `path`: the background wear settings, the panel wear
## settings, the border and corridor overlay settings, and the print frame settings that were changed.
func save_print_look(path: String) -> Error:
  var file: ConfigFile = ConfigFile.new()
  for uniform: String in background_defaults():
    file.set_value('background', uniform, background_material.get_shader_parameter(uniform))
  for uniform: String in panel_defaults():
    file.set_value('panel', uniform, panel_material.get_shader_parameter(uniform))
  for uniform: String in print_defaults():
    file.set_value('print', uniform, _print_material(uniform).get_shader_parameter(uniform))
  for setting: String in print_settings:
    file.set_value('layout', setting, print_settings[setting])
  DirAccess.make_dir_recursive_absolute(path.get_base_dir())
  return file.save(path)


## Load a print look saved by `save_print_look`, starting from the print defaults. Returns false if the
## file cannot be read.
func load_print_look(path: String) -> bool:
  var file: ConfigFile = ConfigFile.new()
  if file.load(path) != OK:
    push_warning('[PrintLook] could not read print look file %s' % path)
    return false
  reset_print_look()
  var background: Dictionary = background_defaults()
  for uniform: String in _section_keys(file, 'background'):
    if background.has(uniform):
      background_material.set_shader_parameter(uniform, file.get_value('background', uniform))
  var panel: Dictionary = panel_defaults()
  for uniform: String in _section_keys(file, 'panel'):
    if panel.has(uniform):
      panel_material.set_shader_parameter(uniform, file.get_value('panel', uniform))
  for setting: String in _section_keys(file, 'print'):
    set_print_value(setting, file.get_value('print', setting))
  for setting: String in _section_keys(file, 'layout'):
    set_print_value(setting, file.get_value('layout', setting))
  return true


# Every uniform is set explicitly, so a saved print look lists every one of them.
func _write_print_defaults() -> void:
  var background: Dictionary = background_defaults()
  for uniform: String in background:
    background_material.set_shader_parameter(uniform, background[uniform])
  var panel: Dictionary = panel_defaults()
  for uniform: String in panel:
    panel_material.set_shader_parameter(uniform, panel[uniform])
  var frame: Dictionary = print_defaults()
  for uniform: String in frame:
    _print_material(uniform).set_shader_parameter(uniform, frame[uniform])


func _section_keys(file: ConfigFile, section: String) -> PackedStringArray:
  return file.get_section_keys(section) if file.has_section(section) else PackedStringArray()
