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


func _has_status(actor: Actor, id: String) -> bool:
  for s in actor.statuses:
    if s.id == id:
      return true
  return false


func _item_has_status(item: Item, id: String) -> bool:
  for s in item.statuses:
    if s.id == id:
      return true
  return false


func _run_basic() -> Dictionary:
  var p := _spawn(Balance.PLAYER_START_HP, [ItemCatalog.WEAPON])
  var e := _spawn(Balance.ENEMY_PLACEHOLDER_HP, [ItemCatalog.ENEMY_CLAW])
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
  blk.status_id = 'block'
  blk.value = 5.0
  blk.shape = ItemEffect.Shape.SELF
  avenger.effects = [blk]
  avenger.trigger_subs = [{
    'event': EventBus.Event.STATUS_APPLIED,
    'amount': Balance.TRIGGER_PUSH_FULL,
    'filter': 'poison',
  }]

  var p := Actor.new(500.0)
  p.board.append(Item.new(ItemCatalog.get_def(ItemCatalog.POISON_DAGGER), p))
  p.board.append(Item.new(avenger, p))
  var e := _spawn(500.0, [ItemCatalog.ENEMY_CLAW])
  var cm := _manager(p, [e])
  cm.start()

  # Step until the poison lands on the enemy.
  var guard := 0
  while not _has_status(e, 'poison') and guard < 1000:
    cm.sim_step()
    guard += 1
  assert_true(_has_status(e, 'poison'), 'poison was applied')
  assert_false(_has_status(p, 'block'), 'the push does NOT fire the avenger the same step')

  cm.sim_step()
  assert_true(_has_status(p, 'block'), 'the avenger fires one step later (loop-proof synergy)')


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
  var p := _spawn(1_000_000.0, [ItemCatalog.WEAPON])
  var e := _spawn(1_000_000.0, [ItemCatalog.ENEMY_CLAW])
  var cm := _manager(p, [e])
  cm.start()
  var peak := 0
  for _i in 2000:
    cm.sim_step()
    peak = maxi(peak, cm._deliveries.size())
  assert_false(cm._resolved, 'neither actor dies in this window — the fight is still live')
  assert_lt(peak, 6, 'in-flight + animating Deliveries stay bounded (without pruning this would be ~50+)')


func test_actor_and_item_statuses_advance_identically() -> void:
  # A timed status on an actor and on an item must count down + expire on the SAME
  # step — item statuses are advanced uniformly, not skipped. High HP so the fight
  # outlasts the status duration.
  var p := _spawn(1000.0, [ItemCatalog.WEAPON])
  var e := _spawn(1000.0, [ItemCatalog.ENEMY_CLAW])
  var cm := _manager(p, [e])
  cm.start()
  StatusManager.apply(p, 'weak', 1.0, Balance.STATUS_WEAK_DURATION)            # timed status on the actor
  StatusManager.apply(p.board[0], 'weak', 1.0, Balance.STATUS_WEAK_DURATION)   # timed status on one of its items
  assert_true(_has_status(p, 'weak'), 'actor weak applied')
  assert_true(_item_has_status(p.board[0], 'weak'), 'item weak applied')

  var dur_steps: int = int(ceil(Balance.STATUS_WEAK_DURATION / Balance.STEP))
  for _i in dur_steps - 1:
    cm.sim_step()
  assert_true(_has_status(p, 'weak'), 'actor weak still ticking')
  assert_true(_item_has_status(p.board[0], 'weak'), 'item weak still ticking')

  cm.sim_step()   # the expiry step
  assert_false(_has_status(p, 'weak'), 'actor weak expired')
  assert_false(_item_has_status(p.board[0], 'weak'), 'item weak expired on the same step')


# --- spore engine seams (docs/systems/spore_engine.md) -----------------------------------

func _instant_damage_item(owner_actor: Actor, value: float) -> Item:
  var def := ItemDef.new()
  var hit := ItemEffect.new()
  hit.kind = Delivery.Kind.DAMAGE
  hit.value = value
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = 0.0
  def.effects = [hit]
  return Item.new(def, owner_actor)


func _status_count(actor: Actor, id: String) -> float:
  for s in actor.statuses:
    if s.id == id:
      return s.count
  return 0.0


