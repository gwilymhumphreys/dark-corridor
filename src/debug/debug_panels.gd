class_name DebugPanelsAutoload
extends Node
## Dev-only debug panel + the full-screen palette clamp (docs/systems/debug_panel.md,
## docs/systems/palette_clamp.md). Registered as the `DebugPanels` autoload so the panel and the
## clamp cover every screen, the corridor testbed and the combat sandbox. It also owns the world
## clamp material that the combat corridor is drawn through.
##
## F1 toggles the panel, in debug builds only. Choices last for the session only. Panel text is
## English on purpose: `tools/extract_pot.gd` skips `src/debug/`.

enum CorridorKind { SCALED, PERSPECTIVE, THREE_D }
enum EnemyImages { PAINTED, PIXEL, CUT_OUT }

const PALETTE_ROOT: String = 'res://assets/palettes'
const MAX_COLOURS: int = 64   # must match MAX_COLOURS in palette_clamp.gdshaderinc
const WORLD_CLAMP_SHADER: Shader = preload('res://src/shaders/world_clamp.gdshader')
const CORRIDOR_SCENES: Dictionary = {
  CorridorKind.SCALED: preload('res://src/scenes/corridors/corridor_scaled.tscn'),
  CorridorKind.PERSPECTIVE: preload('res://src/scenes/corridors/corridor_perspective.tscn'),
  CorridorKind.THREE_D: preload('res://src/scenes/corridors/corridor_3d.tscn'),
}

## The renderer `CombatCorridor` instances. Read when a fight's combat view is built.
var corridor_kind: CorridorKind = CorridorKind.SCALED
## How the 3D corridor is lit: its shader light or four wall lights. Read per fight.
var corridor_light: Corridor3D.LightMode = Corridor3D.LightMode.SHADER
## Renderer exports set from `--corridor-set=property=value` arguments (property -> value). The
## combat corridor applies them before its renderer enters the tree.
var corridor_settings: Dictionary = {}
## Whether enemies use a random painted sample (with or without its black background) or the
## original pixel sprite. Read per fight.
var enemy_images: EnemyImages = EnemyImages.CUT_OUT
## The palette file the world clamp on the combat corridor uses, or '' when it is off.
var world_palette: String = ''
## The material every combat corridor is drawn through. Its palette follows `world_palette`.
var world_material: ShaderMaterial = ShaderMaterial.new()

var _palette_paths: Array[String] = []   # item id - 1 -> palette path, in both palette options (id 0 = Off)
var _palettes_scanned: bool = false
var _perceptual: bool = false
var _dithering: bool = false

@onready var _clamp_layer: CanvasLayer = $ClampLayer
@onready var _clamp_material: ShaderMaterial = $ClampLayer/ClampRect.material
@onready var _panel_layer: CanvasLayer = $PanelLayer
@onready var _palette_option: OptionButton = $PanelLayer/Panel/Rows/PaletteRow/Option
@onready var _world_option: OptionButton = $PanelLayer/Panel/Rows/WorldPaletteRow/Option
@onready var _matching_option: OptionButton = $PanelLayer/Panel/Rows/MatchingRow/Option
@onready var _dithering_check: CheckButton = $PanelLayer/Panel/Rows/DitheringRow/Check
@onready var _corridor_option: OptionButton = $PanelLayer/Panel/Rows/CorridorRow/Option
@onready var _light_option: OptionButton = $PanelLayer/Panel/Rows/LightRow/Option
@onready var _enemy_option: OptionButton = $PanelLayer/Panel/Rows/EnemyRow/Option


func _ready() -> void:
  _clamp_layer.visible = false
  _panel_layer.visible = false
  world_material.shader = WORLD_CLAMP_SHADER
  _write_palette(world_material, PackedColorArray())
  _palette_option.item_selected.connect(_on_palette_selected)
  _world_option.item_selected.connect(_on_world_palette_selected)
  _matching_option.item_selected.connect(_on_matching_selected)
  _dithering_check.toggled.connect(_on_dithering_toggled)
  _corridor_option.item_selected.connect(_on_corridor_selected)
  _light_option.item_selected.connect(_on_light_selected)
  _enemy_option.item_selected.connect(_on_enemy_selected)
  _sync_controls()
  _apply_command_line()


## Dev hooks for screenshots: `--palette=<res path>` starts with that palette clamped,
## `--world-palette=<res path>` sets the world clamp, `--perceptual` and `--dither` set
## the matching and dithering.
func _apply_command_line() -> void:
  var args: PackedStringArray = OS.get_cmdline_user_args()
  for arg: String in args:
    if arg.begins_with('--palette='):
      set_palette(PaletteLoader.load_palette(arg.substr(10)))
    elif arg.begins_with('--world-palette='):
      set_world_palette(arg.substr(16))
    elif arg.begins_with('--corridor='):
      var kinds: Dictionary = { 'scaled': CorridorKind.SCALED, 'perspective': CorridorKind.PERSPECTIVE, '3d': CorridorKind.THREE_D }
      corridor_kind = kinds.get(arg.substr(11), corridor_kind)
    elif arg.begins_with('--corridor-set='):
      var pair: PackedStringArray = arg.substr(15).split('=')
      if pair.size() == 2:
        corridor_settings[pair[0]] = str_to_var(pair[1])
    elif arg.begins_with('--corridor-light='):
      var modes: Dictionary = { 'shader': Corridor3D.LightMode.SHADER, 'walls': Corridor3D.LightMode.WALL_LIGHTS }
      corridor_light = modes.get(arg.substr(17), corridor_light)
    elif arg.begins_with('--monster-image='):
      MonsterImages.forced_path = arg.substr(16)
  if '--perceptual' in args:
    _on_matching_selected(1)
  if '--dither' in args:
    _on_dithering_toggled(true)
  _sync_controls()


func _exit_tree() -> void:
  _palette_paths.clear()


func _input(event: InputEvent) -> void:
  if not OS.is_debug_build():
    return
  if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
    toggle_panel()
    get_viewport().set_input_as_handled()


func toggle_panel() -> void:
  if not _palettes_scanned:
    _scan_palettes()
  _panel_layer.visible = not _panel_layer.visible


## The renderer scene for the chosen corridor kind.
func corridor_scene() -> PackedScene:
  return CORRIDOR_SCENES[corridor_kind]


## Back to the defaults: both clamps off, scaled corridor, painted enemies. Used between tests.
func reset_settings() -> void:
  corridor_kind = CorridorKind.SCALED
  corridor_light = Corridor3D.LightMode.SHADER
  corridor_settings.clear()
  enemy_images = EnemyImages.CUT_OUT
  MonsterImages.forced_path = ''
  set_palette(PackedColorArray())
  set_world_palette('')
  _on_matching_selected(0)
  _on_dithering_toggled(false)
  if _palettes_scanned:
    _palette_option.select(0)
    _world_option.select(0)
  _sync_controls()


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
  _corridor_option.select(corridor_kind)
  _light_option.select(corridor_light)
  _enemy_option.select(enemy_images)
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


func _on_corridor_selected(index: int) -> void:
  corridor_kind = index as CorridorKind


func _on_light_selected(index: int) -> void:
  corridor_light = index as Corridor3D.LightMode


func _on_enemy_selected(index: int) -> void:
  enemy_images = index as EnemyImages
