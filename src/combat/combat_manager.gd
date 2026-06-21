class_name CombatManager
extends Node
## The per-fight orchestrator (docs/systems/combat_manager.md). Owns the Timekeeper, the
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

# Two side-rosters (docs/systems/spore_engine.md Cap 3). The PLAYER side is the run-state actor +
# run-scoped `allies` (persistent, passed in) + `_player_tokens` (combat-scoped summons);
# the ENEMY side is `enemies` (+ enemy summons append here). Targeting + win/loss work over
# the rosters. `player` stays the run-state ref — loss is the PLAYER dying (a token doesn't
# save the run); win is the whole enemy side dead.
var player: Actor
# `enemies` / `allies` are deliberately UNTYPED Arrays: both are shared BY REFERENCE
# with their owners (the Encounter's spawned list; the RunManager's run-scoped allies
# — register_ally relies on that sharing), and a typed assignment would copy.
var enemies: Array = []          # Array[Actor] — the enemy side, left-to-right
var allies: Array = []           # Array[Actor] — run-scoped player-side allies (passed in)
var timekeeper: Timekeeper
var bus: EventBus
var rng: RandomNumberGenerator   # the per-fight stream — random item-targeting (#14/#20)
# The per-fight observation sink (docs/systems/combat_log.md) — OPTIONAL, null-guarded at every
# write. The run screen / the autotest assign one after start(); the sandbox + most GUT tests
# leave it null (no observation needed). Direct-written at each mutation site (not the event bus):
# the bus's listener channel carries no amount + no timestamp. No game-object refs are stored.
var combat_log: CombatLog = null

var _player_tokens: Array[Actor] = []   # combat-scoped player-side summons (dissolved)
var _discarded: Array[Actor] = []       # combat-scoped bodies reaped on death; dissolved at teardown
var _discarded_player_side: Array[Actor] = []   # the reaped that still resolve player-side

var _items: Array[Item] = []            # cooldown Tickers, registration order
# Items CREATED mid-fight (docs/systems/item_creation_and_decay.md Cap 1) — combat-scoped, like
# _player_tokens: tracked here so teardown strips them from their (possibly run-scoped) board and
# they never reach the run snapshot. A created item still lives on actor.board for targeting/firing.
var _created_items: Array[Item] = []
var _ctx: StatusContext = null          # the reserved status `ctx`, realized (decay's remove-item)
var _deliveries: Array[Delivery] = []   # in-flight + recently-resolved
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
  bus.side_resolver = _on_player_side   # side is resolved at EVENT time (rosters mutate)
  rng = RandomNumberGenerator.new()
  rng.seed = _combat_seed
  _ctx = StatusContext.new(self)   # the handle active status hooks act through (decay → remove_item)
  _register_actor(player)
  for a in allies:
    _register_actor(a)
  for e in enemies:
    _register_actor(e)


## Add an Actor to a side mid-fight (docs/systems/spore_engine.md Cap 3) — a summon / boss add. Registers
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


## Register a RUN-scoped ally acquired MID-FIGHT (Cap 3 Stage B). It is already on the
## player side — `allies` is the SAME array the RunManager appended to (shared by reference)
## — so it only needs its Tickers/triggers registered to start fighting. NOT add_actor:
## that files a body as a combat-scoped token (dissolved at teardown); a run-scoped ally
## must survive. The RunManager calls this from add_ally when a fight is live.
func register_ally(actor: Actor) -> void:
  if actor == null or _resolved:
    return
  _register_actor(actor)


## Build a token Actor from an authored EnemyDef (its HP + board) — the same way Encounter
## spawns enemies. The token def is content (the owner authors saprolings / boss adds).
func _spawn_token(def_id: String) -> Actor:
  var def: EnemyDef = EnemyCatalog.get_def(def_id)
  if def == null:
    # A typo'd summon_def_id (content-authoring error): log + skip rather than crash. add_actor
    # already no-ops on a null actor, so the summon simply doesn't land — be safe for players.
    push_error('[CombatManager] _spawn_token: unknown enemy id "%s" — summon skipped.' % def_id)
    return null
  var actor := Actor.new(def.max_hp)
  actor.display_name = def.name_key
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
    _register_item(it)
    _seed_item_uses(it)


