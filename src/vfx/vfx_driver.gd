class_name VfxDriver
extends Node2D
## The combat wall (docs/systems/vfx_driver.md), minimal and grown incrementally. Everything it
## draws is a pure function of the CombatManager's Delivery set + the Timekeeper's render_time():
## projectiles in flight, a burst where each one lands, and floating damage numbers. The impact sound
## is the one exception — it fires once per landing at wall-clock speed. Writes no game state.
## The shapes are drawn by small effect classes in `src/vfx/drawers/`, one per effect.
##
## PLACEHOLDER: the projectile disc is a stand-in so the timing and the causal link can be judged.
## The trial drawers switched by `comet_projectiles` and `pixel_projectile` replace it. The effects are
## meant to be replaced by proper VFX animations once those exist; do not treat their shape as the
## intended look.

signal big_hit(strength: float)   # a hit of at least BIG_HIT_DAMAGE landed; strength is 0 to 1

const BIG_HIT_DAMAGE: float = 200.0   # the smallest hit that pauses and shakes the screen
const BIGGEST_HIT_DAMAGE: float = 2000.0   # the hit that pauses and shakes the most
const ARC_HEIGHT: float = 0.05  # how high a projectile's path rises, as a fraction of the distance it flies
## Played when a struck actor names no hurt sound of its own, so the target layer works before
## any enemy has a voice.
const DEFAULT_HURT_SOUND: String = 'combat/hurt'
## Played alongside the landing sound of a delivery that crit. Crit is never delivered itself.
const CRIT_SOUND: String = 'mechanics/' + CritMechanic.ID
## The travel layer's folder. Its own recordings are the default flight sound for every item;
## subfolders named after an item's `travel_sound`, a type tag or a mechanic override it.
const TRAVEL_SOUND: String = 'combat/travel'
## The mechanics whose deliveries land on the target's health bar rather than on the target.
const BAR_MECHANICS: Array[String] = [ShieldMechanic.ID, HealMechanic.ID, RegenMechanic.ID]

## TRIAL: whether projectiles fly as `ProjectileCometDrawer`'s comet (true) or the placeholder disc
## (false). Switched in the debug panel's Feedback tab, or with `--projectile=disc` at start-up.
static var comet_projectiles: bool = DevArgs.value('--projectile') != 'disc'
## TRIAL: which `ProjectilePixelDrawer` animation projectiles fly as, counting from 1, or 0 for none,
## which leaves the comet or disc. Set in the debug panel's Feedback tab, or with
## `--pixel-projectile=<name>` at start-up (the animation's name in lower case, spaces as underscores).
static var pixel_projectile: int = ProjectilePixelDrawer.option_index(DevArgs.value('--pixel-projectile'))
## TRIAL: how many screen pixels each pixel of a pixel projectile covers. Set in the Feedback tab.
static var pixel_projectile_scale: float = 3.0

var combat: CombatManager
var layout: CombatView        # the swappable view surface — item_pos / actor_pos / target_pos
var _sounded: Dictionary = {}   # Delivery instance id -> true, so each landing sounds once
var _launched: Dictionary = {}  # Delivery instance id -> true, so each flight sounds once
var _projectile: EffectDrawer
var _comet: ProjectileCometDrawer
var _pixel: ProjectilePixelDrawer
## Pixel projectiles are drawn on this child, whose texture filter is nearest so their pixels stay sharp.
var _pixel_layer: Node2D
var _damage_number: DamageNumberDrawer
## The damage numbers are drawn on this child, so they can take their own material: the element
## material, like the value pills, when `effects_damage_numbers` says so (`_numbers_material_update`).
var _numbers: Node2D
var _attack_hit: AttackHitDrawer
var _poison: PoisonDrawer
var _burn: BurnDrawer
var _bleed: BleedDrawer
var _shield: ShieldDrawer
var _heal: HealDrawer
var _regen: HealDrawer
var _impact_drawers: Dictionary = {}   # mechanic id (or Delivery.Kind.APPLY_STATUS) -> EffectDrawer


func setup(cm: CombatManager, layout_source: CombatView) -> void:
  combat = cm
  layout = layout_source


