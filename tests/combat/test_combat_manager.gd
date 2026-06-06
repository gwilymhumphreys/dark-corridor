extends GutTest
## Step 4 — the per-fight orchestrator. A full deterministic fight, seed-free
## reproducibility, the poison->avenger trigger firing one step later (loop-proof
## synergy), mid-flight fizzle, simultaneous-death-is-loss, and teardown breaking
## the reference cycles.


var _made: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  # Tear each fight down (as the Encounter will) and free the manager Node, so no
  # orphans linger past the test.
  for cm in _made:
    if is_instance_valid(cm):
      cm.teardown()
      cm.free()
  _made.clear()
  TestCleanup.reset_all_managers()


# --- helpers ----------------------------------------------------------------

func _spawn(max_hp: float, item_ids: Array) -> Actor:
  var a := Actor.new(max_hp)
  for id in item_ids:
    a.board.append(Item.new(ItemCatalog.get_def(id), a))
  return a


func _manager(p: Actor, enemy_list: Array) -> CombatManager:
  var cm := CombatManager.new(p, enemy_list)
  _made.append(cm)
  return cm


func _has_status(actor: Actor, type: int) -> bool:
  for s in actor.statuses:
    if s.type == type:
      return true
  return false


func _item_has_status(item: Item, type: int) -> bool:
  for s in item.statuses:
    if s.type == type:
      return true
  return false


func _run_basic() -> Dictionary:
  var p := _spawn(Balance.PLAYER_START_HP, [ItemCatalog.Id.WEAPON])
  var e := _spawn(Balance.ENEMY_PLACEHOLDER_HP, [ItemCatalog.Id.ENEMY_CLAW])
  var cm := _manager(p, [e])
  cm.start()
  var steps := cm.run_headless()
  return { 'won': cm._player_won, 'steps': steps, 'hp': p.hp }


# --- tests ------------------------------------------------------------------

func test_player_beats_weaker_enemy() -> void:
  var r := _run_basic()
  assert_true(r['won'], 'player (100 HP) outlasts the grunt (40 HP) at equal output')
  assert_gt(r['steps'], 0, 'the fight took some steps')


func test_fight_is_deterministic() -> void:
  var a := _run_basic()
  var b := _run_basic()
  assert_eq(a['won'], b['won'], 'same winner')
  assert_eq(a['steps'], b['steps'], 'same step count (no RNG in Phase 1)')
  assert_almost_eq(a['hp'], b['hp'], 0.0001, 'identical final HP — bit-reproducible')


func test_poison_trigger_fires_avenger_next_step() -> void:
  # A custom avenger that NEVER fires on its own cooldown, so any block it grants
  # MUST come from the poison trigger.
  var avenger := ItemDef.new()
  avenger.cooldown = 9999.0
  var blk := ItemEffect.new()
  blk.kind = Delivery.Kind.APPLY_STATUS
  blk.status_type = StatusDef.Type.BLOCK
  blk.value = 5.0
  blk.shape = ItemEffect.Shape.SELF
  avenger.effects = [blk]
  avenger.trigger_subs = [{
    'event': EventBus.Event.STATUS_APPLIED,
    'amount': Balance.TRIGGER_PUSH_FULL,
    'filter': StatusDef.Type.POISON,
  }]

  var p := Actor.new(500.0)
  p.board.append(Item.new(ItemCatalog.get_def(ItemCatalog.Id.POISON_DAGGER), p))
  p.board.append(Item.new(avenger, p))
  var e := _spawn(500.0, [ItemCatalog.Id.ENEMY_CLAW])
  var cm := _manager(p, [e])
  cm.start()

  # Step until the poison lands on the enemy.
  var guard := 0
  while not _has_status(e, StatusDef.Type.POISON) and guard < 1000:
    cm.sim_step()
    guard += 1
  assert_true(_has_status(e, StatusDef.Type.POISON), 'poison was applied')
  assert_false(_has_status(p, StatusDef.Type.BLOCK), 'the push does NOT fire the avenger the same step')

  cm.sim_step()
  assert_true(_has_status(p, StatusDef.Type.BLOCK), 'the avenger fires one step later (loop-proof synergy)')


func test_delivery_fizzles_if_target_died() -> void:
  var p := Actor.new(100.0)
  var e := Actor.new(10.0)
  var cm := _manager(p, [e])
  cm.start()
  e.take_damage(10.0)   # enemy already dead
  var d := Delivery.new()
  d.kind = Delivery.Kind.DAMAGE
  d.value = 5.0
  d.target = e
  d.travel = Ticker.new(1)
  cm._land(d)
  assert_true(d.fizzled, 'a delivery to a dead target fizzles, applies nothing')