func test_opponent_fuel_consume_scales_the_mass_hit() -> void:
  # Cap 1 (Mass): an item spends the TARGET's stacked spore for bonus damage. The target
  # isn't known at fire, so the Combat manager consumes it at Delivery spawn.
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  var cm := _manager(p, [e])
  cm.start()
  StatusManager.apply(e, 'poison', 5.0)
  var def := ItemDef.new()
  var hit := ItemEffect.new()
  hit.kind = Delivery.Kind.DAMAGE
  hit.value = 10.0
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = 0.0
  hit.consume_id = 'poison'
  hit.consume_amount = 4.0
  hit.consume_from_target = true   # opponent-fuel (Mass)
  hit.consume_scale = 3.0
  def.effects = [hit]

  var before: float = e.hp
  var arrived: Array = []
  cm._fire_item(Item.new(def, p), arrived)
  for d in arrived:
    cm._land(d)
  assert_almost_eq(before - e.hp, 10.0 + 4.0 * 3.0, 0.0001, 'Mass damage = base 10 + 4 poison consumed × 3')
  assert_almost_eq(_status_count(e, 'poison'), 1.0, 0.0001, 'the target spent 4 of 5 poison stacks')


func test_blinded_attacker_damage_whiffs() -> void:
  # Cap 2: a blinded actor still FIRES, but its DAMAGE Delivery is marked evaded at fire and
  # whiffs on land (no damage) — distinct from silence's "doesn't fire".
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  var cm := _manager(p, [e])
  cm.start()
  StatusManager.apply(p, 'blind', 1.0)
  var arrived: Array = []
  cm._fire_item(_instant_damage_item(p, 8.0), arrived)
  assert_eq(arrived.size(), 1, 'the attack still fired (a delivery spawned)')
  assert_true(arrived[0].evaded, 'a blinded attacker marks its damage evaded')
  var before: float = e.hp
  cm._land(arrived[0])
  assert_true(arrived[0].fizzled, 'the evaded swing whiffs on land')
  assert_almost_eq(e.hp, before, 0.0001, 'and deals no damage')


func test_blinded_attacker_nondamage_still_lands() -> void:
  # Evasion is damage-only (default): a blinded actor's status appliers still resolve.
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  var cm := _manager(p, [e])
  cm.start()
  StatusManager.apply(p, 'blind', 1.0)
  var def := ItemDef.new()
  var ap := ItemEffect.new()
  ap.kind = Delivery.Kind.APPLY_STATUS
  ap.status_id = 'poison'
  ap.value = 3.0
  ap.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  ap.travel = 0.0
  def.effects = [ap]
  var arrived: Array = []
  cm._fire_item(Item.new(def, p), arrived)
  assert_false(arrived[0].evaded, 'a non-damage delivery is not evaded')
  cm._land(arrived[0])
  assert_true(_has_status(e, 'poison'), 'the blinded actor still applies its status')


# --- mid-fight roster: summons + both-side rosters (docs/systems/spore_engine.md Cap 3) --

func _summon_item(owner_actor: Actor, token_id: String, in_front: bool = true) -> Item:
  var def := ItemDef.new()
  var s := ItemEffect.new()
  s.kind = Delivery.Kind.SUMMON
  s.summon_def_id = token_id
  s.summon_in_front = in_front
  s.shape = ItemEffect.Shape.SELF
  s.travel = 0.0
  def.effects = [s]
  return Item.new(def, owner_actor)


func test_summon_adds_a_token_to_the_players_side() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  var cm := _manager(p, [e])
  cm.start()
  var before: int = cm.player_side().size()
  var arrived: Array = []
  cm._fire_item(_summon_item(p, EnemyCatalog.SPORE_THRALL), arrived)
  for d in arrived:
    cm._land(d)
  assert_eq(cm.player_side().size(), before + 1, 'a token joined the player side')
  assert_eq(cm._leftmost_living_opponent(e), cm.player_side()[0], 'and is the enemy\'s leftmost target (body-block)')


func test_enemy_summon_adds_to_the_enemy_side() -> void:
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  var cm := _manager(p, [e])
  cm.start()
  var arrived: Array = []
  cm._fire_item(_summon_item(e, EnemyCatalog.SPORE_THRALL), arrived)
  for d in arrived:
    cm._land(d)
  assert_eq(cm.enemies.size(), 2, 'the enemy summoned an add onto its own side')


# --- reaping the combat-scoped dead vs. keeping a downed run-scoped ally ------

