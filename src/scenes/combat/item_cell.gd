class_name ItemCell
extends Control
## One board item in the framed combat view (docs/systems/ui_layout.md): a cardboard token frame
## (PanelToken) holding the item's icon (`ItemDef.icon`), a row of mechanic-coloured value pills straddling
## the top edge (one per mechanic effect), a cooldown fill over the icon (a semi-transparent fill
## rising from the bottom edge with a solid torn-paper line along its top, drawn by
## `cooldown_fill.gdshader`), and a scale-punch recoil when it fires. Structure is authored in
## item_cell.tscn, including the pills; this binds the data, drives the fill's shader and fills in the pills.
## Reads the live Item; writes nothing.
##
## The recoil is a pure function of the COMBAT clock (render_time − fire_time, the
## vfx_driver.md rule) — under hover slow-mo it glides with everything else, and pause
## freezes it. The Timekeeper is RefCounted, so holding it here outlives the fight's
## teardown safely.

const CELL_SIZE := Vector2(120, 120)   # the default (the player's prominent board); HUDs shrink it
const COOLDOWN_SHADER: Shader = preload('res://src/shaders/cooldown_fill.gdshader')
const RECOIL_SCALE: float = 1.3
const RECOIL_DURATION: float = 0.18    # combat-clock seconds

var item: Item
var cell_size: Vector2 = CELL_SIZE
var _pill_ratio: float = 1.0   # the `pill_size` print setting the pills were built with
var _shown_level: int = 1      # the item level the pills and the level tag were built for
var _tag_settings: Vector2 = Vector2.ZERO   # the level tag's print settings it was placed with
# False outside a fight: the fill is hidden whatever the item's progress. Applies at once.
var show_cooldown: bool = true:
  set(value):
    show_cooldown = value
    if not value:
      _recoil_start = -1.0   # the reset at fight end is not a fire; drop any recoil it started
      scale = Vector2.ONE
    if is_node_ready():
      _update_cooldown()

## True while the tooltip poll reports this cell as the one under the pointer. Board items take no
## mouse events of their own (mouse_filter = ignore, docs/systems/tooltips.md), so the framed combat
## view sets this instead of a `UIJuice` node doing it.
var hovered: bool = false:
  set(value):
    if hovered == value:
      return
    hovered = value
    _hover_to(1.0 if value else 0.0)
    if value:
      SfxManager.play_ui_hover()

@onready var _pills: HBoxContainer = $Pills
@onready var _frame: Control = $Frame
@onready var _icon: TextureRect = $Frame/Icon
@onready var _cooldown: ColorRect = $Cooldown
@onready var _temporary_tag: Control = $TemporaryTag
@onready var _level_tag: Control = $LevelTag
@onready var _level_label: Label = $LevelTag/Label

var _timekeeper: Timekeeper = null     # the fight's clock; null = no recoil (sandbox/tests)
var _last_progress: float = 0.0        # a fresh fight starts at 0 — no spurious recoil on bind
var _last_fires: int = 0               # a relic's fire count at the last frame (relics recoil on a new fire)
var _recoil_start: float = -1.0        # render_time at the last fire; -1 = idle
var _hover: float = 0.0                # how far the highlight has come in
var _hover_tween: Tween
var _askew: Vector3 = Vector3.ZERO     # this cell's tilt and shift, each from -1 to 1 (set_askew)
static var _seed_count: int = 0        # a different tear in each cell


func _ready() -> void:
  pivot_offset = cell_size * 0.5   # recoil / hover scale from the centre
  _seed_count += 1
  var cooldown_material: ShaderMaterial = ShaderMaterial.new()
  cooldown_material.shader = COOLDOWN_SHADER
  cooldown_material.set_shader_parameter('cell_seed', float(_seed_count))
  cooldown_material.set_shader_parameter('fill_colour', Colours.COOLDOWN_FILL)
  cooldown_material.set_shader_parameter('line_colour', Colours.COOLDOWN_RING)
  _cooldown.material = cooldown_material
  _push_cooldown_size()
  var askew_rng: RandomNumberGenerator = RandomNumberGenerator.new()
  askew_rng.seed = _seed_count
  _askew = Vector3(askew_rng.randf_range(-1.0, 1.0), askew_rng.randf_range(-1.0, 1.0), askew_rng.randf_range(-1.0, 1.0))
  # The highlight goes on the frame, not the cell: the value pills hang outside the cell's rectangle.
  ControlFeedback.attach(_frame, false)


