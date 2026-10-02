class_name PrintLookAutoload
extends Node
## Owns the print look (docs/systems/print_frame.md, docs/systems/panel_wear.md): background wear,
## panel wear, the print border and the corridor overlay — their materials, settings, defaults and
## reset, and how they are written to and read from a look preset (docs/systems/look_presets.md).
## Background wear is a preset part of its own, with its own tab, so it is written, read and reset
## separately from the rest. Registered as the `PrintLook` autoload, before `DebugPanels`, which keeps
## the Print and Background tabs and the `--print-set=`, `--background-set=`, `--panel-set=` start-up
## arguments.
##
## Also hands out and frees the per-control canvas items `WornStyleBox` draws panel wear into, each with
## its own copy of `panel_material`, so the registry survives a Print tab rebuild and is freed in one
## place at exit.

const BACKGROUND_SHADER: Shader = preload('res://src/shaders/background_wear.gdshader')
const PANEL_SHADER: Shader = preload('res://src/shaders/panel_wear.gdshader')
const BORDER_SHADER: Shader = preload('res://src/shaders/print_border.gdshader')
const OVERLAY_SHADER: Shader = preload('res://src/shaders/corridor_overlay.gdshader')
const GRID_SHADER: Shader = preload('res://src/shaders/board_grid.gdshader')
const BACKGROUND_SETTINGS_INCLUDE: ShaderInclude = preload('res://src/shaders/background_wear_settings.gdshaderinc')
## Background wear uniforms set from `Colours` by `ScreenBackground` and `PrintFrame`, so they are not
## look settings.
const BACKGROUND_COLOUR_UNIFORMS: Array[String] = [
  'wear_dark_colour',
  'wear_light_colour',
]
## Panel wear uniforms set from `Colours`, or per control on each panel's own material, so they are not
## look settings.
const PANEL_COLOUR_UNIFORMS: Array[String] = ['wear_dark_colour', 'wear_light_colour', 'panel_rect', 'panel_seed']
# The control highlight shares the panel wear shader and material, but its settings are its own preset
# part and its own tab (docs/systems/control_feedback.md). They stay out of `panel_defaults` on their
# own, because that reads the shader's own code and an included file's uniforms are not in it.
## Border, corridor overlay and board grid uniforms set by `PrintFrame` or the combat view, so they are
## not look settings.
const PRINT_FRAME_UNIFORMS: Array[String] = [
  'border_colour',
  'border_wear_colour',
  'rect_size',
  'paper_colour',
  'pencil_colour',
  'square_size',
]
## Print frame settings that are not shader uniforms (setting -> default), from the Print and Tokens
## tabs, presets and `--print-set=`. Sizes are in pixels on the interface canvas, angles in degrees
## unless a setting says radians, and dropdowns hold an enum's index.
## - `padding`: the space inside every side of each screen section (`ScreenSections`).
## - `token_*`: the player's items set down askew like cardboard tokens (largest tilt and shift) and the
##   token look (`apply_token_style`): shadow blur, offset and opacity, how far the fill is blended
##   towards the card colour, and whether the portraits are tokens too.
## - `item_layout`, `status_layout`, `panel_background`, `allies_box`: the character panel layout
##   (`CharacterPanel` enums) and whether the allies sit in a labelled pencil box.
## - `section_gap`, `label_gap`: the character sheet's gaps (`apply_sheet_spacing`).
## - `medium_token_size`, `ally_item_size`, `status_size`, `pill_size`: enemy and ally item cells, status
##   icons, and every value pill against its base size.
## - `level_tag_corner`, `level_tag_size`: which corner of an item cell shows the item's level
##   (top left, top right, bottom left, bottom right) and its size against its base size (`ItemCell`).
## - `map_icons_as_pictures`, `map_cleared_look`: the map's icons and its cleared squares (`MapStrip`).
## - `paper_burn_*`: the paper burn effect (`PaperBurn`, docs/systems/paper_burn.md).
## - `page_turn_*`: the page turn between screens (`PageTurn`, docs/systems/page_turn.md).
## - `card_*`, `deck_peek`: the encounter cards dealt from a deck (`EncounterChoice`): the seconds a card
##   takes to travel from the deck, between one card leaving and the next, and to turn over; the largest
##   turn a card lands with; the gap between cards as a share of a card's width; and how much of the
##   deck shows below the top edge, as a share of its height (1 = all of it).
const PRINT_SETTING_DEFAULTS: Dictionary = {
  'padding': 20.0,
  'token_tilt': 3.0,
  'token_shift': 4.0,
  'token_shadow_size': 6.0,
  'token_shadow_offset': 4.0,
  'token_shadow_darkness': 0.6,
  'token_fill_amount': 0.0,
  'token_portraits': false,
  'item_layout': 0,
  'status_layout': 1,
  'panel_background': 0,
  'allies_box': true,
  'section_gap': 32.0,
  'label_gap': 8.0,
  'medium_token_size': 80.0,
  'ally_item_size': 60.0,
  'status_size': 44.0,
  'pill_size': 1.0,
  'level_tag_corner': 3,
  'level_tag_size': 1.0,
  'map_icons_as_pictures': true,
  'map_cleared_look': 1,
  'paper_burn_duration': 1.6,
  'paper_burn_raggedness': 10.0,
  'paper_burn_detail': 12.0,
  'paper_burn_ember_width': 5.0,
  'paper_burn_char_width': 4.0,
  'paper_burn_scorch_width': 14.0,
  'paper_burn_brightness': 1.0,
  'paper_burn_dither': true,
  'paper_burn_palette': true,
  'paper_burn_particles': true,
  'page_turn_duration': 1.1,
  'page_turn_hold': 0.0,
  'page_turn_easing': 2.0,
  'page_turn_lead': 0.9,
  'page_turn_bend': 2.0,
  'page_turn_corner': 0.5,
  'page_turn_camera_distance': 4.0,
  'page_turn_camera_offset': 0.3,
  'page_turn_light_across': -0.35,
  'page_turn_light_down': -0.3,
  'page_turn_shading': 0.6,
  'page_turn_highlight': 0.12,
  'page_turn_show_through': 0.0,
  'page_turn_shadow_darkness': 0.55,
  'page_turn_shadow_softness': 0.25,
  'page_turn_edge_width': 2.0,
  'card_deal_time': 0.3,
  'card_deal_gap': 0.15,
  'card_turn_time': 0.25,
  'card_tilt': 2.5,
  'card_spacing': 0.15,
  'deck_peek': 1.0,
}
## The theme styles the token look is written to (docs/systems/ui_theme.md).
const TOKEN_STYLES: Array[String] = ['PanelToken', 'PanelTokenWide']
## The theme styles the section gap is written to (apply_sheet_spacing).
const SHEET_GAP_STYLES: Array[String] = ['SheetColumn', 'SheetRow', 'SheetStack']