func test_dead_enemy_is_reaped_and_the_fight_continues() -> void:
  var p := Actor.new(1000.0)
  var e1 := _spawn(40.0, [ItemCatalog.ENEMY_CLAW])
  var e2 := _spawn(1000.0, [ItemCatalog.ENEMY_CLAW])
  var cm := _manager(p, [e1, e2])
  cm.start()
  e1.take_damage(50.0)         # slay e1 outright
  cm.sim_step()                # the reap runs this step
  assert_false(e1 in cm.enemies, 'the slain enemy was reaped from the roster')
  assert_true(e2 in cm.enemies, 'the living enemy remains')
  assert_false(cm.is_resolved(), 'and the fight continues (one enemy left)')


func test_dead_summon_token_is_reaped_like_an_enemy() -> void:
  var p := Actor.new(1000.0)
  var e := _spawn(1000.0, [ItemCatalog.ENEMY_CLAW])
  var cm := _manager(p, [e])
  cm.start()
  var token := _spawn(5.0, [ItemCatalog.ENEMY_CLAW])
  cm.add_actor(token, true, true)   # a combat-scoped player-side summon
  assert_true(token in cm.player_side(), 'the token joined the player side')
  token.take_damage(50.0)
  cm.sim_step()
  assert_false(token in cm.player_side(), 'a dead combat-scoped token is reaped like an enemy')


func test_downed_run_scoped_ally_stays_on_the_roster() -> void:
  var p := Actor.new(1000.0)
  var e := _spawn(1000.0, [ItemCatalog.ENEMY_CLAW])
  var ally := _spawn(5.0, [ItemCatalog.ENEMY_CLAW])
  var cm := CombatManager.new(p, [e], 0, [ally])
  _made.append(cm)
  cm.start()
  ally.take_damage(50.0)
  cm.sim_step()
  assert_true(ally in cm.allies, 'a downed run-scoped ally is NOT reaped — its slot stays')
  assert_false(ally.is_alive(), 'it is downed (out of combat, revived by the RunManager next fight)')


func test_dead_actor_items_stop_ticking_and_firing() -> void:
  # The bug a single-enemy fight hid: in a multi-body fight a slain body must stop swinging.
  var p := Actor.new(1000.0)
  var e1 := _spawn(40.0, [ItemCatalog.ENEMY_CLAW])
  var e2 := _spawn(1000.0, [ItemCatalog.ENEMY_CLAW])
  var cm := _manager(p, [e1, e2])
  cm.start()
  e1.take_damage(40.0)
  assert_false(e1.is_alive(), 'e1 is down')
  for _i in 10:
    cm.sim_step()
  assert_eq(e1.board[0].cooldown.accum, 0.0, 'a dead body\'s items neither tick nor fire')
  assert_gt(e2.board[0].cooldown.accum, 0.0, 'a living body\'s items still tick')


func test_player_token_body_blocks_then_exposes_the_player() -> void:
  var p := Actor.new(100.0)
  var e := Actor.new(100.0)
  var cm := _manager(p, [e])
  cm.start()
  var token := Actor.new(15.0)
  cm.add_actor(token, true, true)   # player side, in front
  assert_eq(cm._leftmost_living_opponent(e), token, 'the token body-blocks the player')
  token.take_damage(15.0)
  assert_eq(cm._leftmost_living_opponent(e), p, 'once it falls, the player is exposed')


func test_player_death_loses_even_with_a_living_token() -> void:
  var p := Actor.new(5.0)
  var e := Actor.new(100.0)
  var cm := _manager(p, [e])
  cm.start()
  cm.add_actor(Actor.new(15.0), true, true)
  watch_signals(cm)
  p.take_damage(5.0)
  cm._check_resolution()
  assert_signal_emitted(cm, 'resolved')
  assert_eq(get_signal_parameters(cm, 'resolved')[0], false, 'the player dying loses — a surviving token does not save the run')