func _ready() -> void:
  _projectile = ProjectileDiscDrawer.new()
  _comet = ProjectileCometDrawer.new()
  _pixel = ProjectilePixelDrawer.new()
  _pixel_layer = Node2D.new()
  _pixel_layer.name = 'PixelProjectiles'
  _pixel_layer.use_parent_material = true
  _pixel_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
  _pixel_layer.draw.connect(_draw_pixel_projectiles)
  add_child(_pixel_layer)
  _damage_number = DamageNumberDrawer.new()
  _numbers = Node2D.new()
  _numbers.name = 'Numbers'
  _numbers.use_parent_material = true
  _numbers.draw.connect(_draw_numbers)
  add_child(_numbers)
  _attack_hit = AttackHitDrawer.new()
  _poison = PoisonDrawer.new()
  _burn = BurnDrawer.new()
  _bleed = BleedDrawer.new()
  _shield = ShieldDrawer.new()
  _heal = HealDrawer.new()
  _regen = HealDrawer.new(RegenMechanic.ID)
  _impact_drawers[ShieldMechanic.ID] = _shield
  _impact_drawers[HealMechanic.ID] = _heal
  # A regen tick's visual-only delivery also carries RegenMechanic.ID, so it draws this too.
  _impact_drawers[RegenMechanic.ID] = _regen


func _process(_delta: float) -> void:
  _sound_new_impacts()
  _numbers_material_update()
  queue_redraw()
  _pixel_layer.queue_redraw()
  _numbers.queue_redraw()


func _exit_tree() -> void:
  # CLAUDE.md runtime cleanup: drop the live-fight refs and the sounded set on free.
  combat = null
  layout = null
  _sounded.clear()
  _launched.clear()


func _draw() -> void:
  if combat == null or combat.timekeeper == null:
    return
  var now: float = combat.timekeeper.render_time()
  for d in combat.deliveries():
    if d.fizzled:
      continue
    var travel_dur: float = d.travel.threshold * Timekeeper.STEP
    if not d.landed:
      if travel_dur > 0.0 and pixel_projectile <= 0:
        var src: Vector2 = _source_point(d)
        # The same point the landing effect will use, so the disc does not jump on landing.
        var dst: Vector2 = _landing_point(d)
        var t: float = clampf((now - d.fire_time) / travel_dur, 0.0, 1.0)
        if comet_projectiles:
          _comet.draw_flight(self, d, arc_point(src, dst, t), arc_direction(src, dst, t), now - d.fire_time)
        else:
          _projectile.draw_effect(self, d, arc_point(src, dst, t), now - d.fire_time)   # PLACEHOLDER shape
      continue
    var landing: Vector2 = _landing_point(d)
    var key: Variant = _impact_key(d)
    var mechanic: String = trial_mechanic(d)
    if d.kind == Delivery.Kind.APPLY_STATUS:
      pass   # on an actor the status's icon pops in where it lands (PopAnimation), so nothing is drawn over it
    elif mechanic == AttackMechanic.ID:
      _attack_hit.draw_hit(self, d, landing, _landing_direction_of(d, landing), now - d.impact_time)
    elif mechanic == PoisonMechanic.ID:
      _poison.draw_effect(self, d, landing, now - d.impact_time)
    elif mechanic == BurnMechanic.ID:
      _burn.draw_effect(self, d, landing, now - d.impact_time)
    elif mechanic == BleedMechanic.ID:
      # A bleed tick's drops spurt upward, so it needs no direction (and its source is a status's).
      var direction: Vector2 = Vector2.UP if d.visual_only else _landing_direction_of(d, landing)
      _bleed.draw_hit(self, d, landing, direction, now - d.impact_time)
    elif _impact_drawers.has(key):
      var drawer: EffectDrawer = _impact_drawers[key]
      drawer.draw_effect(self, d, landing, now - d.impact_time)


# Projectiles in flight as pixel animations, on their own child node, when `pixel_projectile` picks one.
func _draw_pixel_projectiles() -> void:
  if pixel_projectile <= 0 or combat == null or combat.timekeeper == null:
    return
  var now: float = combat.timekeeper.render_time()
  for d in combat.deliveries():
    var travel_dur: float = d.travel.threshold * Timekeeper.STEP
    if d.fizzled or d.landed or travel_dur <= 0.0:
      continue
    var src: Vector2 = _source_point(d)
    var dst: Vector2 = _landing_point(d)
    var t: float = clampf((now - d.fire_time) / travel_dur, 0.0, 1.0)
    _pixel.draw_flight(_pixel_layer, d, pixel_projectile - 1, arc_point(src, dst, t), arc_direction(src, dst, t), now - d.fire_time, pixel_projectile_scale)


