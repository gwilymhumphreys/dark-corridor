class_name VfxDriver
extends Node2D
## The combat wall (docs/systems/vfx_driver.md), minimal and grown incrementally. Everything it
## draws is a pure function of the CombatManager's Delivery set + the Timekeeper's render_time():
## projectiles in flight, a burst where each one lands, and floating damage numbers. The impact sound
## is the one exception — it fires once per landing at wall-clock speed. Writes no game state.
## The shapes are drawn by small effect classes in `src/vfx/drawers/`, one per effect.
##
## PLACEHOLDER: the circles drawn here — the projectile disc and the impact ring — are stand-ins so
## the timing and the causal link can be judged. They are meant to be replaced by proper VFX
## animations once those exist; do not treat their shape as the intended look.

signal big_hit(strength: float)   # a hit of at least BIG_HIT_DAMAGE landed; strength is 0 to 1

const SCATTER_RADIUS: float = 44.0   # how far a landing point can be nudged from the target centre
const BIG_HIT_DAMAGE: float = 200.0   # the smallest hit that pauses and shakes the screen
const BIGGEST_HIT_DAMAGE: float = 2000.0   # the hit that pauses and shakes the most

var combat: CombatManager
var layout: CombatView        # the swappable view surface — item_pos / actor_pos / target_pos
var _sounded: Dictionary = {}   # Delivery instance id -> true, so each landing sounds once
var _projectile: EffectDrawer
var _damage_number: DamageNumberDrawer
var _impact_drawers: Dictionary = {}   # mechanic id (or Delivery.Kind.APPLY_STATUS) -> EffectDrawer


func setup(cm: CombatManager, layout_source: CombatView) -> void:
  combat = cm
  layout = layout_source


func _ready() -> void:
  _projectile = ProjectileDiscDrawer.new()
  _damage_number = DamageNumberDrawer.new()
  var ring: ImpactRingDrawer = ImpactRingDrawer.new()
  # Every mechanic id maps to the same ring for now (docs/plans/mechanics.md). A DoT tick's
  # visual-only Delivery carries its status id as the mechanic, so its ring still draws.
  for mechanic_id in [AttackMechanic.ID, ShieldMechanic.ID, HealMechanic.ID, PoisonMechanic.ID, BurnMechanic.ID, BleedMechanic.ID, RegenMechanic.ID, CritMechanic.ID]:
    _impact_drawers[mechanic_id] = ring
  _impact_drawers[Delivery.Kind.APPLY_STATUS] = ring


func _process(_delta: float) -> void:
  _sound_new_impacts()
  queue_redraw()


func _exit_tree() -> void:
  # CLAUDE.md runtime cleanup: drop the live-fight refs and the sounded set on free.
  combat = null
  layout = null
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
    var key: Variant = _impact_key(d)
    if _impact_drawers.has(key):
      var drawer: EffectDrawer = _impact_drawers[key]
      drawer.draw_effect(self, d, landing, now - d.impact_time)
    if _shows_number(d):
      _damage_number.draw_effect(self, d, landing, now - d.impact_time)


## How big a hit is, from 0 at BIG_HIT_DAMAGE to 1 at BIGGEST_HIT_DAMAGE, or -1 for anything that
## is not an attack or is smaller than BIG_HIT_DAMAGE.
static func big_hit_strength(delivery: Delivery) -> float:
  if delivery.mechanic != AttackMechanic.ID or delivery.value < BIG_HIT_DAMAGE:
    return -1.0
  return clampf((delivery.value - BIG_HIT_DAMAGE) / (BIGGEST_HIT_DAMAGE - BIG_HIT_DAMAGE), 0.0, 1.0)


## The impact-drawer key for a delivery: its mechanic id for a mechanic delivery, else its kind
## (APPLY_STATUS). SUMMON / CREATE_ITEM have no entry and so draw nothing.
static func _impact_key(delivery: Delivery) -> Variant:
  if delivery.kind == Delivery.Kind.MECHANIC:
    return delivery.mechanic
  return delivery.kind


## Whether a landing shows a number: attack and heal landings, plus every visual-only delivery
## (a DoT tick's number, which carries no landing of its own).
static func _shows_number(delivery: Delivery) -> bool:
  if delivery.visual_only:
    return true
  return delivery.mechanic == AttackMechanic.ID or delivery.mechanic == HealMechanic.ID


## One sound per landing, played the first time a delivery shows as landed. Sounds are
## fire-and-forget at wall-clock pitch — unlike the drawing, they are not a function of
## render_time, because slowing audio sounds bad. Ids of deliveries the manager has dropped are
## forgotten, so the set stays as small as the fight's live deliveries. A big hit also emits
## `big_hit` here, once, so the view can pause and shake.
func _sound_new_impacts() -> void:
  if combat == null:
    return
  var live: Dictionary = {}
  for d in combat.deliveries():
    var id: int = d.get_instance_id()
    live[id] = true
    # Summons and created items have no impact to hear, as they have none to see.
    if not d.landed or d.fizzled or not _impact_drawers.has(_impact_key(d)) or _sounded.has(id):
      continue
    _sounded[id] = true
    SfxManager.play_impact()
    var strength: float = big_hit_strength(d)
    if strength >= 0.0:
      big_hit.emit(strength)
  for id: int in _sounded.keys():
    if not live.has(id):
      _sounded.erase(id)