func test_register_ally_joins_a_live_fight_and_survives_teardown() -> void:
  # A run-scoped ally acquired mid-fight: register_ally registers its items (it fights), it's
  # on the player side, and it is NOT dissolved at teardown (run-scoped, unlike a token).
  var p := Actor.new(1000.0)
  var e := Actor.new(1000.0)
  var ally := _spawn(50.0, [ItemCatalog.WEAPON])
  var cm := CombatManager.new(p, [e], 0, [])   # no starting allies
  cm.start()
  cm.allies.append(ally)        # mirror RunManager.add_ally (shared array)
  cm.register_ally(ally)
  assert_true(ally in cm.player_side(), 'the mid-fight ally is on the player side')
  for _i in 5:
    cm.sim_step()
  assert_gt(ally.board[0].cooldown.accum, 0.0, 'its items tick (registered into the live fight)')
  cm.teardown()
  cm.free()
  assert_eq(ally.board.size(), 1, 'a run-scoped ally is not dissolved at fight end')


func test_summoned_token_is_dissolved_but_run_scoped_side_survives() -> void:
  var p := _spawn(100.0, [ItemCatalog.WEAPON])
  var ally := _spawn(50.0, [ItemCatalog.WEAPON])
  var e := _spawn(40.0, [ItemCatalog.ENEMY_CLAW])
  var cm := CombatManager.new(p, [e], 0, [ally])   # ally is run-scoped (passed in)
  cm.start()
  var token := _spawn(15.0, [ItemCatalog.ENEMY_CLAW])
  cm.add_actor(token, true, true)                  # token is combat-scoped (summoned)
  var weak_token: WeakRef = weakref(token)
  var weak_token_item: WeakRef = weakref(token.board[0])
  cm.teardown()
  cm.free()
  token = null
  assert_null(weak_token.get_ref(), 'a combat-scoped token frees at fight end')
  assert_null(weak_token_item.get_ref(), 'and its board items free')
  assert_eq(p.board.size(), 1, 'the run-scoped player keeps its board')
  assert_eq(ally.board.size(), 1, 'a run-scoped ally is NOT dissolved')


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
  p.board.append(Item.new(ItemCatalog.get_def(ItemCatalog.HEX_BOLT), p))
  var e := Actor.new(5000.0)
  for _i in 4:
    e.board.append(Item.new(ItemCatalog.get_def(ItemCatalog.ENEMY_CLAW), e))
  var cm := CombatManager.new(p, [e], combat_seed)
  _made.append(cm)
  cm.start()
  for _i in 1000:
    cm.sim_step()
    for idx in e.board.size():
      if _item_has_status(e.board[idx], 'silence'):
        return idx
  return -1


func test_item_target_with_no_enemy_items_yields_no_targets() -> void:
  # An item-target shape against an opponent with an empty board resolves to no targets
  # (the firing item just lands nothing — no crash, no phantom target).
  var p := Actor.new(100.0)
  var e := Actor.new(100.0)   # no board items
  var cm := _manager(p, [e])
  cm.start()
  var payload := Payload.new()
  payload.shape = ItemEffect.Shape.OPPONENT_ITEM_RANDOM
  assert_eq(cm._resolve_targets(payload, p).size(), 0, 'no enemy items → no item targets')


func test_dot_tick_through_block_does_not_skip_a_later_status() -> void:
  # A poison tick calls take_damage, which can erase a depleted block from the SAME
  # status list the step-pass is walking. A naive in-place loop would then skip the
  # status after block. Set up [block, poison, weak] with poison about to tick and
  # block small enough to be fully consumed — weak must still advance this pass.
  var p := Actor.new(100.0)
  var a := Actor.new(100.0)
  var cm := _manager(p, [a])
  cm.start()
  StatusManager.apply(a, 'block', 1.0)          # one poison tick empties it
  var pois: StatusEffect = StatusManager.apply(a, 'poison', 3.0)
  pois.ticker.accum = pois.ticker.threshold - 1.0            # fire on the next advance
  var weak: StatusEffect = StatusManager.apply(a, 'weak', 1.0, Balance.STATUS_WEAK_DURATION)   # after poison in the list

  cm._advance_statuses_on(a)

  assert_eq(weak.ticker.accum, 1.0, 'the status after block still advanced (no skip)')
  assert_false(_has_status(a, 'block'), 'block was consumed and erased mid-pass')
  assert_eq(a.hp, 98.0, 'poison dealt 3, block absorbed 1, 2 leaked to HP')


