class_name VfxDriver
extends Node2D
## The combat wall (vfx_driver_prd), minimal + opaque. A pure function of the
## CombatManager's Delivery set + the Timekeeper's render_time(): solid
## projectiles in flight, pop-in damage numbers on landing. No alpha, no impact
## flash / screen pulse yet (grown incrementally). Writes no game state.

const PROJ_RADIUS := 14.0
const NUM_DURATION := 0.6    # seconds a damage number shows (render-time)

var combat: CombatManager
var layout                    # provides item_pos(item) / actor_pos(actor)
var _font: Font


func setup(cm: CombatManager, layout_source) -> void:
  combat = cm
  layout = layout_source
  _font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
  queue_redraw()


func _draw() -> void:
  if combat == null or combat.timekeeper == null:
    return
  var now: float = combat.timekeeper.render_time()
  for d in combat._deliveries:
    if d.fizzled:
      continue
    var travel_dur: float = d.travel.threshold * Timekeeper.STEP
    if not d.landed and travel_dur > 0.0:
      var src: Vector2 = layout.item_pos(d.source)
      var dst: Vector2 = layout.actor_pos(d.target)
      var t: float = clampf((now - d.fire_time) / travel_dur, 0.0, 1.0)
      draw_circle(src.lerp(dst, t), PROJ_RADIUS, d.color)
    elif d.landed and d.kind == Delivery.Kind.DAMAGE:
      var age: float = now - d.impact_time
      if age >= 0.0 and age < NUM_DURATION:
        var pos: Vector2 = layout.actor_pos(d.target) + Vector2(-24.0, -190.0 - age * 120.0)
        draw_string(_font, pos, str(int(d.value)), HORIZONTAL_ALIGNMENT_LEFT, -1, 52, d.color)