func test_simultaneous_death_is_loss() -> void:
  var p := Actor.new(5.0)
  var e := Actor.new(5.0)
  var cm := _manager(p, [e])
  cm.start()
  watch_signals(cm)
  p.take_damage(5.0)
  e.take_damage(5.0)
  cm._check_resolution()
  assert_signal_emitted(cm, 'resolved')
  assert_eq(get_signal_parameters(cm, 'resolved')[0], false, 'both dead same tick = loss')


func test_deliveries_are_pruned_not_accumulated() -> void:
  # Two unkillable actors trading blows forever: without pruning, every fired
  # Delivery would pile up in _deliveries. With it, only the few in-flight /
  # still-animating at any moment survive — the set stays bounded.
  var p := _spawn(1_000_000.0, [ItemCatalog.Id.WEAPON])
  var e := _spawn(1_000_000.0, [ItemCatalog.Id.ENEMY_CLAW])
  var cm := _manager(p, [e])
  cm.start()
  var peak := 0
  for i in 2000:
    cm.sim_step()
    peak = maxi(peak, cm._deliveries.size())
  assert_false(cm._resolved, 'neither actor dies in this window — the fight is still live')
  assert_lt(peak, 6, 'in-flight + animating Deliveries stay bounded (without pruning this would be ~50+)')


func test_actor_and_item_statuses_advance_identically() -> void:
  # A timed status on an actor and on an item must count down + expire on the SAME
  # step — item statuses are advanced uniformly, not skipped. High HP so the fight
  # outlasts the status duration.
  var p := _spawn(1000.0, [ItemCatalog.Id.WEAPON])
  var e := _spawn(1000.0, [ItemCatalog.Id.ENEMY_CLAW])
  var cm := _manager(p, [e])
  cm.start()
  StatusManager.apply(p, StatusDef.Type.WEAK, 1.0)            # timed status on the actor
  StatusManager.apply(p.board[0], StatusDef.Type.WEAK, 1.0)   # timed status on one of its items
  assert_true(_has_status(p, StatusDef.Type.WEAK), 'actor weak applied')
  assert_true(_item_has_status(p.board[0], StatusDef.Type.WEAK), 'item weak applied')

  var dur_steps: int = int(ceil(Balance.SAMPLE_DEBUFF_DURATION / Balance.STEP))
  for i in dur_steps - 1:
    cm.sim_step()
  assert_true(_has_status(p, StatusDef.Type.WEAK), 'actor weak still ticking')
  assert_true(_item_has_status(p.board[0], StatusDef.Type.WEAK), 'item weak still ticking')

  cm.sim_step()   # the expiry step
  assert_false(_has_status(p, StatusDef.Type.WEAK), 'actor weak expired')
  assert_false(_item_has_status(p.board[0], StatusDef.Type.WEAK), 'item weak expired on the same step')


func test_random_item_target_is_reproducible_by_seed() -> void:
  # OPPONENT_ITEM_RANDOM (Hex Bolt → silence a random enemy item) picks on the seeded
  # per-fight RNG, so the same combat seed silences the same item (#14/#20: random
  # targeting that's still bit-reproducible / resume-safe).
  var a: int = _hex_silence_index(777)
  var b: int = _hex_silence_index(777)
  assert_ne(a, -1, 'the hex silenced one of the enemy items')
  assert_eq(a, b, 'the same combat seed silences the same item')


func test_random_item_target_varies_across_seeds() -> void:
  # Genuinely seed-driven, not secretly fixed: a spread of seeds hits more than one item.
  var seen: Dictionary = {}
  for s in 25:
    seen[_hex_silence_index(s * 13 + 1)] = true
  assert_gt(seen.size(), 1, 'different combat seeds silence different items')


# Run Hex Bolt (player) vs a 4-item enemy under `combat_seed`; return the board index of
# the first item it silences (the random pick), or -1 if none within the guard.
func _hex_silence_index(combat_seed: int) -> int:
  var p := Actor.new(5000.0)
  p.board.append(Item.new(ItemCatalog.get_def(ItemCatalog.Id.HEX_BOLT), p))
  var e := Actor.new(5000.0)
  for i in 4:
    e.board.append(Item.new(ItemCatalog.get_def(ItemCatalog.Id.ENEMY_CLAW), e))
  var cm := CombatManager.new(p, [e], combat_seed)
  _made.append(cm)
  cm.start()
  for _i in 1000:
    cm.sim_step()
    for idx in e.board.size():
      if _item_has_status(e.board[idx], StatusDef.Type.SILENCE):
        return idx
  return -1