## Register one item with the sweep + event bus: append its cooldown Ticker to the swept set and
## subscribe its declared triggers. Shared by fight-start registration (_register_actor) and the
## mid-fight add_item (Cap 1) — the same wiring an item gets either way.
func _register_item(it: Item) -> void:
  _items.append(it)
  for sub in it.def.trigger_subs:
    # The CONTENT default for trigger source is OWN_SIDE — "when MY side does X"
    # (decision #30); a def opts out per subscription via 'source_filter'.
    bus.subscribe(sub['event'], it.cooldown, sub['amount'], sub.get('filter', null),
        sub.get('source_filter', EventBus.SourceFilter.OWN_SIDE), it)


## Seed an item's decay use-status from its def's starting_uses (docs/systems/item_creation_and_decay.md
## Cap 2): >0 applies Decay with that many activations at item birth (fight start, or add_item for a
## created chunk), so authoring stays one number while the live thing is a status content can top up
## or re-target. 0 = unlimited (never decays). Combat-scoped like every status (#26).
func _seed_item_uses(it: Item) -> void:
  if it.def.starting_uses > 0:
    StatusManager.apply(it, DecayStatus.ID, float(it.def.starting_uses))


## Add a new Item to a live board mid-fight (docs/systems/item_creation_and_decay.md Cap 1) — the cousin
## of add_actor (which adds a whole Actor). Builds the item from an ItemCatalog def, appends it to
## `actor`'s board, registers its cooldown Ticker + trigger subs, and seeds its decay use-status.
## COMBAT-SCOPED: tracked in _created_items so teardown strips it from the (possibly run-scoped)
## board and the run snapshot never serializes it. Resolved at a CREATE_ITEM Delivery's land.
func add_item(actor: Actor, def_id: String) -> void:
  if actor == null or _resolved:
    return
  var def: ItemDef = ItemCatalog.get_def(def_id)
  if def == null:
    # A typo'd create_item_def_id (content-authoring error): log it (the catalog already did)
    # and skip the create rather than crash a live fight — be safe for players.
    push_error('[CombatManager] add_item: unknown item id "%s" — create skipped.' % def_id)
    return
  var it := Item.new(def, actor)
  it.cooldown.accum = 0.0
  actor.board.append(it)
  _created_items.append(it)
  _register_item(it)
  _seed_item_uses(it)


## Remove a SINGLE live item from its owner's board mid-fight — the genuinely new plumbing (the
## decay use-status emptying calls this via StatusContext; Cap 1's teardown strip converges here).
## Mirrors the dead-actor reap for one item: drop it from the board + the swept set, deregister its
## triggers (so it stops firing AND stops receiving/emitting pushes), and dissolve it to break the
## Item<->Actor cycle. Idempotent.
func remove_item(it: Item) -> void:
  if it == null:
    return
  # Publish ITEM_DESTROYED FIRST (docs/systems/item_creation_and_decay.md — charge-on-destroy hook),
  # before deregistering this item's wiring, so the bus still routes the event to the OTHER items
  # (a charge item subscribes it). Source = the destroyed item's OWNER, so OWN_SIDE trigger filtering
  # works ("when MY item dies", decision #30). GUARDED: a fight resolving/tearing down strips items
  # too, and that is not a "destroy" for triggers — suppress the publish once _resolved (the flag
  # add_item guards on; teardown also nulls `bus`, the redundant backstop). Decay-death and Cap-2
  # consume-death are the same event — both flow through here.
  if bus != null and not _resolved:
    bus.publish(EventBus.Event.ITEM_DESTROYED, it.def.id, it.owner, it)
  _items.erase(it)
  _created_items.erase(it)
  if bus != null:
    bus.unsubscribe(it)
  if it.owner != null:
    it.owner.board.erase(it)
  it.dissolve()


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
  var fired_items: Array[Item] = []
  for it in _items:
    # A dead actor's items neither tick nor fire (Cap 3 — matters once a side has >1 body:
    # in a multi-enemy fight a slain body must stop swinging). Its statuses still resolve
    # on their own targets; only this owner's own item firing is suppressed.
    if it.owner != null and not it.owner.is_alive():
      continue
    # A gated item's cooldown FREEZES (decision #30): no accrual while silenced, so the
    # gate lifting never releases a banked burst — the first fire comes one full
    # cooldown after the gate lifts. (Item.fire() keeps its own gate check as backstop.)
    if it.is_gated():
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
  var arrived: Array[Delivery] = []
  for d in _deliveries:
    if not d.landed and not d.fizzled and d.step_travel():
      arrived.append(d)

  # 2. Fire crossed items -> resolve shapes -> spawn Deliveries (travel-0 land now).
  for it in fired_items:
    _fire_item(it, arrived)

  # 3. Land arrived (travelled this step + instant spawns).
  for d in arrived:
    _land(d)

  # 4. Reap the combat-scoped dead (enemies + summon tokens leave combat on death; a downed
  #    run-scoped ally stays — see _reap_dead). Before the win/loss check, so clearing the last
  #    enemy this step resolves the fight.
  _reap_dead()

  # 5. (Routing is inline: events published in fire/land push tickers, which are
  #    only evaluated next step — one link per step, loop-proof.)

  # 6. Win/loss.
  _check_resolution()

  # 7. Drop spent Deliveries (fizzled = no visual; landed = held briefly for the
  #    impact number/flash) so the in-flight set can't grow unbounded over a long
  #    fight — docs/systems/vfx_driver.md's "keep until the visual elapses, then drop."
  _prune_deliveries()


