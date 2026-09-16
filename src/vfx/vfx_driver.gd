class_name VfxDriver
extends Node2D
## The combat wall (docs/systems/vfx_driver.md), minimal and grown incrementally. Everything it
## draws is a pure function of the CombatManager's Delivery set + the Timekeeper's render_time():
## projectiles in flight, a burst where each one lands, and pop-in damage numbers. The impact sound
## is the one exception — it fires once per landing at wall-clock speed. Writes no game state.
## The shapes are drawn by small effect classes in `src/vfx/drawers/`, one per effect.
##
## PLACEHOLDER: the circles drawn here — the projectile disc and the impact ring — are stand-ins so
## the timing and the causal link can be judged. They are meant to be replaced by proper VFX
## animations once those exist; do not treat their shape as the intended look.

const NUM_DURATION := 0.6    # seconds a damage number shows (render-time)
const SCATTER_RADIUS: float = 44.0   # how far a landing point can be nudged from the target centre

var combat: CombatManager
var layout: CombatView        # the swappable view surface — item_pos / actor_pos / target_pos
var _font: Font
var _sounded: Dictionary = {}   # Delivery instance id -> true, so each landing sounds once
var _projectile: EffectDrawer
var _impact_drawers: Dictionary = {}   # Delivery.Kind -> EffectDrawer


func setup(cm: CombatManager, layout_source: CombatView) -> void:
  combat = cm
  layout = layout_source


func _ready() -> void:
  _projectile = ProjectileDiscDrawer.new()
  var ring: ImpactRingDrawer = ImpactRingDrawer.new()
  _impact_drawers[Delivery.Kind.DAMAGE] = ring
  _impact_drawers[Delivery.Kind.HEAL] = ring
  _impact_drawers[Delivery.Kind.APPLY_STATUS] = ring


func _process(_delta: float) -> void:
  _sound_new_impacts()
  queue_redraw()


func _exit_tree() -> void:
  # CLAUDE.md runtime cleanup: drop the live-fight refs and the sounded set on free.
  combat = null
  layout = null
  _font = null
  _sounded.clear()


## A small fixed nudge for one delivery's landing point, so several hits on the same target do not
## stack their rings and numbers in one spot. It is derived from the delivery's own identity rather
## than drawn each frame, so the effect stays where it landed instead of jittering, and it touches
## no game state — the autotest draws nothing, so seeded runs are unchanged.
static func scatter_offset(delivery: Delivery) -> Vector2:
  var id: int = delivery.get_instance_id()
  var angle: float = float(hash(id) % 3600) / 3600.0 * TAU
  var distance: float = float(hash(id * 31 + 7) % 1000) / 1000.0 * SCATTER_RADIUS
  return Vector2(cos(angle), sin(angle)) * distance


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
        # The same scattered point the ring will use, so the disc does not jump on landing.
        var dst: Vector2 = layout.target_pos(d.target) + scatter_offset(d)   # Actor OR Item target
        var t: float = clampf((now - d.fire_time) / travel_dur, 0.0, 1.0)
        _projectile.draw_effect(self, d, src.lerp(dst, t), now - d.fire_time)   # PLACEHOLDER shape
      continue
    var landing: Vector2 = layout.target_pos(d.target) + scatter_offset(d)
    if _impact_drawers.has(d.kind):
      var drawer: EffectDrawer = _impact_drawers[d.kind]
      drawer.draw_effect(self, d, landing, now - d.impact_time)
    if d.kind == Delivery.Kind.DAMAGE:
      var age: float = now - d.impact_time
      if age >= 0.0 and age < NUM_DURATION:
        var pos: Vector2 = landing + Vector2(-24.0, -190.0 - age * 120.0)
        draw_string(_font, pos, str(int(d.value)), HORIZONTAL_ALIGNMENT_LEFT, -1, 52, d.color)


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