func test_unresolved_item_target_shape_yields_no_targets() -> void:
  # The item-target shapes aren't resolved yet (they need the per-fight RNG, #14/#20).
  # An item authored with one must visibly fire nothing (and warn once) — not crash.
  var p := Actor.new(100.0)
  var e := Actor.new(100.0)
  var cm := _manager(p, [e])
  cm.start()
  var payload := Payload.new()
  payload.shape = ItemEffect.Shape.OPPONENT_ITEM_RANDOM
  assert_eq(cm._resolve_targets(payload, p).size(), 0, 'an unresolved item-target shape resolves to no targets')


func test_dot_tick_through_block_does_not_skip_a_later_status() -> void:
  # A poison tick calls take_damage, which can erase a depleted block from the SAME
  # status list the step-pass is walking. A naive in-place loop would then skip the
  # status after block. Set up [block, poison, weak] with poison about to tick and
  # block small enough to be fully consumed — weak must still advance this pass.
  var p := Actor.new(100.0)
  var a := Actor.new(100.0)
  var cm := _manager(p, [a])
  cm.start()
  StatusManager.apply(a, StatusDef.Type.BLOCK, 1.0)          # one poison tick empties it
  var pois: Status = StatusManager.apply(a, StatusDef.Type.POISON, 3.0)
  pois.ticker.accum = pois.ticker.threshold - 1.0            # fire on the next advance
  var weak: Status = StatusManager.apply(a, StatusDef.Type.WEAK, 1.0)   # after poison in the list

  cm._advance_statuses_on(a)

  assert_eq(weak.ticker.accum, 1.0, 'the status after block still advanced (no skip)')
  assert_false(_has_status(a, StatusDef.Type.BLOCK), 'block was consumed and erased mid-pass')
  assert_eq(a.hp, 98.0, 'poison dealt 3, block absorbed 1, 2 leaked to HP')


func test_dot_tick_shows_a_visual_on_the_wall() -> void:
  # A DoT tick applies damage inside the status pass (no Delivery lands), so the wall
  # would show nothing. We spawn a visual-only Delivery carrying the tick's number.
  var p := Actor.new(100.0)
  var a := Actor.new(100.0)
  var cm := _manager(p, [a])
  cm.start()
  var pois: Status = StatusManager.apply(a, StatusDef.Type.POISON, 3.0)
  pois.ticker.accum = pois.ticker.threshold - 1.0
  cm._advance_statuses_on(a)
  var visuals: Array = []
  for d in cm.deliveries():
    if d.visual_only:
      visuals.append(d)
  assert_eq(visuals.size(), 1, 'a poison tick spawns exactly one visual-only Delivery')
  assert_eq(visuals[0].target, a, 'the number pops on the poisoned actor')
  assert_almost_eq(visuals[0].value, 3.0, 0.001, 'it shows the damage the tick dealt')
  assert_true(visuals[0].landed, 'it is pre-landed — _land never runs on it')


func test_enemy_actor_and_items_free_after_teardown() -> void:
  # The Actor<->Item cycle (board holds the item, item.owner holds the actor back)
  # must be broken at teardown, or every fight leaks its enemy + board (RefCounted
  # has no cycle collection). Player has no board here so only the enemy cycle is
  # under test. weakref goes null only once the object is actually freed.
  var p := Actor.new(100.0)
  var e := _spawn(40.0, [ItemCatalog.Id.ENEMY_CLAW])
  var weak_enemy: WeakRef = weakref(e)
  var weak_item: WeakRef = weakref(e.board[0])
  var cm := CombatManager.new(p, [e])
  cm.start()
  cm.teardown()
  cm.free()
  e = null   # drop the last external strong ref; only a cycle could keep it alive
  assert_null(weak_enemy.get_ref(), 'the enemy actor frees after the fight')
  assert_null(weak_item.get_ref(), 'and its board items free too')