## Advance one step of every status on `target` (an Actor OR an Item), dropping any
## that expired. Periodic-damage statuses only ever sit on actors (the `take_damage`
## owner); timed / static shapes work on either — so one pass serves both, and item
## statuses tick on the same cadence as actor statuses.
func _advance_statuses_on(target) -> void:
  var spent: Array[StatusEffect] = []
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
        # The DoT damage is logged HERE — the bus publishes no event for a tick, so this is the
        # only place the log catches it. `st.source` may be an Item (→ its name + owner side), an
        # Actor (→ SOURCELESS + that actor's side), or null (→ SOURCELESS, credited to the
        # target's opponent). The single source of truth (docs/systems/combat_log.md Design B):
        # this credits each tick to its own status's source exactly.
        if combat_log != null:
          combat_log.on_damage(_status_source_name(st), _status_source_side(st, target),
              target.display_name, _side_of(target), dealt, timekeeper.sim_time)
  for st in spent:
    st.on_expire(target, null)   # the natural-removal hook (every removal site calls it)
    target.statuses.erase(st)


## A visual-only Delivery for a DoT tick so the wall shows the number — the damage
## itself was already applied inside StatusManager.advance_status. Pre-landed, never
## passed to _land, and flagged so the autotest's direct-hit attribution skips it.
func _dot_visual(status: StatusEffect, target, dealt: float) -> Delivery:
  var d := Delivery.new()
  d.kind = Delivery.Kind.DAMAGE
  d.value = dealt
  d.target = target
  d.source = status.source
  d.color = status.color
  d.travel = Ticker.new(0)
  d.fire_time = timekeeper.sim_time
  d.impact_time = timekeeper.sim_time
  d.landed = true
  d.visual_only = true
  return d


