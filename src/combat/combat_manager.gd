class_name CombatManager
extends Node
## The per-fight orchestrator (combat_manager_prd). Owns the Timekeeper, the
## component registry, the event bus, and the in-flight Deliveries; runs the
## single fixed-step tick (advance -> fire -> land -> route -> win/loss). Makes no
## combat decisions — boards auto-fire on their Tickers. Instanced one-per-fight.
## Within-step order is deterministic (decision #24): each component TYPE is swept
## in a fixed order — item cooldowns, then statuses (actor- AND item-targeted,
## advanced uniformly), then Delivery travel — and
## within a type in insertion order (board order at start, then the deterministic
## fire order). That realizes #24's bit-reproducible sweep; the literal monotonic
## `seq_id` field is deferred until cross-type registration order actually matters.

signal resolved(player_won: bool)

# Two side-rosters (spore_engine_prd Cap 3). The PLAYER side is the run-state actor +
# run-scoped `allies` (persistent, passed in) + `_player_tokens` (combat-scoped summons);
# the ENEMY side is `enemies` (+ enemy summons append here). Targeting + win/loss work over
# the rosters. `player` stays the run-state ref — loss is the PLAYER dying (a token doesn't
# save the run); win is the whole enemy side dead.
var player: Actor
var enemies: Array = []          # Array[Actor] — the enemy side, left-to-right
var allies: Array = []           # Array[Actor] — run-scoped player-side allies (passed in)
var timekeeper: Timekeeper
var bus: EventBus
var rng: RandomNumberGenerator   # the per-fight stream — random item-targeting (#14/#20)

var _player_tokens: Array = []   # Array[Actor] — combat-scoped player-side summons (dissolved)

var _items: Array = []           # Array[Item] — cooldown Tickers, registration order
var _deliveries: Array = []      # Array[Delivery] — in-flight + recently-resolved
var _resolved: bool = false
var _player_won: bool = false
var _torn_down: bool = false
var _combat_seed: int = 0


## `combat_seed` seeds the per-fight RNG (decision #20: a derived per-fight stream so
## random targeting is reproducible AND a re-entered fight replays identically). The
## RunManager derives it from the run seed + beat index; tests / sandbox may leave it 0.
func _init(player_actor: Actor, enemy_actors: Array, combat_seed: int = 0, ally_actors: Array = []) -> void:
  player = player_actor
  enemies = enemy_actors
  allies = ally_actors
  _combat_seed = combat_seed


## Create the clock + bus + per-fight RNG, register every starting actor's cooldown Tickers,
## and subscribe each item's declared triggers. Call once before the fight runs.
func start() -> void:
  timekeeper = Timekeeper.new()
  bus = EventBus.new()
  rng = RandomNumberGenerator.new()
  rng.seed = _combat_seed
  _register_actor(player)
  for a in allies:
    _register_actor(a)
  for e in enemies:
    _register_actor(e)


## Add an Actor to a side mid-fight (spore_engine_prd Cap 3) — a summon / boss add. Registers
## its item Tickers + triggers and inserts it into the side; `in_front` puts it leftmost
## (body-block / adds-in-front). Combat-scoped — dissolved at teardown (it is NOT in `allies`).
func add_actor(actor: Actor, on_player_side: bool, in_front: bool = true) -> void:
  if actor == null or _resolved:
    return
  _register_actor(actor)
  if on_player_side:
    if in_front:
      _player_tokens.push_front(actor)
    else:
      _player_tokens.push_back(actor)
  else:
    if in_front:
      enemies.push_front(actor)
    else:
      enemies.push_back(actor)


## Build a token Actor from an authored EnemyDef (its HP + board) — the same way Encounter
## spawns enemies. The token def is content (the owner authors saprolings / boss adds).
func _spawn_token(def_id: int) -> Actor:
  var def: EnemyDef = EnemyCatalog.get_def(def_id)
  var actor := Actor.new(def.max_hp)
  for item_id in def.item_ids:
    actor.board.append(Item.new(ItemCatalog.get_def(item_id), actor))
  return actor