# Where a delivery's projectile starts: the firing item's cell, or the potion slot a thrown consumable came from.
func _source_point(d: Delivery) -> Vector2:
  return layout.consumable_pos(d.consumable) if d.consumable != null else layout.item_pos(d.source)


# The damage numbers, on their own child node and above every other effect.
func _draw_numbers() -> void:
  if combat == null or combat.timekeeper == null:
    return
  var now: float = combat.timekeeper.render_time()
  for d in combat.deliveries():
    if d.fizzled or not d.landed or not _shows_number(d):
      continue
    _damage_number.draw_effect(_numbers, d, _landing_point(d), now - d.impact_time)


# The numbers share the wall's material, unless the wall takes the interface look and its
# `effects_damage_numbers` setting asks for them to be drawn like the value pills
# (docs/systems/interface_look.md).
func _numbers_material_update() -> void:
  var effects: ShaderMaterial = InterfaceLook.effects_material
  var like_pills: bool = material == effects and effects.get_shader_parameter('effects_on') == true \
    and effects.get_shader_parameter('effects_damage_numbers') == 1
  _numbers.use_parent_material = not like_pills
  _numbers.material = InterfaceLook.element_material if like_pills else null


## Where a delivery lands. A status application lands where the status has its icon on the actor's
## panel, or will have it once applied (`layout.status_pos`); on an item, at the centre of the item's
## cell. Shield, healing and regen given to an actor land on its health bar. Anything else lands on
## its target (an actor or an item), nudged by `EffectDrawer.scatter_offset` so several hits on one
## target do not stack in one spot.
func _landing_point(d: Delivery) -> Vector2:
  if d.kind == Delivery.Kind.APPLY_STATUS:
    return layout.status_pos(d.target, d.status_id) if d.target is Actor else layout.target_pos(d.target)
  if d.kind == Delivery.Kind.MECHANIC and d.mechanic in BAR_MECHANICS and d.target is Actor:
    return layout.health_bar_pos(d.target)
  return layout.target_pos(d.target) + EffectDrawer.scatter_offset(d)


## A projectile's point on its path at progress t (0 to 1): a straight line from src to dst,
## raised up the screen by a curve that is highest halfway and zero at both ends, so it starts at
## the firing item and lands exactly on the landing point.
static func arc_point(src: Vector2, dst: Vector2, t: float) -> Vector2:
  var rise: float = 4.0 * t * (1.0 - t) * ARC_HEIGHT * src.distance_to(dst)
  return src.lerp(dst, t) + Vector2.UP * rise


## The direction a projectile is travelling at progress t along its arc from src to dst (the slope
## of `arc_point`): the straight line, bent upward on the way up and downward on the way down.
static func arc_direction(src: Vector2, dst: Vector2, t: float) -> Vector2:
  return (dst - src) + Vector2.UP * 4.0 * (1.0 - 2.0 * t) * ARC_HEIGHT * src.distance_to(dst)


## The direction a projectile is travelling as it lands at the end of its arc from src to dst.
static func landing_direction(src: Vector2, dst: Vector2) -> Vector2:
  return arc_direction(src, dst, 1.0)


## The direction a delivery's projectile was travelling as it landed at `landing`.
func _landing_direction_of(d: Delivery, landing: Vector2) -> Vector2:
  return landing_direction(_source_point(d), landing)


## How big a hit is, from 0 at BIG_HIT_DAMAGE to 1 at BIGGEST_HIT_DAMAGE, or -1 for anything that
## is not an attack or is smaller than BIG_HIT_DAMAGE.
static func big_hit_strength(delivery: Delivery) -> float:
  if delivery.mechanic != AttackMechanic.ID or delivery.value < BIG_HIT_DAMAGE:
    return -1.0
  return clampf((delivery.value - BIG_HIT_DAMAGE) / (BIGGEST_HIT_DAMAGE - BIG_HIT_DAMAGE), 0.0, 1.0)