func _fire_item(it: Item, arrived: Array) -> void:
  # Re-check the owner: the status pass runs AFTER crossings are collected, so a DoT
  # tick can kill an actor whose item crossed this same step — a slain body must not
  # swing (the Cap 3 rule; the loop's check above only covers earlier deaths).
  if it.owner != null and not it.owner.is_alive():
    return
  var payloads := it.fire()
  if payloads.is_empty():
    return   # gated (silence)
  bus.publish(EventBus.Event.ITEM_FIRED, it.def.id, it.owner, it)
  if combat_log != null:
    combat_log.on_item_fired(it.def.name_key, _side_of(it.owner), timekeeper.sim_time)
  # The item still fires (cooldown reset, fire-emote) even when blinded — but its DAMAGE
  # whiffs (docs/systems/spore_engine.md Cap 2). Locked at fire so a swing launched while blinded misses.
  var blinded: bool = StatusManager.has_evasion(it.owner)
  for p in payloads:
    # Own-board item-consume (the Mass-twin, docs/systems/item_creation_and_decay.md): spend a pile of
    # the owner's matching board items as fuel BEFORE spawning this payload's deliveries — counted +
    # removed once (a single board pool), scaling this payload's value by the count. Removed VIA
    # remove_item so each consumed item publishes ITEM_DESTROYED (the synergy: a charge-on-destroy
    # item charges off active consume for free — consume-death is the same event as decay-death).
    if p.consume_item_def_id != '':
      p.value += _consume_board_items(it.owner, p.consume_item_def_id, p.consume_item_amount) * p.consume_item_scale
    for target in _resolve_targets(p, it.owner):
      var d := _spawn_delivery(p, target)
      # Opponent-fuel consume (Mass, Cap 1): spend the resolved TARGET's stacks here (it's
      # only known now), scaling the Delivery — the Item stayed downward-clean (it declared).
      if p.consume_id != '' and p.consume_from_target:
        d.value += StatusManager.consume(target, p.consume_id, p.consume_amount) * p.consume_scale
      if blinded and d.kind == Delivery.Kind.DAMAGE:
        d.evaded = true
      _deliveries.append(d)
      if d.travel.crossed():
        arrived.append(d)   # instant (travel 0) lands this same step
  # Drain the item's use-statuses AFTER its payload(s) are spawned (docs/systems/item.md fire
  # pipeline): decay spends one activation, so the final fire still lands, then removes the item at 0.
  _drain_uses(it)


## After an item fires, advance its item-targeted use-statuses (Decay): each spends one activation
## and, at 0, asks the StatusContext to remove the host item. Iterate a COPY — a spent use-status
## removes the item, which clears item.statuses mid-pass.
func _drain_uses(it: Item) -> void:
  for s in it.statuses.duplicate():
    s.on_holder_fired(it, _ctx)


## Consume up to `amount` of `owner_actor`'s board items whose def id matches `def_id`, as fuel for an
## own-board-consume payload (docs/systems/item_creation_and_decay.md — the Mass-twin). `amount` <= 0
## consumes ALL present. Each match is removed via remove_item (the ITEM_DESTROYED-publishing path),
## so a charge-on-destroy item sees consume-death and decay-death as the same event. Iterates a COPY —
## remove_item mutates the board mid-pass (cf. _drain_uses walking it.statuses.duplicate()). Returns
## the count removed (the scaling multiplier). Deterministic — no RNG.
func _consume_board_items(owner_actor: Actor, def_id: String, amount: int) -> int:
  if owner_actor == null:
    return 0
  var removed: int = 0
  for it in owner_actor.board.duplicate():
    if amount > 0 and removed >= amount:
      break
    if it.def.id == def_id:
      remove_item(it)
      removed += 1
  return removed


