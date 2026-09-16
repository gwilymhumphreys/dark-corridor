class_name VfxDriver
extends Node2D
## The combat wall (docs/systems/vfx_driver.md), minimal and grown incrementally. Everything it
## draws is a pure function of the CombatManager's Delivery set + the Timekeeper's render_time():
## projectiles in flight, a burst where each one lands, and pop-in damage numbers. The impact sound
## is the one exception — it fires once per landing at wall-clock speed. Writes no game state.
##
## PLACEHOLDER: the circles drawn here — the projectile disc and the impact ring — are stand-ins so
## the timing and the causal link can be judged. They are meant to be replaced by proper VFX
## animations once those exist; do not treat their shape as the intended look.

const PROJ_RADIUS := 14.0
const NUM_DURATION := 0.6    # seconds a damage number shows (render-time)
const IMPACT_DURATION: float = 0.22   # seconds an impact burst shows (render-time)
const IMPACT_RADIUS_START: float = 12.0
const IMPACT_RADIUS_END: float = 72.0
const IMPACT_WIDTH: float = 12.0      # ring thickness at the moment of the hit
const IMPACT_POINTS: int = 24

var combat: CombatManager
var layout: CombatView        # the swappable view surface — item_pos / actor_pos / target_pos
var _font: Font
var _sounded: Dictionary = {}   # Delivery instance id -> true, so each landing sounds once


func setup(cm: CombatManager, layout_source: CombatView) -> void:
  combat = cm
  layout = layout_source


func _process(_delta: float) -> void:
  _sound_new_impacts()
  queue_redraw()


func _exit_tree() -> void:
  # CLAUDE.md runtime cleanup: drop the live-fight refs and the sounded set on free.
  combat = null
  layout = null
  _font = null
  _sounded.clear()


## How far through its burst a hit landed `age` render-seconds ago is (0 at the moment of the hit,
## towards 1 as it finishes), or -1 when there is no burst to draw.
static func impact_progress(age: float) -> float:
  if age < 0.0 or age >= IMPACT_DURATION:
    return -1.0
  return age / IMPACT_DURATION


func _draw() -> void:
  if combat == null or combat.timekeeper == null:
    return
  # The project theme's font, so damage numbers follow the font style.
  var theme: Theme = ThemeDB.get_project_theme()
  _font = theme.default_font if theme != null and theme.default_font != null else ThemeDB.fallback_font
  var now: float = combat.timekeeper.render_time()
  for d in combat.deliveries():
    if d.fizzled:
      continue
    if d.kind == Delivery.Kind.SUMMON or d.kind == Delivery.Kind.CREATE_ITEM:
      continue   # adds a body / an item to a side; no projectile to draw (the arrival tell is content, not yet built)
    var travel_dur: float = d.travel.threshold * Timekeeper.STEP
    if not d.landed:
      if travel_dur > 0.0:
        var src: Vector2 = layout.item_pos(d.source)
        var dst: Vector2 = layout.target_pos(d.target)   # Actor OR Item target
        var t: float = clampf((now - d.fire_time) / travel_dur, 0.0, 1.0)
        draw_circle(src.lerp(dst, t), PROJ_RADIUS, d.color)   # PLACEHOLDER shape
      continue
    _draw_impact(d, now - d.impact_time)
    if d.kind == Delivery.Kind.DAMAGE:
      var age: float = now - d.impact_time
      if age >= 0.0 and age < NUM_DURATION:
        var pos: Vector2 = layout.target_pos(d.target) + Vector2(-24.0, -190.0 - age * 120.0)
        draw_string(_font, pos, str(int(d.value)), HORIZONTAL_ALIGNMENT_LEFT, -1, 52, d.color)


## A ring that snaps outward from the landing point and thins as it goes, in the delivery's colour
## (the same colour the firing item flashes, so the eye joins the two).
##
## PLACEHOLDER: a drawn circle standing in for a real impact animation.
func _draw_impact(d: Delivery, age: float) -> void:
  var progress: float = impact_progress(age)
  if progress < 0.0:
    return
  var eased: float = 1.0 - pow(1.0 - progress, 3.0)   # fast out, then slow
  var radius: float = lerpf(IMPACT_RADIUS_START, IMPACT_RADIUS_END, eased)
  var width: float = maxf(lerpf(IMPACT_WIDTH, 1.0, eased), 1.0)
  draw_arc(layout.target_pos(d.target), radius, 0.0, TAU, IMPACT_POINTS, d.color, width)


## One sound per landing, played the first time a delivery shows as landed. Sounds are
## fire-and-forget at wall-clock pitch — unlike the drawing, they are not a function of
## render_time, because slowing audio sounds bad. Ids of deliveries the manager has dropped are
## forgotten, so the set stays as small as the fight's live deliveries.
func _sound_new_impacts() -> void:
  if combat == null:
    return
  var live: Dictionary = {}
  for d in combat.deliveries():
    var id: int = d.get_instance_id()
    live[id] = true
    if not d.landed or d.fizzled or _sounded.has(id):
      continue
    _sounded[id] = true
    SfxManager.play_impact()
  for id: int in _sounded.keys():
    if not live.has(id):
      _sounded.erase(id)
