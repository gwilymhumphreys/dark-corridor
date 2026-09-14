class_name DebugPanelsAutoload
extends Node
## Dev-only debug panel + the full-screen palette clamp (docs/systems/debug_panel.md,
## docs/systems/palette_clamp.md). Registered as the `DebugPanels` autoload so the panel and the
## clamp cover every screen, the corridor testbed and the combat sandbox.
##
## F1 toggles the panel, in debug builds only. Choices last for the session only. Panel text is
## English on purpose: `tools/extract_pot.gd` skips `src/debug/`.

enum CorridorKind { SCALED, PERSPECTIVE, THREE_D }
enum EnemyImages { PAINTED, PIXEL }

const PALETTE_ROOT: String = 'res://assets/palettes'
const MAX_COLOURS: int = 64   # must match MAX_COLOURS in palette_clamp.gdshader
const CORRIDOR_SCENES: Dictionary = {
  CorridorKind.SCALED: preload('res://src/scenes/corridors/corridor_scaled.tscn'),
  CorridorKind.PERSPECTIVE: preload('res://src/scenes/corridors/corridor_perspective.tscn'),
  CorridorKind.THREE_D: preload('res://src/scenes/corridors/corridor_3d.tscn'),
}

## The renderer `CombatCorridor` instances. Read when a fight's combat view is built.
var corridor_kind: CorridorKind = CorridorKind.SCALED
## Whether enemies use a random painted sample or the original pixel sprite. Read per fight.
var enemy_images: EnemyImages = EnemyImages.PAINTED

var _palette_paths: Array[String] = []   # OptionButton item id - 1 -> palette path (id 0 = Off)
var _palettes_scanned: bool = false
var _perceptual: bool = false
var _dithering: bool = false

@onready var _clamp_layer: CanvasLayer = $ClampLayer
@onready var _clamp_material: ShaderMaterial = $ClampLayer/ClampRect.material
@onready var _panel_layer: CanvasLayer = $PanelLayer
@onready var _palette_option: OptionButton = $PanelLayer/Panel/Rows/PaletteRow/Option
@onready var _matching_option: OptionButton = $PanelLayer/Panel/Rows/MatchingRow/Option
@onready var _dithering_check: CheckButton = $PanelLayer/Panel/Rows/DitheringRow/Check
@onready var _corridor_option: OptionButton = $PanelLayer/Panel/Rows/CorridorRow/Option
@onready var _enemy_option: OptionButton = $PanelLayer/Panel/Rows/EnemyRow/Option


func _ready() -> void:
  _clamp_layer.visible = false
  _panel_layer.visible = false
  _palette_option.item_selected.connect(_on_palette_selected)
  _matching_option.item_selected.connect(_on_matching_selected)
  _dithering_check.toggled.connect(_on_dithering_toggled)
  _corridor_option.item_selected.connect(_on_corridor_selected)
  _enemy_option.item_selected.connect(_on_enemy_selected)
  _sync_controls()
  _apply_command_line()


## Dev hooks for screenshots: `--palette=<res path>` starts with that palette clamped,
## `--perceptual` and `--dither` set the matching and dithering.
func _apply_command_line() -> void:
  var args: PackedStringArray = OS.get_cmdline_user_args()
  for arg: String in args:
    if arg.begins_with('--palette='):
      set_palette(PaletteLoader.load_palette(arg.substr(10)))
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


## Back to the defaults: clamp off, scaled corridor, painted enemies. Used between tests.
func reset_settings() -> void:
  corridor_kind = CorridorKind.SCALED
  enemy_images = EnemyImages.PAINTED
  set_palette(PackedColorArray())
  _on_matching_selected(0)
  _on_dithering_toggled(false)
  if _palettes_scanned:
    _palette_option.select(0)
  _sync_controls()


## Clamp the screen to `colours`, or turn the clamp off with an empty array.
func set_palette(colours: PackedColorArray) -> void:
  if colours.is_empty():
    _clamp_layer.visible = false
    _clamp_material.set_shader_parameter('colour_count', 0)
    return
  if colours.size() > MAX_COLOURS:
    push_warning('[DebugPanels] palette has %d colours; only the first %d are used' % [colours.size(), MAX_COLOURS])
  var count: int = mini(colours.size(), MAX_COLOURS)
  var rgb: Image = Image.create_empty(MAX_COLOURS, 1, false, Image.FORMAT_RGBA8)
  var lab: Image = Image.create_empty(MAX_COLOURS, 1, false, Image.FORMAT_RGBF)
  for i in count:
    rgb.set_pixel(i, 0, colours[i])
    var oklab: Vector3 = PaletteLoader.to_oklab(colours[i])
    lab.set_pixel(i, 0, Color(oklab.x, oklab.y, oklab.z))
  _clamp_material.set_shader_parameter('palette_rgb', ImageTexture.create_from_image(rgb))
  _clamp_material.set_shader_parameter('palette_lab', ImageTexture.create_from_image(lab))
  _clamp_material.set_shader_parameter('colour_count', count)
  _clamp_layer.visible = true


# The palette folder is scanned on first open, not at startup, so headless tests and autotest
# runs do no extra work.
func _scan_palettes() -> void:
  _palettes_scanned = true
  _palette_option.clear()
  _palette_paths.clear()
  _palette_option.add_item('Off', 0)
  var groups: Dictionary = PaletteLoader.find_palettes(PALETTE_ROOT)
  for folder: String in groups:
    if folder != '':
      _palette_option.add_separator(folder)
    for path: String in groups[folder]:
      _palette_paths.append(path)
      _palette_option.add_item(path.get_file().get_basename(), _palette_paths.size())
  _palette_option.select(0)


func _sync_controls() -> void:
  _corridor_option.select(corridor_kind)
  _enemy_option.select(enemy_images)
  _matching_option.select(1 if _perceptual else 0)
  _dithering_check.set_pressed_no_signal(_dithering)


func _on_palette_selected(index: int) -> void:
  var id: int = _palette_option.get_item_id(index)
  if id <= 0:
    set_palette(PackedColorArray())
    return
  set_palette(PaletteLoader.load_palette(_palette_paths[id - 1]))


func _on_matching_selected(index: int) -> void:
  _perceptual = index == 1
  _clamp_material.set_shader_parameter('perceptual', _perceptual)


func _on_dithering_toggled(on: bool) -> void:
  _dithering = on
  _clamp_material.set_shader_parameter('dithering', _dithering)


func _on_corridor_selected(index: int) -> void:
  corridor_kind = index as CorridorKind


func _on_enemy_selected(index: int) -> void:
  enemy_images = index as EnemyImages