## Retain in-flight Deliveries and recently-landed ones (for their impact visual);
## drop fizzled ones (no visual) and landed ones whose visual hold has elapsed.
## Keyed off sim_time — the VFX wall reads render_time, which tracks it. This is
## what keeps `_deliveries` bounded; teardown clears whatever's left at fight end.
func _prune_deliveries() -> void:
  var now: float = timekeeper.sim_time
  var kept: Array[Delivery] = []
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
  d.status_id = p.status_id
  d.duration = p.duration
  d.summon_def_id = p.summon_def_id
  d.summon_in_front = p.summon_in_front
  d.create_item_def_id = p.create_item_def_id
  d.flags = p.flags
  d.color = p.color
  d.source = p.source
  d.source_actor = p.source_actor
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
  # A single target that died/left mid-flight fizzles — no retarget (docs/systems/combat_model.md). For an
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
        var dealt: float = d.target.take_damage(d.value, d.flags)
        bus.publish(EventBus.Event.DAMAGE_DEALT, null, d.source_actor, _source_item_of(d))
        if combat_log != null:
          # `d.value` is the GROSS hit (pre-block); `dealt` is the NET HP lost — log both
          # (gross = the threat metric, survives a full block; net = what HP actually did).
          combat_log.on_damage(_delivery_source_name(d), _delivery_source_side(d),
              d.target.display_name, _side_of(d.target), dealt, timekeeper.sim_time, d.value)
    Delivery.Kind.HEAL:
      if d.target is Actor:
        var healed: float = d.target.heal(d.value)
        bus.publish(EventBus.Event.HEALED, null, d.source_actor, _source_item_of(d))
        if combat_log != null:
          combat_log.on_heal(_delivery_source_name(d), _delivery_source_side(d),
              d.target.display_name, _side_of(d.target), healed, timekeeper.sim_time)
    Delivery.Kind.APPLY_STATUS:   # target is an Actor OR an Item — both hold a status list
      var applied: StatusEffect = StatusManager.apply(d.target, d.status_id, d.value, d.duration, d.source, d.flags)
      if applied != null:   # an unknown id applies nothing — publish no event for it
        bus.publish(EventBus.Event.STATUS_APPLIED, d.status_id, d.source_actor, _source_item_of(d))
        if combat_log != null:
          # Shield (block) carries its value; every other status is a count. Use BlockStatus.ID,
          # not a literal, so the two stay in step (docs/systems/combat_log.md Cap 2 site 5).
          if d.status_id == BlockStatus.ID:
            combat_log.on_block(_delivery_source_name(d), _delivery_source_side(d),
                _target_name(d.target), _target_side(d.target), d.value, timekeeper.sim_time)
          else:
            combat_log.on_status_applied(_delivery_source_name(d), _delivery_source_side(d),
                _target_name(d.target), _target_side(d.target), d.status_id, timekeeper.sim_time)
    Delivery.Kind.SUMMON:   # spawn a token onto the summoner's side (shape SELF → target = summoner)
      if d.summon_def_id != '' and d.target is Actor:
        add_actor(_spawn_token(d.summon_def_id), _on_player_side(d.target), d.summon_in_front)
    Delivery.Kind.CREATE_ITEM:   # create an item on the firing actor's OWN board (shape SELF → target = firer)
      if d.create_item_def_id != '' and d.target is Actor:
        add_item(d.target, d.create_item_def_id)


## The firing Item behind a Delivery, for event source identity — `source` doubles as
## the VFX origin, so it is null for a thrown consumable (the throw's actor identity
## still rides `source_actor`).
func _source_item_of(d: Delivery) -> Item:
  return d.source if d.source is Item else null


# --- CombatLog source/side resolution (docs/systems/combat_log.md) -----------
# The log stores name_keys + side ints (never object refs), resolved at the write site.

## Which side an actor is on, as a CombatLog.Side (the log keys per side — a colorless
## item can sit on both, so a flat key would conflate them).
func _side_of(actor) -> int:
  return CombatLog.Side.PLAYER if _on_player_side(actor) else CombatLog.Side.ENEMY


## The opposite side — for a source-less DoT, whose dealer is the holder's opponent.
func _other_side(side: int) -> int:
  return CombatLog.Side.ENEMY if side == CombatLog.Side.PLAYER else CombatLog.Side.PLAYER


## The dealing item's name_key behind a Delivery — SOURCELESS when there is none (a
## thrown consumable has a null `source`; its actor identity rides `source_actor`).
func _delivery_source_name(d: Delivery) -> String:
  var it: Item = _source_item_of(d)
  return it.def.name_key if it != null else CombatLog.SOURCELESS


## The dealing side behind a Delivery — the source item's owner side, else the acting
## actor's (a thrown consumable), else the target's opponent (a fully source-less hit).
func _delivery_source_side(d: Delivery) -> int:
  var it: Item = _source_item_of(d)
  if it != null and it.owner != null:
    return _side_of(it.owner)
  if d.source_actor != null:
    return _side_of(d.source_actor)
  return _other_side(_target_side(d.target))


## A status-targeting Delivery's target name — the Actor's display_name, or for an
## item-targeted status the host item's name_key.
func _target_name(target) -> String:
  if target is Actor:
    return target.display_name
  if target is Item:
    return target.def.name_key
  return ''


## A status-targeting Delivery's target side — the Actor's side, or the host item's owner's.
func _target_side(target) -> int:
  if target is Item:
    return _side_of(target.owner)
  return _side_of(target)


## A DoT status's applier name_key — the applier item's name when known, else SOURCELESS
## (an Actor-applied or item-less DoT; the old DOT_FAMILY fallback moves to the log).
func _status_source_name(st: StatusEffect) -> String:
  if st.source is Item and st.source.def != null:
    return st.source.def.name_key
  return CombatLog.SOURCELESS