## Shrink the cell (the enemy HUDs / ally slots use smaller cells than the player's board, which
## shrinks its own as it fills). Call after the cell is in the tree. A cell that already holds an
## item rebuilds its pills at the new size.
func set_cell_size(px: float) -> void:
  cell_size = Vector2(px, px)
  custom_minimum_size = cell_size
  # A cell anchored to fill its parent (the potion slot's) takes its size from the parent.
  if anchor_left == anchor_right and anchor_top == anchor_bottom:
    size = cell_size
  pivot_offset = cell_size * 0.5
  if is_node_ready():
    _push_cooldown_size()
    if item != null:
      _build_pills()


## Set the cell down slightly askew, like a cardboard token placed by hand: up to `tilt_degrees` of
## rotation and `shift` pixels of offset, the same share of each for this cell every time. Drawn with
## the visual-only offset transform, so the grid's layout is unchanged.
func set_askew(tilt_degrees: float, shift: float) -> void:
  offset_transform_enabled = true
  offset_transform_pivot_ratio = Vector2(0.5, 0.5)
  offset_transform_rotation = deg_to_rad(_askew.x * tilt_degrees)
  offset_transform_position = Vector2(_askew.y, _askew.z) * shift


func _exit_tree() -> void:
  if _hover_tween and _hover_tween.is_valid():
    _hover_tween.kill()
  _hover_tween = null
  # CLAUDE.md runtime cleanup: drop the live refs on free.
  item = null
  _timekeeper = null
  _icon.texture = null
  _cooldown.material = null


## Bind to an item. Call after the cell is in the tree (so the node refs exist).
## `timekeeper` is the fight's clock for the recoil; null (default) disables it.
## `temporary` shows the tag for an item created during the fight, which leaves when the fight ends.
func setup(target_item: Item, timekeeper: Timekeeper = null, temporary: bool = false) -> void:
  item = target_item
  _timekeeper = timekeeper
  _last_fires = item.fires if item != null else 0
  _temporary_tag.visible = temporary
  _icon.texture = load(item.def.icon) as Texture2D if item != null and item.def.icon != '' else null
  _build_pills()
  _update_level_tag()
  _update_cooldown()


## Show a picture with no item behind it (a map square's token): no value pills, no cooldown fill and
## no "Temporary" tag. Call after the cell is in the tree.
func show_picture(texture: Texture2D) -> void:
  item = null
  _temporary_tag.visible = false
  _icon.texture = texture
  show_cooldown = false
  _build_pills()
  _update_level_tag()


## Tint the picture, for a single-colour icon such as a map square's. With `as_picture` the icon keeps
## the item icons' material and takes every picture effect; otherwise it is drawn with the interface
## element material, like the value pills, so the palette colour is kept
## (docs/systems/interface_look.md).
func tint_picture(colour: Color, as_picture: bool = false) -> void:
  _icon.self_modulate = colour
  _icon.material = InterfaceLook.framed_material if as_picture else InterfaceLook.element_material


## Keep the selected border on, such as on the map's current square (docs/systems/control_feedback.md).
func set_marked(marked: bool) -> void:
  ControlFeedback.set_selected(_frame, marked)


## A pill per mechanic effect (damage, shield, heal ...), tinted by the mechanic's colour. An effect
## that applies a status (Mighty Blow's Empowered) or is not a mechanic (an attack bonus, decision #60)
## gets no pill; its amount is in the tooltip. The
## pills sit in a centred row straddling the top edge (vertical centre on the frame's top border).
## The pills are placed in item_cell.tscn; unused ones stay hidden.
func _build_pills() -> void:
  var pills: Array[Node] = _pills.get_children()
  for pill: Node in pills:
    (pill as ValuePill).visible = false
  _pill_ratio = PrintLook.print_setting('pill_size')
  if item == null:
    return
  # Every pill is the same size whatever the cell's size, so its number reads the same everywhere.
  var ratio: float = _pill_ratio
  _pills.add_theme_constant_override('separation', int(round(4.0 * ratio)))
  var index: int = 0
  for effect: ItemEffect in item.def.effects:
    if effect.kind != Delivery.Kind.MECHANIC or not MechanicRegistry.is_mechanic(effect.mechanic):
      continue   # an effect that is not a mechanic (an attack bonus) is written in the tooltip only
    if index >= pills.size():
      push_error('ItemCell: %s has more values than item_cell.tscn has pills' % item.def.id)
      break
    var pill: ValuePill = pills[index]
    pill.visible = true
    pill.setup(TooltipContent.fmt(item.display_value(effect)), _effect_color(effect), ratio)
    index += 1
  var pills_size: Vector2 = _pills.get_combined_minimum_size()
  _pills.size = pills_size
  _pills.position = Vector2((cell_size.x - pills_size.x) * 0.5, -pills_size.y * 0.5)


