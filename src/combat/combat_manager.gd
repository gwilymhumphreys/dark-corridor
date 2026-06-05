class_name CombatManager
extends Node
## The per-fight orchestrator (combat_manager_prd). Owns the Timekeeper, the
## component registry, the event bus, and the in-flight Deliveries; runs the
## single fixed-step tick (advance -> fire -> land -> route -> win/loss). Makes no
## combat decisions — boards auto-fire on their Tickers. Instanced one-per-fight.
## Registry order is insertion order = the deterministic seq_id (decision #24).

signal resolved(player_won: bool)

var player: Actor
var enemies: Array = []          # Array[Actor], left-to-right
var timekeeper: Timekeeper
var bus: EventBus

var _items: Array = []           # Array[Item] — cooldown Tickers, registration order
var _deliveries: Array = []      # Array[Delivery] — in-flight + recently-resolved
var _resolved: bool = false
var _player_won: bool = false


func _init(player_actor: Actor, enemy_actors: Array) -> void:
  player = player_actor
  enemies = enemy_actors


## Create the clock + bus, register the boards' cooldown Tickers, and subscribe
## each item's declared triggers. Call once before the fight runs.
func start() -> void:
  timekeeper = Timekeeper.new()
  bus = EventBus.new()
  _register_actor(player)
  for e in enemies:
    _register_actor(e)


func _register_actor(actor: Actor) -> void:
  for it in actor.board:
    _items.append(it)
    for sub in it.def.trigger_subs:
      bus.subscribe(sub['event'], it.cooldown, sub['amount'], sub.get('filter', -1))


# --- The tick ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
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
    if it.cooldown.step():
      fired_items.append(it)
  # Statuses are advanced per owner — the actor's list IS the container/owner.
  for actor in _all_actors():
    var spent: Array = []
    for st in actor.statuses:
      if StatusManager.advance_status(st, actor):
        spent.append(st)
    for st in spent:
      actor.statuses.erase(st)
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


func _fire_item(it: Item, arrived: Array) -> void:
  var payloads := it.fire()
  if payloads.is_empty():
    return   # gated (silence)
  bus.publish(EventBus.Event.ITEM_FIRED)
  for p in payloads:
    for target in _resolve_targets(p, it):
      var d := _spawn_delivery(p, target)
      _deliveries.append(d)
      if d.travel.crossed():
        arrived.append(d)   # instant (travel 0) lands this same step


func _spawn_delivery(p: Payload, target) -> Delivery:
  var d := Delivery.new()
  d.kind = p.kind
  d.value = p.value
  d.status_type = p.status_type
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
  # A single target that died mid-flight fizzles — no retarget (combat_prd).
  if d.target is Actor and not d.target.is_alive():
    d.fizzled = true
    return
  d.impact_time = timekeeper.sim_time
  d.landed = true
  match d.kind:
    Delivery.Kind.DAMAGE:
      d.target.take_damage(d.value, d.flags)
      bus.publish(EventBus.Event.DAMAGE_DEALT)
    Delivery.Kind.HEAL:
      d.target.heal(d.value)
      bus.publish(EventBus.Event.HEALED)
    Delivery.Kind.APPLY_STATUS:
      StatusManager.apply(d.target, d.status_type, d.value, d.source)
      bus.publish(EventBus.Event.STATUS_APPLIED, d.status_type)


# --- Target-shape resolution (the runtime targeting authority) --------------

func _resolve_targets(p: Payload, it: Item) -> Array:
  match p.shape:
    ItemEffect.Shape.SELF:
      return [it.owner]
    ItemEffect.Shape.OPPONENT_LEFTMOST:
      var t = _leftmost_living_opponent(it.owner)
      return [t] if t != null else []
    ItemEffect.Shape.ALL_OPPONENTS:
      return _living_opponents(it.owner)
    _:
      return []   # item-target shapes (random / all-items) — later


func _all_actors() -> Array:
  return [player] + enemies


func _opponents_of(actor: Actor) -> Array:
  return enemies if actor == player else [player]


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


## Break the Actor<->Status / Item<->Status reference cycles at fight end so the
## actors/items can free (CLAUDE.md runtime cleanup). Combat-scoped statuses are
## dropped (none are run-persistent in Phase 1). Call after reading the result.
func teardown() -> void:
  _clear_statuses(player)
  for e in enemies:
    _clear_statuses(e)
  _items.clear()
  _deliveries.clear()
  timekeeper = null
  bus = null


func _clear_statuses(actor: Actor) -> void:
  for it in actor.board:
    it.statuses.clear()
  actor.statuses.clear()