func test_dot_tick_shows_a_visual_on_the_wall() -> void:
  # A DoT tick applies damage inside the status pass (no Delivery lands), so the wall
  # would show nothing. We spawn a visual-only Delivery carrying the tick's number.
  var p := Actor.new(100.0)
  var a := Actor.new(100.0)
  var cm := _manager(p, [a])
  cm.start()
  var pois: StatusEffect = StatusManager.apply(a, 'poison', 3.0)
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
  var e := _spawn(40.0, [ItemCatalog.ENEMY_CLAW])
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
  var p := _spawn(1000.0, [ItemCatalog.WEAPON])
  var e := _spawn(1000.0, [ItemCatalog.ENEMY_CLAW])
  var cm := _manager(p, [e])
  cm.start()
  for _i in 20:
    cm.sim_step()
  assert_gt(p.board[0].cooldown.accum, 0.0, 'the weapon charged partway through fight 1')
  cm.teardown()   # the player survives teardown (only its statuses clear); its board persists

  # A new fight with the SAME persistent player board must start the item fresh.
  var e2 := _spawn(1000.0, [ItemCatalog.ENEMY_CLAW])
  var cm2 := _manager(p, [e2])
  cm2.start()
  assert_eq(p.board[0].cooldown.accum, 0.0, 'fight 2 starts every board item at a fresh cooldown')


func test_teardown_clears_combat_state() -> void:
  var p := _spawn(Balance.PLAYER_START_HP, [ItemCatalog.POISON_DAGGER])
  var e := _spawn(Balance.ENEMY_PLACEHOLDER_HP, [ItemCatalog.ENEMY_CLAW])
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
  var p := _spawn(Balance.PLAYER_START_HP, [ItemCatalog.WEAPON])
  var e := _spawn(Balance.ENEMY_PLACEHOLDER_HP, [ItemCatalog.ENEMY_CLAW])
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
  var p := _spawn(Balance.PLAYER_START_HP, [ItemCatalog.WEAPON])
  var e := _spawn(Balance.ENEMY_PLACEHOLDER_HP, [ItemCatalog.ENEMY_CLAW])
  var cm := _manager(p, [e])
  cm.start()
  cm.request_slowmo(true)
  assert_almost_eq(cm.timekeeper.effective_scale(), Balance.TIMESCALE_SLOWMO, 0.0001, 'hover slows the clock')
  cm.request_slowmo(false)
  assert_almost_eq(cm.timekeeper.effective_scale(), Balance.TIMESCALE_BASE, 0.0001, 'exit returns to base')


# --- Event-bus source identity (decision #30) ---

## A trigger item that never fires on its own cooldown, so any block it grants MUST
## come from its trigger push. `source_filter` omitted = the OWN_SIDE content default.
func _never_fires_avenger(source_filter: int = -1) -> ItemDef:
  var def := ItemDef.new()
  def.cooldown = 9999.0
  var blk := ItemEffect.new()
  blk.kind = Delivery.Kind.APPLY_STATUS
  blk.status_id = 'block'
  blk.value = 5.0
  blk.shape = ItemEffect.Shape.SELF
  def.effects = [blk]
  var sub := {
    'event': EventBus.Event.STATUS_APPLIED,
    'amount': Balance.TRIGGER_PUSH_FULL,
    'filter': 'poison',
  }
  if source_filter >= 0:
    sub['source_filter'] = source_filter
  def.trigger_subs = [sub]
  return def


func test_enemy_poison_does_not_charge_own_side_trigger() -> void:
  # Decision #30 headline: a trigger defaults to "when MY side applies X" — an
  # ENEMY-applied poison must not charge the player's reactive item.
  var p := Actor.new(500.0)
  p.board.append(Item.new(_never_fires_avenger(), p))
  var e := Actor.new(500.0)
  e.board.append(Item.new(ItemCatalog.get_def(ItemCatalog.POISON_DAGGER), e))
  var cm := _manager(p, [e])
  cm.start()
  var guard := 0
  while not _has_status(p, 'poison') and guard < 1000:
    cm.sim_step()
    guard += 1
  assert_true(_has_status(p, 'poison'), 'the enemy poisoned the player')
  cm.sim_step()
  cm.sim_step()
  assert_false(_has_status(p, 'block'), "the enemy's application charged nothing (OWN_SIDE default)")