## A DoT status's dealer side — the applier item's owner side, an applier Actor's side, or
## (no source) the holder's opponent (a DoT damages its holder; the dealer is the other side).
func _status_source_side(st: StatusEffect, holder) -> int:
  if st.source is Item and st.source.owner != null:
    return _side_of(st.source.owner)
  if st.source is Actor:
    return _side_of(st.source)
  return _other_side(_side_of(holder))


# --- Target-shape resolution (the runtime targeting authority) --------------

## Resolve a payload's relative shape into concrete targets, relative to `owner_actor`
## (the firing item's owner, or a thrown consumable's thrower).
func _resolve_targets(p: Payload, owner_actor: Actor) -> Array:
  match p.shape:
    ItemEffect.Shape.SELF:
      return [owner_actor]
    ItemEffect.Shape.OPPONENT_LEFTMOST:
      var t = _leftmost_living_opponent(owner_actor)
      return [t] if t != null else []
    ItemEffect.Shape.ALL_OPPONENTS:
      return _living_opponents(owner_actor)
    ItemEffect.Shape.OPPONENT_ITEM_RANDOM:
      return _random_opponent_item(owner_actor)
    ItemEffect.Shape.ALL_OPPONENT_ITEMS:
      return _all_opponent_items(owner_actor)
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
  push_warning('[CombatManager] target shape %d has no resolver; the effect fires nothing.' % shape)


## Is a Delivery's target still a valid landing site? An Actor must be alive; an Item's
## owning actor must be alive (an item-targeted status applies to the Item itself).
func _target_alive(target) -> bool:
  if target is Actor:
    return target.is_alive()
  if target is Item:
    return target.owner != null and target.owner.is_alive()
  return false


## The ordered player side: combat-scoped summons (front, body-block) then the run-state
## actor then run-scoped allies. Leftmost-living targeting walks this in order; the
## multi-actor view reads it to render every player-side body. A fresh array each call.
func player_side() -> Array:
  return _player_tokens + [player] + allies


func _on_player_side(actor) -> bool:
  return actor == player or actor in allies or actor in _player_tokens \
      or actor in _discarded_player_side


func _all_actors() -> Array:
  return player_side() + enemies


func _opponents_of(actor: Actor) -> Array:
  # A fresh array either way (never the live `enemies` ref) — callers may resolve targets
  # while the roster mutates (a summon lands mid-resolution).
  return enemies.duplicate() if _on_player_side(actor) else player_side()


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


## Reap the COMBAT-SCOPED dead from the live rosters: dead enemies and dead player-side summon
## tokens leave combat — out of targeting + firing, their HUD removed, dissolved at teardown.
## RUN-SCOPED allies are deliberately NOT reaped: a downed ally stays on the roster (its slot
## remains, it just stops participating — its items are already skipped while dead) and is
## revived to full by the RunManager at the next fight. The player is never reaped (its death
## is the loss). Their item Tickers are dropped from the sweep so they stop being advanced.
func _reap_dead() -> void:
  _reap_from(enemies, false)
  _reap_from(_player_tokens, true)


func _reap_from(roster: Array, player_side_roster: bool) -> void:
  for i in range(roster.size() - 1, -1, -1):
    var actor: Actor = roster[i]
    if not actor.is_alive():
      for it in actor.board:
        # Deliberately NOT via remove_item: an item leaving with its DEAD OWNER is not a "destroy"
        # for triggers (docs/systems/item_creation_and_decay.md). ITEM_DESTROYED fires only for the
        # ACTIVE removal of a still-owned item (decay-depletion, own-board-consume) — a charge-on-
        # destroy item does NOT charge when a token/ally/enemy dies. So this strips the wiring
        # directly (drop from the sweep + unsubscribe) and publishes nothing.
        _items.erase(it)
        bus.unsubscribe(it)   # a reaped body's items stop receiving trigger pushes
      roster.remove_at(i)
      if player_side_roster:
        # A reaped player-side token must still resolve as player-side for events its
        # in-flight Deliveries land after the reap (_on_player_side checks live rosters).
        _discarded_player_side.append(actor)
      _discarded.append(actor)   # kept intact (live Deliveries/VFX may still ref it); dissolved at teardown


func _finish(won: bool) -> void:
  _resolved = true
  _player_won = won
  set_physics_process(false)
  resolved.emit(won)


