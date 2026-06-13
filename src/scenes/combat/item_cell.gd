class_name ItemCell
extends Control
## One board item in the framed combat view (docs/systems/ui_layout.md): an opaque effect-family
## colour panel + its value, a Bazaar-style radial cooldown ring, and a scale-punch
## recoil when it fires. Structure is authored in item_cell.tscn; this binds the data
## and draws the ring + recoil. Reads the live Item; writes nothing. No alpha.
##
## The recoil is a pure function of the COMBAT clock (render_time − fire_time, the
## vfx_driver.md rule) — under hover slow-mo it glides with everything else, and pause
## freezes it. The Timekeeper is RefCounted, so holding it here outlives the fight's
## teardown safely.

const CELL_SIZE := Vector2(120, 120)   # the default (the player's prominent board); HUDs shrink it
const RECOIL_SCALE: float = 1.3
const RECOIL_DURATION: float = 0.18    # combat-clock seconds

var item: Item
var cell_size: Vector2 = CELL_SIZE

@onready var _panel: ColorRect = $Panel
@onready var _value: Label = $Value

var _timekeeper: Timekeeper = null     # the fight's clock; null = no recoil (sandbox/tests)
var _last_progress: float = 0.0        # a fresh fight starts at 0 — no spurious recoil on bind
var _recoil_start: float = -1.0        # render_time at the last fire; -1 = idle


func _ready() -> void:
  pivot_offset = cell_size * 0.5   # recoil / hover scale from the centre


## Shrink the cell (the enemy HUDs / ally slots use smaller cells than the player's board).
## Call after the cell is in the tree, before setup(). Scales the value font to match.
func set_cell_size(px: float) -> void:
  cell_size = Vector2(px, px)
  custom_minimum_size = cell_size
  size = cell_size
  pivot_offset = cell_size * 0.5
  _value.add_theme_font_size_override('font_size', int(round(44.0 * px / CELL_SIZE.x)))


func _exit_tree() -> void:
  # CLAUDE.md runtime cleanup: drop the live refs on free.
  item = null
  _timekeeper = null


## Bind to an item. Call after the cell is in the tree (so the node refs exist).
## `timekeeper` is the fight's clock for the recoil; null (default) disables it.
func setup(target_item: Item, timekeeper: Timekeeper = null) -> void:
  item = target_item
  _timekeeper = timekeeper
  _panel.color = item.def.panel_color
  _value.text = _value_text()
  queue_redraw()


func _value_text() -> String:
  if item == null or item.def.effects.is_empty():
    return ''
  return str(int(item.def.effects[0].value))


func _process(_delta: float) -> void:
  if item == null:
    return
  var progress: float = item.cooldown.progress()
  if progress < _last_progress - 0.2:   # cooldown reset -> it just fired
    _recoil_start = _timekeeper.render_time() if _timekeeper != null else -1.0
  _last_progress = progress
  _update_recoil()
  queue_redraw()


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


func _draw() -> void:
  draw_rect(Rect2(Vector2.ZERO, cell_size), Color.BLACK, false, Consts.PANEL_BORDER_WIDTH)
  if item == null:
    return
  var progress: float = item.cooldown.progress()
  if progress < 1.0:
    var centre: Vector2 = cell_size * 0.5
    draw_arc(centre, cell_size.x * 0.5 + 8.0, -PI * 0.5, -PI * 0.5 + progress * TAU, Consts.COOLDOWN_RING_SEGMENTS, Colours.COOLDOWN_RING, Consts.COOLDOWN_RING_WIDTH)


## Centre of the cell in global (screen) space — the VFX wall reads it. With a centre
## pivot, scaling keeps the visual centre fixed, so scale plays no part here.
func cell_centre() -> Vector2:
  return global_position + cell_size * 0.5