func test_opponent_side_filter_inverts_the_default() -> void:
  var p := Actor.new(500.0)
  p.board.append(Item.new(_never_fires_avenger(EventBus.SourceFilter.OPPONENT_SIDE), p))
  var e := Actor.new(500.0)
  e.board.append(Item.new(ItemCatalog.get_def(ItemCatalog.POISON_DAGGER), e))
  var cm := _manager(p, [e])
  cm.start()
  var guard := 0
  while not _has_status(p, 'poison') and guard < 1000:
    cm.sim_step()
    guard += 1
  cm.sim_step()
  assert_true(_has_status(p, 'block'), "an OPPONENT_SIDE sub charges off the enemy's application")


func test_summoned_token_trigger_resolves_own_side_at_event_time() -> void:
  # add_actor subscribes BEFORE roster insertion — side must resolve at event time,
  # or a summon's trigger would never see its own side's events.
  var p := Actor.new(500.0)
  p.board.append(Item.new(ItemCatalog.get_def(ItemCatalog.POISON_DAGGER), p))
  var e := Actor.new(500.0)
  var cm := _manager(p, [e])
  cm.start()
  var token := Actor.new(50.0)
  token.board.append(Item.new(_never_fires_avenger(), token))
  cm.add_actor(token, true)
  var guard := 0
  while not _has_status(e, 'poison') and guard < 1000:
    cm.sim_step()
    guard += 1
  assert_true(_has_status(e, 'poison'), "the player's poison landed")
  cm.sim_step()
  assert_true(_has_status(token, 'block'), "the player-side token's trigger charged off its own side")


func test_reaped_actors_trigger_item_receives_no_pushes() -> void:
  # _reap_from unsubscribes a dead body's items — no zombie pushes into its tickers.
  # A SECOND living enemy keeps the fight (and the poison applications) going, so a
  # still-subscribed item WOULD be pushed — the assertion is not vacuous.
  var p := Actor.new(500.0)
  p.board.append(Item.new(ItemCatalog.get_def(ItemCatalog.POISON_DAGGER), p))
  var dies := Actor.new(50.0)
  var reactive := ItemDef.new()
  reactive.cooldown = 9999.0
  reactive.trigger_subs = [{
    'event': EventBus.Event.STATUS_APPLIED,
    'amount': Balance.TRIGGER_PUSH_FULL,
    'filter': 'poison',
    'source_filter': EventBus.SourceFilter.ANY,
  }]
  var reactive_item := Item.new(reactive, dies)
  dies.board.append(reactive_item)
  var survives := Actor.new(100000.0)
  var cm := _manager(p, [dies, survives])
  cm.start()
  dies.take_damage(999.0)
  cm.sim_step()   # reaps the dead enemy
  assert_false(cm.enemies.has(dies), 'the dead enemy left the roster')
  var accum_at_reap: float = reactive_item.cooldown.accum
  var guard := 0
  var poison_landed := false
  while guard < 1000:
    cm.sim_step()
    guard += 1
    if _has_status(survives, 'poison'):
      poison_landed = true
      break
  cm.sim_step()   # the push (if any, wrongly) would convert on the next step
  assert_true(poison_landed, 'poison kept landing on the surviving enemy')
  assert_eq(reactive_item.cooldown.accum, accum_at_reap, 'no pushes reached the reaped item')


func test_subscribed_trigger_item_frees_after_teardown() -> void:
  # The bus now holds strong Subscription -> Item refs; teardown's bus.clear() must
  # release them (the current leak tests use the sub-less claw — this covers triggers).
  var p := _spawn(Balance.PLAYER_START_HP, [])
  var e := Actor.new(40.0)
  e.board.append(Item.new(ItemCatalog.get_def(ItemCatalog.AVENGER), e))
  var cm := _manager(p, [e])
  cm.start()
  var item_ref: WeakRef = weakref(e.board[0])
  cm.teardown()
  assert_null(item_ref.get_ref(), 'a subscribed trigger item frees after teardown')


func test_item_fired_event_carries_item_and_owner() -> void:
  var p := _spawn(Balance.PLAYER_START_HP, [ItemCatalog.WEAPON])
  var e := _spawn(1000.0, [])
  var cm := _manager(p, [e])
  cm.start()
  var seen: Array = []
  cm.bus.add_listener(EventBus.Event.ITEM_FIRED,
      func(data, source_actor, source_item) -> void:
        seen.append([data, source_actor, source_item]))
  var guard := 0
  while seen.is_empty() and guard < 1000:
    cm.sim_step()
    guard += 1
  assert_eq(seen.size(), 1, 'the first fire was observed')
  assert_eq(seen[0][0], ItemCatalog.WEAPON, 'ITEM_FIRED data is the def id')
  assert_eq(seen[0][1], p, 'source actor is the owner')
  assert_eq(seen[0][2], p.board[0], 'source item is the firing item')