func _register_actor(actor: Actor) -> void:
  for it in actor.board:
    # Cooldowns are combat-scoped, like statuses (decision #26): the player's board
    # persists across the run, so reset each item's accumulator at fight start. Else
    # fight N+1 opens mid-charge from where fight N happened to stop, AND a resumed
    # save (which rebuilds items fresh at accum 0) would diverge from continuous play
    # — breaking decision #20's "a re-entered fight replays identically." Enemy items
    # are fresh instances each fight, so this only matters for the player.
    it.cooldown.accum = 0.0
    _items.append(it)
    for sub in it.def.trigger_subs:
      bus.subscribe(sub['event'], it.cooldown, sub['amount'], sub.get('filter', -1))


# --- The tick ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
  tick(delta)


## Advance the fight by real `delta` (steps_due × sim_step). THE one tick, exposed
## so a real-time client can drive it WITHOUT mounting the logic tree: a directly
## added CombatManager (the sandbox) self-drives via `_physics_process`; the Phase-4
## run screen calls `tick(delta)` each physics frame on the active fight; the headless
## autotest calls `sim_step()` directly (no real time → bit-reproducible). All three
## are the same tick — none mounts the Encounter / Run manager.
func tick(delta: float) -> void:
  if _resolved or timekeeper == null:
    return
  for i in timekeeper.steps_due(delta):
    if _resolved:
      break
    sim_step()


## One combat tick — a fixed STEP of game-time. (Headless autotest calls this
## directly in a loop; no _physics_process, no steps_due.)
func sim_step() -> void:
  timekeeper.advance()

  # 1. Advance every component one step; collect crossings.
  var fired_items: Array = []
  for it in _items:
    # A dead actor's items neither tick nor fire (Cap 3 — matters once a side has >1 body:
    # in a multi-enemy fight a slain body must stop swinging). Its statuses still resolve
    # on their own targets; only this owner's own item firing is suppressed.
    if it.owner != null and not it.owner.is_alive():
      continue
    if it.cooldown.step():
      fired_items.append(it)
  # Advance every status uniformly — actor-targeted AND item-targeted alike. A
  # status lives on its target (the target is its own owner for advancement), so
  # the same pass serves both; item statuses are not a special case.
  for actor in _all_actors():
    _advance_statuses_on(actor)
    for it in actor.board:
      _advance_statuses_on(it)
  var arrived: Array = []
  for d in _deliveries:
    if not d.landed and not d.fizzled and d.step_travel():
      arrived.append(d)

  # 2. Fire crossed items -> resolve shapes -> spawn Deliveries (travel-0 land now).
  for it in fired_items:
    _fire_item(it, arrived)

  # 3. Land arrived (travelled this step + instant spawns).
  for d in arrived:
    _land(d)

  # 4. (Routing is inline: events published in fire/land push tickers, which are
  #    only evaluated next step — one link per step, loop-proof.)

  # 5. Win/loss.
  _check_resolution()

  # 6. Drop spent Deliveries (fizzled = no visual; landed = held briefly for the
  #    impact number/flash) so the in-flight set can't grow unbounded over a long
  #    fight — vfx_driver_prd's "keep until the visual elapses, then drop."
  _prune_deliveries()


## Advance one step of every status on `target` (an Actor OR an Item), dropping any
## that expired. Periodic-damage statuses only ever sit on actors (the `take_damage`
## owner); timed / static shapes work on either — so one pass serves both, and item
## statuses tick on the same cadence as actor statuses.
func _advance_statuses_on(target) -> void:
  var spent: Array = []
  # Iterate a COPY: a PERIODIC tick calls take_damage, which can erase a spent block
  # status from `target.statuses` mid-pass (StatusManager.resolve_incoming_damage).
  # Mutating the list being iterated would skip the status after it — so walk a
  # snapshot, apply, and erase expiries afterward.
  for st in target.statuses.duplicate():
    var hp_before: float = target.hp if target is Actor else 0.0
    if StatusManager.advance_status(st, target):
      spent.append(st)
    # Surface a DoT tick on the VFX wall (the damage was already applied above): a
    # pre-landed, payload-less Delivery the wall draws as a number. Periodic statuses
    # only ever sit on actors, so this never runs for item statuses.
    if target is Actor:
      var dealt: float = hp_before - target.hp
      if dealt > 0.0:
        _deliveries.append(_dot_visual(st, target, dealt))
  for st in spent:
    target.statuses.erase(st)