## The material every screen background is drawn through (background_wear.gdshader).
var background_material: ShaderMaterial = ShaderMaterial.new()
## The panel wear settings (panel_wear.gdshader). Each worn UI panel is drawn through its own copy,
## which also holds that panel's rect, seed and highlight amounts; `set_panel_setting` writes a setting
## here and to every copy. The per-panel values are not instance uniforms, because the compatibility
## renderer only has room for about 256 canvas items using them (docs/systems/godot_notes.md).
var panel_material: ShaderMaterial = ShaderMaterial.new()
## The border around the combat corridor (print_border.gdshader), drawn by `PrintFrame`.
var border_material: ShaderMaterial = ShaderMaterial.new()
## The wear and worn edge drawn over the combat corridor (corridor_overlay.gdshader), by `PrintFrame`.
var overlay_material: ShaderMaterial = ShaderMaterial.new()
## The pencil grid behind the player's items (board_grid.gdshader), drawn by `CombatViewFramed`.
var grid_material: ShaderMaterial = ShaderMaterial.new()
## Print frame settings changed from their defaults (setting -> value); see `print_setting()`.
var print_settings: Dictionary = {}

var _background_defaults: Dictionary = {}   # background wear uniform -> default value, read from its code
var _panel_defaults: Dictionary = {}   # panel wear uniform -> default value, read from its code
var _print_defaults: Dictionary = {}   # border, corridor overlay and board grid uniform -> default value
var _panel_children: Dictionary = {}   # parent canvas item RID -> [child RID, frame last cleared, rect drawn, material]
var _panel_seed_count: int = 0


func _ready() -> void:
  background_material.shader = BACKGROUND_SHADER
  panel_material.shader = PANEL_SHADER
  border_material.shader = BORDER_SHADER
  overlay_material.shader = OVERLAY_SHADER
  grid_material.shader = GRID_SHADER
  _write_print_defaults()
  _write_background_defaults()
  push_wear_colours()
  get_tree().node_removed.connect(_on_node_removed)
  apply_sheet_spacing()


func _exit_tree() -> void:
  for entry: Array in _panel_children.values():
    RenderingServer.free_rid(entry[0])
  _panel_children.clear()


