class_name HealthBar
extends VBoxContainer
## The health bar shared by the player portrait, the enemy panel and the ally slots
## (docs/systems/mechanics.md → Health bar). Shield is drawn over health from the left, and the
## bar's width stands for max health or shield, whichever is larger, so either can grow past the
## other. When health or shield changes, its fill moves to the new value over CHANGE_DURATION rather
## than jumping. A faint line marks every LINE_STEP points. On the bar, one centred row: the health, then
## the shield icon and value, then the other mechanic statuses (StatusNumbers). The shield readout
## pops in when shield appears and bumps when it rises (PopAnimation). Reads the actor each frame;
## writes nothing.

const LINE_STEP: int = 100             # points between the faint lines across the bar
const SCALE_EASE_SPEED: float = 8.0    # how fast the bar's scale eases to a new size (per second)
const LINE_WIDTH: float = 2.0
const CHANGE_DURATION: float = 0.3     # seconds a fill takes to move to a new health or shield value

## The bar's size in canvas pixels; each view sets its own.
@export var bar_size: Vector2 = Vector2(266, 40):
  set(value):
    bar_size = value
    if is_node_ready():
      _bar.custom_minimum_size = value
## The `Colours` variables for the health fill and the empty part of the bar.
@export var fill_colour_name: String = 'HP_BAR_FILL'
@export var background_colour_name: String = 'HP_BAR_BG'

var actor: Actor = null:
  set(value):
    actor = value
    if is_node_ready():
      _status_numbers.actor = value
      _shown_scale = _target_scale()
      _snap_fills()

var _shown_scale: float = 1.0   # the points the full bar width stands for, eased towards the target
var _health: EasedValue = EasedValue.new()   # the health the fill shows
var _shield_points: EasedValue = EasedValue.new()   # the shield the fill shows
var _shield_shown: int = 0   # the shield the readout showed last frame, to spot it appearing or rising

@onready var _shield: HBoxContainer = $Bar/Readout/Shield
@onready var _shield_icon: TextureRect = $Bar/Readout/Shield/Icon
@onready var _shield_value: Label = $Bar/Readout/Shield/Value
@onready var _bar: Control = $Bar
@onready var _background: NamedColourRect = $Bar/Background
@onready var _health_fill: NamedColourRect = $Bar/HealthFill
@onready var _shield_fill: NamedColourRect = $Bar/ShieldFill
@onready var _lines: Control = $Bar/Lines
@onready var _label: Label = $Bar/Readout/Label
@onready var _status_numbers: StatusNumbers = $Bar/Readout/StatusNumbers


func _ready() -> void:
  _bar.custom_minimum_size = bar_size
  _background.colour_name = background_colour_name
  _background._copy_colour()
  _health_fill.colour_name = fill_colour_name
  _health_fill._copy_colour()
  var shield_mechanic: Mechanic = MechanicRegistry.get_mechanic(ShieldMechanic.ID)
  _shield_icon.texture = load(shield_mechanic.icon) as Texture2D
  KeywordIcon.dress(_shield_icon, shield_mechanic.icon, shield_mechanic.color())
  _shield_value.modulate = shield_mechanic.color()
  _lines.draw.connect(_draw_lines)
  _status_numbers.actor = actor
  _shown_scale = _target_scale()
  _snap_fills()


func _process(delta: float) -> void:
  if actor == null:
    _shield.hide()
    return
  var shield: int = StatusManager.stack_count(actor, ShieldMechanic.ID)
  var target: float = _target_scale()
  if not is_equal_approx(_shown_scale, target):
    _shown_scale = lerpf(_shown_scale, target, 1.0 - exp(-SCALE_EASE_SPEED * delta))
    if absf(_shown_scale - target) < 0.5:
      _shown_scale = target
    _lines.queue_redraw()
  var shown_health: float = _health.step(float(actor.hp), delta)
  var shown_shield: float = _shield_points.step(float(shield), delta)
  _health_fill.anchor_right = clampf(shown_health / _shown_scale, 0.0, 1.0)
  _health_fill.offset_right = 0.0
  _shield_fill.anchor_right = clampf(shown_shield / _shown_scale, 0.0, 1.0)
  _shield_fill.offset_right = 0.0
  _label.text = str(actor.hp)
  _shield.visible = shield > 0
  _shield_value.text = str(shield)
  if shield > _shield_shown:
    if _shield_shown == 0:
      PopAnimation.pop_in(_shield)
    else:
      PopAnimation.bump(_shield)
  _shield_shown = shield