## A visual-only Delivery for a DoT tick so the wall shows the number — the damage
## itself was already applied inside StatusManager.advance_status. Pre-landed, never
## passed to _land, and flagged so the autotest's direct-hit attribution skips it.
func _dot_visual(status: Status, target, dealt: float) -> Delivery:
  var d := Delivery.new()
  d.kind = Delivery.Kind.DAMAGE
  d.value = dealt
  d.target = target
  d.source = status.source
  d.color = StatusCatalog.get_def(status.type).color
  d.travel = Ticker.new(0)
  d.fire_time = timekeeper.sim_time
  d.impact_time = timekeeper.sim_time
  d.landed = true
  d.visual_only = true
  return d


func _fire_item(it: Item, arrived: Array) -> void:
  var payloads := it.fire()
  if payloads.is_empty():
    return   # gated (silence)
  bus.publish(EventBus.Event.ITEM_FIRED)
  # The item still fires (cooldown reset, fire-emote) even when blinded — but its DAMAGE
  # whiffs (spore_engine_prd Cap 2). Locked at fire so a swing launched while blinded misses.
  var blinded: bool = StatusManager.has_evasion(it.owner)
  for p in payloads:
    for target in _resolve_targets(p, it.owner):
      var d := _spawn_delivery(p, target)
      # Opponent-fuel consume (Mass, Cap 1): spend the resolved TARGET's stacks here (it's
      # only known now), scaling the Delivery — the Item stayed downward-clean (it declared).
      if p.consume_type >= 0 and p.consume_from_target:
        d.value += StatusManager.consume(target, p.consume_type, p.consume_amount) * p.consume_scale
      if blinded and d.kind == Delivery.Kind.DAMAGE:
        d.evaded = true
      _deliveries.append(d)
      if d.travel.crossed():
        arrived.append(d)   # instant (travel 0) lands this same step


## Retain in-flight Deliveries and recently-landed ones (for their impact visual);
## drop fizzled ones (no visual) and landed ones whose visual hold has elapsed.
## Keyed off sim_time — the VFX wall reads render_time, which tracks it. This is
## what keeps `_deliveries` bounded; teardown clears whatever's left at fight end.
func _prune_deliveries() -> void:
  var now: float = timekeeper.sim_time
  var kept: Array = []
  for d in _deliveries:
    if d.fizzled:
      continue
    if d.landed and now - d.impact_time >= Balance.DELIVERY_VISUAL_HOLD:
      continue
    kept.append(d)
  _deliveries = kept


func _spawn_delivery(p: Payload, target) -> Delivery:
  var d := Delivery.new()
  d.kind = p.kind
  d.value = p.value
  d.status_type = p.status_type
  d.summon_def_id = p.summon_def_id
  d.summon_in_front = p.summon_in_front
  d.flags = p.flags
  d.color = p.color
  d.source = p.source
  d.target = target
  d.travel = Ticker.from_seconds(p.travel)
  d.fire_time = timekeeper.sim_time
  return d