func test_thrown_consumable_event_carries_the_thrower() -> void:
  var p := _spawn(Balance.PLAYER_START_HP, [])
  var e := _spawn(1000.0, [])
  var cm := _manager(p, [e])
  cm.start()
  var seen: Array = []
  cm.bus.add_listener(EventBus.Event.DAMAGE_DEALT,
      func(_data, source_actor, source_item) -> void:
        seen.append([source_actor, source_item]))
  var def := ConsumableDef.new()
  def.id = 'test_dart'
  def.name_key = 'Test Dart'
  var effect := ItemEffect.new()
  effect.kind = Delivery.Kind.DAMAGE
  effect.value = 5.0
  effect.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  effect.travel = 0.0
  def.effects = [effect]
  cm.throw_consumable(Consumable.new(def), p)
  assert_eq(seen.size(), 1, 'the throw published DAMAGE_DEALT')
  assert_eq(seen[0][0], p, 'source actor is the thrower')
  assert_null(seen[0][1], 'source item is null — a throw has no firing Item')


func test_fight_with_triggers_is_deterministic() -> void:
  var results: Array = []
  for _round in 2:
    var p := Actor.new(200.0)
    p.board.append(Item.new(ItemCatalog.get_def(ItemCatalog.POISON_DAGGER), p))
    p.board.append(Item.new(ItemCatalog.get_def(ItemCatalog.AVENGER), p))
    var e := _spawn(200.0, [ItemCatalog.ENEMY_CLAW])
    var cm := _manager(p, [e])
    cm.start()
    var steps := cm.run_headless()
    results.append({ 'steps': steps, 'hp': p.hp, 'won': cm.player_won() })
  assert_eq(results[0]['steps'], results[1]['steps'], 'same step count with triggers live')
  assert_almost_eq(results[0]['hp'], results[1]['hp'], 0.0001, 'identical final HP')
  assert_eq(results[0]['won'], results[1]['won'], 'same winner')


# --- Review fixes: gate freeze · same-step death · throw resolution · guards ---

## Observes on_expire at the Combat manager's timed-expiry removal site.
class ExpiryProbeStatus extends TimedStatus:
  var expired_called: bool = false


  func _init() -> void:
    id = 'expiry_probe'


  func on_expire(_target, _ctx) -> void:
    expired_called = true


func test_gated_item_cooldown_freezes_and_lifts_without_burst() -> void:
  # Decision #30: a gate (silence) FREEZES the cooldown — no accrual while gated, so
  # the gate lifting releases no banked burst; the first fire lands one full cooldown
  # after the lift.
  var p := _spawn(Balance.PLAYER_START_HP, [ItemCatalog.WEAPON])
  var e := _spawn(1000.0, [])
  var cm := _manager(p, [e])
  cm.start()
  var weapon: Item = p.board[0]
  var silence: StatusEffect = StatusManager.apply(weapon, 'silence', 1.0)
  var threshold := int(weapon.cooldown.threshold)
  for _i in threshold * 3:
    cm.sim_step()
  assert_eq(weapon.cooldown.accum, 0.0, 'a gated cooldown holds at zero — nothing banked')
  assert_true(cm.deliveries().is_empty(), 'no fires while gated')
  weapon.statuses.erase(silence)   # lift the gate (a timed gate would expire the same way)
  for _i in threshold - 1:
    cm.sim_step()
  assert_true(cm.deliveries().is_empty(), 'no instant fire on the lift — the cooldown restarts')
  cm.sim_step()
  assert_eq(cm.deliveries().size(), 1, 'exactly one fire, one full cooldown after the lift')


func test_dot_killed_actor_does_not_fire_collected_swing() -> void:
  # The status pass runs AFTER crossings are collected, so a poison tick can kill an
  # actor whose item crossed this same step — the collected swing must be suppressed.
  var p := _spawn(Balance.PLAYER_START_HP, [])
  var e := _spawn(10.0, [ItemCatalog.ENEMY_CLAW])
  var cm := _manager(p, [e])
  cm.start()
  var claw: Item = e.board[0]
  claw.cooldown.accum = claw.cooldown.threshold - 1.0    # crosses next step
  var poison: StatusEffect = StatusManager.apply(e, 'poison', 99.0)
  poison.ticker.accum = poison.ticker.threshold - 1.0    # ticks (lethally) the same step
  var hp_before: float = p.hp
  cm.sim_step()
  assert_false(e.is_alive(), 'the poison tick killed the enemy this step')
  for _i in 60:   # long enough for any (wrongly) launched swing to land
    cm.sim_step()
  assert_eq(p.hp, hp_before, "the dead enemy's collected swing never fired")