## The canvas item `WornStyleBox` draws a control's worn panel background into, creating it the first
## time it is asked for a given `parent` (the control's own canvas item RID). Cleared once per process
## frame, so a control drawing several styles in one frame (e.g. normal then focus) keeps both, and a
## resize leaves nothing from an earlier frame. Also cleared when `rect` differs from the one drawn
## earlier in the frame: a control resized and drawn again within one frame would otherwise keep its
## style at the old size as well.
func panel_wear_child(parent: RID, rect: Rect2) -> RID:
  var child: RID = panel_child(parent)
  var entry: Array = _panel_children[parent]
  var frame: int = Engine.get_process_frames()
  if entry[1] != frame or entry[2] != rect:
    RenderingServer.canvas_item_clear(child)
    entry[1] = frame
    entry[2] = rect
  return child


## The same canvas item, without clearing it. Clearing it would wipe the panel drawn into it this frame.
func panel_child(parent: RID) -> RID:
  if not _panel_children.has(parent):
    var child: RID = RenderingServer.canvas_item_create()
    RenderingServer.canvas_item_set_parent(child, parent)
    RenderingServer.canvas_item_set_draw_behind_parent(child, true)
    var material: ShaderMaterial = panel_material.duplicate() as ShaderMaterial
    _panel_seed_count += 1
    material.set_shader_parameter('panel_seed', float(_panel_seed_count))
    RenderingServer.canvas_item_set_material(child, material.get_rid())
    _panel_children[parent] = [child, -1, Rect2(), material]
  return _panel_children[parent][0]


## Set a per-panel value (its rect, or a control highlight amount) on the material of the panel drawn
## behind `parent`, creating its canvas item if there is none yet.
func set_panel_value(parent: RID, uniform: String, value: Variant) -> void:
  panel_child(parent)
  (_panel_children[parent][3] as ShaderMaterial).set_shader_parameter(uniform, value)


## The material of the panel drawn behind `parent`, or null if it has none.
func panel_material_of(parent: RID) -> ShaderMaterial:
  return _panel_children[parent][3] if _panel_children.has(parent) else null


## Set a setting shared by every worn panel, on `panel_material` and on every panel's own copy: a panel
## wear or control highlight setting, or a colour pushed from `Colours`.
func set_panel_setting(uniform: String, value: Variant) -> void:
  panel_material.set_shader_parameter(uniform, value)
  for entry: Array in _panel_children.values():
    (entry[3] as ShaderMaterial).set_shader_parameter(uniform, value)


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
  set_panel_setting('wear_dark_colour', Colours.UI_PANEL_WEAR)
  set_panel_setting('wear_light_colour', Colours.UI_PANEL_WEAR_LIGHT)
  apply_token_style()


## Write the token settings onto the theme's token styles: the shadow, whose colour comes from
## `Colours`, and the fill, blended from `Colours.UI_BACKGROUND` towards `Colours.UI_TOKEN_CARD`. Both
## are worked out from `Colours`, so this runs again after an interface palette sets them. The
## token's edge is the panel wear's worn edge (docs/systems/panel_wear.md). `WornStyleBox` does not
## pass on its wrapped style's `changed` signal, so each wrapper
## emits its own, which the theme passes on to every control using it.
func apply_token_style() -> void:
  var theme: Theme = ThemeDB.get_project_theme()
  if theme == null:
    return
  var shadow_colour: Color = Colours.UI_PANEL_SHADOW
  shadow_colour.a = print_setting('token_shadow_darkness')
  var fill_colour: Color = Colours.UI_BACKGROUND.lerp(Colours.UI_TOKEN_CARD, print_setting('token_fill_amount'))
  for type: String in TOKEN_STYLES:
    var worn: WornStyleBox = theme.get_stylebox('panel', type) as WornStyleBox
    var box: StyleBoxFlat = worn.base as StyleBoxFlat
    box.shadow_size = roundi(print_setting('token_shadow_size'))
    box.shadow_offset = Vector2.ONE * float(print_setting('token_shadow_offset'))
    box.shadow_color = shadow_colour
    box.bg_color = fill_colour
    worn.emit_changed()


## Write the character sheet's two gaps onto the theme (docs/systems/ui_theme.md): `section_gap` between
## the parts of the sheet (`SheetColumn`, `SheetRow`, `SheetStack`) and `label_gap` between a label and
## its box (`SheetSection`). Every part of the combat view's right column is laid out with these styles,
## so the gaps are the same everywhere.
func apply_sheet_spacing() -> void:
  var theme: Theme = ThemeDB.get_project_theme()
  if theme == null:
    return
  for type: String in SHEET_GAP_STYLES:
    theme.set_constant('separation', type, roundi(print_setting('section_gap')))
  theme.set_constant('separation', 'SheetSection', roundi(print_setting('label_gap')))


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