func _land(d: Delivery) -> void:
  if d.landed or d.fizzled:
    return
  # A blinded attacker's swing whiffs (Cap 2): it travelled, then misses — no land, no
  # damage. `evaded` (set at fire) is the fizzle reason the VFX wall reads for the tell.
  if d.evaded:
    d.fizzled = true
    return
  # A single target that died/left mid-flight fizzles — no retarget (combat_prd). For an
  # item target, "alive" means its owning actor is still alive (you can't silence a
  # dead enemy's item).
  if not _target_alive(d.target):
    d.fizzled = true
    return
  d.impact_time = timekeeper.sim_time
  d.landed = true
  match d.kind:
    Delivery.Kind.DAMAGE:
      if d.target is Actor:   # damage/heal are actor-targeted; item shapes carry statuses
        d.target.take_damage(d.value, d.flags)
        bus.publish(EventBus.Event.DAMAGE_DEALT)
    Delivery.Kind.HEAL:
      if d.target is Actor:
        d.target.heal(d.value)
        bus.publish(EventBus.Event.HEALED)
    Delivery.Kind.APPLY_STATUS:   # target is an Actor OR an Item — both hold a status list
      StatusManager.apply(d.target, d.status_type, d.value, d.source, d.flags)
      bus.publish(EventBus.Event.STATUS_APPLIED, d.status_type)
    Delivery.Kind.SUMMON:   # spawn a token onto the summoner's side (shape SELF → target = summoner)
      if d.summon_def_id >= 0 and d.target is Actor:
        add_actor(_spawn_token(d.summon_def_id), _on_player_side(d.target), d.summon_in_front)


# --- Target-shape resolution (the runtime targeting authority) --------------

## Resolve a payload's relative shape into concrete targets, relative to `owner`
## (the firing item's owner, or a thrown consumable's thrower).
func _resolve_targets(p: Payload, owner: Actor) -> Array:
  match p.shape:
    ItemEffect.Shape.SELF:
      return [owner]
    ItemEffect.Shape.OPPONENT_LEFTMOST:
      var t = _leftmost_living_opponent(owner)
      return [t] if t != null else []
    ItemEffect.Shape.ALL_OPPONENTS:
      return _living_opponents(owner)
    ItemEffect.Shape.OPPONENT_ITEM_RANDOM:
      return _random_opponent_item(owner)
    ItemEffect.Shape.ALL_OPPONENT_ITEMS:
      return _all_opponent_items(owner)
    _:
      # A future shape with no resolver — warn ONCE so an authored item using it isn't a
      # silent no-op (it would fire nothing with no clue why).
      _warn_unhandled_shape(p.shape)
      return []


var _warned_shapes: Dictionary = {}   # shapes we've already warned about (no log spam)


## Warn once per unhandled target shape — a content-authoring aid (the tick loop would
## otherwise call this every step the offending item fires).
func _warn_unhandled_shape(shape: int) -> void:
  if _warned_shapes.has(shape):
    return
  _warned_shapes[shape] = true
  push_warning('[CombatManager] target shape %d is not resolved yet (item-target shapes need the per-fight RNG, #14/#20); the effect fires nothing.' % shape)


## Is a Delivery's target still a valid landing site? An Actor must be alive; an Item's
## owning actor must be alive (an item-targeted status applies to the Item itself).
func _target_alive(target) -> bool:
  if target is Actor:
    return target.is_alive()
  if target is Item:
    return target.owner != null and target.owner.is_alive()
  return false


## The ordered player side: combat-scoped summons (front, body-block) then the run-state
## actor then run-scoped allies. Leftmost-living targeting walks this in order.
func _player_side() -> Array:
  return _player_tokens + [player] + allies


func _on_player_side(actor) -> bool:
  return actor == player or actor in allies or actor in _player_tokens


func _all_actors() -> Array:
  return _player_side() + enemies


func _opponents_of(actor: Actor) -> Array:
  return enemies if _on_player_side(actor) else _player_side()


func _living_opponents(actor: Actor) -> Array:
  var out: Array = []
  for o in _opponents_of(actor):
    if o.is_alive():
      out.append(o)
  return out


func _leftmost_living_opponent(actor: Actor):
  for o in _opponents_of(actor):
    if o.is_alive():
      return o
  return null


## Every Item on a living opponent's board — the pool item-target shapes draw from.
func _all_opponent_items(actor: Actor) -> Array:
  var out: Array = []
  for o in _living_opponents(actor):
    out.append_array(o.board)
  return out