## The level tag: the item's level in a corner of the cell, hidden at level 1 (decision #61). It is drawn
## over the cell and takes no layout space. Its corner and size are the `level_tag_corner` and
## `level_tag_size` print settings (F7). A placeholder look; the owner picks the real one.
func _update_level_tag() -> void:
  _shown_level = item.level if item != null else 1
  _level_tag.visible = _shown_level > 1
  if not _level_tag.visible:
    return
  _level_label.text = str(_shown_level)
  _level_tag.size = _level_tag.get_combined_minimum_size()
  _tag_settings = _level_tag_settings()
  var corner: int = int(_tag_settings.x)   # top left, top right, bottom left, bottom right
  var ratio: float = _tag_settings.y
  _level_tag.scale = Vector2(ratio, ratio)
  var tag_size: Vector2 = _level_tag.size * ratio
  var right: bool = corner == 1 or corner == 3
  var bottom: bool = corner >= 2
  _level_tag.position = Vector2(cell_size.x - tag_size.x if right else 0.0, cell_size.y - tag_size.y if bottom else 0.0)


## The level tag's print settings as (corner, size), to notice a change on the F7 tab.
static func _level_tag_settings() -> Vector2:
  return Vector2(float(PrintLook.print_setting('level_tag_corner')), float(PrintLook.print_setting('level_tag_size')))


## The pill's tint: the mechanic's colour (a mechanic effect's own colour is unset).
func _effect_color(effect: ItemEffect) -> Color:
  return MechanicRegistry.get_mechanic(effect.mechanic).color()


func _process(_delta: float) -> void:
  if _pill_ratio != PrintLook.print_setting('pill_size'):
    _build_pills()
  if item == null:
    return
  if item.level != _shown_level:   # merged: its values and its tag changed
    _build_pills()
    _update_level_tag()
  elif _level_tag.visible and _tag_settings != _level_tag_settings():
    _update_level_tag()
  var progress: float = item.cooldown.progress()
  # A relic's bar is full for a single step before it fires, which a frame can miss, so a relic
  # recoils on a new fire instead of on its bar emptying.
  var fired: bool = item.fires > _last_fires if item.def is RelicDef else progress < _last_progress - 0.2
  if show_cooldown and fired:
    _recoil_start = _timekeeper.render_time() if _timekeeper != null else -1.0
  _last_progress = progress
  _last_fires = item.fires
  _update_recoil()
  _update_cooldown()


## Scale = f(render_time − fire_time): the same stateless pattern as the projectiles,
## so the recoil honours slow-mo and pause instead of popping at wall speed.
func _update_recoil() -> void:
  if _recoil_start < 0.0 or _timekeeper == null:
    scale = Vector2.ONE
    return
  var since: float = _timekeeper.render_time() - _recoil_start
  if since >= RECOIL_DURATION:
    scale = Vector2.ONE
    _recoil_start = -1.0
    return
  var s: float = Tween.interpolate_value(
      RECOIL_SCALE, 1.0 - RECOIL_SCALE, since, RECOIL_DURATION, Tween.TRANS_BACK, Tween.EASE_OUT)
  scale = Vector2(s, s)


## The fill covers the cell up to the cooldown's progress, and is hidden outright once the item is
## ready, so a charged item shows its art unobscured. Hidden entirely when show_cooldown is off.
func _update_cooldown() -> void:
  var progress: float = item.cooldown.progress() if item != null else 1.0
  # A relic has no bar to show (docs/systems/content.md → Relic).
  _cooldown.visible = show_cooldown and progress < 1.0 and not (item != null and item.def is RelicDef)
  if _cooldown.visible:
    (_cooldown.material as ShaderMaterial).set_shader_parameter('cooldown_progress', progress)


func _push_cooldown_size() -> void:
  (_cooldown.material as ShaderMaterial).set_shader_parameter('rect_size', cell_size)


## Centre of the cell in global (screen) space — the VFX wall reads it. With a centre
## pivot, scaling keeps the visual centre fixed, so scale plays no part here.
func cell_centre() -> Vector2:
  return global_position + cell_size * 0.5


func _hover_to(amount: float) -> void:
  if not is_node_ready():
    return
  if _hover_tween and _hover_tween.is_valid():
    _hover_tween.kill()
  var set_hover: Callable = func(value: float) -> void:
    _hover = value
    ControlFeedback.set_hover(_frame, value)
  _hover_tween = create_tween()
  _hover_tween.tween_method(set_hover, _hover, amount, ControlFeedback.setting_float('hover_time'))