func test_lethal_potion_resolves_fight_without_a_step() -> void:
  # A throw can land outside the step loop (paused, timescale 0): resolution must not
  # wait for a sim_step that never comes.
  var p := _spawn(Balance.PLAYER_START_HP, [])
  var e := _spawn(10.0, [ItemCatalog.ENEMY_CLAW])
  var cm := _manager(p, [e])
  cm.start()
  var def := ConsumableDef.new()
  def.id = 'test_bomb'
  def.name_key = 'Test Bomb'
  var effect := ItemEffect.new()
  effect.kind = Delivery.Kind.DAMAGE
  effect.value = 50.0
  effect.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  effect.travel = 0.0
  def.effects = [effect]
  cm.throw_consumable(Consumable.new(def), p)
  assert_true(cm.is_resolved(), 'the lethal throw resolved the fight immediately')
  assert_true(cm.player_won(), 'and the player won it')


func test_status_applied_event_only_published_on_success() -> void:
  # An unknown status id applies nothing — no STATUS_APPLIED event may be routed for it.
  var p := _spawn(Balance.PLAYER_START_HP, [])
  var e := _spawn(1000.0, [])
  var cm := _manager(p, [e])
  cm.start()
  var probe := Ticker.new(100)
  cm.bus.subscribe(EventBus.Event.STATUS_APPLIED, probe, 1.0, null)
  cm._land(_status_delivery(e, 'nonexistent_status'))
  assert_eq(probe.accum, 0.0, 'an unknown id publishes no event')
  cm._land(_status_delivery(e, 'block'))
  assert_gt(probe.accum, 0.0, 'a real apply still publishes')


func test_free_while_mounted_breaks_cycles_via_exit_tree() -> void:
  # The _exit_tree safety net: a CombatManager freed while in the tree must break the
  # enemy Actor<->Item cycle even when nobody called teardown() first.
  var p := _spawn(Balance.PLAYER_START_HP, [])
  var e := _spawn(40.0, [ItemCatalog.ENEMY_CLAW])
  var cm := CombatManager.new(p, [e])
  cm.start()
  add_child(cm)
  var item_ref: WeakRef = weakref(e.board[0])
  cm.free()
  assert_null(item_ref.get_ref(), 'freeing a mounted manager dissolved the enemy board')


func test_timed_expiry_calls_on_expire() -> void:
  # The Combat manager's status pass is one of the three natural-removal sites — the
  # hook must run there (the facade's two sites are covered in test_status_manager).
  var p := _spawn(Balance.PLAYER_START_HP, [])
  var e := _spawn(1000.0, [])
  var cm := _manager(p, [e])
  cm.start()
  var probe := ExpiryProbeStatus.new()
  probe.setup(1.0, 0.1, null, 0)
  p.statuses.append(probe)
  for _i in int(probe.ticker.threshold) + 1:
    cm.sim_step()
  assert_true(probe.expired_called, 'on_expire ran at timed expiry')
  assert_false(p.statuses.has(probe), 'and the expired status was removed')


func _status_delivery(target, status_id: String) -> Delivery:
  var d := Delivery.new()
  d.kind = Delivery.Kind.APPLY_STATUS
  d.status_id = status_id
  d.value = 1.0
  d.target = target
  d.travel = Ticker.new(0)
  return d


func test_physics_process_drives_tick_when_mounted() -> void:
  # A directly-mounted CombatManager (the sandbox) must still self-drive: its
  # _physics_process delegates to tick(). Mount it, run a couple of physics frames,
  # and confirm the clock advanced. Not via _manager — we own its lifetime here.
  var p := _spawn(Balance.PLAYER_START_HP, [ItemCatalog.WEAPON])
  var e := _spawn(Balance.ENEMY_PLACEHOLDER_HP, [ItemCatalog.ENEMY_CLAW])
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