## One random Item from that pool, chosen on the seeded per-fight RNG (decision #14:
## item-target selection is random, unlike the deterministic leftmost actor rule; the
## seed keeps the fight bit-reproducible). [] when no opponent has a board item.
func _random_opponent_item(actor: Actor) -> Array:
  var pool: Array = _all_opponent_items(actor)
  if pool.is_empty():
    return []
  return [pool[rng.randi_range(0, pool.size() - 1)]]


# --- Resolution + lifecycle -------------------------------------------------

func _check_resolution() -> void:
  if _resolved:
    return
  # Check the player first so simultaneous death resolves to a loss (provisional).
  if not player.is_alive():
    _finish(false)
  elif _all_enemies_dead():
    _finish(true)


func _all_enemies_dead() -> bool:
  for e in enemies:
    if e.is_alive():
      return false
  return true


func _finish(player_won: bool) -> void:
  _resolved = true
  _player_won = player_won
  set_physics_process(false)
  resolved.emit(player_won)


## The fight result surface (the `resolved` signal is the push form; these are
## the pull form the headless autotest polls after each sim_step).
func is_resolved() -> bool:
  return _resolved


func player_won() -> bool:
  return _player_won


## The in-flight + recently-landed Delivery set — the read-only "wall" the VFX
## driver and the autotest logger sample (vfx_driver_prd / autotest.md). Pruned
## each step, so it stays bounded; never mutate it from outside.
func deliveries() -> Array:
  return _deliveries


## Drive the fight to resolution headlessly (no real time). Returns the step
## count. The cap is a stuck-fight backstop.
func run_headless(max_steps: int = 100000) -> int:
  var steps := 0
  while not _resolved and steps < max_steps:
    sim_step()
    steps += 1
  return steps


## UI timescale intent (hover slow-mo). The UI never writes the dial directly —
## it asks; the manager sets its Timekeeper's override.
func request_slowmo(on: bool) -> void:
  if timekeeper == null:
    return
  if on:
    timekeeper.set_override(Balance.TIMESCALE_SLOWMO)
  else:
    timekeeper.clear_override()


## Throw-potion intent: activate a thrown consumable (content_prd). Build its
## effect(s) into Deliveries resolved relative to the thrower, then land any that
## arrive instantly — the same resolution surface as an item fire, minus the
## Ticker. The RunManager removes the potion from its slot; this just resolves it.
func throw_consumable(consumable, thrower: Actor) -> void:
  if _resolved:
    return
  for effect in consumable.def.effects:
    var p := _payload_from_effect(effect)
    for target in _resolve_targets(p, thrower):
      var d := _spawn_delivery(p, target)
      _deliveries.append(d)
      if d.travel.crossed():
        _land(d)


## Build a Payload from an ItemEffect template (shared by consumable throws; items
## go through Item._resolve_effect, which also applies enchants). A consumable has
## no source Item — source stays null.
func _payload_from_effect(effect: ItemEffect) -> Payload:
  var p := Payload.new()
  p.kind = effect.kind
  p.value = effect.value
  p.shape = effect.shape
  p.travel = effect.travel
  p.status_type = effect.status_type
  p.flags = effect.flags
  p.color = effect.color
  p.source = null
  return p


## Break the fight's reference cycles so it can free (CLAUDE.md runtime cleanup),
## idempotent. ALL statuses are combat-scoped and dropped here (#26). The RUN-SCOPED
## player side (the run-state actor + persistent `allies`) PERSISTS — only its combat
## statuses clear, its board survives. COMBAT-SCOPED actors (enemies, enemy summons,
## player-side tokens) are discarded, so we break their Actor<->Item cycle (dissolve).
## Call after reading the result.
func teardown() -> void:
  if _torn_down:
    return
  _torn_down = true
  _clear_statuses(player)
  for a in allies:
    _clear_statuses(a)
  for e in enemies:
    e.dissolve()
  for t in _player_tokens:
    t.dissolve()
  _items.clear()
  _deliveries.clear()
  enemies = []
  allies = []
  _player_tokens = []
  player = null
  timekeeper = null
  bus = null
  rng = null


func _clear_statuses(actor: Actor) -> void:
  for it in actor.board:
    it.statuses.clear()
  actor.statuses.clear()
