class_name HealthBar
extends VBoxContainer
## The health bar shared by the player portrait, the enemy panel and the ally slots
## (docs/systems/mechanics.md → Health bar). Shield is drawn over health from the left, and the
## bar's width stands for max health or shield, whichever is larger, so either can grow past the
## other. A faint line marks every LINE_STEP points. On the bar: the shield icon and value at the
## left, the health in the centre, and the other mechanic statuses (StatusNumbers) at the right. Reads the actor each frame; writes
## nothing.

const LINE_STEP: int = 100             # points between the faint lines across the bar
const SCALE_EASE_SPEED: float = 8.0    # how fast the bar's scale eases to a new size (per second)
const LINE_WIDTH: float = 2.0

## The bar's size in canvas pixels; each view sets its own.
@export var bar_size: Vector2 = Vector2(400, 40):
  set(value):
    bar_size = value
    if is_node_ready():
      _bar.custom_minimum_size = value
## The `Colours` variables for the health fill and the empty part of the bar.
@export var fill_colour_name: String = 'HP_BAR_FILL'
@export var background_colour_name: String = 'HP_BAR_BG'
## The text ladder rung for the health label.
@export var label_variation: StringName = &''

var actor: Actor = null:
  set(value):
    actor = value
    if is_node_ready():
      _status_numbers.actor = value
      _shown_scale = _target_scale()

var _shown_scale: float = 1.0   # the points the full bar width stands for, eased towards the target

@onready var _shield: HBoxContainer = $Bar/Shield
@onready var _shield_icon: TextureRect = $Bar/Shield/Icon
@onready var _shield_value: Label = $Bar/Shield/Value
@onready var _bar: Control = $Bar
@onready var _background: NamedColourRect = $Bar/Background
@onready var _health_fill: NamedColourRect = $Bar/HealthFill
@onready var _shield_fill: NamedColourRect = $Bar/ShieldFill
@onready var _lines: Control = $Bar/Lines
@onready var _label: Label = $Bar/Label
@onready var _status_numbers: StatusNumbers = $Bar/StatusNumbers


func _ready() -> void:
  _bar.custom_minimum_size = bar_size
  _background.colour_name = background_colour_name
  _background._copy_colour()
  _health_fill.colour_name = fill_colour_name
  _health_fill._copy_colour()
  _label.theme_type_variation = label_variation
  var icon_path: String = MechanicRegistry.get_mechanic(ShieldMechanic.ID).icon
  _shield_icon.texture = load(icon_path) as Texture2D
  # Drawn in the text colour, like the health number: the readout sits on the shield fill, which is
  # the shield colour.
  KeywordIcon.dress(_shield_icon, icon_path, Colours.UI_TEXT)
  _lines.draw.connect(_draw_lines)
  _status_numbers.actor = actor
  _shown_scale = _target_scale()


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
  _health_fill.anchor_right = clampf(actor.hp / _shown_scale, 0.0, 1.0)
  _health_fill.offset_right = 0.0
  _shield_fill.anchor_right = clampf(shield / _shown_scale, 0.0, 1.0)
  _shield_fill.offset_right = 0.0
  _label.text = str(actor.hp)
  _shield.visible = shield > 0
  _shield_value.text = str(shield)


func _exit_tree() -> void:
  actor = null


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