## Every border, corridor overlay and board grid uniform with a default in their own shader code
## (uniform name -> value), except `PRINT_FRAME_UNIFORMS`. The overlay's copy of the background wear
## settings is not included.
func print_defaults() -> Dictionary:
  if _print_defaults.is_empty():
    var code: String = '\n'.join([BORDER_SHADER.code, OVERLAY_SHADER.code, GRID_SHADER.code])
    _print_defaults = _uniform_defaults(code, PRINT_FRAME_UNIFORMS)
  return _print_defaults


## A print frame setting's current value: changed in `print_settings`, otherwise its default.
func print_setting(setting: String) -> Variant:
  return print_settings.get(setting, PRINT_SETTING_DEFAULTS[setting])


## Set a border, corridor overlay or board grid uniform, a panel wear uniform, or a print frame
## setting, by name. Unknown names are ignored.
func set_print_value(setting: String, value: Variant) -> void:
  if print_defaults().has(setting):
    _print_material(setting).set_shader_parameter(setting, value)
  elif panel_defaults().has(setting):
    set_panel_setting(setting, value)
  elif PRINT_SETTING_DEFAULTS.has(setting):
    print_settings[setting] = value
    apply_token_style()
    apply_sheet_spacing()


func _print_material(uniform: String) -> ShaderMaterial:
  if uniform.begins_with('board_grid'):
    return grid_material
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


## Every panel wear, border, corridor overlay and board grid effect back to its shader default, and
## no print frame settings. Background wear has its own reset.
func reset_print_look() -> void:
  _write_print_defaults()
  print_settings.clear()
  apply_token_style()
  apply_sheet_spacing()


## Every background wear effect back to its shader default.
func reset_background_look() -> void:
  _write_background_defaults()


## Write the current print look into a preset file: every panel wear, border, corridor overlay and
## board grid setting, and every print frame setting. Background wear is written by
## `write_background_look`.
func write_print_look(file: ConfigFile) -> void:
  for uniform: String in panel_defaults():
    file.set_value('print_panel', uniform, panel_material.get_shader_parameter(uniform))
  for uniform: String in print_defaults():
    file.set_value('print_frame', uniform, _print_material(uniform).get_shader_parameter(uniform))
  for setting: String in PRINT_SETTING_DEFAULTS:
    file.set_value('print_layout', setting, print_setting(setting))


## Write the current background wear into a preset file: every background wear setting.
func write_background_look(file: ConfigFile) -> void:
  for uniform: String in background_defaults():
    file.set_value('print_background', uniform, background_material.get_shader_parameter(uniform))


## Set the print look from a preset file written by `write_print_look`, starting from the print
## defaults. Settings the file leaves out keep their defaults.
func read_print_look(file: ConfigFile) -> void:
  reset_print_look()
  var panel: Dictionary = panel_defaults()
  for uniform: String in _section_keys(file, 'print_panel'):
    if panel.has(uniform):
      set_panel_setting(uniform, file.get_value('print_panel', uniform))
  for setting: String in _section_keys(file, 'print_frame'):
    set_print_value(setting, file.get_value('print_frame', setting))
  for setting: String in _section_keys(file, 'print_layout'):
    set_print_value(setting, file.get_value('print_layout', setting))


## Set the background wear from a preset file written by `write_background_look`, starting from the
## background defaults. Settings the file leaves out keep their defaults.
func read_background_look(file: ConfigFile) -> void:
  reset_background_look()
  var background: Dictionary = background_defaults()
  for uniform: String in _section_keys(file, 'print_background'):
    if background.has(uniform):
      background_material.set_shader_parameter(uniform, file.get_value('print_background', uniform))


# Every uniform is set explicitly, so a saved preset lists every one of them.
func _write_print_defaults() -> void:
  var panel: Dictionary = panel_defaults()
  for uniform: String in panel:
    set_panel_setting(uniform, panel[uniform])
  var frame: Dictionary = print_defaults()
  for uniform: String in frame:
    _print_material(uniform).set_shader_parameter(uniform, frame[uniform])


func _write_background_defaults() -> void:
  var background: Dictionary = background_defaults()
  for uniform: String in background:
    background_material.set_shader_parameter(uniform, background[uniform])


func _section_keys(file: ConfigFile, section: String) -> PackedStringArray:
  return file.get_section_keys(section) if file.has_section(section) else PackedStringArray()