## The mechanic id the trial drawers (attack, poison, burn, bleed) are chosen by: the delivery's
## mechanic for a mechanic delivery, else the empty string. They are not chosen by `_impact_key`,
## which is an int for a status application, because comparing an int with a String is an error.
static func trial_mechanic(delivery: Delivery) -> String:
  return delivery.mechanic if delivery.kind == Delivery.Kind.MECHANIC else ''


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
    if not d.landed and not d.fizzled and not _launched.has(id):
      _launched[id] = true
      # No fallback: _travel_key_of already chose a folder that holds sounds.
      SfxManager.play_sound(_travel_key_of(d), -1.0, 0.0, false)
    if not d.landed or d.fizzled or not has_impact_sound(d) or _sounded.has(id):
      continue
    _sounded[id] = true
    SfxManager.play_sound(_sound_key_of(d))
    SfxManager.play_sound(_hurt_key_of(d))
    if d.crit:
      # A crit adds a layer on top of the hit. It is guarded because one critting fire can land
      # on several targets in the same frame, and that is still one crit.
      SfxManager.play_sound_guarded(CRIT_SOUND, CRIT_SOUND)
    var strength: float = big_hit_strength(d)
    if strength >= 0.0:
      big_hit.emit(strength)
  for id: int in _sounded.keys():
    if not live.has(id):
      _sounded.erase(id)
  for id: int in _launched.keys():
    if not live.has(id):
      _launched.erase(id)


## Whether a landing makes a sound. Summons and created items have no impact to hear, as they have
## none to see. Charge and decharge draw no ring on the item they move, but they still land on it,
## so they are heard.
static func has_impact_sound(d: Delivery) -> bool:
  return d.kind != Delivery.Kind.SUMMON and d.kind != Delivery.Kind.CREATE_ITEM


## The folder for the target layer of a hit (docs/systems/audio.md): the sound the thing being
## struck makes, played alongside the weapon layer so the two are heard as one event. An actor
## with no `hurt_sound` uses the shared folder. Only a landed attack on an actor has anything to
## hurt — an item target, a heal, an evaded hit and a damage-over-time tick's visual-only
## delivery all return the empty string, which play_sound ignores.
func _hurt_key_of(d: Delivery) -> String:
  if d.mechanic != AttackMechanic.ID or d.evaded or d.visual_only:
    return ''
  if not (d.target is Actor):
    return ''
  return d.target.hurt_sound if d.target.hurt_sound != '' else DEFAULT_HURT_SOUND


## The folder for the travel layer (docs/systems/audio.md): a soft sound while a projectile is in
## flight, played once when it launches. The first of `travel_folders` that holds sounds is used,
## so every item plays the shared default until a more specific folder is filled. A delivery with
## no travel time, a summon and a created item have no travel sound, so they return the empty string.
func _travel_key_of(d: Delivery) -> String:
  for folder: String in travel_folders(d):
    if SfxManager.has_sounds(folder):
      return folder
  return ''


## The travel folders a delivery could play, most specific first: the firing item's own
## `travel_sound`, then one folder per type tag in the order the item lists them, then the
## mechanic, then the shared default. A thrown consumable has no firing item, so it starts at the
## mechanic. Empty when the delivery has no flight to cover.
static func travel_folders(d: Delivery) -> Array[String]:
  var folders: Array[String] = []
  if d.kind == Delivery.Kind.SUMMON or d.kind == Delivery.Kind.CREATE_ITEM:
    return folders
  if d.travel == null or d.travel.threshold <= 0:
    return folders
  if d.source is Item and d.source.def != null:
    var def: ItemDef = d.source.def
    if def.travel_sound != '':
      folders.append(TRAVEL_SOUND + '/' + def.travel_sound)
    for tag: String in def.types:
      folders.append(TRAVEL_SOUND + '/' + tag)
  if d.kind == Delivery.Kind.MECHANIC and d.mechanic != '':
    folders.append(TRAVEL_SOUND + '/' + d.mechanic)
  folders.append(TRAVEL_SOUND)
  return folders


## The sound folder a landing delivery plays. A mechanic names its own folder; a status
## application uses its status id. The empty string is only reached by a delivery naming a
## mechanic the registry does not have, and play_sound ignores it.
func _sound_key_of(d: Delivery) -> String:
  if d.kind == Delivery.Kind.MECHANIC and MechanicRegistry.has(d.mechanic):
    return MechanicRegistry.get_mechanic(d.mechanic).sound_key(d)
  if d.kind == Delivery.Kind.APPLY_STATUS and d.status_id != '':
    return 'statuses/' + d.status_id
  return ''