## The fight result surface (the `resolved` signal is the push form; these are
## the pull form the headless autotest polls after each sim_step).
func is_resolved() -> bool:
  return _resolved


func player_won() -> bool:
  return _player_won


## The in-flight + recently-landed Delivery set — the read-only "wall" the VFX
## driver and the autotest logger sample (docs/systems/vfx_driver.md / autotest.md). Pruned
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


## Throw-potion intent: activate a thrown consumable (docs/systems/content.md). Build its
## effect(s) into Deliveries resolved relative to the thrower, then land any that
## arrive instantly — the same resolution surface as an item fire, minus the
## Ticker. The RunManager removes the potion from its slot; this just resolves it.
func throw_consumable(consumable, thrower: Actor) -> void:
  if _resolved:
    return
  if combat_log != null:
    combat_log.on_throw(consumable.def.id, _side_of(thrower), timekeeper.sim_time)
  for effect in consumable.def.effects:
    # The shared template copy only — a throw deliberately SKIPS the item-side stages
    # (enchant scaling, modify_outgoing, evasion): potions are exempt (decision #30).
    var p := Payload.from_effect(effect)
    p.source_actor = thrower   # event source identity; `source` stays null (the VFX origin)
    # Self-fuel consume (Cap 1) — the thrower is known here, so resolve it like an item fire.
    if p.consume_id != '' and not p.consume_from_target:
      p.value += StatusManager.consume(thrower, p.consume_id, p.consume_amount) * p.consume_scale
    for target in _resolve_targets(p, thrower):
      var d := _spawn_delivery(p, target)
      if p.consume_id != '' and p.consume_from_target:   # opponent-fuel: spend the target's stacks
        d.value += StatusManager.consume(target, p.consume_id, p.consume_amount) * p.consume_scale
      _deliveries.append(d)
      if d.travel.crossed():
        _land(d)
  # A throw can be lethal outside the step loop (e.g. while paused at timescale 0, when
  # no sim_step follows to notice) — reap and resolve NOW, like step 4/6 of sim_step.
  _reap_dead()
  _check_resolution()




## Break the fight's reference cycles so it can free (CLAUDE.md runtime cleanup),
## idempotent. ALL statuses are combat-scoped and dropped here (#26). The RUN-SCOPED
## player side (the run-state actor + persistent `allies`) PERSISTS — only its combat
## statuses clear, its board survives. COMBAT-SCOPED actors (enemies, enemy summons,
## player-side tokens) are discarded, so we break their Actor<->Item cycle (dissolve).
## Call after reading the result.
## Safety net (CLAUDE.md runtime cleanup): a CombatManager freed while in the tree
## (the sandbox host, or any future mount) still breaks its cycles. The owning
## Encounter calls teardown() explicitly; this is the idempotent backstop.
func _exit_tree() -> void:
  teardown()


func teardown() -> void:
  if _torn_down:
    return
  _torn_down = true
  # Strip combat-scoped CREATED items (Cap 1) from their boards FIRST, while owner refs are intact.
  # On a RUN-SCOPED board (the player / an ally) this restores the drafted board so the run snapshot
  # — taken between fights — never serializes a created chunk. On a combat-scoped board it is
  # redundant with the dissolve below, but harmless.
  for it in _created_items:
    if it.owner != null:
      it.owner.board.erase(it)
    it.dissolve()
  _created_items.clear()
  _clear_statuses(player)
  for a in allies:
    _clear_statuses(a)
  for e in enemies:
    e.dissolve()
  for t in _player_tokens:
    t.dissolve()
  for d in _discarded:   # combat-scoped bodies reaped mid-fight — dissolve them here too
    d.dissolve()
  _items.clear()
  _deliveries.clear()
  enemies = []
  allies = []
  _player_tokens = []
  _discarded = []
  _discarded_player_side = []
  player = null
  timekeeper = null
  if bus != null:
    bus.clear()   # releases the bus's strong Subscription -> Item refs + listeners
  bus = null
  rng = null
  _ctx = null   # the StatusContext holds a back-ref to this manager — drop it


func _clear_statuses(actor: Actor) -> void:
  for it in actor.board:
    it.statuses.clear()
  actor.statuses.clear()