func _exit_tree() -> void:
  actor = null


## The centre of the bar in global coordinates, where shield lands (docs/systems/vfx_driver.md).
func bar_centre() -> Vector2:
  return _bar.global_position + _bar.size * 0.5


## Where the mechanic status `id` shows on the bar, in global coordinates: the icon of the shield
## readout or of its StatusNumbers entry (the VFX wall flies the status's projectile there). An entry
## not shown yet is placed where it will appear: after the shown entries before it, with the whole
## readout moved left by half the width it adds, because the readout is centred on the bar.
func status_centre(id: String) -> Vector2:
  var shown: Control = _shield if id == ShieldMechanic.ID else _status_numbers.entry_for(id)
  if shown == null:
    return bar_centre()
  var icon: Control = shown.get_node('Icon')
  if shown.visible:
    return icon.get_global_rect().get_center()
  var row: HBoxContainer = shown.get_parent()
  var separation: float = float(row.get_theme_constant('separation'))
  var left: float = row.global_position.x
  var others: bool = false
  for child: Node in row.get_children():
    var control: Control = child as Control
    if control == null or control == shown or not control.visible:
      continue
    others = true
    if control.get_index() < shown.get_index():
      left = control.global_position.x + control.size.x + separation
  var added: float = shown.get_combined_minimum_size().x + (separation if others else 0.0)
  var icon_width: float = maxf(icon.get_combined_minimum_size().x, icon.custom_minimum_size.y)
  return Vector2(left - added * 0.5 + icon_width * 0.5, bar_centre().y)


# Show the actor's health and shield at once, with no easing: a new actor is not a change.
func _snap_fills() -> void:
  if actor == null:
    return
  _health.snap(float(actor.hp))
  _shield_points.snap(float(StatusManager.stack_count(actor, ShieldMechanic.ID)))


## The points the full bar width should stand for: max health, or shield when it is larger.
func _target_scale() -> float:
  if actor == null:
    return 1.0
  return maxf(float(maxi(actor.max_hp, 1)), float(StatusManager.stack_count(actor, ShieldMechanic.ID)))


## A faint line every LINE_STEP points, and one where max health ends when shield has pushed the
## scale past it (otherwise max health is the bar's right edge).
func _draw_lines() -> void:
  if actor == null:
    return
  var colour: Color = Colours.HP_BAR_LINE
  var width: float = _lines.size.x
  var height: float = _lines.size.y
  var points: int = LINE_STEP
  while points < _shown_scale:
    var x: float = width * points / _shown_scale
    _lines.draw_line(Vector2(x, 0.0), Vector2(x, height), colour, LINE_WIDTH)
    points += LINE_STEP
  if actor.max_hp < _shown_scale:
    var x: float = width * actor.max_hp / _shown_scale
    _lines.draw_line(Vector2(x, 0.0), Vector2(x, height), colour, LINE_WIDTH * 2.0)


## A number shown on the bar that moves to each new value over CHANGE_DURATION, easing out. A
## change that arrives mid-move starts from where the fill is at that moment.
class EasedValue:
  var from: float = 0.0
  var to: float = 0.0
  var elapsed: float = 0.0


  func snap(value: float) -> void:
    from = value
    to = value
    elapsed = CHANGE_DURATION


  ## Move on by `delta` seconds towards `target` and return the value to show.
  func step(target: float, delta: float) -> float:
    if not is_equal_approx(target, to):
      from = shown()
      to = target
      elapsed = 0.0
    elapsed = minf(elapsed + delta, CHANGE_DURATION)
    return shown()


  func shown() -> float:
    var through: float = elapsed / CHANGE_DURATION
    return lerpf(from, to, 1.0 - pow(1.0 - through, 2.0))