func test_item_cooldowns_reset_each_fight() -> void:
  # The player's board persists across the run, but a cooldown is combat-scoped (like
  # a status): it must NOT carry over. Else fight N+1 opens mid-charge, and a resumed
  # save (items rebuilt fresh at accum 0) diverges from continuous play (decision #20).
  var p := _spawn(1000.0, [ItemCatalog.Id.WEAPON])
  var e := _spawn(1000.0, [ItemCatalog.Id.ENEMY_CLAW])
  var cm := _manager(p, [e])
  cm.start()
  for i in 20:
    cm.sim_step()
  assert_gt(p.board[0].cooldown.accum, 0.0, 'the weapon charged partway through fight 1')
  cm.teardown()   # the player survives teardown (only its statuses clear); its board persists

  # A new fight with the SAME persistent player board must start the item fresh.
  var e2 := _spawn(1000.0, [ItemCatalog.Id.ENEMY_CLAW])
  var cm2 := _manager(p, [e2])
  cm2.start()
  assert_eq(p.board[0].cooldown.accum, 0.0, 'fight 2 starts every board item at a fresh cooldown')


func test_teardown_clears_combat_state() -> void:
  var p := _spawn(Balance.PLAYER_START_HP, [ItemCatalog.Id.POISON_DAGGER])
  var e := _spawn(Balance.ENEMY_PLACEHOLDER_HP, [ItemCatalog.Id.ENEMY_CLAW])
  var cm := _manager(p, [e])
  cm.start()
  cm.run_headless()
  cm.teardown()
  assert_true(p.statuses.is_empty(), 'player combat statuses cleared')
  assert_true(e.statuses.is_empty(), 'enemy combat statuses cleared')
  assert_true(cm._deliveries.is_empty(), 'in-flight deliveries dropped')


# --- Phase 4: the real-time tick seam ---------------------------------------

func test_tick_drives_fight_to_resolution() -> void:
  # tick(delta) is the run screen's real-time driver: it turns real delta into
  # whole sim-steps (steps_due) and runs them. Same verdict as run_headless, just
  # off a clock instead of a raw loop.
  var p := _spawn(Balance.PLAYER_START_HP, [ItemCatalog.Id.WEAPON])
  var e := _spawn(Balance.ENEMY_PLACEHOLDER_HP, [ItemCatalog.Id.ENEMY_CLAW])
  var cm := _manager(p, [e])
  cm.start()
  var guard := 0
  while not cm.is_resolved() and guard < 2000:
    cm.tick(0.1)   # ~6 sim-steps per call at base scale x1
    guard += 1
  assert_true(cm.is_resolved(), 'tick(delta) drives the fight to a verdict')
  assert_true(cm.player_won(), 'player (100 HP) beats the grunt (40 HP)')


func test_request_slowmo_sets_and_clears_the_dial() -> void:
  # The slow-mo-on-hover intent: the view never writes the dial — it asks, and the
  # manager sets / clears its Timekeeper's momentary override (back to base, not x1).
  var p := _spawn(Balance.PLAYER_START_HP, [ItemCatalog.Id.WEAPON])
  var e := _spawn(Balance.ENEMY_PLACEHOLDER_HP, [ItemCatalog.Id.ENEMY_CLAW])
  var cm := _manager(p, [e])
  cm.start()
  cm.request_slowmo(true)
  assert_almost_eq(cm.timekeeper.effective_scale(), Balance.TIMESCALE_SLOWMO, 0.0001, 'hover slows the clock')
  cm.request_slowmo(false)
  assert_almost_eq(cm.timekeeper.effective_scale(), Balance.TIMESCALE_BASE, 0.0001, 'exit returns to base')


func test_physics_process_drives_tick_when_mounted() -> void:
  # A directly-mounted CombatManager (the sandbox) must still self-drive: its
  # _physics_process delegates to tick(). Mount it, run a couple of physics frames,
  # and confirm the clock advanced. Not via _manager — we own its lifetime here.
  var p := _spawn(Balance.PLAYER_START_HP, [ItemCatalog.Id.WEAPON])
  var e := _spawn(Balance.ENEMY_PLACEHOLDER_HP, [ItemCatalog.Id.ENEMY_CLAW])
  var cm := CombatManager.new(p, [e])
  cm.start()
  cm.timekeeper.set_base_scale(20.0)   # many sim-steps per physics frame
  add_child(cm)
  var before: float = cm.timekeeper.sim_time
  await get_tree().physics_frame
  await get_tree().physics_frame
  assert_gt(cm.timekeeper.sim_time, before, 'mounted _physics_process advanced the clock via tick()')
  remove_child(cm)
  cm.teardown()
  cm.free()
